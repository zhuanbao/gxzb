local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local g_bShowWndByTray = false
local gStatCount = 0
local gnLastReportRunTmUTC = tipUtil:GetCurrentUTCTime()
local gTimeoutTimerId = nil

local gbLoadCfgSucc = false
local g_tipNotifyIcon = nil
local g_bIsUpdating = false
local JsonFun = nil

local gTaskInfo = nil
local g_strSeverInterfacePrefix = "http://diamond.test.com/pc"

local g_tPopupWndList = {
	[1] = {"GXZB.RemindTipWnd", "GXZB.RemindTipWndTree"},
}

local g_tConfigFileStruct = {
	["tUserConfig"] = {
		["strFileName"] = "UserConfig.dat",
		["tContent"] = {}, 
		["fnMergeOldFile"] = function(infoTable, strFileName) return MergeOldUserCfg(infoTable, strFileName) end,
	},
}


function LoadJSONHelper()
	local strJSONHelperPath = __document.."\\..\\JSON.lua"
	local Module = XLLoadModule(strJSONHelperPath)
	JsonFun = XLGetGlobal("Clent.Json")
end
LoadJSONHelper()

function FailExitTipWnd(iExitCode)
	local tStatInfo = {}
		
	tStatInfo.strEC = "failexit"
	tStatInfo.strEA = GetInstallSrc() or ""
	tStatInfo.strEL = tostring(iExitCode)
	tStatInfo.Exit = true
		
	TipConvStatistic(tStatInfo)
end

function TipConvStatistic(tStat)
	local rdRandom = tipUtil:GetCurrentUTCTime()
	local tStatInfo = tStat or {}
	local strDefaultNil = "gs_null"
	
	local strCID = GetPeerID()
	local strEC = tStatInfo.strEC 
	local strEA = tStatInfo.strEA 
	local strEL = tStatInfo.strEL
	local strEV = tStatInfo.strEV
	
	if IsNilString(strEC) then
		strEC = strDefaultNil
	end
	
	if IsNilString(strEA) then
		strEA = strDefaultNil
	end
	
	if IsNilString(strEL) then
		strEL = strDefaultNil
	end
	
	if tonumber(strEV) == nil then
		strEV = 1
	end

	local strUrl = "http://www.google-analytics.com/collect?v=1&tid=UA-55122790-1&cid="..tostring(strCID)
					.."&t=event&ec="..tostring(strEC).."&ea="..tostring(strEA)
					.."&el="..tostring(strEL).."&ev="..tostring(strEV)
	TipLog("TipConvStatistic: " .. tostring(strUrl))
	
	gStatCount = gStatCount + 1
	if not gForceExit and tStat.Exit then
		gForceExit = true
	end
	tipAsynUtil:AsynSendHttpStat(strUrl, function()
		gStatCount = gStatCount - 1
		if gStatCount == 0 and gForceExit then
			ExitTipWnd()
		end
	end)
	
	local iStatCount = gStatCount
	if gForceExit and iStatCount > 0 and gTimeoutTimerId == nil then	--开启定时退出定时器
		local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
		gTimeoutTimerId = timeMgr:SetTimer(function(Itm, id)
			Itm:KillTimer(id)
			ExitTipWnd()
		end, 15000 * iStatCount)
	end
end

function RegisterFunctionObject(self)
	local obj = {}
	obj.TipLog = TipLog
	obj.FailExitTipWnd = FailExitTipWnd
	obj.TipConvStatistic = TipConvStatistic
	obj.ReportAndExit = ReportAndExit
	obj.ShowPopupWndByName = ShowPopupWndByName
	obj.GetCfgPathWithName = GetCfgPathWithName
	obj.LoadTableFromFile = LoadTableFromFile
	obj.ShowExitRemindWnd = ShowExitRemindWnd
	obj.RegQueryValue = RegQueryValue
	obj.RegSetValue = RegSetValue
	obj.RegDeleteValue = RegDeleteValue
	obj.GetGXZBVersion = GetGXZBVersion
	obj.GetGXZBMinorVer = GetGXZBMinorVer
	obj.CheckTimeIsAnotherDay = CheckTimeIsAnotherDay
	obj.PopupBubbleOneDay = PopupBubbleOneDay
	obj.NewAsynGetHttpFile = NewAsynGetHttpFile
	obj.DownLoadFileWithCheck = DownLoadFileWithCheck
	obj.DownLoadServerConfig = DownLoadServerConfig
	obj.CheckIsNewVersion = CheckIsNewVersion
	obj.GetFileSaveNameFromUrl = GetFileSaveNameFromUrl
	obj.SetNotifyIconState = SetNotifyIconState
	obj.SetWndForeGround = SetWndForeGround
	obj.PopupNotifyIconTip = PopupNotifyIconTip
	obj.CheckCommonUpdateTime = CheckCommonUpdateTime
	obj.CheckAutoUpdateTime = CheckAutoUpdateTime
	obj.SaveCommonUpdateUTC = SaveCommonUpdateUTC
	obj.SaveAutoUpdateUTC = SaveAutoUpdateUTC
	obj.CheckMD5 = CheckMD5
	obj.GetSpecifyFilterTableFromMem = GetSpecifyFilterTableFromMem
	obj.SaveSpecifyFilterTableToMem = SaveSpecifyFilterTableToMem
	obj.SaveConfigToFileByKey = SaveConfigToFileByKey
	obj.ReadConfigFromMemByKey = ReadConfigFromMemByKey
	obj.CheckIsUpdating = CheckIsUpdating
	obj.SetIsUpdating = SetIsUpdating
	obj.GetTimeStamp = GetTimeStamp
	obj.CheckForceVersion = CheckForceVersion
	obj.IsUACOS = IsUACOS
	obj.DownLoadTempQrcode = DownLoadTempQrcode
	obj.CycleQuerySeverForBindResult = CycleQuerySeverForBindResult
	obj.SetUserBindInfo = SetUserBindInfo
	obj.InitTrayTipWnd = InitTrayTipWnd 
	obj.ReadAllConfigInfo = ReadAllConfigInfo
	obj.StartRunCountTimer = StartRunCountTimer
	obj.CreatePopupTipWnd = CreatePopupTipWnd
	obj.InitMinerInfoToServer = InitMinerInfoToServer
	obj.GetInstallSrc = GetInstallSrc
	obj.SaveAllConfig = SaveAllConfig
	obj.CheckPeerIDList = CheckPeerIDList
	obj.DownLoadHeadImg = DownLoadHeadImg
	XLSetGlobal("Global.FunctionHelper", obj)
