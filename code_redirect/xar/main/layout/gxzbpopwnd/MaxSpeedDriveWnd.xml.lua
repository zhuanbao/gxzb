local tFunctionHelper = XLGetGlobal("FunctionHelper")
local tipUtil = XLGetObject("API.Util")
local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
local g_strDriverVer = nil
local g_nCurHashRate = 0

function TipLog(strLog)
	tipUtil:Log("MaxSpeedDriveWnd: " .. tostring(strLog))
end

function IsRealString(str)
	return type(str) == "string" and str ~= ""
end

function UpadteRecommendTime(bClear)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tProfitMax"]) ~= "table" then
		tUserConfig["tProfitMax"] = {}
	end
	local tabRecommendDriver = tUserConfig["tProfitMax"]["tRecommendDriver"]
	if type(tabRecommendDriver) ~= "table" then
		tUserConfig["tProfitMax"]["tRecommendDriver"] = {}
	end
	if bClear then
		tUserConfig["tProfitMax"]["tRecommendDriver"] = {}
	else
		local nRecommendCnt = tUserConfig["tProfitMax"]["tRecommendDriver"]["nCnt"] or 0
		tUserConfig["tProfitMax"]["tRecommendDriver"]["nCnt"] = nRecommendCnt + 1
		tUserConfig["tProfitMax"]["tRecommendDriver"]["nLastTime"] = tFunctionHelper.GetCurrentServerTime()
	end
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
end

function OnClickClose(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:EndDialog(0)
	local tStatInfo = {}
	tStatInfo.fu1 = "closemaxspeeddrive"
	tStatInfo.fu5 = ClientWorkModule:GetRealMiningType() or 0
	StatisticClient:SendClickReport(tStatInfo)
	
	UpadteRecommendTime(false)
end

--start SharePlugin.exe /xarpath ..\xar\plugin /xarname updatedriver /wndid updatedrv /driverver 390.77
function RunUpdateDriverPlugin()
	local strDir = tFunctionHelper.GetModuleDir()
	local strPluginExePath = tipUtil:PathCombine(strDir, "SharePlugin.exe")
	local _,_,strInstallDir = string.find(tostring(strDir), "(.+)\\[^\\]+$")
	local strPluginXarDir = tipUtil:PathCombine(strInstallDir, "xar\\plugin")
	local strXarName = "updatedriver"
	local strWndID = "updatedrv"
	local strCmd = "/xarpath \"" .. strPluginXarDir .. "\" /xarname " .. strXarName .. " /wndid " .. strWndID .. " /driverver " .. g_strDriverVer
	tipUtil:ShellExecute(0, "runas", strPluginExePath, strCmd, 0, "SW_SHOWNORMAL")
	TipLog("[RunUpdateDriverPlugin] strCmd = " .. tostring(strCmd))
end

function OnClickUpdate(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:EndDialog(0)
	
	RunUpdateDriverPlugin()
	local tStatInfo = {}
	tStatInfo.fu1 = "updatemaxspeeddrive"
	tStatInfo.fu5 = ClientWorkModule:GetRealMiningType() or 0
	StatisticClient:SendClickReport(tStatInfo)
	UpadteRecommendTime(true)
	if ClientWorkModule:CheckIsWorking() then
		ClientWorkModule:NotifyQuit()
	end
	UIInterface:ShowRemindRebootWarning()
end

function ShowContent(objtree)
	local nClient = ClientWorkModule:GetRealMiningType()
	if nClient == 7 or nClient == nil then
		return
	end
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tProfitMax"]) ~= "table" then
		return
	end
	local tabRate = tUserConfig["tProfitMax"]["tRate"]
	local tabGpuSpeed = tUserConfig["tProfitMax"]["tServerGpuSpeed"]
	if type(tabRate) ~= "table" or type(tabGpuSpeed) ~= "table" then
		return
	end
	local nRate = 0
	if nClient == 1 then
		nRate = tFunctionHelper.FetchValueByPath(tabRate, {"data", "ca", "rate"}) or 0
	elseif nClient == 2 or nClient == 3 then
		nRate = tFunctionHelper.FetchValueByPath(tabRate, {"data", "cb", "rate"}) or 0
	elseif nClient == 4 or nClient == 5 or nClient == 6 then
		nRate = tFunctionHelper.FetchValueByPath(tabRate, {"data", "cc", "rate"}) or 0
	end
	local tabClientSpeed = tabGpuSpeed[tostring(nClient)]
	if type(tabClientSpeed) ~= "table" then
		return
	end
	g_strDriverVer = tabClientSpeed["VerRef"]
	local strSpeedDesc = ""
	if g_nCurHashRate <= 0 then
		local nMaxSpeed = nRate*tabClientSpeed["MaxSpeed"]
		strSpeedDesc = string.format("升级后您的赚宝速度可高达%.0f元宝/小时", nMaxSpeed)
	else
		local fPrecent = (tabClientSpeed["MaxSpeed"]-g_nCurHashRate)/g_nCurHashRate
		if fPrecent < 1 then
			strSpeedDesc = string.format("升级后您的赚宝速度可提升%.0f%%。", fPrecent*100)
		else
			strSpeedDesc = string.format("升级后您的赚宝速度可提升%.2f倍。", fPrecent)
		end
	end
	--local nMinSpeed = nRate*tabClientSpeed["MinSpeed"]
	local strContent = string.format("检测到您的显卡驱动程序不匹配，为了充分发挥显卡本身的高性能，建议您升级显卡驱动至官方推荐版本%s。%s", g_strDriverVer, strSpeedDesc)
	local objContent = objtree:GetUIObject("MaxSpeedDriveWnd.Content")
	objContent:SetText(strContent)
end

function SetCurrentHashRate(nCurHashRate)
	g_nCurHashRate = nCurHashRate
end

function OnCreate(self)
	local userData = self:GetUserData()
	if userData and userData.parentWnd then
		SetCurrentHashRate(userData.nCurHashRate or 0)
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
		local tStatInfo = {}
		tStatInfo.fu1 = "showmaxspeeddrive"
		tStatInfo.fu5 = ClientWorkModule:GetRealMiningType() or 0
		StatisticClient:SendEventReport(tStatInfo)
		local objtree = self:GetBindUIObjectTree()
		ShowContent(objtree)
	end
end