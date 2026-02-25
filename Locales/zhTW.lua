-- zhTW.lua - 繁體中文本地化

local ADDON_NAME = "PhaseDetector"
local PhaseDetector = _G[ADDON_NAME]

if PhaseDetector and PhaseDetector.Locales then
    PhaseDetector.Locales:Register("zhTW", {
        -- 位面检测消息
        ["PhaseDetectedFirstTime"] = "當前%s的位面是：%s",
        ["PhaseChanged"] = "當前%s的位面已變更為：%s",
        ["DetectionStopped"] = "位面檢測已停止",
        
        -- 提示信息
        ["AddonEnabled"] = "位面檢測器已啟用！",
        ["AddonDisabled"] = "位面檢測器已禁用！",
        
        -- 错误信息
        -- 命令幫助
        ["CommandHelpTitle"] = "PhaseDetector 命令：",
        ["CommandHelpOn"] = "  /phd on - 啟用插件",
        ["CommandHelpOff"] = "  /phd off - 禁用插件",
        

        -- 螢幕顯示
        ["ScreenPhaseID"] = "位面ID：%s",
    })
end