end

function SaveCommonUpdateUTC()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["nLastCommonUpdateUTC"] = tipUtil:GetCurrentUTCTime()
	SaveConfigToFileByKey("tUserConfig")
end

function IsNilString(AString)
	if AString == nil or AString == "" then
		return true
	end
	return false
end

function IsRealString(str)
	return type(str) == "string" and str ~= ""
end

function MessageBox(str)
	if not IsRealString(str) then
		return
	end
	
	tipUtil:MsgBox(str, "错误", 0x10)
end


function GetTimeStamp()
	local strPeerId = GetPeerID()
	local iFlag = tonumber(string.sub(strPeerId, 12, 12), 16) or 0
	local iTime = tipUtil:GetCurrentUTCTime()
	local ss = math.floor((iTime + 8 * 3600  - (iFlag + 1) * 3600)/(24*3600))
	local strStamp = "?stamp=" .. tostring(ss)
	return strStamp 
end


function TipLog(strLog)
	if type(tipUtil.Log) == "function" then
		tipUtil:Log("@@client log: " .. tostring(strLog))
	end
end

function IsUserFullScreen()
	local bRet = false
	if type(tipUtil.IsNowFullScreen) == "function" then
		bRet = tipUtil:IsNowFullScreen()
	end
	return bRet
end

function CheckTimeIsAnotherDay(LastTime)
	local bRet = false
	local LYear, LMonth, LDay, LHour, LMinute, LSecond = tipUtil:FormatCrtTime(LastTime)
	local curTime = tipUtil:GetCurrentUTCTime()
	local CYear, CMonth, CDay, CHour, CMinute, CSecond = tipUtil:FormatCrtTime(curTime)
	if LYear ~= CYear or LMonth ~= CMonth or LDay ~= CDay then
		bRet = true
	end
	return bRet
end


function QueryAllUsersDir()	--获取AllUser路径
	local bRet = false
	local strPublicEnv = "%PUBLIC%"
	local strRet = tipUtil:ExpandEnvironmentStrings(strPublicEnv)
	if strRet == nil or strRet == "" or strRet == strPublicEnv then
		local nCSIDL_COMMON_APPDATA = 35 --CSIDL_COMMON_APPDATA(0x0023)
		strRet = tipUtil:GetSpecialFolderPathEx(nCSIDL_COMMON_APPDATA)
	end
	if not IsNilString(strRet) and tipUtil:QueryFileExists(strRet) then
		bRet = true
	end
	return bRet, strRet
end


function GetFileSaveNameFromUrl(url)
	local _, _, strFileName = string.find(tostring(url), ".*/(.*)$")
	local npos = string.find(strFileName, "?", 1, true)
	if npos ~= nil then
		strFileName = string.sub(strFileName, 1, npos-1)
	end
	return strFileName
end


function CheckIsNewVersion(strNewVer, strCurVer)
	if not IsRealString(strNewVer) or not IsRealString(strCurVer) then
		return false
	end

	local a,b,c,d = string.match(strNewVer, "(%d+)%.(%d+)%.(%d+)%.(%d+)")
	local A,B,C,D = string.match(strCurVer, "(%d+)%.(%d+)%.(%d+)%.(%d+)")
	
	a = tonumber(a)
	b = tonumber(b)
	c = tonumber(c)
	d = tonumber(d)
	
	A = tonumber(A)
	B = tonumber(B)
	C = tonumber(C)
	D = tonumber(D)
	
	return a>A or (a==A and (b>B or (b==B and (c>C or (c==C and d>D)))))
end


function GetPeerID()
	local strPeerID = RegQueryValue("HKEY_LOCAL_MACHINE\\Software\\gxzb\\PeerId")
	if IsRealString(strPeerID) then
		return string.upper(strPeerID)
	end

	local strRandPeerID = tipUtil:GetPeerId()
	if not IsRealString(strRandPeerID) then
		return ""
	end
	
	RegSetValue("HKEY_LOCAL_MACHINE\\Software\\gxzb\\PeerId", strRandPeerID)
	return string.upper(strRandPeerID)
end

--渠道
function GetInstallSrc()
	local strInstallSrc = RegQueryValue("HKEY_LOCAL_MACHINE\\Software\\gxzb\\InstallSource")
	if not IsNilString(strInstallSrc) then
		return tostring(strInstallSrc)
	end
	
	return ""
end


function NewAsynGetHttpFile(strUrl, strSavePath, bDelete, funCallback, nTimeoutInMS)
	local bHasAlreadyCallback = false
	local timerID = nil
	
	if string.find(strUrl, "^https://") == nil then
		tipAsynUtil:AsynGetHttpFile(strUrl, strSavePath, bDelete, 
			function (nRet, strTargetFilePath, strHeaders)
				if timerID ~= nil then
					tipAsynUtil:KillTimer(timerID)
				end
				if not bHasAlreadyCallback then
					bHasAlreadyCallback = true
					funCallback(nRet, strTargetFilePath, strHeaders)
				end
			end)
	else
		tipAsynUtil:AjaxGetHttpFile(strUrl, strSavePath, function(nRet, strTargetFilePath, strHeaders)
			if timerID ~= nil then
				tipAsynUtil:KillTimer(timerID)
			end
			if not bHasAlreadyCallback then
				bHasAlreadyCallback = true
				funCallback(nRet, strTargetFilePath, strHeaders)
			end
		end)
	end
	
	timerID = tipAsynUtil:SetTimer(nTimeoutInMS or 2 * 60 * 1000,
		function (nTimerId)
			tipAsynUtil:KillTimer(nTimerId)
			timerID = nil
			if not bHasAlreadyCallback then
				bHasAlreadyCallback = true
				funCallback(-2)
			end
		end)
end

function CheckMD5(strFilePath, strExpectedMD5) 
	local bPassCheck = false
	
	if not IsNilString(strFilePath) then
		local strMD5 = tipUtil:GetMD5Value(strFilePath)
		TipLog("[CheckMD5] strFilePath = " .. tostring(strFilePath) .. ", strMD5 = " .. tostring(strMD5))
		if not IsRealString(strExpectedMD5) 
			or (not IsNilString(strMD5) and not IsNilString(strExpectedMD5) and string.lower(strMD5) == string.lower(strExpectedMD5))
			then
			bPassCheck = true
		end
	end
	
	TipLog("[CheckMD5] strFilePath = " .. tostring(strFilePath) .. ", strExpectedMD5 = " .. tostring(strExpectedMD5) .. ". bPassCheck = " .. tostring(bPassCheck))
	return bPassCheck
