local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")

function TipLog(strLog)
	tipUtil:Log("OpenBoxWnd: " .. tostring(strLog))
end

function OnClickClose(self)
	local tStatInfo = {}
	tStatInfo.fu1 = "openbox"
	tStatInfo.fu5 = "closesuspendlayer"
	StatisticClient:SendClickReport(tStatInfo)
	
	OpenBox:RemoveSuspendWndLayer()
	OpenBox:RemoveOpenBoxWnd()
end

function OnClickLookBox(self)
	OpenBox:OpenWeb()
	local tStatInfo = {}
	tStatInfo.fu1 = "openbox"
	tStatInfo.fu5 = "openweb"
	tStatInfo.fu6 = "suspendlayer"
	StatisticClient:SendClickReport(tStatInfo)
	OpenBox:KillDestoryOpenBoxWndTimerId()
	Helper:DestoryModelessWnd("GXZB.OpenBoxWnd")
end

function OnMouseLeave(self)
	OpenBox:SetDestoryOpenBoxWndTimerId()
end

function OnMouseMove(self)
	OpenBox:KillDestoryOpenBoxWndTimerId()
end

function OnMouseLeaveClose(self)
	self:RouteToFather()
end

function OnMouseMoveClose(self)
	self:RouteToFather()
end

function OnMouseLeaveBtn(self)
	self:RouteToFather()
end

function OnMouseMoveBtn(self)
	self:RouteToFather()
end

function OnCreate(self)

end

function OnShowWindow(self, bShow)
	if bShow then
		self:SetTopMost(true)
	else
		
	end	
end

