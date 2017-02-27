local GXZBMenu = XLGetGlobal("GXZBMenu")
if not GXZBMenu then
	GXZBMenu = {}
	XLSetGlobal("GXZBMenu", GXZBMenu)
end

local bReverse = true
local menuFunTable = {}

function menuFunTable.OnInit_autowork(self)
	if Helper:QueryRegValue("HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\gxzb") then
		local icon = self:GetControlObject("menu.item.icon")
		icon:SetObjPos2(9, "(father.height - 13)/2", 13, 13)
		icon:SetResID("bitmap.menu.setting_check.normal")
	end
end

function menuFunTable.OnSelect_autowork(self)
	if Helper:QueryRegValue("HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\gxzb") then
		Helper.tipUtil:DeleteRegValue("HKEY_CURRENT_USER", "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\gxzb")
	else
		local strExePath = Helper.tipUtil:QueryRegValue("HKEY_LOCAL_MACHINE", "Software\\gxzb", "Path")
		if not Helper:IsRealString(strExePath) or not Helper.tipUtil:QueryFileExists(strExePath) then
			return
		end
		Helper.tipUtil:SetRegValue("HKEY_CURRENT_USER", "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run", "gxzb", "\""..strExePath.."\" /sstartfrom sysboot /embedding")
	end
end

function menuFunTable.OnInit_hideball(self)
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.XuanFuWnd.Instance")
	local text = self:GetControlObject("menu.item.text")
	if objHostWnd and objHostWnd:GetVisible() then
		text:SetText("隐藏悬浮球")
	else
		text:SetText("显示悬浮球")
	end
end

function menuFunTable.OnSelect_hideball(self)
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.XuanFuWnd.Instance")
	if objHostWnd then
		if objHostWnd:GetVisible() then
			objHostWnd:Show(0)
		else
			objHostWnd:Show(1)
		end
	end
end

function menuFunTable.OnSelect_setting(self)
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	objHostWnd:Show(1)
	local maskWnd = Helper:CreateTransparentMask(objHostWnd)
	Helper:CreateModalWnd("GXZB.SettingWnd", "GXZB.SettingWndTree", maskWnd:GetWndHandle(), {["parentWnd"] = maskWnd})
	Helper:DestoryTransparentMask(objHostWnd)
end

function menuFunTable.OnSelect_checkupdate(self)
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	objHostWnd:Show(1)
	local maskWnd = Helper:CreateTransparentMask(objHostWnd)
	Helper:CreateModalWnd("GXZB.UpdateWnd", "GXZB.UpdateWndTree", maskWnd:GetWndHandle(), {["parentWnd"] = maskWnd})
	Helper:DestoryTransparentMask(objHostWnd)
end

function menuFunTable.OnSelect_about(self)
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	objHostWnd:Show(1)
	local maskWnd = Helper:CreateTransparentMask(objHostWnd)
	Helper:CreateModalWnd("GXZB.AboutWnd", "GXZB.AboutWndTree", maskWnd:GetWndHandle(), {["parentWnd"] = maskWnd})
	Helper:DestoryTransparentMask(objHostWnd)
end

function menuFunTable.OnSelect_exit(self)
	local wnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	if wnd then
		wnd:Show(0)
	end
	local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
	tFunctionHelper.ReportAndExit()
end

local menuTable = {
{id="autowork", text = "开机自动赚宝"},
{id="hideball", text = "隐藏悬浮球"},
{id="setting", text = "设置"},
{id="checkupdate", text = "检查更新"},
{id="about", text = "关于"},
{id="exit", text = "退出"},
}

GXZBMenu.SettingMenu = {}
GXZBMenu.SettingMenu.menuTable = menuTable
GXZBMenu.SettingMenu.menuFunTable = menuFunTable