end


function DownLoadFileWithCheck(strURL, strSavePath, strCheckMD5, fnCallBack)
	if type(fnCallBack) ~= "function"  then
		return
	end

	if IsRealString(strCheckMD5) and CheckMD5(strSavePath, strCheckMD5) then
		TipLog("[DownLoadFileWithCheck]File Already existed")
		fnCallBack(1, strSavePath)
		return
	end
	
	NewAsynGetHttpFile(strURL, strSavePath, false, function(bRet, strDownLoadPath)
		TipLog("[DownLoadFileWithCheck] NewAsynGetHttpFile:bret = " .. tostring(bRet) 
				.. ", strURL = " .. tostring(strURL) .. ", strDownLoadPath = " .. tostring(strDownLoadPath))
		if 0 == bRet then
			strSavePath = strDownLoadPath
            if CheckMD5(strSavePath, strCheckMD5) then
				fnCallBack(bRet, strSavePath)
			else
				TipLog("[DownLoadFileWithCheck]Did Not Pass MD5 Check")
				fnCallBack(-2)
			end	
		else
			TipLog("[DownLoadFileWithCheck] DownLoad failed")
			fnCallBack(-3)
		end
	end)
end


function CheckIsUpdating()
	return g_bIsUpdating
end

function SetIsUpdating(bIsUpdating)
	if type(bIsUpdating) == "boolean" then
		g_bIsUpdating = bIsUpdating
	end
end


function DownLoadServerConfig(fnCallBack, nTimeInMs)
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	
	local strConfigURL = tUserConfig["strServerConfigURL"]
	if not IsRealString(strConfigURL) then
		fnCallBack(-1)
		return
	end
	
	local strSavePath = GetCfgPathWithName("ServerConfig.dat")
	if not IsRealString(strSavePath) then
		fnCallBack(-1)
		return
	end
	
	local strStamp = GetTimeStamp()
	local strURLFix = strConfigURL..strStamp
	local nTime = tonumber(nTimeInMs) or 5*1000
		
	NewAsynGetHttpFile(strURLFix, strSavePath, false
	, function(bRet, strRealPath)
		TipLog("[DownLoadServerConfig] bRet:"..tostring(bRet)
				.." strRealPath:"..tostring(strRealPath))
				
		if 0 == bRet then
			fnCallBack(0, strSavePath)
		else
			fnCallBack(bRet)
		end		
	end, nTime)
end

function SaveAllConfig()
	if gbLoadCfgSucc then
		for strKey, tContent in pairs(g_tConfigFileStruct) do
			SaveConfigToFileByKey(strKey)
		end
	end
end

function ReadAllConfigInfo()
	for strKey, tConfig in pairs(g_tConfigFileStruct) do
		local strFileName = tConfig["strFileName"]
		local strCfgPath = GetCfgPathWithName(strFileName)
		local infoTable = LoadTableFromFile(strCfgPath)
		if type(infoTable) ~= "table" then
			TipLog("[ReadAllConfigInfo] GetConfigFile failed! "..tostring(strFileName))
			return false
		end
		
		local tContent = infoTable
		local bMerge = false
		local fnMergeOldFile = tConfig["fnMergeOldFile"]
		if type(fnMergeOldFile) == "function" then
			bMerge, tContent = fnMergeOldFile(infoTable, strFileName)
		end
		
		tConfig["tContent"] = tContent
		if bMerge then
			SaveConfigToFileByKey(strKey)
		end
	end

	gbLoadCfgSucc = true	
	TipLog("[ReadAllConfigInfo] success!")
	return true
end

function ExitTipWnd(statInfo)
	SaveAllConfig()			
	TipLog("************ Exit ************")
	tipUtil:Exit("Exit")
end


function DestroyMainWnd()
	local hostwndManager = XLGetObject("Xunlei.UIEngine.HostWndManager")
	local strHostWndName = "GXZBTipWnd.MainFrame"
	local objHostWnd = hostwndManager:GetHostWnd(strHostWndName)
	if objHostWnd then
		hostwndManager:RemoveHostWnd(strHostWndName)
	end
end

function CreatePopupTipWnd()
	for key, tItem in pairs(g_tPopupWndList) do
		local strHostWndName = tItem[1]
		local strTreeName = tItem[2]
		local bSucc = CreateWndByName(strHostWndName, strTreeName)
		
		if not bSucc then
			TipLog("[CreatePopupTipWnd] create wnd failed: "..tostring(strHostWndName))
			FailExitTipWnd(5)
			return false
		end
	end
	
	return true
end

function CreateWndByName(strHostWndName, strTreeName)
	local bSuccess = false
	local strInstWndName = strHostWndName..".Instance"
	local strInstTreeName = strTreeName..".Instance"
	
	local templateMananger = XLGetObject("Xunlei.UIEngine.TemplateManager")
	local frameHostWndTemplate = templateMananger:GetTemplate(strHostWndName, "HostWndTemplate" )
	if frameHostWndTemplate then
		local frameHostWnd = frameHostWndTemplate:CreateInstance(strInstWndName)
		if frameHostWnd then
			local objectTreeTemplate = nil
			objectTreeTemplate = templateMananger:GetTemplate(strTreeName, "ObjectTreeTemplate")
			if objectTreeTemplate then
				local uiObjectTree = objectTreeTemplate:CreateInstance(strInstTreeName)
				if uiObjectTree then
					frameHostWnd:BindUIObjectTree(uiObjectTree)
					local iRet = frameHostWnd:Create()
					if iRet ~= nil and iRet ~= 0 then
						bSuccess = true
					end
				end
			end
		end
	end

	return bSuccess
end

function DestroyPopupWnd()
	local hostwndManager = XLGetObject("Xunlei.UIEngine.HostWndManager")

	for key, tItem in pairs(g_tPopupWndList) do
		local strPopupWndName = tItem[1]
		local strPopupInst = strPopupWndName..".Instance"
		
		local objPopupWnd = hostwndManager:GetHostWnd(strPopupInst)
		if objPopupWnd then
			hostwndManager:RemoveHostWnd(strPopupInst)
		end
	end
end


function GetGXZBVersion()
	local strgxzbPath = RegQueryValue("HKEY_LOCAL_MACHINE\\Software\\gxzb\\path")
	if not IsRealString(strgxzbPath) or not tipUtil:QueryFileExists(strgxzbPath) then
		return ""
	end

	return tipUtil:GetFileVersionString(strgxzbPath)
