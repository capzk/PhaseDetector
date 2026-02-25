-- ruRU.lua - Russian localization

local ADDON_NAME = "PhaseDetector"
local PhaseDetector = _G[ADDON_NAME]

if PhaseDetector and PhaseDetector.Locales then
    PhaseDetector.Locales:Register("ruRU", {
        -- Phase detection messages
        ["PhaseDetectedFirstTime"] = "Текущая фаза в %s: %s",
        ["PhaseChanged"] = "Текущая фаза в %s изменена на: %s",
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
