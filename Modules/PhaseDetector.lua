-- PhaseDetector.lua - 位面检测模块

local ADDON_NAME = "PhaseDetector"
local addon = _G[ADDON_NAME]

local PhaseDetector = {}
addon.PhaseDetector = PhaseDetector

-- 位面检测状态
PhaseDetector.lastReportedMapID = nil
PhaseDetector.lastReportedPhaseID = nil
PhaseDetector.lastSeenMapID = nil
PhaseDetector.phaseCache = {}
PhaseDetector.isRunning = false
PhaseDetector.phaseFrame = nil
PhaseDetector.eventFrame = nil
PhaseDetector.isPaused = false  -- 新增：暂停状态标记

-- 性能优化：缓存上次检测的 GUID，避免重复处理相同目标
PhaseDetector.lastTargetGUID = nil
PhaseDetector.lastMouseoverGUID = nil

-- 性能优化：缓存 API 调用
local InCombatLockdown = InCombatLockdown
local UnitGUID = UnitGUID
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

local function GetCreatureIDFromGUID(guid)
    if not guid then
        return nil
    end

    if C_GUIDUtil_GetCreatureID then
        local creatureID = C_GUIDUtil_GetCreatureID(guid)
        if creatureID then
            return tonumber(creatureID)
        end
    end

    local _, _, _, _, _, npcID = strsplit("-", guid)
    if not npcID then
        return nil
    end

    return tonumber(npcID)
end

-- 安全检查：是否在受限环境中（副本、战场、竞技场等）
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

function PhaseDetector:Initialize()
    self.phaseCache = {}
    self.lastReportedMapID = nil
    self.lastReportedPhaseID = nil
    self.lastSeenMapID = nil
    self.lastTargetGUID = nil
    self.lastMouseoverGUID = nil
    self.isPaused = false

    self:CreatePhaseDisplay()
end

function PhaseDetector:GetPhaseFromGUID(guid)
    if not guid then
        return nil
    end

    local unitType, _, shardID, instancePart = strsplit("-", guid)
    if not unitType then
        return nil
    end

    local numericNpcID = GetCreatureIDFromGUID(guid)
    if numericNpcID and EXCLUDED_PLAYER_MOUNT_NPC_IDS[numericNpcID] then
        return nil
    end
    
    -- 位面ID = 分片ID-实例ID（GUID第3-4部分）
    if unitType == "Creature" and shardID and instancePart then
        return shardID .. "-" .. instancePart
    end

    return nil
end

-- 性能优化：只在目标变化时获取位面ID
function PhaseDetector:GetPhaseFromTarget()
    local guid = UnitGUID("target")
    
    -- 如果目标 GUID 没有变化，跳过处理
    if guid == self.lastTargetGUID then
        return nil
    end

    local phaseID = self:GetPhaseFromGUID(guid)
    if phaseID then
        self.lastTargetGUID = guid
    elseif not guid then
        self.lastTargetGUID = nil
    end

    return phaseID
end

-- 性能优化：只在鼠标指向变化时获取位面ID
function PhaseDetector:GetPhaseFromMouseover()
    local guid = UnitGUID("mouseover")
    
    -- 如果鼠标指向 GUID 没有变化，跳过处理
    if guid == self.lastMouseoverGUID then
        return nil
    end

    local phaseID = self:GetPhaseFromGUID(guid)
    if phaseID then
        self.lastMouseoverGUID = guid
    elseif not guid then
        self.lastMouseoverGUID = nil
    end

    return phaseID
end


function PhaseDetector:CreatePhaseDisplay()
    if self.phaseFrame then
        return
    end

    local frame = CreateFrame("Frame", "PhaseDetectorPhaseFrame", UIParent)
    frame:SetSize(220, 24)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -20)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()

        local screenWidth = UIParent:GetWidth()
        local screenHeight = UIParent:GetHeight()
        local centerX, centerY = selfFrame:GetCenter()
        local halfWidth = selfFrame:GetWidth() / 2
        local halfHeight = selfFrame:GetHeight() / 2

        if not centerX or not centerY or not screenWidth or not screenHeight then
            return
        end

        if centerX < halfWidth then
            centerX = halfWidth
        elseif centerX > (screenWidth - halfWidth) then
            centerX = screenWidth - halfWidth
        end

        if centerY < halfHeight then
            centerY = halfHeight
        elseif centerY > (screenHeight - halfHeight) then
            centerY = screenHeight - halfHeight
        end

        selfFrame:ClearAllPoints()
        selfFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
    end)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")

    frame.text = text
    frame:Hide()

    self.phaseFrame = frame
end

function PhaseDetector:UpdatePhaseDisplay(phaseID)
    if not self.phaseFrame then
        return
    end

    -- 在战斗中跳过 UI 更新，避免潜在的保护问题
    if InCombatLockdown() then
        return
    end

    if not phaseID then
        self.phaseFrame:Hide()
        return
    end

    local L = addon.L or {}
    local line = string.format(L["ScreenPhaseID"] or "Phase ID: %s", phaseID)
    self.phaseFrame.text:SetText(line)
    self.phaseFrame:Show()
end