end


function IsUACOS()
	local bRet = true
	local iMax, iMin = tipUtil:GetOSVersion()
	if type(iMax) == "number" and iMax <= 5 then
		bRet = false
	end
	return bRet
end


function GetGXZBMinorVer()
	local strVersion = GetGXZBVersion()
	if not IsRealString(strVersion) then
		return ""
	end
	
	local _, _, strMinorVer = string.find(strVersion, "%d+%.%d+%.%d+%.(%d+)")
	return strMinorVer
end


function RegQueryValue(sPath)
	if IsRealString(sPath) then
		local sRegRoot, sRegPath, sRegKey = string.match(sPath, "^(.-)[\\/](.*)[\\/](.-)$")
		if IsRealString(sRegRoot) and IsRealString(sRegPath) then
			return tipUtil:QueryRegValue(sRegRoot, sRegPath, sRegKey or "") or ""
		end
	end
	return ""
end


function RegDeleteValue(sPath)
	if IsRealString(sPath) then
		local sRegRoot, sRegPath = string.match(sPath, "^(.-)[\\/](.*)")
				
		if IsRealString(sRegRoot) and IsRealString(sRegPath) then
			return tipUtil:DeleteRegValue(sRegRoot, sRegPath)
		end
	end
	return false
end


function RegSetValue(sPath, value)
	if IsRealString(sPath) then
		local sRegRoot, sRegPath, sRegKey = string.match(sPath, "^(.-)[\\/](.*)[\\/](.-)$")
		if IsRealString(sRegRoot) and IsRealString(sRegPath) then
			return tipUtil:SetRegValue(sRegRoot, sRegPath, sRegKey or "", value or "")
		end
	end
	return false
end


function LoadTableFromFile(strDatFilePath)
	local tResult = nil

	if IsRealString(strDatFilePath) and tipUtil:QueryFileExists(strDatFilePath) then
		local tMod = XLLoadModule(strDatFilePath)
		if type(tMod) == "table" and type(tMod.GetSubTable) == "function" then
			local tDat = tMod.GetSubTable()
			if type(tDat) == "table" then
				tResult = tDat
			end
		end
	end
	
	return tResult
end

function SetWndForeGround(objHostWnd)
	if not objHostWnd then
		return
	end

	if not IsUserFullScreen() then
		-- objHostWnd:SetTopMost(true)
		if type(tipUtil.SetWndPos) == "function" then
			local hWnd = objHostWnd:GetWndHandle()
			if hWnd ~= nil then
				TipLog("[SetWndForeGround] success")
				tipUtil:SetWndPos(hWnd, 0, 0, 0, 0, 0, 0x0043)
			end
		end
	elseif type(tipUtil.GetForegroundProcessInfo) == "function" then
		local hFrontHandle, strPath = tipUtil:GetForegroundProcessInfo()
		if hFrontHandle ~= nil then
			objHostWnd:BringWindowToBack(hFrontHandle)
		end
	end
end

function ShowPopupWndByName(strWndName, bSetTop)
	local hostwndManager = XLGetObject("Xunlei.UIEngine.HostWndManager")
	local frameHostWnd = hostwndManager:GetHostWnd(tostring(strWndName))
	if frameHostWnd == nil then
		TipLog("[ShowPopupWindow] GetHostWnd failed: "..tostring(strWndName))
		return
	end

	if not IsUserFullScreen() then
		if type(tipUtil.SetWndPos) == "function" then
			local hWnd = frameHostWnd:GetWndHandle()
			if hWnd ~= nil then
				TipLog("[ShowPopupWndByName] success")
				if bSetTop then
					frameHostWnd:SetTopMost(true)
					tipUtil:SetWndPos(hWnd, 0, 0, 0, 0, 0, 0x0043)
				else
					tipUtil:SetWndPos(hWnd, -2, 0, 0, 0, 0, 0x0043)
				end
			end
		end
	elseif type(tipUtil.GetForegroundProcessInfo) == "function" then
		local hFrontHandle, strPath = tipUtil:GetForegroundProcessInfo()
		if hFrontHandle ~= nil then
			frameHostWnd:BringWindowToBack(hFrontHandle)
		end
	end
	
	frameHostWnd:Show(5)
end


function ShowExitRemindWnd()
	ShowPopupWndByName("TipExitRemindWnd.Instance", true)
end


function HideTray()
	if g_tipNotifyIcon then
		g_tipNotifyIcon:Hide()
	end
end


function InitTrayTipWnd(objHostWnd)
    if not objHostWnd then
	    TipLog("[InitTrayTipWnd] para error")
	    return
	end

	--创建托盘
    local tipNotifyIcon = XLGetObject("Notify.Icon")
	if not tipNotifyIcon then
		TipLog("[InitTrayTipWnd] not support NotifyIcon")
	    return
	end
	
	local hostwndManager = XLGetObject("Xunlei.UIEngine.HostWndManager")
	
	----托盘事件响应
	function OnTrayEvent(event1,event2,event3,event4)
		local strHostWndName = "GSTrayMenuHostWnd.MainFrame"
		local newWnd = hostwndManager:GetHostWnd(strHostWndName)	
				
		--单击右键,创建并显示菜单
		if event3 == 517 then
			if not newWnd then
        		CreateTrayTipWnd(objHostWnd)
			end
		end
		
		--单击左键
		if event3 == 0x0202 then
			ShowMainPanleByTray(objHostWnd)
			ShowIntroduceOnce()
		end
		
		--点击气泡
		if event3 == 1029 then
			if g_bShowWndByTray then
				ShowMainPanleByTray(objHostWnd)	
			end
		end
		
		--mousemove
		if event3 == 512 then
			SetNotifyIconState()
		end
	end

	tipNotifyIcon:Attach(OnTrayEvent)
	g_tipNotifyIcon = tipNotifyIcon
	SetNotifyIconState()
	tipNotifyIcon:Show()
	return g_tipNotifyIcon
end


function ShowMainPanleByTray(objHostWnd)
	local hostwndManager = XLGetObject("Xunlei.UIEngine.HostWndManager")
	if objHostWnd then
		objHostWnd:Show(5)
		SetWndForeGround(objHostWnd)
		local strState = objHostWnd:GetWindowState()
		if tostring(strState) == "min" then
			objHostWnd:BringWindowToTop(true)
		end
		
		-- local strHostWndName = "TipFilterRemindWnd.Instance"
		-- local objPopupWnd = hostwndManager:GetHostWnd(strHostWndName)
		-- if objPopupWnd and objPopupWnd:GetVisible() then
			-- local hWnd = objPopupWnd:GetWndHandle()
			-- if hWnd then
				-- objHostWnd:BringWindowToBack(hWnd)
			-- end
		-- end
	end
