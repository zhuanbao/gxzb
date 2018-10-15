local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local IPCUtil = XLGetObject("IPC.Util")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local hostwndManager = XLGetObject("Xunlei.UIEngine.HostWndManager")
local tFunctionHelper = XLGetGlobal("FunctionHelper")



function OnClickRewardEnter(self, x, y)
	local tStatInfo = {}
	tStatInfo.fu1 = "invotecode"
	tStatInfo.fu5 = "showinvotereward"
	tStatInfo.fu6 = "takecashpanel"
	StatisticClient:SendClickReport(tStatInfo)
	
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	objHostWnd:Show(1)
	Helper:CreateModalWnd("GXZB.InviteRewardInfo", "GXZB.InviteRewardInfoTree", objHostWnd:GetWndHandle(), {["parentWnd"] = objHostWnd})
	--Helper:CreateModalWnd("GXZB.InviteCodeBindWnd", "GXZB.InviteCodeBindTree", objHostWnd:GetWndHandle(), {["parentWnd"] = objHostWnd})
end