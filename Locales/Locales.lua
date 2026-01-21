-- Locales.lua - 本地化系统

local ADDON_NAME = "PhaseDetector"
local PhaseDetector = _G[ADDON_NAME]

local Locales = {}
PhaseDetector.Locales = Locales

-- 本地化数据存储
Locales.data = {}

-- 注册本地化文本
function Locales:Register(locale, data)
    if not self.data[locale] then
        self.data[locale] = {}
    end
    
    for key, value in pairs(data) do
        self.data[locale][key] = value
    end
end

-- 获取当前语言环境的本地化文本
function Locales:GetLocale()
    local locale = GetLocale()
    local enUS = self.data["enUS"] or {}
    local localeData = self.data[locale] or enUS
    
    -- 创建本地化表，支持缺失键的回退
    local L = setmetatable({}, {
        __index = function(t, key)
            return localeData[key] or enUS[key] or key
        end
    })
    
    return L
end
