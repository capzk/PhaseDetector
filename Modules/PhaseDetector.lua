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

-- 性能优化：缓存上次检测的 GUID，避免重复处理相同目标
PhaseDetector.lastTargetGUID = nil
PhaseDetector.lastMouseoverGUID = nil

-- 性能优化：缓存 API 调用
local InCombatLockdown = InCombatLockdown
local UnitGUID = UnitGUID
local strsplit = strsplit
local pcall = pcall
local C_Map_GetBestMapForUnit = C_Map.GetBestMapForUnit
local C_Map_GetMapInfo = C_Map.GetMapInfo
local C_PvP_IsInBrawl = C_PvP.IsInBrawl
local C_PvP_IsRatedMap = C_PvP.IsRatedMap
local C_PvP_IsActiveBattlefield = C_PvP.IsActiveBattlefield
local IsInInstance = IsInInstance

-- 安全检查：是否在受限环境中（副本、战场、竞技场等）
local function IsInRestrictedEnvironment()
    -- 检查是否在副本中
    local inInstance, instanceType = IsInInstance()
    if inInstance then
        -- instanceType: "pvp" (战场), "arena" (竞技场), "party" (5人本), "raid" (团本), "scenario" (场景战役)
        return true
    end
    
    -- 检查 PvP 环境（使用 pcall 保护，防止 API 不可用）
    local success, result
    
    success, result = pcall(C_PvP_IsInBrawl)
    if success and result then
        return true
    end
    
    success, result = pcall(C_PvP_IsRatedMap)
    if success and result then
        return true
    end
    
    success, result = pcall(C_PvP_IsActiveBattlefield)
    if success and result then
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

    self:CreatePhaseDisplay()
end

function PhaseDetector:GetPhaseFromGUID(guid)
    if not guid then
        return nil
    end

    -- 在战斗中跳过处理，避免触发秘密值保护
    if InCombatLockdown() then
        return nil
    end
    
    -- 在受限环境中跳过处理
    if IsInRestrictedEnvironment() then
        return nil
    end

    -- 使用 pcall 保护，防止秘密值操作触发错误
    local success, unitType, _, shardID, instancePart = pcall(strsplit, "-", guid)
    if not success or not unitType then
        return nil
    end
    
    -- 位面ID = 分片ID-实例ID（GUID第3-4部分）
    if (unitType == "Creature" or unitType == "Vehicle") and shardID and instancePart then
        return shardID .. "-" .. instancePart
    end

    return nil
end

-- 性能优化：只在目标变化时获取位面ID
function PhaseDetector:GetPhaseFromTarget()
    -- 使用 pcall 保护 UnitGUID 调用
    local success, guid = pcall(UnitGUID, "target")
    if not success then
        return nil
    end
    
    -- 如果目标 GUID 没有变化，跳过处理
    if guid == self.lastTargetGUID then
        return nil
    end
    
    self.lastTargetGUID = guid
    return self:GetPhaseFromGUID(guid)
end

-- 性能优化：只在鼠标指向变化时获取位面ID
function PhaseDetector:GetPhaseFromMouseover()
    -- 使用 pcall 保护 UnitGUID 调用
    local success, guid = pcall(UnitGUID, "mouseover")
    if not success then
        return nil
    end
    
    -- 如果鼠标指向 GUID 没有变化，跳过处理
    if guid == self.lastMouseoverGUID then
        return nil
    end
    
    self.lastMouseoverGUID = guid
    return self:GetPhaseFromGUID(guid)
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
    -- 使用 pcall 保护 API 调用
    local success, mapID = pcall(C_Map_GetBestMapForUnit, "player")
    if not success or not mapID then
        return nil, nil
    end
    
    -- 如果地图ID没变，直接返回缓存
    if mapID == cachedMapID and cachedMapName then
        return cachedMapID, cachedMapName
    end
    
    success, mapInfo = pcall(C_Map_GetMapInfo, mapID)
    if not success or not mapInfo then
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
    
    local L = addon.L
    local message
    
    if isFirstTime then
        message = string.format(L["PhaseDetectedFirstTime"], mapName, phaseID)
    else
        message = string.format(L["PhaseChanged"], mapName, phaseID)
    end
    
    SendSystemMessageToPlayer(message)
end

-- 性能优化：事件驱动的位面信息更新
function PhaseDetector:UpdatePhaseInfo(eventType)
    -- 使用 pcall 包装整个函数，防止任何未预期的错误
    local success, err = pcall(function()
        if not addon.db or not addon.db.enabled then
            return
        end
        
        -- 在战斗中禁用功能，避免触发秘密值保护
        if InCombatLockdown() then
            return
        end
        
        -- 在战场和副本中禁用功能
        if IsInRestrictedEnvironment() then
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
        
        -- 性能优化：根据事件类型只检测相应的单位
        local detectedPhaseID = nil
        if eventType == "PLAYER_TARGET_CHANGED" then
            detectedPhaseID = self:GetPhaseFromTarget()
        elseif eventType == "UPDATE_MOUSEOVER_UNIT" then
            detectedPhaseID = self:GetPhaseFromMouseover()
        end
        
        -- 如果没有检测到新的位面ID（目标未变化或无效），直接返回
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
    end)
    
    -- 如果发生错误，静默处理，不影响游戏
    if not success and err then
        -- 可选：记录错误到调试日志（生产环境中可以注释掉）
        -- print("PhaseDetector Error:", err)
    end
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
    
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        -- 性能优化：事件处理函数传递事件类型
        self.eventFrame:SetScript("OnEvent", function(_, event)
            self:UpdatePhaseInfo(event)
        end)
    end
    
    -- 只注册必要的事件，完全事件驱动
    self.eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    self.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
end

-- 停止位面检测
function PhaseDetector:StopDetection()
    if not self.isRunning then
        return
    end
    
    self.isRunning = false
    
    if self.eventFrame then
        self.eventFrame:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
        self.eventFrame:UnregisterEvent("PLAYER_TARGET_CHANGED")
    end

    -- 清理缓存
    self.lastTargetGUID = nil
    self.lastMouseoverGUID = nil
    self:UpdatePhaseDisplay(nil)
    
    local L = addon.L or {}
    print(L["DetectionStopped"] or "PhaseDetector detection stopped")
end
