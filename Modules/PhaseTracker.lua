-- PhaseTracker.lua - 位面检测服务

local ADDON_NAME = "PhaseDetector"
local addon = _G[ADDON_NAME]

local PhaseTracker = {}
addon.PhaseTracker = PhaseTracker

PhaseTracker.lastReportedMapID = nil
PhaseTracker.lastReportedPhaseID = nil
PhaseTracker.lastSeenMapID = nil
PhaseTracker.phaseCache = {}
PhaseTracker.isPaused = false
PhaseTracker.lastTargetGUID = nil
PhaseTracker.lastMouseoverGUID = nil

local InCombatLockdown = InCombatLockdown
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitPlayerControlled = UnitPlayerControlled
local UnitIsOtherPlayersPet = UnitIsOtherPlayersPet
local UnitIsOtherPlayersBattlePet = UnitIsOtherPlayersBattlePet
local UnitIsBattlePet = UnitIsBattlePet
local UnitIsWildBattlePet = UnitIsWildBattlePet
local UnitInVehicle = UnitInVehicle
local UnitUsingVehicle = UnitUsingVehicle
local UnitCreatureID = UnitCreatureID
local strsplit = strsplit
local tonumber = tonumber
local C_Map_GetBestMapForUnit = C_Map and C_Map.GetBestMapForUnit or nil
local C_Map_GetMapInfo = C_Map and C_Map.GetMapInfo or nil
local C_PvP_IsInBrawl = C_PvP and C_PvP.IsInBrawl or nil
local C_PvP_IsRatedMap = C_PvP and C_PvP.IsRatedMap or nil
local C_PvP_IsActiveBattlefield = C_PvP and C_PvP.IsActiveBattlefield or nil
local C_GUIDUtil_GetCreatureID = C_GUIDUtil and C_GUIDUtil.GetCreatureID or nil
local IsInInstance = IsInInstance

-- 玩家坐骑随行 NPC（商人/拍卖师/幻化师/车夫等）黑名单
-- 来源：Warcraft Wiki 分类 "NPCs on player mounts" 与对应 Wowhead NPC 链接
local EXCLUDED_PLAYER_MOUNT_NPC_IDS = {
    [32638] = true,   -- Hakmud of Argus
    [32639] = true,   -- Gnimo
    [32641] = true,   -- Drix Blackwrench
    [32642] = true,   -- Mojodishu
    [62821] = true,   -- Mystic Birdhat
    [62822] = true,   -- Cousin Slowhands
    [64515] = true,   -- Mystic Birdhat (variant)
    [64516] = true,   -- Cousin Slowhands (variant)
    [89713] = true,   -- Koak Hoburn
    [89715] = true,   -- Franklin Martin
    [128288] = true,  -- Hakmud of Argus (Argus variant)
    [142666] = true,  -- Collector Unta
    [142668] = true,  -- Merchant Maku
}

local cachedMapID = nil
local cachedMapName = nil

local function GetDisplay()
    return addon.PhaseDisplay
end

local function HideDisplay()
    local display = GetDisplay()
    if display and display.Hide then
        display:Hide()
    end
end

local function IsInRestrictedEnvironment()
    -- 检查是否在副本中
    if IsInInstance and IsInInstance() then
        -- instanceType: "pvp" (战场), "arena" (竞技场), "party" (5人本), "raid" (团本), "scenario" (场景战役)
        return true
    end

    -- 检查 PvP 环境
    if C_PvP_IsInBrawl and C_PvP_IsInBrawl() then
        return true
    end

    if C_PvP_IsRatedMap and C_PvP_IsRatedMap() then
        return true
    end

    if C_PvP_IsActiveBattlefield and C_PvP_IsActiveBattlefield() then
        return true
    end

    return false
end

