-- PhaseDetector.lua - 位面检测控制器

local ADDON_NAME = "PhaseDetector"
local addon = _G[ADDON_NAME]

local PhaseDetector = {}
addon.PhaseDetector = PhaseDetector

PhaseDetector.isRunning = false
PhaseDetector.eventFrame = nil

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
    if tracker then
        tracker.isPaused = false
    end

    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_ENTERING_WORLD" then
                self:CheckEnvironment()
            elseif event == "PLAYER_REGEN_ENABLED" then
                local activeTracker = GetTracker()
                if activeTracker and activeTracker.ResetUnitCache then
                    activeTracker:ResetUnitCache()
                end

                self:HandleDetectionEvent("PLAYER_TARGET_CHANGED")
                self:HandleDetectionEvent("UPDATE_MOUSEOVER_UNIT")
            else
                self:HandleDetectionEvent(event)
            end
        end)
    end

    self.eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    self.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    self:CheckEnvironment()
end

-- 检查当前环境并决定是否暂停
function PhaseDetector:CheckEnvironment()
    local tracker = GetTracker()
    if not tracker then
        return
    end

    if tracker.IsRestrictedEnvironment and tracker:IsRestrictedEnvironment() then
        if not tracker.isPaused and tracker.PauseDetection then
            tracker:PauseDetection()
        end
    else
        if tracker.isPaused and tracker.ResumeDetection then
            tracker:ResumeDetection()
        end
    end
end

-- 停止位面检测
function PhaseDetector:StopDetection()
    if not self.isRunning then
        return
    end

    self.isRunning = false

    local tracker = GetTracker()
    if tracker then
        tracker.isPaused = false
        if tracker.ResetUnitCache then
            tracker:ResetUnitCache()
        end
    end

    if self.eventFrame then
        self.eventFrame:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
        self.eventFrame:UnregisterEvent("PLAYER_TARGET_CHANGED")
        self.eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        self.eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end

    local display = GetDisplay()
    if display and display.Hide then
        display:Hide()
    end

    local L = addon.L or {}
    print(L["DetectionStopped"] or "PhaseDetector detection stopped")
end
