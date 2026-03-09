-- zhCN.lua - 简体中文本地化

local ADDON_NAME = "PhaseDetector"
local PhaseDetector = _G[ADDON_NAME]

if PhaseDetector and PhaseDetector.Locales then
    PhaseDetector.Locales:Register("zhCN", {
        -- 位面检测消息
        ["PhaseDetectedFirstTime"] = "当前%s位面：%s",
        ["PhaseChanged"] = "当前%s的位面已变更为：%s",
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
