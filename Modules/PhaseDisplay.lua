-- PhaseDisplay.lua - 位面显示模块

local ADDON_NAME = "PhaseDetector"
local addon = _G[ADDON_NAME]

local PhaseDisplay = {}
addon.PhaseDisplay = PhaseDisplay

local InCombatLockdown = InCombatLockdown

function PhaseDisplay:Initialize()
    self.lastDisplayedPhaseID = nil
    self:CreatePhaseDisplay()
end

function PhaseDisplay:CreatePhaseDisplay()
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

function PhaseDisplay:Hide()
    self.lastDisplayedPhaseID = nil

    if self.phaseFrame and self.phaseFrame:IsShown() then
        self.phaseFrame:Hide()
    end
end

function PhaseDisplay:UpdatePhaseDisplay(phaseID)
    if not self.phaseFrame then
        return
    end

    if not phaseID then
        self:Hide()
        return
    end

    -- 在战斗中跳过 UI 更新，避免潜在的保护问题
    if InCombatLockdown() then
        return
    end

    if self.lastDisplayedPhaseID == phaseID and self.phaseFrame:IsShown() then
        return
    end

    local L = addon.L or {}
    if self.lastDisplayedPhaseID ~= phaseID then
        local line = string.format(L["ScreenPhaseID"] or "Phase ID: %s", phaseID)
        self.phaseFrame.text:SetText(line)
        self.lastDisplayedPhaseID = phaseID
    end

    if not self.phaseFrame:IsShown() then
        self.phaseFrame:Show()
    end
end
