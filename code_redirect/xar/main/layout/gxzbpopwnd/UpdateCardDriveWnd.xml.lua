local tFunctionHelper = XLGetGlobal("FunctionHelper")
local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}

function OnClickClose(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:EndDialog(0)
	UIInterface._tabErrorMsg = nil
	UIInterface._bShowUpdateDriveWnd = false
end

function OnClickUpdateDrive(self)
	local tabInfo = UIInterface._tabErrorMsg
	local strDriveUpdateWeb = ""
	if tabInfo[1] == 2 then
		strDriveUpdateWeb = "http://www.nvidia.cn/Download/index.aspx?lang=cn"
	else
		strDriveUpdateWeb = "http://support.amd.com/zh-cn/download"
	end
	Helper.tipUtil:OpenURL(strDriveUpdateWeb)
	local tStatInfo = {}
	tStatInfo.fu1 = "opendrviepage"
	tStatInfo.fu5 = tabInfo[1]
	tStatInfo.fu6 = strDriveUpdateWeb
	StatisticClient:SendClickReport(tStatInfo)
end

function OnClickRestart(self)
	--[[
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:Show(0)
	UIInterface:DestroyPopupWnd()
	--]]
	UIInterface:DestroyAllWnd()
	local tStatInfo = {}
	tStatInfo.fu1 = "restart"
	tStatInfo.fu5 = "updatedrive"
	StatisticClient:SendClickReport(tStatInfo)
	StatisticClient:RestartClient()
	--StatisticClient:FailExitProcess(6)
end

function OnCreate(self)
	local userData = self:GetUserData()
	if userData and userData.parentWnd then
		local objtree = self:GetBindUIObjectTree()
		local objRootLayout = objtree:GetUIObject("root")
		local nLayoutL, nLayoutT, nLayoutR, nLayoutB = objRootLayout:GetObjPos()
		local nLayoutWidth  = nLayoutR - nLayoutL
		local nLayoutHeight = nLayoutB - nLayoutT
	
		local parentLeft, parentTop, parentRight, parentBottom = userData.parentWnd:GetWindowRect()
		local parentWidth  = parentRight - parentLeft
		local parentHeight = parentBottom - parentTop
		self:Move( parentLeft + (parentWidth - nLayoutWidth)/2, parentTop + (parentHeight - nLayoutHeight)/2, nLayoutWidth, nLayoutHeight)
	end
end

function OnShowWindow(self, bShow)
	if bShow then
		local tabInfo = UIInterface._tabErrorMsg
		local nClientType = tabInfo[1]
		local tStatInfo = {}
		tStatInfo.fu1 = "showdrivewnd"
		tStatInfo.fu5 = nClientType
		StatisticClient:SendEventReport(tStatInfo)
	end
end