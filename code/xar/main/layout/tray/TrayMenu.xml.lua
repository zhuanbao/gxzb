-------事件---
function OnSelect_Setting(self)
	GXZBMenu.SettingMenu.menuFunTable.OnSelect_setting()
end


function OnSelect_Sysboot(self)
	GXZBMenu.SettingMenu.menuFunTable.OnSelect_autowork()
end


function OnInit_Sysboot(self)
	local attr = self:GetAttribute()
	if Helper:QueryRegValue("HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\gxzb") then
		attr.Icon = "bitmap.menu.setting_check.normal"
	else
		attr.Icon = ""
	end
end

function OnInit_Hideball(self)
	local attr = self:GetAttribute()
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.XuanFuWnd.Instance")
	if objHostWnd and objHostWnd:GetVisible() then
		attr.Text = "隐藏悬浮球"
	else
		attr.Text = "显示悬浮球"
	end
end

function OnSelect_Hideball(self)
	--GXZBMenu.SettingMenu.menuFunTable.OnInit_hideball()
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.XuanFuWnd.Instance")
	if objHostWnd then
		if objHostWnd:GetVisible() then
			objHostWnd:Show(0)
		else
			objHostWnd:Show(1)
		end
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