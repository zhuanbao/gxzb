local tFunctionHelper = XLGetGlobal("FunctionHelper")
local tipUtil = XLGetObject("API.Util")
local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")
local tClientProc = XLGetGlobal("ClientProc")

local g_strDriverVer = nil
local g_nCurHashRate = 0

function TipLog(strLog)
	tipUtil:Log("MaxSpeedDriveWnd: " .. tostring(strLog))
end

function IsRealString(str)
	return type(str) == "string" and str ~= ""
end

function OnMouseEnter(self)
	local objBtnHover = self:GetObject("BtnHover")
	if not objBtnHover then
		objBtnHover = objFactory:CreateUIObject("BtnHover", "ImageObject")
		self:AddChild(objBtnHover)
		objBtnHover:SetObjPos(-5, -9, 20, -6)
		objBtnHover:SetResID("GXZB.PopUpWnd.Btn.Hover")
	end
	objBtnHover:SetVisible(true)
end

function OnMouseLeave(self)
	local objBtnHover = self:GetObject("BtnHover")
	if objBtnHover then
		objBtnHover:SetVisible(false)
	end
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
	local nGPUClient, nCPUClient = tClientProc.GetModeWrokingClient()
	local tStatInfo = {}
	tStatInfo.fu1 = "closemaxspeeddrive"
	tStatInfo.fu5 = nGPUClient
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
	local nGPUClient, nCPUClient = tClientProc.GetModeWrokingClient()
	local tStatInfo = {}
	tStatInfo.fu1 = "updatemaxspeeddrive"
	tStatInfo.fu5 = nGPUClient
	StatisticClient:SendClickReport(tStatInfo)
	UpadteRecommendTime(true)
	if MainWorkModule:CheckIsWorking() then
		MainWorkModule:NotifyQuit()
	end
	UIInterface:ShowRemindRebootWarning()
end

function ShowContent(objtree)
	local nGPUClient, nCPUClient = tClientProc.GetModeWrokingClient()
	if nGPUClient == 0 then
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
	if nGPUClient == 1 then
		nRate = tFunctionHelper.FetchValueByPath(tabRate, {"data", "ca", "rate"}) or 0
	elseif nGPUClient == 2 or nGPUClient == 3 then
		nRate = tFunctionHelper.FetchValueByPath(tabRate, {"data", "cb", "rate"}) or 0
	elseif nGPUClient == 4 or nGPUClient == 5 or nGPUClient == 6 then
		nRate = tFunctionHelper.FetchValueByPath(tabRate, {"data", "cc", "rate"}) or 0
	end
	local tabClientSpeed = tabGpuSpeed[tostring(nGPUClient)]
	if type(tabClientSpeed) ~= "table" then
		return
	end
	g_strDriverVer = tabClientSpeed["VerRef"]
	local strVerDesc = string.format("检测到您的显卡驱动程序不匹配，为了充分发挥显卡的高性能，建议您升级至官方推荐版本%s，升级后您的赚宝速度最高", g_strDriverVer)
	local objVerDesc = objtree:GetUIObject("MaxSpeedDriveWnd.Text.Desc")
	objVerDesc:SetText(strVerDesc)
	
	local strSpeedDesc = ""
	if g_nCurHashRate <= 0 then
		local nMaxSpeed = nRate*tabClientSpeed["MaxSpeed"]
		strSpeedDesc = string.format("可高达%.0f元宝/小时", nMaxSpeed)
	else
		local fPrecent = (tabClientSpeed["MaxSpeed"]-g_nCurHashRate)/g_nCurHashRate
		if fPrecent < 1 then
			strSpeedDesc = string.format("可提升%.0f%%", fPrecent*100)
		else
			strSpeedDesc = string.format("可提升%.2f倍", fPrecent)
		end
	end
	local objContent = objtree:GetUIObject("MaxSpeedDriveWnd.Text.Improve")
	objContent:SetText(strSpeedDesc)
	
	
end

function SetCurrentHashRate(nCurHashRate)
	g_nCurHashRate = nCurHashRate
end

function OnCreate(self)
	local userData = self:GetUserData()
	if userData and userData.parentWnd then
		SetCurrentHashRate(userData.nCurHashRate or 0)
		local objtree = self:GetBindUIObjectTree()
		local objRootLayout = objtree:GetUIObject("MaxSpeedDriveWnd.Content")
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
		local nGPUClient, nCPUClient = tClientProc.GetModeWrokingClient()
		local tStatInfo = {}
		tStatInfo.fu1 = "showmaxspeeddrive"
		tStatInfo.fu5 = nGPUClient
		StatisticClient:SendEventReport(tStatInfo)
		local objtree = self:GetBindUIObjectTree()
		ShowContent(objtree)
	end
end