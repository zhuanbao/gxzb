local tFunctionHelper = XLGetGlobal("FunctionHelper")
local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}

function ExitAndReport(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:Show(0)
	UIInterface:DestroyPopupWnd()
	StatisticClient:FailExitProcess(6)
end

function OnClickClose(self)
	ExitAndReport(self)
end

function OnClickExit(self)
	ExitAndReport(self)
end

function OnOpenUrl(self)
	local strZcashAWebUrl = "http://www.eastredm.com/download_a.html"
	Helper.tipUtil:OpenURL(strZcashAWebUrl)
	local tStatInfo = {}
	tStatInfo.fu1 = "openzcashawnd"
	StatisticClient:SendClickReport(tStatInfo)
	ExitAndReport(self)
end

function PopupInDeskMiddle(self)
	local objtree = self:GetBindUIObjectTree()
	local objRootLayout = objtree:GetUIObject("root")
    local templateMananger = XLGetObject("Xunlei.UIEngine.TemplateManager")
	
	local nLayoutL, nLayoutT, nLayoutR, nLayoutB = objRootLayout:GetObjPos()
	local nLayoutWidth = nLayoutR - nLayoutL
	local nLayoutHeight = nLayoutB - nLayoutT
	
	local workleft, worktop, workright, workbottom = Helper.tipUtil:GetWorkArea()
	self:Move((workright - nLayoutWidth)/2, (workbottom - nLayoutHeight)/2, nLayoutWidth, nLayoutHeight)
	return true
end

function OnShowWindow(self, bShow)
	if bShow then
		local objtree = self:GetBindUIObjectTree()
		PopupInDeskMiddle(self)
	end
end