local function SendSystemMessageToPlayer(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        local info = ChatTypeInfo and ChatTypeInfo["SYSTEM"]
        if info then
            DEFAULT_CHAT_FRAME:AddMessage(message, info.r, info.g, info.b)
        else
            DEFAULT_CHAT_FRAME:AddMessage(message)
        end
    else
        print(message)
    end
end

local function ResetPhaseState(self)
    self.phaseCache = {}
    self.lastReportedMapID = nil
    self.lastReportedPhaseID = nil
end

local function ResetMapState(self)
    ResetPhaseState(self)
    self.lastSeenMapID = nil
end

local function ResetUnitState(self)
    self.lastTargetGUID = nil
    self.lastMouseoverGUID = nil
end

local function ResetDetectionState(self)
    ResetMapState(self)
    ResetUnitState(self)
end

local function IsIgnoredUnit(unit)
    if not unit or not UnitExists or not UnitExists(unit) then
        return true
    end

    if UnitIsPlayer and UnitIsPlayer(unit) then
        return true
    end

    if UnitPlayerControlled and UnitPlayerControlled(unit) then
        return true
    end

    if UnitIsOtherPlayersPet and UnitIsOtherPlayersPet(unit) then
        return true
    end

    if UnitIsOtherPlayersBattlePet and UnitIsOtherPlayersBattlePet(unit) then
        return true
    end

    if UnitIsBattlePet and UnitIsBattlePet(unit) then
        return true
    end

    if UnitIsWildBattlePet and UnitIsWildBattlePet(unit) then
        return true
    end

    -- 玩家坐骑上的商人/拍卖师等通常作为“在载具中的单位”暴露出来。
    if UnitInVehicle and UnitInVehicle(unit) then
        return true
    end

    if UnitUsingVehicle and UnitUsingVehicle(unit) then
        return true
    end

    return false
end

local function GetCreatureIDFromUnit(unit, guid)
    if UnitCreatureID then
        local creatureID = UnitCreatureID(unit)
        if creatureID then
            return tonumber(creatureID)
        end
    end

    if C_GUIDUtil_GetCreatureID then
        local creatureID = C_GUIDUtil_GetCreatureID(guid)
        if creatureID then
            return tonumber(creatureID)
        end
    end

    local _, _, _, _, _, npcID = strsplit("-", guid)
    if npcID then
        return tonumber(npcID)
    end

    return nil
end

function PhaseTracker:Initialize()
    ResetDetectionState(self)
    self.isPaused = false
end

function PhaseTracker:IsRestrictedEnvironment()
    return IsInRestrictedEnvironment()
end

function PhaseTracker:ResetUnitCache()
    ResetUnitState(self)
end

function PhaseTracker:GetPhaseFromUnit(unit, guid)
    if not guid or IsIgnoredUnit(unit) then
        return nil
    end

    local unitType, _, serverID, _, zoneUID = strsplit("-", guid)
    if not unitType then
        return nil
    end

    local numericNpcID = GetCreatureIDFromUnit(unit, guid)

    if numericNpcID and EXCLUDED_PLAYER_MOUNT_NPC_IDS[numericNpcID] then
        return nil
    end

    -- 位面ID = ServerID-ZoneUID（GUID第3和第5部分）
    if unitType == "Creature" and serverID and zoneUID then
        return serverID .. "-" .. zoneUID
    end

    return nil
end

-- 性能优化：只在目标变化时获取位面ID
function PhaseTracker:GetPhaseFromTarget()
    local guid = UnitGUID("target")

    -- 如果目标 GUID 没有变化，跳过处理
    if guid == self.lastTargetGUID then
        return nil
    end

    -- 无论是否可解析，都记录最新 GUID，避免“不可解析单位 -> 原NPC”漏检
    self.lastTargetGUID = guid
    return self:GetPhaseFromUnit("target", guid)
end

-- 性能优化：只在鼠标指向变化时获取位面ID
function PhaseTracker:GetPhaseFromMouseover()
    local guid = UnitGUID("mouseover")

    -- 如果鼠标指向 GUID 没有变化，跳过处理
    if guid == self.lastMouseoverGUID then
        return nil
    end

    -- 无论是否可解析，都记录最新 GUID，避免“不可解析单位 -> 原NPC”漏检
    self.lastMouseoverGUID = guid
    return self:GetPhaseFromUnit("mouseover", guid)
end

function PhaseTracker:GetCurrentMapInfo()
    if not C_Map_GetBestMapForUnit or not C_Map_GetMapInfo then
        return nil, nil
    end

    local mapID = C_Map_GetBestMapForUnit("player")
    if not mapID then
        return nil, nil
    end

    -- 如果地图ID没变，直接返回缓存
    if mapID == cachedMapID and cachedMapName then
        return cachedMapID, cachedMapName
    end

    local mapInfo = C_Map_GetMapInfo(mapID)
    if not mapInfo then
        return nil, nil
    end

    -- 更新缓存
    cachedMapID = mapID
    cachedMapName = mapInfo.name

    return mapID, mapInfo.name
end

function PhaseTracker:AnnouncePhase(mapName, phaseID, isFirstTime)
    if not addon.db or not addon.db.enabled then
        return
    end

    local L = addon.L or {}
    local template
    if isFirstTime then
        template = L["PhaseDetectedFirstTime"] or "Current phase in %s is: %s"
    else
        template = L["PhaseChanged"] or "Current phase in %s has changed to: %s"
    end

    local message = string.format(template, mapName, phaseID)
    SendSystemMessageToPlayer(message)
end

-- 性能优化：事件驱动的位面信息更新
function PhaseTracker:UpdatePhaseInfo(eventType)
    if not addon.db or not addon.db.enabled then
        return
    end

    -- 在战场/副本等受限环境中强制暂停，避免任何后续检测调用
    if IsInRestrictedEnvironment() then
        if not self.isPaused then
            self:PauseDetection()
        end
        return
    end

    -- 如果已暂停，离开受限环境后恢复
    if self.isPaused then
        self:ResumeDetection()
    end

    -- 在战斗中禁用功能
    if InCombatLockdown() then
        return
    end

    local mapID, mapName = self:GetCurrentMapInfo()
    if not mapID or not mapName then
        return
    end

    -- 直接使用 mapID 作为缓存键，避免同名地图冲突与字符串分配
    local mapKey = mapID

    -- 地图切换时清理缓存
    if self.lastSeenMapID and self.lastSeenMapID ~= mapKey then
        ResetPhaseState(self)
        ResetUnitState(self)
        HideDisplay()
    end

    local detectedPhaseID = nil
    if eventType == "PLAYER_TARGET_CHANGED" then
        detectedPhaseID = self:GetPhaseFromTarget()
    elseif eventType == "UPDATE_MOUSEOVER_UNIT" then
        detectedPhaseID = self:GetPhaseFromMouseover()
    end

    if not detectedPhaseID then
        return
    end

    local cachedPhaseID = self.phaseCache[mapKey]
    local mapChanged = self.lastSeenMapID ~= mapKey
    local shouldAnnounce = false
    local isFirstTime = false

    if mapChanged then
        shouldAnnounce = true
        isFirstTime = true
    elseif cachedPhaseID ~= detectedPhaseID then
        shouldAnnounce = true
        isFirstTime = (cachedPhaseID == nil)
    end

    self.phaseCache[mapKey] = detectedPhaseID
    self.lastSeenMapID = mapKey

    local display = GetDisplay()
    if display and display.UpdatePhaseDisplay then
        display:UpdatePhaseDisplay(detectedPhaseID)
    end

    if shouldAnnounce then
        -- 避免重复通知相同的地图和位面组合
        if self.lastReportedMapID ~= mapKey or self.lastReportedPhaseID ~= detectedPhaseID then
            self:AnnouncePhase(mapName, detectedPhaseID, isFirstTime)
            self.lastReportedMapID = mapKey
            self.lastReportedPhaseID = detectedPhaseID
        end
    end
end

-- 暂停检测（进入受限环境时）
function PhaseTracker:PauseDetection()
    if self.isPaused then
        return
    end

    self.isPaused = true

    HideDisplay()

    -- 清理缓存
    ResetUnitState(self)
end

-- 恢复检测（离开受限环境时）
function PhaseTracker:ResumeDetection()
    if not self.isPaused then
        return
    end

    self.isPaused = false
    ResetDetectionState(self)
end
