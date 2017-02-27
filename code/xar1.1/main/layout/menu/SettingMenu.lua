local GXZBMenu = XLGetGlobal("GXZBMenu")
if not GXZBMenu then
	GXZBMenu = {}
	XLSetGlobal("GXZBMenu", GXZBMenu)
end

local menuFunTable = {}

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
{id="setting", text = "设置"},
{id="checkupdate", text = "检查更新"},
{id="about", text = "关于"},
{id="exit", text = "退出"},
}

GXZBMenu.SettingMenu = {}
GXZBMenu.SettingMenu.menuTable = menuTable
GXZBMenu.SettingMenu.menuFunTable = menuFunTable
