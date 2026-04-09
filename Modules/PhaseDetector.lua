-- PhaseDetector.lua - 位面检测控制器

local ADDON_NAME = "PhaseDetector"
local addon = _G[ADDON_NAME]

local PhaseDetector = {}
addon.PhaseDetector = PhaseDetector

PhaseDetector.isRunning = false
PhaseDetector.eventFrame = nil
PhaseDetector.isEnvironmentBlocked = false
PhaseDetector.detectionEventsRegistered = false

local function GetTracker()
    return addon.PhaseTracker
end

local function GetDisplay()
    return addon.PhaseDisplay
end

function PhaseDetector:Initialize()
    local tracker = GetTracker()
    if tracker and tracker.Initialize then
        tracker:Initialize()
    end

    local display = GetDisplay()
    if display and display.Initialize then
        display:Initialize()
    end
end

function PhaseDetector:HandleDetectionEvent(eventType)
    local tracker = GetTracker()
    if tracker and tracker.UpdatePhaseInfo then
        tracker:UpdatePhaseInfo(eventType)
    end
end

function PhaseDetector:SetDetectionEventsEnabled(enabled)
    if not self.eventFrame then
        return
    end

    if enabled and not self.detectionEventsRegistered then
        self.eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        self.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        self.detectionEventsRegistered = true
    elseif not enabled and self.detectionEventsRegistered then
        self.eventFrame:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
        self.eventFrame:UnregisterEvent("PLAYER_TARGET_CHANGED")
        self.detectionEventsRegistered = false
    end
end

function PhaseDetector:TriggerImmediateDetection()
    if self.isEnvironmentBlocked then
        return
    end

    local tracker = GetTracker()
    if tracker and tracker.ResetUnitCache then
        tracker:ResetUnitCache()
    end

    self:HandleDetectionEvent("PLAYER_TARGET_CHANGED")
    self:HandleDetectionEvent("UPDATE_MOUSEOVER_UNIT")
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

    local tracker = GetTracker()
    if tracker and tracker.ResetRuntimeState then
        tracker:ResetRuntimeState()
    end

    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
                self:CheckEnvironment(false)
            elseif event == "PLAYER_REGEN_ENABLED" then
                self:CheckEnvironment(false)
                if self.isEnvironmentBlocked then
                    return
                end
                self:TriggerImmediateDetection()
            else
                if self.isEnvironmentBlocked then
                    return
                end
                self:HandleDetectionEvent(event)
            end
        end)
    end

    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    self:CheckEnvironment(true)
end

-- 检查当前环境并决定是否暂停
function PhaseDetector:CheckEnvironment(forceUpdate)
    local tracker = GetTracker()
    if not tracker then
        return
    end

    local restricted = tracker.IsRestrictedEnvironment and tracker:IsRestrictedEnvironment()

    if restricted then
        if forceUpdate or not self.isEnvironmentBlocked then
            self.isEnvironmentBlocked = true
            self:SetDetectionEventsEnabled(false)
            if tracker.PauseDetection then
                tracker:PauseDetection()
            end
        end
    else
        if forceUpdate or self.isEnvironmentBlocked then
            self.isEnvironmentBlocked = false
            self:SetDetectionEventsEnabled(true)
            if tracker.ResumeDetection then
                tracker:ResumeDetection()
            end
            self:TriggerImmediateDetection()
        elseif not self.detectionEventsRegistered then
            self:SetDetectionEventsEnabled(true)
        end
    end
end

-- 停止位面检测
function PhaseDetector:StopDetection()
    if not self.isRunning then
        return
    end

    self.isRunning = false
    self.isEnvironmentBlocked = false

    local tracker = GetTracker()
    if tracker then
        if tracker.ResetRuntimeState then
            tracker:ResetRuntimeState()
        elseif tracker.ResetUnitCache then
            tracker:ResetUnitCache()
            tracker.isPaused = false
        end
    end

    self:SetDetectionEventsEnabled(false)

    if self.eventFrame then
        self.eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        self.eventFrame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
        self.eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end

    local display = GetDisplay()
    if display and display.Hide then
        display:Hide()
    end

    local L = addon.L or {}
    print(L["DetectionStopped"] or "PhaseDetector detection stopped")
end
