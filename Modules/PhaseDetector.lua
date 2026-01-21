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
    
    local L = addon.L or {}
    print(L["DetectorInitialized"] or "PhaseDetector initialized")

    self:CreatePhaseDisplay()
end

function PhaseDetector:GetPhaseFromGUID(guid)
    if not guid then
        return nil
    end

    -- 位面ID = 分片ID-实例ID（GUID第3-4部分）
    local unitType, _, shardID, instancePart = strsplit("-", guid)
    if (unitType == "Creature" or unitType == "Vehicle") and shardID and instancePart then
        return shardID .. "-" .. instancePart
    end

    return nil
end

-- 从NPC GUID获取位面ID
function PhaseDetector:GetPhaseFromNPC()
    local unit = "mouseover"
    local guid = UnitGUID(unit)
    
    if not guid then
        unit = "target"
        guid = UnitGUID(unit)
    end
    
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

    if not phaseID then
        self.phaseFrame:Hide()
        return
    end

    local L = addon.L or {}
    local line = string.format(L["ScreenPhaseID"] or "Phase ID: %s", phaseID)
    self.phaseFrame.text:SetText(line)
    self.phaseFrame:Show()
end


-- 获取当前地图信息
function PhaseDetector:GetCurrentMapInfo()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        return nil, nil
    end
    
    local mapInfo = C_Map.GetMapInfo(mapID)
    if not mapInfo then
        return nil, nil
    end
    
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

-- 更新位面信息
function PhaseDetector:UpdatePhaseInfo()
    if not addon.db or not addon.db.enabled then
        return
    end
    
    local mapID, mapName = self:GetCurrentMapInfo()
    if not mapID or not mapName then
        return
    end

    if self.lastSeenMapID and self.lastSeenMapID ~= mapID then
        self.phaseCache = {}
        self.lastReportedMapID = nil
        self.lastReportedPhaseID = nil
        self:UpdatePhaseDisplay(nil)
    end
    
    local detectedPhaseID = self:GetPhaseFromNPC()
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
        self.eventFrame:SetScript("OnEvent", function(_, event)
            if event == "UPDATE_MOUSEOVER_UNIT" or event == "PLAYER_TARGET_CHANGED" then
                self:UpdatePhaseInfo()
            end
        end)
    end
    self.eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    self.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    
    local L = addon.L or {}
    print(L["DetectionStarted"] or "PhaseDetector detection started")
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

    self:UpdatePhaseDisplay(nil)
    
    local L = addon.L or {}
    print(L["DetectionStopped"] or "PhaseDetector detection stopped")
end

