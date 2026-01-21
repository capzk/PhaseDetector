-- ruRU.lua - Russian localization

local ADDON_NAME = "PhaseDetector"
local PhaseDetector = _G[ADDON_NAME]

if PhaseDetector and PhaseDetector.Locales then
    PhaseDetector.Locales:Register("ruRU", {
        -- Phase detection messages
        ["PhaseDetectedFirstTime"] = "Фаза обнаружена в %s: %s",
        ["PhaseChanged"] = "Фаза изменена в %s: %s",
        ["AddonLoaded"] = "PhaseDetector v%s загружен",
        ["DetectorInitialized"] = "PhaseDetector инициализирован",
        ["DetectionStarted"] = "PhaseDetector: обнаружение запущено",
        ["DetectionStopped"] = "PhaseDetector: обнаружение остановлено",

        -- Status messages
        ["AddonEnabled"] = "PhaseDetector включен!",
        ["AddonDisabled"] = "PhaseDetector отключен!",

        -- Error messages
        -- Command help
        ["CommandHelpTitle"] = "Команды PhaseDetector:",
        ["CommandHelpOn"] = "  /phd on - Включить аддон",
        ["CommandHelpOff"] = "  /phd off - Выключить аддон",
        

        -- Screen display
        ["ScreenPhaseID"] = "ID фазы: %s",
    })
end