end


function SetNotifyIconState(strText)
	if not g_tipNotifyIcon then
		return
	end
	g_tipNotifyIcon:ShowNotifyIconTip(false)
	
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	local bWorkOpen = tUserConfig["bWorkOpen"] or false
	local nMoneyCount = tUserConfig["nMoneyCountOneDay"] or 0
	
	local strState = "正常赚宝"
	if not bWorkOpen then
		strState = "停止赚宝"
	end
	local strDefaultText = "共享赚宝\r\n状态："..strState.."\r\n今日赚得元宝："..tostring(nMoneyCount).."元"
	
	local strResImageDir = __document .. "\\..\\..\\..\\..\\res"
	local strImageName = "GXZB.TrayIcon.Close.ico"
	if bWorkOpen then
		strImageName = "GXZB.TrayIcon.Open.ico"
	end
	
	local strImagePath = strResImageDir.. "\\".. strImageName
	if not tipUtil:QueryFileExists(strImagePath) then
		strImagePath = nil
	end
	
	local strShowText = strText or strDefaultText
	g_tipNotifyIcon:SetIcon(strImagePath, strShowText)
end


function PopupNotifyIconTip(strText, bShowWndByTray)
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	local bBubbleRemind = FetchValueByPath(tUserConfig, {"tConfig", "BubbleRemind", "bState"})
	
	if not bBubbleRemind then
		g_bShowWndByTray = false
		return
	end
	
	if IsRealString(strText) and g_tipNotifyIcon then
		g_tipNotifyIcon:ShowNotifyIconTip(true, strText)
	end
	
	g_bShowWndByTray = bShowWndByTray
end


function PopupBubbleOneDay()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	local nLastBubbleUTC = tonumber(tUserConfig["nLastBubbleUTC"]) 
	
	if not IsNilString(nLastBubbleUTC) and not CheckTimeIsAnotherDay(nLastBubbleUTC) then
		return
	end
	
	local nNoShowFilterBubble = tonumber(tUserConfig["nNoShowFilterBubble"]) 
	if not IsNilString(nNoShowFilterBubble) then
		return
	end
	
	ShowPopupWndByName("TipFilterBubbleWnd.Instance", true)
	tUserConfig["nLastBubbleUTC"] = tipUtil:GetCurrentUTCTime()
	SaveConfigToFileByKey("tUserConfig")
end


function CreateTrayTipWnd(objHostWnd)
	local uTempltMgr = XLGetObject("Xunlei.UIEngine.TemplateManager")
	local uHostWndMgr = XLGetObject("Xunlei.UIEngine.HostWndManager")
	local uObjTreeMgr = XLGetObject("Xunlei.UIEngine.TreeManager")

	if uTempltMgr and uHostWndMgr and uObjTreeMgr then
		local uHostWnd = nil
		local strHostWndTempltName = "TipTrayWnd"
		local strHostWndTempltClass = "HostWndTemplate"
		local strHostWndName = "GSTrayMenuHostWnd.MainFrame"
		local uHostWndTemplt = uTempltMgr:GetTemplate(strHostWndTempltName, strHostWndTempltClass)
		if uHostWndTemplt then
			uHostWnd = uHostWndTemplt:CreateInstance(strHostWndName)
		end

		local uObjTree = nil
		local strObjTreeTempltName = "TrayMenuTree"
		local strObjTreeTempltClass = "ObjectTreeTemplate"
		local strObjTreeName = "GSTrayMenuWnd.MainObjectTree"
		local uObjTreeTemplt = uTempltMgr:GetTemplate(strObjTreeTempltName, strObjTreeTempltClass)
		if uObjTreeTemplt then
			uObjTree = uObjTreeTemplt:CreateInstance(strObjTreeName)
		end

		if uHostWnd and uObjTree then
			--函数会阻塞
			local bSucc = ShowPopupMenu(uHostWnd, uObjTree)
			
			if bSucc and uHostWnd:GetMenuMode() == "manual" then
				uObjTreeMgr:DestroyTree(strObjTreeName)
				uHostWndMgr:RemoveHostWnd(strHostWndName)
			end
		end
	end
end


function ShowPopupMenu(uHostWnd, uObjTree)
	uHostWnd:BindUIObjectTree(uObjTree)
					
	local nPosCursorX, nPosCursorY = tipUtil:GetCursorPos()
	if type(nPosCursorX) ~= "number" or type(nPosCursorY) ~= "number" then
		return false
	end
	
	local nScrnLeft, nScrnTop, nScrnRight, nScrnBottom = tipUtil:GetScreenArea()
	
	local objMainLayout = uObjTree:GetUIObject("TrayMenu.Main")
	if not objMainLayout then
	    return false
	end	
		
	local nL, nT, nR, nB = objMainLayout:GetObjPos()				
	local nMenuContainerWidth = nR - nL
	local nMenuContainerHeight = nB - nT
	local nMenuScreenLeft = nPosCursorX
	local nMenuScreenTop = nPosCursorY - nMenuContainerHeight
	TipLog("[ShowTrayCtrlPanel] about to popup menu")
	
	if nMenuScreenLeft+nMenuContainerWidth > nScrnRight - 10 then
		nMenuScreenLeft = nPosCursorX - nMenuContainerWidth
	end
	
	-- uHostWnd:SetFocus(false) --先失去焦点，否则存在菜单不会消失的bug
	
	--函数会阻塞
	local bOk = uHostWnd:TrackPopupMenu(objHostWnd, nMenuScreenLeft, nMenuScreenTop, nMenuContainerWidth, nMenuContainerHeight)
	TipLog("[ShowPopupMenu] end menu")
	
	return bOk
end

-------------------------------

function FetchValueByPath(obj, path)
	local cursor = obj
	for i = 1, #path do
		cursor = cursor[path[i]]
		if cursor == nil then
			return nil
		end
	end
	return cursor
end


function ReadConfigFromMemByKey(strKey)
	if not IsRealString(strKey) or type(g_tConfigFileStruct[strKey])~="table" then
		return nil
	end

	local tContent = g_tConfigFileStruct[strKey]["tContent"]
	return tContent
