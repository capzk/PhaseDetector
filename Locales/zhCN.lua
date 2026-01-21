-- zhCN.lua - 简体中文本地化

local ADDON_NAME = "PhaseDetector"
local PhaseDetector = _G[ADDON_NAME]

if PhaseDetector and PhaseDetector.Locales then
    PhaseDetector.Locales:Register("zhCN", {
        -- 位面检测消息
        ["PhaseDetectedFirstTime"] = "检测到%s的位面：%s",
        ["PhaseChanged"] = "%s的位面已变更为：%s",
        ["AddonLoaded"] = "PhaseDetector v%s 加载完成",
        ["DetectorInitialized"] = "位面检测器初始化完成",
        ["DetectionStarted"] = "位面检测已启动",
        ["DetectionStopped"] = "位面检测已停止",
        
        -- 提示信息
        ["AddonEnabled"] = "位面检测器已启用！",
        ["AddonDisabled"] = "位面检测器已禁用！",
        
        -- 错误信息
        -- 命令帮助
        ["CommandHelpTitle"] = "PhaseDetector 命令：",
        ["CommandHelpOn"] = "  /phd on - 启用插件",
        ["CommandHelpOff"] = "  /phd off - 禁用插件",
        

        -- 屏幕显示
        ["ScreenPhaseID"] = "位面ID：%s",
    })
end
