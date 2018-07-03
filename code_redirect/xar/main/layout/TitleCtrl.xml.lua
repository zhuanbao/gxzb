local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local Helper =  XLGetGlobal("Helper")
-----事件----
function OnClickCloseBtn(self)
	HideWndToTray(self)
end

function OnClickMinBtn(self)
	local objTree = self:GetOwner()
	if nil == objTree then
		return
	end
	
	local objHostWnd = objTree:GetBindHostWnd()
	if nil == objHostWnd then
		return
	end
	
	objHostWnd:Min()	
end

function OnClickConfigBtn(self)
	local tree = self:GetOwner()
	local wnd = tree:GetBindHostWnd()
	local curX, curY = self:GetAbsPos()
	local wndX, WmdY = wnd:GetWindowRect()
	curX = curX + wndX
	curY = curY + WmdY
	local menuTable = GXZBMenu.SettingMenu.menuTable
	local menuFunTable = GXZBMenu.SettingMenu.menuFunTable
	local userData = {}
	Helper:CreateMenu(curX-50, curY+20, wnd:GetWndHandle(), menuTable, menuFunTable, userData)
end

function OnClickSupperPCBtn(self)
	local strLink = "http://www.eastredm.com/supercomputer"
	Helper.tipUtil:OpenURL(strLink)
	local tStatInfo = {}
	tStatInfo.fu1 = "opensupperpc"
	tStatInfo.fu5 = "menu"
	StatisticClient:SendClickReport(tStatInfo)
	
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["tConfig"] = tUserConfig["tConfig"] or {}
	tUserConfig["tConfig"]["tMenuSupperPC"] = tUserConfig["tConfig"]["tUserIntroduce"] or {}
	tUserConfig["tConfig"]["tMenuSupperPC"]["nLastClickTime"] = tFunctionHelper.GetCurrentServerTime()
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
	
	local objTree = self:GetOwner()
	local objSupperPCRemind = self:GetControlObject("TitleCtrl.Caption.SupperPC.Remind")
	objSupperPCRemind:SetVisible(false)
end


function OnClickShare(self)
	local wndTree = self:GetOwner()
	local wnd = wndTree:GetBindHostWnd()
	--local maskWnd, maskWndTree = Helper:CreateTransparentMask(wnd)
	
	--创建“设置“窗口之前，先创建一个半透明蒙层（Mask）窗口覆盖到主窗口上，再以Mask窗口为父窗口创建”设置“窗口
	--此时”设置“窗口已经成为主窗口的 孙子 窗口  所以，比较好的方法就是：“不要跟强势的场景处在同一组内”
	local userData = {["parentWnd"] = wnd, ["maskWndParent"] = wnd}
	Helper:CreateModalWnd("ShareWnd", "ShareWndTree", wnd:GetWndHandle(), userData)
end

-----辅助函数----
function SetBkgVisible(objRootCtrl, bVisible)
	local objBkg = objRootCtrl:GetControlObject("TipCtrl.Bkg")
	local objShadow = objRootCtrl:GetControlObject("TipCtrl.MainWnd.TopShadow")
	objBkg:SetVisible(bVisible)
	objShadow:SetVisible(bVisible)
end

function ChangeTitle(self, strTitle)
	local ObjTitleText = self:GetControlObject("TitleCtrl.Caption.Title")
	ObjTitleText:SetText(strTitle)
end

function HideWndToTray(objUIElement)
	local objTree = objUIElement:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:Show(0)
end

function IsRealString(AString)
    return type(AString) == "string" and AString ~= ""
end

function TipLog(strLog)
	if type(tipUtil.Log) == "function" then
		tipUtil:Log("TitleCtrl: " .. tostring(strLog))
	end
end

function OnMouseEnterConfigBtn(self)
	Helper.Tip:SetTips("设置")
	local hoverimage = self:GetObject("TitleCtrl.Caption.Config.Hoverimage")
	hoverimage:SetVisible(true)
end
function OnMouseEnterMinBtn(self)
	Helper.Tip:SetTips("最小化")
	local hoverimage = self:GetObject("TitleCtrl.Caption.BtnMin.Hoverimage")
	hoverimage:SetVisible(true)
end

function OnMouseEnterCloseBtn(self)
	Helper.Tip:SetTips("关闭")
	local hoverimage = self:GetObject("TitleCtrl.Caption.CloseBtn.Hoverimage")
	hoverimage:SetVisible(true)
end

function OnMouseEnterSupperPCBtn(self)
	Helper.Tip:SetTips("超级电脑")
	local hoverimage = self:GetObject("TitleCtrl.Caption.SupperPC.Hoverimage")
	hoverimage:SetVisible(true)
end

function OnMouseLeave(self)
	Helper.Tip:DestoryTipWnd()
	local id = self:GetID()
	local hoverimage = self:GetObject(id..".Hoverimage")
	if hoverimage then
		hoverimage:SetVisible(false)
	end
end