end


function GetCfgPathWithName(strCfgName)
	local bOk, strBaseDir = QueryAllUsersDir()
	if not bOk then
		return ""
	end
	
	local strCfgFilePath = tipUtil:PathCombine(strBaseDir, "gxzb\\"..tostring(strCfgName))
	return strCfgFilePath or ""
end

function GetResSavePath(strName)
	local bOk, strBaseDir = QueryAllUsersDir()
	if not bOk then
		return ""
	end
	
	local strPath = tipUtil:PathCombine(strBaseDir, "gxzb\\res\\"..tostring(strName))
	return strPath or ""
end

function GetSpecifyFilterTableFromMem(strTableName)
	local tFilterTable = ReadConfigFromMemByKey("tFilterConfig") or {}

	if not IsRealString(strTableName) then
		return tFilterTable
	end

	return tFilterTable[strTableName]
end


function SaveSpecifyFilterTableToMem(tNewTable, strTableName)
	local tFilterTable = ReadConfigFromMemByKey("tFilterConfig") or {}

	if not IsRealString(strTableName) then
		tFilterTable = tNewTable
	else
		tFilterTable[strTableName] = tNewTable
	end
end


function SaveConfigToFileByKey(strKey)
	if not IsRealString(strKey) or type(g_tConfigFileStruct[strKey])~="table" then
		return
	end

	local strFileName = g_tConfigFileStruct[strKey]["strFileName"]
	local tContent = g_tConfigFileStruct[strKey]["tContent"]
	local strConfigPath = GetCfgPathWithName(strFileName)
	if IsRealString(strConfigPath) and type(tContent) == "table" then
		tipUtil:SaveLuaTableToLuaFile(tContent, strConfigPath)
	end
end

function MergeOldUserCfg(tCurrentCfg, strFileName)
	local tOldCfg, strOldCfgPath = GetOldCfgContent(strFileName)
	if type(tOldCfg) ~= "table" then
		return false, tCurrentCfg
	end
	
	tCurrentCfg["nLastAutoUpdateUTC"] = tOldCfg["nLastAutoUpdateUTC"]
	tCurrentCfg["nLastBubbleUTC"] = tOldCfg["nLastBubbleUTC"]

	tCurrentCfg["nLastCommonUpdateUTC"] = tOldCfg["nLastCommonUpdateUTC"]
	
	if type(tCurrentCfg["tConfig"]) ~= "table" then
		tCurrentCfg["tConfig"] = {}
	end
	
	local tOldStateConfig = tOldCfg["tConfig"] or {}
	for strKey, tStateInfo in pairs(tOldStateConfig) do
		--是否开机启动以安装时选择为准
		if strKey ~= "AutoStup" then
			tCurrentCfg["tConfig"][strKey] = tStateInfo
		end
	end	
	
	tipUtil:DeletePathFile(strOldCfgPath)
	return true, tCurrentCfg
end


function GetOldCfgContent(strCurFileName)
	local strOldFileName = strCurFileName..".bak"
	local strOldCfgPath = GetCfgPathWithName(strOldFileName)
	if not IsRealString(strOldCfgPath) or not tipUtil:QueryFileExists(strOldCfgPath) then
		return nil
	end
	
	local tOldCfg = LoadTableFromFile(strOldCfgPath)
	return tOldCfg, strOldCfgPath
end

function ReportAndExit()
	DestroyMainWnd()
	DestroyPopupWnd()
	HideTray()
	
	local tStatInfo = {}
		
	SendRunTimeReport(0, true)
	
	tStatInfo.strEC = "exit"	
	tStatInfo.strEA = GetInstallSrc() or ""
	tStatInfo.Exit = true
			
	TipConvStatistic(tStatInfo)
end

function StartRunCountTimer()
	local nTimeSpanInSec = 10 * 60 
	local nTimeSpanInMs = nTimeSpanInSec * 1000
	local timerManager = XLGetObject("Xunlei.UIEngine.TimerManager")
	timerManager:SetTimer(function(item, id)
		gnLastReportRunTmUTC = tipUtil:GetCurrentUTCTime()
		SendRunTimeReport(nTimeSpanInSec, false)
	end, nTimeSpanInMs)
	
	local nTimeSpanInMs = 2*60*1000
	timerManager:SetTimer(function(item, id)
		--SendClientReport(10)
	end, nTimeSpanInMs)
end


function SendRunTimeReport(nTimeSpanInSec, bExit)
	local tStatInfo = {}
	tStatInfo.strEC = "runtime"
	tStatInfo.strEA = GetInstallSrc() or ""
	
	local nRunTime = 0
	if bExit and gnLastReportRunTmUTC ~= 0 then
		nRunTime = math.abs(tipUtil:GetCurrentUTCTime() - gnLastReportRunTmUTC)
	else
		nRunTime = nTimeSpanInSec
	end
	tStatInfo.strEV = nRunTime
	
	TipConvStatistic(tStatInfo)
end

function CheckForceVersion(tForceVersion)
	if type(tForceVersion) ~= "table" then
		return false
	end

	local bRightVer = false
	
	local strCurVersion = GetGXZBVersion()
	local _, _, _, _, _, strCurVersion_4 = string.find(strCurVersion, "(%d+)%.(%d+)%.(%d+)%.(%d+)")
	local nCurVersion_4 = tonumber(strCurVersion_4)
	if type(nCurVersion_4) ~= "number" then
		return bRightVer
	end
	for iIndex = 1, #tForceVersion do
		local strRange = tForceVersion[iIndex]
		local iPos = string.find(strRange, "-")
		if iPos ~= nil then
			local lVer = tonumber(string.sub(strRange, 1, iPos - 1))
			local hVer = tonumber(string.sub(strRange, iPos + 1))
			if lVer ~= nil and hVer ~= nil and nCurVersion_4 >= lVer and nCurVersion_4 <= hVer then
				bRightVer = true
				break
			end
		else
			local verFlag = tonumber(strRange)
			if verFlag ~= nil and nCurVersion_4 == verFlag then
				bRightVer = true
				break
			end
		end
	end
	
	return bRightVer
end

function CheckCommonUpdateTime(nTimeInDay)
	return CheckUpdateTimeSpan(nTimeInDay, "nLastCommonUpdateUTC")
end

function CheckAutoUpdateTime(nTimeInDay)
	return CheckUpdateTimeSpan(nTimeInDay, "nLastAutoUpdateUTC")
end