-- 性能优化：缓存地图信息查询结果
local cachedMapID = nil
local cachedMapName = nil
function PhaseDetector:GetCurrentMapInfo()
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

-- 发送位面检测消息
function PhaseDetector:AnnouncePhase(mapName, phaseID, isFirstTime)
    if not addon.db or not addon.db.enabled then
        return
    end
    
    local L = addon.L or {}
    local template
    if isFirstTime then
        template = L["PhaseDetectedFirstTime"] or "Phase detected in %s: %s"
    else
        template = L["PhaseChanged"] or "Phase changed in %s: %s"
    end

    local message = string.format(template, mapName, phaseID)
    
    SendSystemMessageToPlayer(message)
end

-- 性能优化：事件驱动的位面信息更新
function PhaseDetector:UpdatePhaseInfo(eventType)
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

    -- 地图切换时清理缓存
    if self.lastSeenMapID and self.lastSeenMapID ~= mapID then
        self.phaseCache = {}
        self.lastReportedMapID = nil
        self.lastReportedPhaseID = nil
        self.lastTargetGUID = nil
        self.lastMouseoverGUID = nil
        self:UpdatePhaseDisplay(nil)
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

    local cachedPhaseID = self.phaseCache[mapID]
    local mapChanged = self.lastSeenMapID ~= mapID
    local shouldAnnounce = false
    local isFirstTime = false

    if mapChanged then
        shouldAnnounce = true
        isFirstTime = true
    elseif cachedPhaseID ~= detectedPhaseID then
        shouldAnnounce = true
        isFirstTime = (cachedPhaseID == nil)
    end

    self.phaseCache[mapID] = detectedPhaseID
    self.lastSeenMapID = mapID
    self:UpdatePhaseDisplay(detectedPhaseID)

    if shouldAnnounce then
        -- 避免重复通知相同的地图和位面组合
        local mapPhaseKey = mapID .. "-" .. detectedPhaseID
        local lastReportedKey = (self.lastReportedMapID and self.lastReportedPhaseID) and 
                                (self.lastReportedMapID .. "-" .. self.lastReportedPhaseID) or nil

        if lastReportedKey ~= mapPhaseKey then
            self:AnnouncePhase(mapName, detectedPhaseID, isFirstTime)
            self.lastReportedMapID = mapID
            self.lastReportedPhaseID = detectedPhaseID
        end
    end
end

-- 暂停检测（进入受限环境时）
function PhaseDetector:PauseDetection()
    if self.isPaused then
        return
    end
    
    self.isPaused = true
    
    -- 隐藏悬浮窗
    if self.phaseFrame then
        self.phaseFrame:Hide()
    end
    
    -- 清理缓存
    self.lastTargetGUID = nil
    self.lastMouseoverGUID = nil
end

-- 恢复检测（离开受限环境时）
function PhaseDetector:ResumeDetection()
    if not self.isPaused then
        return
    end
    
    self.isPaused = false
    
    -- 清理缓存，强制重新检测
    self.phaseCache = {}
    self.lastReportedMapID = nil
    self.lastReportedPhaseID = nil
    self.lastSeenMapID = nil
    self.lastTargetGUID = nil
    self.lastMouseoverGUID = nil
end

-- 开始位面检测
function PhaseDetector:StartDetection()
    if self.isRunning then
        return
    end
    if not addon.db or not addon.db.enabled then
        return
    end
    
    self.isRunning = true
    self.isPaused = false
    
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        -- 性能优化：事件处理函数传递事件类型
        self.eventFrame:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_ENTERING_WORLD" then
                -- 区域切换时检查环境
                self:CheckEnvironment()
            elseif event == "PLAYER_REGEN_ENABLED" then
                -- 战斗结束后清理单位缓存，允许在同目标上重新检测
                self.lastTargetGUID = nil
                self.lastMouseoverGUID = nil
                self:CheckEnvironment()
                self:UpdatePhaseInfo("PLAYER_TARGET_CHANGED")
                self:UpdatePhaseInfo("UPDATE_MOUSEOVER_UNIT")
            else
                self:UpdatePhaseInfo(event)
            end
        end)
    end
    
    -- 注册必要的事件
    self.eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    self.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")  -- 监听区域切换
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- 战斗结束后重新检测
    
    -- 启动时立即检查环境
    self:CheckEnvironment()
end

-- 检查当前环境并决定是否暂停
function PhaseDetector:CheckEnvironment()
    if IsInRestrictedEnvironment() then
        if not self.isPaused then
            self:PauseDetection()
        end
    else
        if self.isPaused then
            self:ResumeDetection()
        end
    end
end

-- 停止位面检测
function PhaseDetector:StopDetection()
    if not self.isRunning then
        return
    end
    
    self.isRunning = false
    self.isPaused = false
    
    if self.eventFrame then
        self.eventFrame:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
        self.eventFrame:UnregisterEvent("PLAYER_TARGET_CHANGED")
        self.eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        self.eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end

    -- 清理缓存
    self.lastTargetGUID = nil
    self.lastMouseoverGUID = nil
    self:UpdatePhaseDisplay(nil)
    
    local L = addon.L or {}
    print(L["DetectionStopped"] or "PhaseDetector detection stopped")
end
