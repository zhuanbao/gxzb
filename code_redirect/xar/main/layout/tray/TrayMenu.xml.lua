local tFunctionHelper = XLGetGlobal("FunctionHelper")
-------事件---
function OnSelect_Setting(self)
	GXZBMenu.SettingMenu.menuFunTable.OnSelect_setting()
end


function OnSelect_MainUI(self)
	GXZBMenu.SuspendMenu.menuFunTable.OnSelect_mainui()
end


function OnInit_MainUI(self)
end

function OnInit_Pause(self)
	local attr = self:GetAttribute()
	if MainWorkModule:CheckIsWorking() then
		attr.Text = "暂停"
		attr.Icon = "bitmap.menu.pause.normal"
	else
		attr.Text = "开始"
		attr.Icon = "bitmap.menu.start.normal"
	end
end

function OnSelect_Pause(self)
	UIInterface:SetStateInfoToUser(nil)
	if MainWorkModule:CheckIsWorking() then
		MainWorkModule:NotifyQuit()
		local tStatInfo = {}
		tStatInfo.fu1 = "stopworking"
		tStatInfo.fu5 = "tray"
		StatisticClient:SendClickReport(tStatInfo)
	else
		MainWorkModule:NotifyStart()
		local tStatInfo = {}
		tStatInfo.fu1 = "startworking"
		tStatInfo.fu5 = "tray"
		StatisticClient:SendClickReport(tStatInfo)
	end
end

function OnSelect_Update(self)
	GXZBMenu.SettingMenu.menuFunTable.OnSelect_checkupdate()
end

function OnSelect_About(self)
	GXZBMenu.SettingMenu.menuFunTable.OnSelect_about()
end

function OnSelect_Exit(self)
	GXZBMenu.SettingMenu.menuFunTable.OnSelect_exit()
end