function CheckUpdateTimeSpan(nTimeInDay, strUpdateType)
	if type(nTimeInDay) ~= "number" then
		return false
	end
	
	local nTimeInSec = nTimeInDay*24*3600
	local nCurTimeUTC = tipUtil:GetCurrentUTCTime()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	local nLastUpdateUTC = tUserConfig[strUpdateType] or 0
	local nTimeSpan = math.abs(nCurTimeUTC - nLastUpdateUTC)
	
	if nTimeSpan > nTimeInSec then
		return true
	end	
	
	return false
end

function SaveAutoUpdateUTC()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["nLastAutoUpdateUTC"] = tipUtil:GetCurrentUTCTime()
	SaveConfigToFileByKey("tUserConfig")
end


function QuerySvrForLoginInfo(nSceneID)
	local strInterfaceName = "login"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(GetPeerID()))
	strInterfaceParam = strInterfaceParam .. "&sceneID=" .. tostring(nSceneID)
	local strParam = MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  g_strSeverInterfacePrefix .. strParam
	TipLog("[QuerySvrForLoginInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function CycleQuerySeverForBindResult(nSceneID, fnCallBack, nTimeoutInMS)
	local strBindResult = QuerySvrForLoginInfo(nSceneID)
	strBindResult = "http://cloud.v.xunlei.com/temp/login.dat"
	NewAsynGetHttpContent(strBindResult, false
	, function(nRet, strContent, respHeaders)
		TipLog("[CycleQuerySeverForBindResult] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
				
		if 0 == nRet then
			local tabInfo = JsonFun:decode(strContent)
			if type(tabInfo) ~= "table" 
				or tabInfo["rtn"] ~= 0 then
				TipLog("[DownLoadTempQrcode] Parse Json failed.")
				fnCallBack(false,"解析登陆信息失败")
				return 
			end
			fnCallBack(true,tabInfo)
		else
			fnCallBack(false,"获取绑定二维码信息失败，请检测网络")
		end		
	end,nTimeoutInMS)
end


function MakeInterfaceMd5(strInterface,strInterfaceParam)
	local strParam = "/" .. strInterface .. "?" .. tostring(strInterfaceParam)
	local strMd5 = tipUtil:GetStringMD5(strParam)
	strParam = strParam .. "&md5=" .. strMd5
	return strParam
end

function QuerySvrForQrcodeInfo()
	local strInterfaceName = "getQrcode"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(GetPeerID()))
	local strParam = MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  g_strSeverInterfacePrefix .. strParam
	TipLog("[QuerySvrForQrcodeInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function DownLoadTempQrcode(fnCallBack)
	local strQrcodeUrl = QuerySvrForQrcodeInfo()
	TipLog("[DownLoadTempQrcode] strQrcodeUrl = " .. strQrcodeUrl)
	strQrcodeUrl = "http://cloud.v.xunlei.com/temp/qrcode.dat"
	NewAsynGetHttpContent(strQrcodeUrl, false
	, function(nRet, strContent, respHeaders)
		TipLog("[DownLoadTempQrcode] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
				
		if 0 == nRet then
			local tabInfo = JsonFun:decode(strContent)
			if type(tabInfo) ~= "table" 
				or tabInfo["rtn"] ~= 0 
				or not IsRealString(tabInfo["qrcodeUrl"])
				or tonumber(tabInfo["sceneID"]) == nil then
				TipLog("[DownLoadTempQrcode] Parse Json failed.")
				fnCallBack(false,"解析二维码信息失败")
				return 
			end
			local strQrcodeUrl = tabInfo["qrcodeUrl"]
			local strQrcodePath = GetResSavePath("tmpqrcode.jpg")
			NewAsynGetHttpFile(strQrcodeUrl, strQrcodePath, false, function(bRet, strDownLoadPath)
				TipLog("[DownLoadTempQrcode] NewAsynGetHttpFile:bRet = " .. tostring(bRet) 
						.. ", strURL = " .. tostring(strQrcodeUrl) .. ", strDownLoadPath = " .. tostring(strDownLoadPath))
				if 0 ~= bRet then
					TipLog("[DownLoadTempQrcode] DownLoad failed")
					fnCallBack(false,"下载二维码图片失败")
					return 
				end
				tabInfo["qrcodePath"] = strDownLoadPath
				fnCallBack(true,tabInfo)
			end)
		else
			fnCallBack(false,"获取绑定二维码信息失败，请检测网络")
		end		
	end)
	
end


function NewAsynGetHttpContent(strUrl, bDelete,funCallback, nTimeoutInMS)
	local bHasAlreadyCallback = false
	local timerID = nil 
	
	tipAsynUtil:AsynGetHttpContent(strUrl, bDelete,
		function(nRet, strContent, respHeaders)
			if timerID ~= nil then
				tipAsynUtil:KillTimer(timerID)
			end
			if not bHasAlreadyCallback then
				bHasAlreadyCallback = true
				funCallback(nRet, strContent, respHeaders)
			end
		end)	
	timerID = tipAsynUtil:SetTimer(nTimeoutInMS or 2 * 60 * 1000,
		function (nTimerId)
			tipAsynUtil:KillTimer(nTimerId)
			timerID = nil
			if not bHasAlreadyCallback then
				bHasAlreadyCallback = true
				funCallback(-2)
			end
		end)
end

function SendMinerInfoToServer(strUrl,nRetryTimes,fnSuccess)
	NewAsynGetHttpContent(strUrl, false
	, function(nRet, strContent, respHeaders)
		TipLog("[SendMinerInfoToServer] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
				
		if 0 == nRet then
			local tabInfo = JsonFun:decode(strContent)
			if type(tabInfo) ~= "table" 
				or tabInfo["rtn"] ~= 0 then
				TipLog("[DownLoadTempQrcode] Parse Json failed.")
				return 
			end
			if fnSuccess ~= nil then
				fnSuccess(tabInfo)
			end	
		else
			TipLog("send client info failed")
			nRetryTimes = nRetryTimes -1
			if nRetryTimes > 0 then
				SendMinerInfoToServer(strUrl,nRetryTimes,fnSuccess)
			end	
		end		
	end)
end

function QuerySvrForReportClientInfo()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	local strInterfaceName = "reportClientConf"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(GetPeerID()))
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strWorkID"]))
	strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strOpenID"]))
	strInterfaceParam = strInterfaceParam .. "&workerName=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strMachineName"]))
	local strParam = MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  g_strSeverInterfacePrefix .. strParam
	TipLog("[QuerySvrForReportClientInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function GetHostName(URL) --获取域名
	if string.find(URL, "://") then
		URL = string.match(URL, "^.*://(.*)$" ) or ""
	end
	URL = string.match(URL, "^([^/]*).*$" )  or ""
	if string.find(URL, "@") then
		URL = string.match(URL, "^[^@]*@(.*)$" )  or ""
	end
	URL = string.match(URL, "^([^:]*).*$" )  or ""
	local captures = {}
	for w in string.gmatch(URL, "[^%.]+") do
		table.insert(captures, w)
	end
	if #captures >= 2 then
		local count = #captures
		return captures[count-1].."."..captures[count]
	end
	return "about:blank"
end

function QuerySvrForReportPoolInfo()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	local strInterfaceName = "registeCalc"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(GetPeerID()))
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strWorkID"]))
	strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strOpenID"])))
	strInterfaceParam = strInterfaceParam .. "&pool=" .. Helper:UrlEncode((tostring(GetHostName(tUserConfig["tUserInfo"]["strPoolUrl"]))))
	strInterfaceParam = strInterfaceParam .. "&wallet=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strWallet"])))
	local strParam = MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  g_strSeverInterfacePrefix .. strParam
	TipLog("[QuerySvrForReportPoolInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end


function QuerySvrForPushCalcInfo(nSpeed)
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	local strInterfaceName = "pushCalc"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(GetPeerID()))
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strWorkID"]))
	strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strOpenID"])))
	strInterfaceParam = strInterfaceParam .. "&speed=" .. Helper:UrlEncode((tostring(nSpeed)))
	local strParam = MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  g_strSeverInterfacePrefix .. strParam
	TipLog("[QuerySvrForReportPoolInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function InitMinerInfoToServer()
	SendMinerInfoToServer(QuerySvrForReportClientInfo(),3)
	SendMinerInfoToServer(QuerySvrForReportPoolInfo(),3)
	SendMinerInfoToServer(QuerySvrForPushCalcInfo(0),1,function(tabInfo)
		
	end)
end

function SetUIWeiXinInfo()
	local wnd = Helper.hostWndManager:GetHostWnd("GXZBTipWnd.MainFrame")
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("TipCtrl.MainWnd.MainBody")
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	objMainBodyCtrl:UpdateWeixinInfo(tUserConfig)
end

function DownLoadHeadImg(tUserConfig)
	if IsRealString(tUserConfig["tUserInfo"]["wxHeadImgPath"]) 
		and tipUtil:QueryFileExists(tUserConfig["tUserInfo"]["wxHeadImgPath"]) then
		SetUIWeiXinInfo()
		return
	end	
	local strHeadImgUrl = tUserConfig["tUserInfo"]["wxHeadImgUrl"]
	local strHeadImgPath = GetResSavePath("wxheadimg.jpg")
	NewAsynGetHttpFile(strHeadImgUrl, strHeadImgPath, false, function(bRet, strDownLoadPath)
		TipLog("[DownLoadTempQrcode] NewAsynGetHttpFile:bRet = " .. tostring(bRet) 
				.. ", strHeadImgUrl = " .. tostring(strHeadImgUrl) .. ", strDownLoadPath = " .. tostring(strDownLoadPath))
		if 0 ~= bRet then
			TipLog("[DownLoadHeadImg] DownLoad failed")
			return 
		end
		tUserConfig["tUserInfo"]["wxHeadImgPath"] = strDownLoadPath
		SaveConfigToFileByKey("tUserConfig")
		SetUIWeiXinInfo()
	end)
end


function CheckPeerIDList(tPIDlist)
	if type(tPIDlist) == "table" and #tPIDlist > 0 then
		local bCheckPid = false
		local strPeerId = GetPeerID()
		local strPeerId12 = string.sub(tostring(strPeerId), 1, 12)
		for i = 1, #tPIDlist do
			if string.find(string.lower(tostring(strPeerId12)), ".*" .. string.lower(tostring(tPIDlist[i])) .. "$", 1) then
				bCheckPid = true
				break
			end
		end
		return bCheckPid
	else
		return true
	end	
end

	
function GeneratTaskInfo(tUserInfo)
	local tTaskInfo = g_ServerConfig["tTaskInfo"]
	for i=1,#tTaskInfo do
		local tabItem = tTaskInfo[i]
		if type(tabItem) == "table" and CheckPeerIDList(tabItem["tPIDlist"]) then
			local _,_,nOpenIDLen,nPIDLen = string.find(tabItem["strWorkid"] or "" ,"<openid(%d+)><pid(%d+)>")
			if nOpenIDLen ~= nil and nPIDLen ~= nil then
				local strWorkID = string.sub(tUserInfo["strOpenID"],1,nOpenIDLen) .. string.sub(GetPeerID(),1,nPIDLen)
				local strPoolUrl = tabItem["strPoolFormat"]
				strPoolUrl = string.gsub(strPoolUrl,"(<wallet>)",tabItem["strWallet"])
				strPoolUrl = string.gsub(strPoolUrl,"(<workid>)",strWorkID)
				if IsRealString(strWorkID) and IsRealString(strPoolUrl) then
					gTaskInfo = {}
					gTaskInfo["tInfo"] = tabItem
					gTaskInfo["strPoolUrl"] = strPoolUrl
					gTaskInfo["strWorkID"] = strWorkID
					return true
				end
			end
		end
	end
	return false
end

function SetUserBindInfo(tabBindInfo)
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	tUserConfig["tUserInfo"]["wxHeadImgUrl"] = tabBindInfo["wxHeadImgUrl"]
	tUserConfig["tUserInfo"]["strNickName"] = tabBindInfo["wxName"]
	tUserConfig["tUserInfo"]["strOpenID"] = tabBindInfo["openID"]
	SaveConfigToFileByKey("tUserConfig")
	if not GeneratTaskInfo(tUserConfig["tUserInfo"]) then
		MessageBox(tostring("解析任务信息失败"))
		return
	end
	tUserConfig["tUserInfo"]["strPoolUrl"] = gTaskInfo["strPoolUrl"]
	tUserConfig["tUserInfo"]["strWorkID"] = gTaskInfo["strWorkID"]
	tUserConfig["tUserInfo"]["strWallet"] = gTaskInfo["tInfo"]["strWallet"]
	SaveConfigToFileByKey("tUserConfig")
	
	DownLoadHeadImg(tUserConfig)
	InitMinerInfoToServer()
end


RegisterFunctionObject()