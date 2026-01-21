-- Core.lua - PhaseDetector 核心文件

local ADDON_NAME = "PhaseDetector"
local PhaseDetector = {}
_G[ADDON_NAME] = PhaseDetector

-- 全局变量
PhaseDetector.version = "1.0.0"
PhaseDetector.loaded = false
PhaseDetector.db = nil

-- 默认设置
local defaultSettings = {
    enabled = true
}

-- 初始化函数
function PhaseDetector:Initialize()
    -- 初始化运行期配置（不持久化）
    local db = {}
    for key, value in pairs(defaultSettings) do
        db[key] = value
    end
    self.db = db
    
    -- 初始化本地化
    if PhaseDetector.Locales then
        PhaseDetector.L = PhaseDetector.Locales:GetLocale()
    end
    
    -- 初始化位面检测器
    if PhaseDetector.PhaseDetector then
        PhaseDetector.PhaseDetector:Initialize()
    end
    
    self.loaded = true
    
    local L = PhaseDetector.L or {}
    local loadedText = L["AddonLoaded"] or "PhaseDetector v%s loaded"
    print(string.format(loadedText, self.version))
end

-- 事件处理
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == ADDON_NAME then
        PhaseDetector:Initialize()
    elseif event == "PLAYER_LOGIN" then
        -- 玩家登录后自动启动位面检测
        if PhaseDetector.db and PhaseDetector.db.enabled and PhaseDetector.PhaseDetector and PhaseDetector.PhaseDetector.StartDetection then
            PhaseDetector.PhaseDetector:StartDetection()
        elseif PhaseDetector.PhaseDetector and PhaseDetector.PhaseDetector.StopDetection then
            PhaseDetector.PhaseDetector:StopDetection()
        end
    end
end)

-- 斜杠命令
SLASH_PHASEDETECTOR1 = "/phd"
SLASH_PHASEDETECTOR2 = "/phasedetector"
SlashCmdList["PHASEDETECTOR"] = function(msg)
    local command = string.lower(msg or "")

    if not PhaseDetector.loaded then
        PhaseDetector:Initialize()
    end
    local L = PhaseDetector.L or {}
    
    if command == "on" or command == "off" then
        PhaseDetector.db.enabled = (command == "on")
        local statusText = PhaseDetector.db.enabled and (L["AddonEnabled"] or "PhaseDetector enabled!") or (L["AddonDisabled"] or "PhaseDetector disabled!")
        print(statusText)

        -- 根据状态启动或停止检测
        if PhaseDetector.db.enabled then
            if PhaseDetector.PhaseDetector and PhaseDetector.PhaseDetector.StartDetection then
                PhaseDetector.PhaseDetector:StartDetection()
            end
        else
            if PhaseDetector.PhaseDetector and PhaseDetector.PhaseDetector.StopDetection then
                PhaseDetector.PhaseDetector:StopDetection()
            end
        end
    else
        print(L["CommandHelpTitle"] or "PhaseDetector commands:")
        print(L["CommandHelpOn"] or "  /phd on - Enable addon")
        print(L["CommandHelpOff"] or "  /phd off - Disable addon")
    end
end
