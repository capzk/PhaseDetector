-- enUS.lua - English localization

local ADDON_NAME = "PhaseDetector"
local PhaseDetector = _G[ADDON_NAME]

if PhaseDetector and PhaseDetector.Locales then
    PhaseDetector.Locales:Register("enUS", {
        -- 位面检测消息
        ["PhaseDetectedFirstTime"] = "Phase detected in %s: %s",
        ["PhaseChanged"] = "Phase changed in %s: %s",
        ["AddonLoaded"] = "PhaseDetector v%s loaded",
        ["DetectorInitialized"] = "PhaseDetector initialized",
        ["DetectionStarted"] = "PhaseDetector detection started",
        ["DetectionStopped"] = "PhaseDetector detection stopped",
        
        -- 提示信息
        ["AddonEnabled"] = "PhaseDetector enabled!",
        ["AddonDisabled"] = "PhaseDetector disabled!",
        
        -- 错误信息
        -- Command help
        ["CommandHelpTitle"] = "PhaseDetector commands:",
        ["CommandHelpOn"] = "  /phd on - Enable addon",
        ["CommandHelpOff"] = "  /phd off - Disable addon",
        

        -- Screen display
        ["ScreenPhaseID"] = "Phase ID: %s",
    })
end
