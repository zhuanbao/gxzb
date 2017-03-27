local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local IPCUtil = XLGetObject("IPC.Util")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")

local g_bShowWndByTray = false
local gStatCount = 0
local gCurrentWorkSpeed = 0

local gnLastReportRunTmUTC = tipUtil:GetCurrentUTCTime()
local gnLastReportMiningTmUTC = tipUtil:GetCurrentUTCTime()
local g_MiningReportTimerId = nil

local gTimeoutTimerId = nil

local gbLoadCfgSucc = false
local g_tipNotifyIcon = nil
local g_bIsUpdating = false
local JsonFun = nil

local g_strCmdLineFormat = nil
local g_strWallet = nil
local g_strPool = nil
local g_strSeverInterfacePrefix = "http://www.eastredm.com/pc"

-- 工作中用到的
local g_bWorking = false
local g_WorkingTimerId = nil
local g_PreWorkState = 0

--服务端信息
local g_SpeedSum = 0 --累加速度，一分钟上报一次时，取这一分钟的平均速度
local g_SpeedSumCounter = 0 --累加的计数器
local g_PerSpeed = 10 --服务端返回的平均速度((元宝/Hour)/M)
local g_MiningSpeedPerHour = 0 --根据矿工当前速度计算的挖矿平均速度(元宝/Hour)
local g_Balance = 0

------限速
--函数15秒调一次
local g_CurrentPerBatch = 0 --当前限速值
local g_GlobalWorkSizeMultiplier_Min = 100
local g_GlobalWorkSizeMultiplier_Max = 4096
local g_GlobalWorkSizeMultiplier_Cur = g_GlobalWorkSizeMultiplier_Max
local g_msExpectPerBatch = 200 --显卡计算每次循环的期望时间间隔(毫秒)
------限速

--local g_WorkWndClass = "WorkWnd_{EFBE3E9F-DEC0-4A65-B87C-BAD1145762FD}"
local g_tPopupWndList = {
	[1] = {"GXZB.RemindTipWnd", "GXZB.RemindTipWndTree"},
	[2] = {"GXZB.SuspendWnd", "GXZB.SuspendWndTree"},
	[3] = {"GXZB.MachineCheckWnd", "GXZB.MachineCheckWndTree"},
	[4] = {"GXZB.ProfitShareWnd", "GXZB.ProfitShareWndTree"},
	[5] = {"GXZB.UpdateFrameWnd", "GXZB.UpdateWndTree"},
}

local g_tConfigFileStruct = {
	["tUserConfig"] = {
		["strFileName"] = "UserConfig.dat",
		["tContent"] = {}, 
		["fnMergeOldFile"] = function(infoTable, strFileName) return MergeOldUserCfg(infoTable, strFileName) end,
	},
	["tEarnings"] = {
		["strFileName"] = "Earnings.dat",
		["tContent"] = {}, 
	},
}

---[[ forlocal
function LoadLocalSvrHelper()
	local strLocalSvrHelper = __document.."\\..\\localcfghelper.lua"
	local Module = XLLoadModule(strLocalSvrHelper)
end
LoadLocalSvrHelper()
--]]
function LoadJSONHelper()
	local strJSONHelperPath = __document.."\\..\\JSON.lua"
	local Module = XLLoadModule(strJSONHelperPath)
	JsonFun = XLGetGlobal("Clent.Json")
end
LoadJSONHelper()


local tryCatch=function(fnFail)  
    local ret,errMessage=pcall(fun); 
	if not ret then
		TipLog("ret:" .. (ret and "true" or "false" )  .. " \nerrMessage:" .. (errMessage or "null")); 
		if type(funFail) == "function" then
			funFail()
		end
	end	
end 

function DeCodeJson(strInfo,fnFail)
	local tabInfo = nil	
	local ret,errMessage=pcall(function()
								tabInfo = JsonFun:decode(strInfo)
							   end) 
	if not ret then
		TipLog("ret:" .. (ret and "true" or "false" )  .. " \nerrMessage:" .. (errMessage or "null")); 
		if type(funFail) == "function" then
			funFail()
		end
	end
	return tabInfo
end

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
	local strDefaultNil = "zb_null"
	
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

	local strUrl = "http://www.google-analytics.com/collect?v=1&tid=UA-96195625-1&cid="..tostring(strCID)
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
		gTimeoutTimerId = timeMgr:SetTimer(function(Itm, id)
			Itm:KillTimer(id)
			ExitTipWnd()
		end, 15000 * iStatCount)
	end
end

function GetModuleDir()
	local strExePath = tipUtil:GetModuleExeName()
	local _,_,strDir = string.find(tostring(strExePath), "(.+)\\[^\\]+$")
	return strDir
end

function GetCommandStrValue(strKey)
	local bRet, strValue = false, nil
	local cmdString = tipUtil:GetCommandLine()
	
	if string.find(cmdString, strKey .. " ") then
		local cmdList = tipUtil:CommandLineToList(cmdString)
		if cmdList ~= nil then	
			for i = 1, #cmdList, 1 do
				local strTmp = tostring(cmdList[i])
				if strTmp == strKey 
					and not string.find(tostring(cmdList[i + 1]), "^/") then		
					bRet = true
					strValue = tostring(cmdList[i + 1])
					break
				end
			end
		end
	end
	return bRet, strValue
end

function RegisterFunctionObject(self)
	local obj = {}
	obj.TipLog = TipLog
	obj.FailExitTipWnd = FailExitTipWnd
	obj.GetCommandStrValue = GetCommandStrValue
	obj.TipConvStatistic = TipConvStatistic
	obj.ReportAndExit = ReportAndExit
	obj.ShowPopupWndByName = ShowPopupWndByName
	obj.GetCfgPathWithName = GetCfgPathWithName
	obj.LoadTableFromFile = LoadTableFromFile
	obj.ShowExitRemindWnd = ShowExitRemindWnd
	obj.RegQueryValue = RegQueryValue
	obj.RegSetValue = RegSetValue
	obj.RegDeleteValue = RegDeleteValue
	obj.GetPeerID = GetPeerID
	obj.GetSystemBits = GetSystemBits
	obj.FormatByteUnit = FormatByteUnit
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
	obj.QueryClientInfo = QueryClientInfo
	obj.TakeCashToServer = TakeCashToServer
	obj.GetHistoryToServer = GetHistoryToServer
	obj.GetInstallSrc = GetInstallSrc
	obj.GetExePath = GetExePath
	obj.SaveAllConfig = SaveAllConfig
	obj.GetCurrentServerTime = GetCurrentServerTime
	obj.CheckIsAnotherDay = CheckIsAnotherDay
	obj.CheckPeerIDList = CheckPeerIDList
	obj.InitMachName = InitMachName
	obj.ShowIntroduceOnce = ShowIntroduceOnce
	obj.PopTipPre4Hour = PopTipPre4Hour
	obj.PopRemindUpdateWnd = PopRemindUpdateWnd
	obj.UpdateSuspendWndVisible = UpdateSuspendWndVisible
	obj.DestroyPopupWnd = DestroyPopupWnd
	obj.SetMachineNameChangeInfo = SetMachineNameChangeInfo
	obj.UpdateMiningSpeed = UpdateMiningSpeed
	obj.GetUserWorkID = GetUserWorkID
	obj.GetMainHostWnd = GetMainHostWnd
	obj.ChangeMainBodyPanel = ChangeMainBodyPanel
	obj.ChangeClientTitle = ChangeClientTitle
	obj.CheckIsBinded = CheckIsBinded
	obj.CheckIsGettedWorkID = CheckIsGettedWorkID
	obj.UpdateUserBalance = UpdateUserBalance
	obj.NotifyPause = NotifyPause
	obj.NotifyQuit = NotifyQuit
	obj.NotifyStart = NotifyStart
	obj.CheckIsWorking = CheckIsWorking
	obj.GeneratTaskInfo = GeneratTaskInfo
	obj.UnBindingClientFromClient = UnBindingClientFromClient
	obj.UnBindingClientFromServer = UnBindingClientFromServer
	obj.DownLoadNewVersion = DownLoadNewVersion
	obj.GetUserCurrentBalance = GetUserCurrentBalance
	obj.SetUserCurrentBalance = SetUserCurrentBalance
	obj.GetClientCurrentState = GetClientCurrentState
	obj.CheckShouldRemindBind = CheckShouldRemindBind
	obj.SaveLastRemindBindUTC = SaveLastRemindBindUTC
	obj.CheckShoudAutoMining = CheckShoudAutoMining
	XLSetGlobal("Global.FunctionHelper", obj)
end

function ChangeMainBodyPanel(strPanelName)
	local wnd = GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	objMainBodyCtrl:ChangePanel(strPanelName)
end

function ChangeClientTitle(strTitle)
	local wnd = GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objTitleCtrl = objRootCtrl:GetControlObject("WndPanel.Title")
	objTitleCtrl:ChangeTitle(strTitle)
end

function CheckShouldRemindBind()
	if CheckIsBinded() then
		return false
	end
	local strCmdline = tipUtil:GetCommandLine()
	if string.find(string.lower(tostring(strCmdline)), "/mining") then
		return false
	end
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	if tUserConfig["nLastRemindBindUTC"] ~= nil then
		return false
	end
	return true
end

function SaveLastRemindBindUTC()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["nLastRemindBindUTC"] = GetCurrentServerTime()
	SaveConfigToFileByKey("tUserConfig")
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


function DownLoadNewVersion(tNewVersionInfo, fnCallBack)
	local strPacketURL = tNewVersionInfo.strPacketURL
	local strMD5 = tNewVersionInfo.strMD5
	if not IsRealString(strPacketURL) then
		return
	end
	
	local strFileName = GetFileSaveNameFromUrl(strPacketURL)
	if not string.find(strFileName, "%.exe$") then
		strFileName = strFileName..".exe"
	end
	local strSaveDir = tipUtil:GetSystemTempPath()
	local strSavePath = tipUtil:PathCombine(strSaveDir, strFileName)
	
	local strStamp = GetTimeStamp()
	local strURLFix = strPacketURL..strStamp
	
	DownLoadFileWithCheck(strURLFix, strSavePath, strMD5
	, function(bRet, strRealPath)
		TipLog("[DownLoadNewVersion] strOpenLink:"..tostring(strPacketURL)
		        .."  bRet:"..tostring(bRet).."  strRealPath:"..tostring(strRealPath))
				
		if 0 == bRet then
			fnCallBack(strRealPath, tNewVersionInfo)
			return
		end
		
		if 1 == bRet then	--安装包已经存在
			fnCallBack(strSavePath, tNewVersionInfo)
			return
		end
	end)	
end


function GetTimeStamp()
	local strPeerId = GetPeerID()
	local iFlag = tonumber(string.sub(strPeerId, 12, 12), 16) or 0
	local iTime = tipUtil:GetCurrentUTCTime()
	local ss = math.floor((iTime + 8 * 3600  - (iFlag + 1) * 3600)/(24*3600))
	local strStamp = "?stamp=" .. tostring(ss)
	return strStamp 
end

function GetSystemBits()
	local iBits = 0
	if type(tipUtil.GetAllSystemInfo) == "function" then
		local tabSystemInfo =  tipUtil:GetAllSystemInfo()
		if type(tabSystemInfo) == "table" then
			iBits = tabSystemInfo["BitNumbers"]
			if type(iBits) ~= "number" then
				iBits = 0
			end
		end
	end
	return iBits
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


function FormatHashRate(nSpeed)
	local nSize = 0
	local strUnit = ""
	if nSpeed >= 1000*1000*1000 then  
		nSize = nSpeed/(1000*1000*1000)
		strUnit = "GH"
		if nSize > 99.999999 then
			nSize = nSize/1000
			strUnit = "TH"
		end
	elseif nSpeed >= 1000*1000 then  
		nSize = nSpeed/(1000*1000)
		strUnit = "MH"
		if nSize > 99.999999 then
			nSize = nSize/1000
			strUnit = "GH"
		end
	elseif nSpeed >= 1000 then   
		nSize = nSpeed/1000
		strUnit = "KH"
		if nSize > 99.999999 then
			nSize = nSize/1000
			strUnit = "MH"
		end
	else
		nSize = nSpeed
		strUnit = "H"
		if nSize > 99.999999 then
			nSize = nSize/1000
			strUnit = "KH"
		end
	end
	
	local strHashRate = string.format("%.2f", nSize)
	strHashRate = strHashRate..strUnit
	
	return strHashRate
end

function FormatByteUnit(nFileSizeInByte, nPrecision)
	if nPrecision == nil then
		nPrecision = 0
	end
	local strPrecision = "%." .. tostring(nPrecision) .. "f"
	local strFileSize = ""
	if tonumber(nFileSizeInByte) == nil then
		return strFileSize
	end

	local nSize = 0
	local strUnit = ""
	if  nFileSizeInByte >= 1024*1024*1024*1024 then
		nSize = nFileSizeInByte/(1024*1024*1024*1024)
		strUnit = "TB"
		
	elseif nFileSizeInByte >= 1024*1024*1024 then  
		nSize = nFileSizeInByte/(1024*1024*1024)
		strUnit = "GB"
		
	elseif nFileSizeInByte >= 1024*1024 then  
		nSize = nFileSizeInByte/(1024*1024)
		strUnit = "MB"
		
	elseif nFileSizeInByte >= 1024 then   
		nSize = nFileSizeInByte/1024
		strUnit = "KB"
		
	else
		nSize = nFileSizeInByte
		strUnit = "B"
	end
	
	strFileSize = string.format(strPrecision, nSize)
	strFileSize = strFileSize..strUnit
	
	return strFileSize
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

function GetMachineID()
	local strGUID = RegQueryValue("HKEY_LOCAL_MACHINE\\Software\\gxzb\\machineid")
	if IsRealString(strGUID) then
		return string.upper(strGUID)
	end
end

--渠道
function GetInstallSrc()
	local strInstallSrc = RegQueryValue("HKEY_LOCAL_MACHINE\\Software\\gxzb\\InstallSource")
	if not IsNilString(strInstallSrc) then
		return tostring(strInstallSrc)
	end
	
	return ""
end

function GetExePath()
	local strExePath = RegQueryValue("HKEY_LOCAL_MACHINE\\Software\\gxzb\\Path")
	if IsRealString(strExePath) then
		return tostring(strExePath)
	else
		return tipUtil:GetModuleExeName()
	end
end

function NewAsynGetHttpFile(strUrl, strSavePath, bDelete, funCallback, nTimeoutInMS)
	local bHasAlreadyCallback = false
	local timerID = nil
	if false then
	--if string.find(strUrl, "^https://") == nil then
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

function SplitStringBySeperator(strToSplit, strSeperator)
	local tResult = {}
	
	if type(strToSplit) == "string" and type(strSeperator) == "string" then
		local nSepStartPos = 0
		local nSepEndPos = 0
		local nLastSepStartPos = 0
		local nLastSepEndPos = 0
		while true do
			nLastSepStartPos = nSepStartPos
			nLastSepEndPos = nSepEndPos
			nSepStartPos, nSepEndPos = string.find(strToSplit, strSeperator, nLastSepEndPos + 1)
			if type(nSepStartPos) ~= "number" or type(nSepEndPos) ~= "number" then
				tResult[#tResult + 1] = string.sub(strToSplit, nLastSepEndPos + 1, -1)
				break
			end
			tResult[#tResult + 1] = string.sub(strToSplit, nLastSepEndPos + 1, nSepStartPos - 1)
		end
	end

	return tResult
end

function ExtractHttpHeaders(strHttpHeaders)
	local tResult = {}
	
	local tHeaderSet = SplitStringBySeperator(strHttpHeaders, "\r\n")
	for i = 1, #tHeaderSet do
		local tHeader = SplitStringBySeperator(tHeaderSet[i], ": ")
		if #tHeader == 2 
			and type(tHeader[1]) == "string" and tHeader[1] ~= "" 
			and type(tHeader[2]) == "string" and tHeader[2] ~= "" 
			then
			tResult[tHeader[1]] = tHeader[2]
		end
	end
	
	return tResult
end

function UpdateTimeCalibration(nLocalUTCInSec, nSvrUTCInSec)
	local nDefaultUTCInSec = tipUtil:GetCurrentUTCTime() or 0
	local nNewLocalUTCInSec = nDefaultUTCInSec
	local nNewSvrUTCInSec = nDefaultUTCInSec
	if type(nLocalUTCInSec) == "number" and type(nSvrUTCInSec) == "number" then
		nNewLocalUTCInSec = nLocalUTCInSec
		nNewSvrUTCInSec = nSvrUTCInSec
	end
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["tStandardTime"] = {}
	tUserConfig["tStandardTime"]["nLocalTime"] = nNewLocalUTCInSec
	tUserConfig["tStandardTime"]["nServerTime"] = nNewSvrUTCInSec
	SaveConfigToFileByKey("tUserConfig")
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
	local nBeginLocalUTCInSec = tipUtil:GetCurrentUTCTime() or 0	
	NewAsynGetHttpFile(strURLFix, strSavePath, false
	, function(bRet, strRealPath, strHttpHeaders)
		TipLog("[DownLoadServerConfig] bRet:"..tostring(bRet)
				..", strRealPath:"..tostring(strRealPath)
				.. ", strHttpHeaders = " .. tostring(strHttpHeaders))
		local nEndLocalUTCInSec = tipUtil:GetCurrentUTCTime() or 0
		local nAvgLocalUTCInSec = math.floor((nBeginLocalUTCInSec + nEndLocalUTCInSec) / 2)
		local tHttpHeaders = ExtractHttpHeaders(strHttpHeaders)	
		if type(tHttpHeaders["Date"]) == "string" then
			local nSvrUTCInSec = tipUtil:InternetTimeToUTCTime(tHttpHeaders["Date"])
			if nAvgLocalUTCInSec ~= 0 
				and type(nSvrUTCInSec) == "number" and nSvrUTCInSec ~= 0 
				then
				UpdateTimeCalibration(nAvgLocalUTCInSec, nSvrUTCInSec)
			end
		end
		if 0 == bRet then
			---[[ forlocal
			strSavePath = GetLocalSvrCfgWithName("ServerConfig.dat", true)
			--]]
			fnCallBack(0, strSavePath)
		else
			fnCallBack(bRet)
		end		
	end, nTime)
end

function GetTimeCalibration()
	local nDefaultUTCInSec = tipUtil:GetCurrentUTCTime() or 0
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	local tTime = tUserConfig["tStandardTime"] or {}
	local nLocalTimeUTCInSec = tTime["nLocalTime"] or nDefaultUTCInSec
	local nSvrTimeUTCInSec = tTime["nServerTime"] or nDefaultUTCInSec
	if tTime["ignore"] == 1 then
		nLocalTimeUTCInSec = 0
		nSvrTimeUTCInSec = 0
	end
	
	return nLocalTimeUTCInSec, nSvrTimeUTCInSec
end

function GetCurrentServerTime()
	local nCurLocalUTCInSec = tipUtil:GetCurrentUTCTime() or 0
	local nLocalUTCInSec, nSvrUTCInSec = GetTimeCalibration()
	local nCurSvrUTCInSec = nCurLocalUTCInSec + (nSvrUTCInSec - nLocalUTCInSec)
	return nCurSvrUTCInSec
end

function CheckIsAnotherDay(nLastTime, nCurrentTime)
	local bRet = false
	local nLYear, nLMonth, nLDay, nLHour, nLMinute, nLSecond = tipUtil:FormatCrtTime(nLastTime)
	local nCYear, nCMonth, nCDay, nCHour, nCMinute, nCSecond = tipUtil:FormatCrtTime(nCurrentTime)
	if nLYear ~= nCYear or nLMonth ~= nCMonth or nLDay ~= nCDay then
		bRet = true
	end
	return bRet
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
			--读失败了不用返回
			--return false
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
	NotifyQuit()
	TipLog("************ Exit ************")
	tipUtil:Exit("Exit")
end

function GetMainHostWnd()
	return Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
end

function DestroyMainWnd()
	local objHostWnd = GetMainHostWnd()
	if objHostWnd then
		Helper.hostWndManager:RemoveHostWnd("GXZB.MainWnd")
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
						--强制隐藏
						frameHostWnd:Show(0)
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

--scene:0或nil 启动时 1赚宝时
function UpdateSuspendWndVisible(scene)
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["tConfig"] = tUserConfig["tConfig"] or {}
	tUserConfig["tConfig"]["ShowBall"] = tUserConfig["tConfig"]["ShowBall"] or {}
	local nState = tUserConfig["tConfig"]["ShowBall"]["nState"]
	local hostwndManager = XLGetObject("Xunlei.UIEngine.HostWndManager")
	if nState == nil or nState == 0 then
		ShowPopupWndByName("GXZB.SuspendWnd.Instance", true)
	elseif nState == 1 then
		local SuspendWnd = hostwndManager:GetHostWnd("GXZB.SuspendWnd.Instance")
		if SuspendWnd then
			SuspendWnd:Show(0)
		end
	elseif scene == 1 and nState == 2 then
		if not CheckIsWorking() then
			local SuspendWnd = hostwndManager:GetHostWnd("GXZB.SuspendWnd.Instance")
			if SuspendWnd then
				SuspendWnd:Show(0)
			end
		else
			ShowPopupWndByName("GXZB.SuspendWnd.Instance",  true)
		end
	end
end

function ShowIntroduceOnce()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	local nLastShowIntroduce = FetchValueByPath(tUserConfig, {"nLastShowIntroduce"})
	local strRegPath = "HKEY_CURRENT_USER\\SOFTWARE\\gxzb\\ShowIntroduce"
	
	if not IsNilString(nLastShowIntroduce) then
		RegDeleteValue(strRegPath)
		return
	end
	
	local strValue = RegQueryValue(strRegPath)
	if IsRealString(strValue) then
		ShowPopupWndByName("TipIntroduceWnd.Instance", true)
		tUserConfig["nLastShowIntroduce"] = tipUtil:GetCurrentUTCTime()
		SaveConfigToFileByKey("tUserConfig")
	end
	
	RegDeleteValue(strRegPath)
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
		objHostWnd:BringWindowToTop(true)
		--[[
		objHostWnd:Show(5)
		SetWndForeGround(objHostWnd)
		local strState = objHostWnd:GetWindowState()
		if tostring(strState) == "min" then
			objHostWnd:BringWindowToTop(true)
		end]]--
		
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
	
	local strState, bShowSpeed = GetToolTipInfo()
	
	local strShowText = "共享赚宝  状态："..strState
	
	local nBalance = GetUserCurrentBalance()
	strShowText = strShowText .. "\r\n金库余额：" .. tostring(nBalance) .. "元宝"
	if bShowSpeed then
		strShowText = strShowText .. "\r\n当前赚宝速度：" .. tostring(g_MiningSpeedPerHour) .. "元宝/小时"
	end

	g_tipNotifyIcon:SetIcon(nil, strShowText)
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
	--记住主窗体位置
	local wnd = GetMainHostWnd()
	if wnd then
		local l, t, r, b = wnd:GetWindowRect()
		local w, h = r-l, b - t
		local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
		tUserConfig["tWindow"] = tUserConfig["tWindow"] or {}
		tUserConfig["tWindow"]["tMain"] = tUserConfig["tWindow"]["tMain"] or {}
		tUserConfig["tWindow"]["tMain"].nLeft = l
		tUserConfig["tWindow"]["tMain"].nTop = t
		tUserConfig["tWindow"]["tMain"].nWidth  = w
		tUserConfig["tWindow"]["tMain"].nHeight = h
		SaveConfigToFileByKey("tUserConfig")
	end
	DestroyMainWnd()
	DestroyPopupWnd()
	HideTray()
	
	local tStatInfo = {}
		
	SendRunTimeReport(0, true)
	SendMiningReport(0, true)
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

function StartMiningCountTimer()
	local nTimeSpanInSec = 10 * 60 
	local nTimeSpanInMs = nTimeSpanInSec * 1000
	if g_MiningReportTimerId ~= nil then
		timeMgr:KillTimer(g_MiningReportTimerId)
		g_MiningReportTimerId = nil
	end
	g_MiningReportTimerId = timeMgr:SetTimer(function(item, id)
		gnLastReportMiningTmUTC = tipUtil:GetCurrentUTCTime()
		SendMiningReport(nTimeSpanInSec, false)
	end, nTimeSpanInMs)
end

function StopMiningCountTimer()
	if g_MiningReportTimerId ~= nil then
		timeMgr:KillTimer(g_MiningReportTimerId)
		g_MiningReportTimerId = nil
	end
end

function SendMiningReport(nTimeSpanInSec, bExit)
	local tStatInfo = {}
	tStatInfo.strEC = "mining"
	tStatInfo.strEA = GetInstallSrc() or ""
	
	local nMiningTime = 0
	if bExit and gnLastReportMiningTmUTC ~= 0 then
		nMiningTime = math.abs(tipUtil:GetCurrentUTCTime() - gnLastReportMiningTmUTC)
	else
		nMiningTime = nTimeSpanInSec
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



function QuerySvrForWorkID()
	local strInterfaceName = "getWorkerID"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(GetPeerID()))
	local strGUID = GetMachineID()
	if IsRealString(strGUID) then
		strInterfaceParam = strInterfaceParam .. "&param1=" .. Helper:UrlEncode(strGUID)
	end	
	local strParam = MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  g_strSeverInterfacePrefix .. strParam
	TipLog("[QuerySvrForWorkID] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function GetUserWorkID(fnCallBack)
	local strUrl = QuerySvrForWorkID()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	local strWorkID = tUserConfig["tUserInfo"]["strWorkID"]
	if not IsRealString(strWorkID) then
		NewAsynGetHttpContent(strUrl, false
		, function(nRet, strContent, respHeaders)
			TipLog("[GetUserWorkID] nRet:"..tostring(nRet)
					.." strContent:"..tostring(strContent))
					
			if 0 == nRet then
				local tabInfo = DeCodeJson(strContent)
				if type(tabInfo) ~= "table" 
					or tabInfo["rtn"] ~= 0
					or type(tabInfo["data"]) ~= "table" then
					TipLog("[GetUserWorkID] Parse Json failed.")
					fnCallBack(false,"解析信息失败")
					return 
				end
				local strWorkID = tabInfo["data"]["workerID"]
				tUserConfig["tUserInfo"]["strWorkID"] = strWorkID
				SaveConfigToFileByKey("tUserConfig")
				fnCallBack(true,strWorkID)
			else
				fnCallBack(false,"连接服务器失败，请检测网络")
			end		
		end)
	else
		fnCallBack(true,strWorkID)
	end
end

function QuerySvrForLoginInfo()
	--这里保证workID不位空
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	local strWorkID = tUserConfig["tUserInfo"]["strWorkID"]
	local strInterfaceName = "bind"
	local strInterfaceParam = "workerID=" .. Helper:UrlEncode(tostring(strWorkID))
	local strParam = MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  g_strSeverInterfacePrefix .. strParam
	TipLog("[QuerySvrForLoginInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function CycleQuerySeverForBindResult(fnCallBack, nTimeoutInMS)
	local strBindResult = QuerySvrForLoginInfo()
	strBindResult = strBindResult.."&rd="..tostring(tipUtil:GetCurrentUTCTime())
	NewAsynGetHttpContent(strBindResult, false
	, function(nRet, strContent, respHeaders)
		TipLog("[CycleQuerySeverForBindResult] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
				
		if 0 == nRet then
			local tabInfo = DeCodeJson(strContent)
			if type(tabInfo) ~= "table" 
				or tabInfo["rtn"] ~= 0 then
				TipLog("[CycleQuerySeverForBindResult] Parse Json failed.")
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

function QuerySvrForQrcodeInfo(strWorkID)
	local strInterfaceName = "getQrcode"
	local strInterfaceParam = "workerID="..Helper:UrlEncode(tostring(strWorkID)) .. "&peerid=" .. Helper:UrlEncode(tostring(GetPeerID()))
	local strGUID = GetMachineID()
	if IsRealString(strGUID) then
		strInterfaceParam = strInterfaceParam .. "&param1=" .. Helper:UrlEncode(strGUID)
	end	
	local strParam = MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  g_strSeverInterfacePrefix .. strParam
	TipLog("[QuerySvrForQrcodeInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function DownLoadTempQrcode(fnCallBack)
	GetUserWorkID(function(bWorkID,strWorkID)
		if bWorkID then
			local strQrcodeUrl = QuerySvrForQrcodeInfo(strWorkID)
			strQrcodeUrl = strQrcodeUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
			TipLog("[DownLoadTempQrcode] strQrcodeUrl = " .. strQrcodeUrl)
			NewAsynGetHttpContent(strQrcodeUrl, false
			, function(nRet, strContent, respHeaders)
				TipLog("[DownLoadTempQrcode] nRet:"..tostring(nRet)
						.." strContent:"..tostring(strContent))
						
				if 0 == nRet then
					local tabInfo = DeCodeJson(strContent)
					if type(tabInfo) ~= "table" 
						or tabInfo["rtn"] ~= 0 
						or type(tabInfo["data"]) ~= "table" 
						or not IsRealString(tabInfo["data"]["qrcodeUrl"])
						or tonumber(tabInfo["data"]["sceneID"]) == nil then
						TipLog("[DownLoadTempQrcode] Parse Json failed.")
						fnCallBack(false,"解析二维码信息失败")
						return 
					end
					local strQrcodeUrl = tabInfo["data"]["qrcodeUrl"]
					local expire = tonumber(tabInfo["data"]["expire"])
					if type(expire) ~= "number" then
						expire = 60*1000
					end
					TipLog("[DownLoadTempQrcode] strQrcodeUrl = "..tostring(strQrcodeUrl)..", expire = "..tostring(expire))
					local strQrcodePath = GetResSavePath("tmpqrcode.jpg")
					NewAsynGetHttpFile(strQrcodeUrl, strQrcodePath, false, function(bRet, strDownLoadPath)
						TipLog("[DownLoadTempQrcode] NewAsynGetHttpFile:bRet = " .. tostring(bRet) 
								.. ", strURL = " .. tostring(strQrcodeUrl) .. ", strDownLoadPath = " .. tostring(strDownLoadPath))
						if 0 ~= bRet then
							TipLog("[DownLoadTempQrcode] DownLoad failed")
							fnCallBack(false,"下载二维码图片失败")
							return 
						end
						tabInfo["data"]["qrcodePath"] = strDownLoadPath
						--tabInfo["data"]["workerID"] = strWorkID
						fnCallBack(true,tabInfo)
					end, expire)
				else
					fnCallBack(false,"获取绑定二维码信息失败，请检测网络")
				end		
			end)
		else
			fnCallBack(false, strWorkID)
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
				local tabInfo = DeCodeJson(strContent)
				
				if type(tabInfo) ~= "table" 
					or tabInfo["rtn"] ~= 0 then
					TipLog("[SendMinerInfoToServer] Parse Json failed.")
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
	if IsRealString(tUserConfig["tUserInfo"]["strOpenID"]) then
		strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strOpenID"]))
	end	
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
	if IsRealString(tUserConfig["tUserInfo"]["strOpenID"]) then
		strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strOpenID"])))
	end
	strInterfaceParam = strInterfaceParam .. "&pool=" .. Helper:UrlEncode((tostring(g_strPool)))
	strInterfaceParam = strInterfaceParam .. "&wallet=" .. Helper:UrlEncode((tostring(g_strWallet)))
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
	if IsRealString(tUserConfig["tUserInfo"]["strOpenID"]) then
		strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strOpenID"])))
	end
	strInterfaceParam = strInterfaceParam .. "&speed=" .. Helper:UrlEncode((tostring(nSpeed)))
	local strParam = MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  g_strSeverInterfacePrefix .. strParam
	TipLog("[QuerySvrForPushCalcInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function QuerySvrForTakeCashInfo(nMoney)
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	local strInterfaceName = "pushCalc"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(GetPeerID()))
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strWorkID"]))
	if IsRealString(tUserConfig["tUserInfo"]["strOpenID"]) then
		strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strOpenID"])))
	end
	strInterfaceParam = strInterfaceParam .. "&speed=" .. Helper:UrlEncode((tostring(nMoney)))
	local strParam = MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  g_strSeverInterfacePrefix .. strParam
	TipLog("[QuerySvrForTakeCashInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

--提现接口
function TakeCashToServer(nMoney, fnCallBack)
	local strReguestUrl = QuerySvrForTakeCashInfo(nMoney)
	strReguestUrl = strReguestUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[TakeCashToServer] strReguestUrl = " .. strReguestUrl)
	NewAsynGetHttpContent(strReguestUrl, false
	, function(nRet, strContent, respHeaders)
		TipLog("[TakeCashToServer] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
				
		if 0 == nRet then
			---[[ forlocal
			strContent = GetLocalSvrCfgWithName("takeCash.json")
			--]]
			local tabInfo = DeCodeJson(strContent)
			if type(tabInfo) ~= "table" then
				TipLog("[TakeCashToServer] parse info error.")
				fnCallBack(false)
				return
			end
			fnCallBack(true, tabInfo)
		else
			TipLog("[TakeCashToServer] get content failed.")
			fnCallBack(false)
		end	
	end)
end

function QuerySvrForGetHistoryInfo(ntype)
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	if not tUserConfig["tUserInfo"]["strWorkID"] then
		TipLog("[QuerySvrForGetHistoryInfo] strWorkID = nil")
		return
	end
	local strInterfaceName = "getHistory"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(GetPeerID()))
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strWorkID"]))
	if IsRealString(tUserConfig["tUserInfo"]["strOpenID"]) then
		strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strOpenID"])))
	end
	strInterfaceParam = strInterfaceParam .. "&type=" .. Helper:UrlEncode((tostring(ntype)))
	local strParam = MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  g_strSeverInterfacePrefix .. strParam
	TipLog("[QuerySvrForGetHistoryInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

--查询收益接口,ntype = 0 最近24小时，1 最近1个月
--不同整点才会去请求，否则使用本地
--请求失败显示上次， 颜色用灰色
function GetHistoryToServer(ntype, fnCallBack)
	local function CheckLastUTC(utc)
		if type(utc) ~= "number" then
			return true
		end
		local nCurrentUtc = tipUtil:GetCurrentUTCTime() or 0
		local nLYear, nLMonth, nLDay, nLHour = tipUtil:FormatCrtTime(utc)
		local nCYear, nCMonth, nCDay, nCHour = tipUtil:FormatCrtTime(utc)
		if nLYear ~= nCYear or nLMonth ~= nCMonth or nLDay ~= nCDay or nLHour ~= nCHour then
			return true
		end
		return false
	end
	local function UINeedTable(t)
		local tmp = {}
		local nCurrent = tipUtil:GetCurrentUTCTime() or 0
		if ntype == 0 then
			nCurrent = nCurrent - 3600
		else
			nCurrent = nCurrent - 86400
		end
		for i, v in ipairs(t) do
			local _, LMonth, LDay, LHour = tipUtil:FormatCrtTime(nCurrent)
			tmp[#t-i+1] = {}
			if ntype == 0 then
				tmp[#t-i+1][1] = string.format("%02d", LHour)..":00"
				nCurrent = nCurrent - 3600
			else
				tmp[#t-i+1][1] = string.format("%02d", LMonth).."/".. string.format("%02d", LDay)
				nCurrent = nCurrent - 86400
			end
			tmp[#t-i+1][2] = v
		end
		return tmp
	end
	local function GetLocal(tLocal)
		local t = {}
		local count = 0
		tLocal = tLocal or {}
		if ntype == 0 then
			if type(tLocal["hour24"]) == "table" and #tLocal["hour24"] == 24 then
				return tLocal["hour24"]
			end
			count = 24
		else
			if type(tLocal["day30"]) == "table" and #tLocal["day30"] == 30 then
				return tLocal["day30"]
			end
			count = 30
		end
		for i = 1, count do
			t[i] = 0
		end
		return UINeedTable(t)
	end
	local function Save2Local(tServer)
		local tEarnings = ReadConfigFromMemByKey("tEarnings") or {}
		tEarnings["lastutc"] = tipUtil:GetCurrentUTCTime() or 0
		--TODO:现在不确定服务器返回什么格式， 等确定了再改这里
		tEarnings["hour24"] = UINeedTable(tServer["hour24"])
		tEarnings["day30"] = UINeedTable(tServer["day30"])
		SaveConfigToFileByKey("tEarnings")
	end
	local tEarnings = ReadConfigFromMemByKey("tEarnings") or {}
	if not CheckLastUTC(tEarnings["lastutc"]) then
		fnCallBack(true, GetLocal(tEarnings))
		return
	end
	local strReguestUrl = QuerySvrForGetHistoryInfo(ntype)
	if not strReguestUrl then
		local tDefault = GetLocal()
		fnCallBack(false, tDefault)
		return
		--[[forlocal
		strContent = GetLocalSvrCfgWithName("getHistory.json")
		local tabInfo = DeCodeJson(strContent)
		fnCallBack(true, UINeedTable(tabInfo["data"][ntype ==0 and "hour24" or "day30"]))
		Save2Local(tabInfo["data"])
		return
		--]]
	end
	strReguestUrl = strReguestUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[GetHistoryToServer] strReguestUrl = " .. strReguestUrl)
	NewAsynGetHttpContent(strReguestUrl, false
	, function(nRet, strContent, respHeaders)
		TipLog("[GetHistoryToServer] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
		---[[forlocal
		strContent = GetLocalSvrCfgWithName("getHistory.json")
		local tabInfo = DeCodeJson(strContent)
		if type(tabInfo) == "table" and type(tabInfo["data"]) == "table" and type(tabInfo["data"]["hour24"]) == "table" and type(tabInfo["data"]["day30"]) == "table" then
			fnCallBack(true, UINeedTable(tabInfo["data"][ntype ==0 and "hour24" or "day30"]))
			Save2Local(tabInfo["data"])
		else
			fnCallBack(false, GetLocal())
		end
		if true then return end
		---]]
		if 0 == nRet then
			local tabInfo = DeCodeJson(strContent)	
			if type(tabInfo) ~= "table" or type(tabInfo["data"]) ~= "table" then
				TipLog("[GetHistoryToServer] parse info error.")
				fnCallBack(false, GetLocal(tEarnings))
				return
			end
			fnCallBack(true, UINeedTable(tabInfo["data"][ntype ==0 and "hour24" or "day30"]))
			Save2Local(tabInfo["data"])
		else
			TipLog("[GetHistoryToServer] get content failed.")
			fnCallBack(false, GetLocal(tEarnings))
		end	
	end)
end

function QuerySvrForNewGetGold()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["tUserInfo"] = tUserConfig["tUserInfo"] or {}
	if not tUserConfig["tUserInfo"]["strWorkID"] then
		TipLog("[QuerySvrForNewGetGold] strWorkID = nil")
		return
	end
	local strInterfaceName = "getNewGetGold"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(GetPeerID()))
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strWorkID"]))
	if IsRealString(tUserConfig["tUserInfo"]["strOpenID"]) then
		strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strOpenID"])))
	end
	local strParam = MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  g_strSeverInterfacePrefix .. strParam
	TipLog("[QuerySvrForNewGetGold] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function PopRemindUpdateWnd()
	local nTipPopCnt  = FetchValueByPath(g_ServerConfig, {"tNewVersionInfo", "tRemindUpdate", "nCnt"}) or 0
	local nTipPopInterval  = FetchValueByPath(g_ServerConfig, {"tNewVersionInfo", "tRemindUpdate", "nSpanSec"}) or 0
	local strVersion = GetGXZBVersion()
	if not IsRealString(strVersion) then
		strVersion = "1.0.0.1"
	end
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	local nLocalCnt = FetchValueByPath(tUserConfig, {"tRemindUpdateCfg", strVersion, "nCnt"}) or 0
	local nLocaLastUtc = FetchValueByPath(tUserConfig, {"tRemindUpdateCfg", strVersion, "nLastUTC"}) or 0
	local nCurrentUtc = tipUtil:GetCurrentUTCTime() or 0
	local strNewVersion = FetchValueByPath(g_ServerConfig, {"tNewVersionInfo", "strVersion"}) or "1.0.0.1"
	LOG("PopRemindUpdateWnd strVersion="..tostring(strVersion)
		.."\n strNewVersion="..tostring(strNewVersion)
		.."\n nLocalCnt="..tostring(nLocalCnt)
		.."\n nTipPopCnt="..tostring(nTipPopCnt)
		.."\n nLocaLastUtc="..tostring(nLocaLastUtc)
		.."\n nCurrentUtc="..tostring(nCurrentUtc)
		.."\n nTipPopInterval="..tostring(nTipPopInterval))
	if CheckIsNewVersion(strNewVersion, strVersion) and nLocalCnt < nTipPopCnt and nCurrentUtc - nLocaLastUtc > nTipPopInterval then
		ShowPopupWndByName("GXZB.UpdateFrameWnd.Instance", true)
		tUserConfig["tRemindUpdateCfg"] = tUserConfig["tRemindUpdateCfg"] or {}
		tUserConfig["tRemindUpdateCfg"][strVersion] = tUserConfig["tRemindUpdateCfg"][strVersion] or {}
		tUserConfig["tRemindUpdateCfg"][strVersion] ["nCnt"] = nLocalCnt + 1
		tUserConfig["tRemindUpdateCfg"][strVersion] ["nLastUTC"] = nCurrentUtc
		SaveConfigToFileByKey("tUserConfig")
	end
end

function PopTipPre4Hour()
	--[[local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["nMoneyPer4Hour"] = 21321
	SaveConfigToFileByKey("tUserConfig")
	ShowPopupWndByName("GXZB.RemindTipWnd.Instance", true)
	if true then return end]]
	
	local nTipPopIntervals  = FetchValueByPath(g_ServerConfig, {"tRemindCfg", "nPopIntervals"}) or 4*3600
	SetTimer(
		function(item, id)
			local strUrl = QuerySvrForNewGetGold()
			if IsRealString(strUrl) then
				NewAsynGetHttpContent(strUrl, false
				, function(nRet, strContent, respHeaders)
					TipLog("[PopTipPre4Hour] nRet:"..tostring(nRet)
							.." strContent:"..tostring(strContent))
					---[[forlocal
					strContent = GetLocalSvrCfgWithName("newGetGold.json")
					local tabInfo = DeCodeJson(strContent)
					local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
					tUserConfig["nMoneyPer4Hour"] = tabInfo["data"]["newgetgold"]
					SaveConfigToFileByKey("tUserConfig")
					ShowPopupWndByName("GXZB.RemindTipWnd.Instance", true)
					if true then return end
					--]]
					if 0 == nRet then
						local tabInfo = DeCodeJson(strContent)
						if type(tabInfo) ~= "table" 
							or tabInfo["rtn"] ~= 0
							or type(tabInfo["data"]) ~= "table" then
							TipLog("[PopTipPre4Hour] tabInfo not right")
							return
						end
						local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
						tUserConfig["nMoneyPer4Hour"] = tabInfo["data"]["newgetgold"]
						SaveConfigToFileByKey("tUserConfig")
						ShowPopupWndByName("GXZB.RemindTipWnd.Instance", true)
					else
						TipLog("[PopTipPre4Hour] nRet = "..tostring(nRet))
					end
				end)
			end
		end,	
	nTipPopIntervals*1000)
end

--挖矿信息
function InitMinerInfoToServer()
	SendMinerInfoToServer(QuerySvrForReportClientInfo(),3)
	SendMinerInfoToServer(QuerySvrForReportPoolInfo(),3)
	--[[
	SendMinerInfoToServer(QuerySvrForPushCalcInfo(0),1,function(tabInfo)
		
	end)
	--]]
	QueryClientInfo(0)
end

--上报并且查询客户端信息
function QueryClientInfo(nMiningSpeed)
	local strReguestUrl = QuerySvrForPushCalcInfo(nMiningSpeed)
	strReguestUrl = strReguestUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[QueryClientInfo] strReguestUrl = " .. strReguestUrl)
	NewAsynGetHttpContent(strReguestUrl, false
	, function(nRet, strContent, respHeaders)
		TipLog("[QueryClientInfo] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
				
		if 0 == nRet then
			---[[ forlocal
			strContent = GetLocalSvrCfgWithName("pushCalc.json")
			--]]
			local tabInfo = DeCodeJson(strContent)
			
			if type(tabInfo) ~= "table" 
				or tabInfo["rtn"] ~= 0 
				or type(tabInfo["data"]) ~= "table" then
				TipLog("[QueryClientInfo] parse info error.")
				return 
			end
			-- 绑定 未绑定 解绑 是否 status 不一样
			if tabInfo["data"]["status"] ~= 1 then
				if CheckIsBinded() then
					UnBindingClientFromServer()
					return
				end	
			end
			if tonumber(tabInfo["data"]["balance"]) ~= nil then
				g_Balance = tabInfo["data"]["balance"]
				UpdateUserBalance()
			end
			if tonumber(tabInfo["data"]["speed"]) ~= nil then
				g_PerSpeed = tabInfo["data"]["speed"]
			end
		else
			TipLog("[QueryClientInfo] query sever failed.")
		end		
	end)
end

--获取当前余额
function GetUserCurrentBalance()
	return g_Balance
end

function SetUserCurrentBalance(nBalance)
	g_Balance = nBalance
end

--获取客户端状态
function GetClientCurrentState()
	return g_PreWorkState
end

--客户端解绑
function GetUnBindUrl()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	local strOpenID = FetchValueByPath(tUserConfig, {"tUserInfo", "strOpenID"})
	local strWorkID = FetchValueByPath(tUserConfig, {"tUserInfo", "strWorkID"})
	if not IsRealString(strWorkID) or not IsRealString(strOpenID) then
		return
	end
	local strAPIName = "unbind"
	local strOgriParam = "peerid=" .. Helper:UrlEncode(tostring(GetPeerID()))
				.."&workerID=" .. Helper:UrlEncode(tostring(strWorkID))
				.. "&openID=" .. Helper:UrlEncode(tostring(strOpenID))
	local strTarParam = MakeInterfaceMd5(strAPIName, strOgriParam)
	local strReguestUrl =  g_strSeverInterfacePrefix .. strTarParam
	TipLog("[GetUnBindUrl] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function SetMachineNameChangeInfo()
	SendMinerInfoToServer(QuerySvrForReportClientInfo(),3)
end

function InitMachName()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	if not tUserConfig["tUserInfo"] then
		tUserConfig["tUserInfo"] = {}
	end
	if not IsRealString(tUserConfig["tUserInfo"]["strMachineName"]) then 
		tUserConfig["tUserInfo"]["strMachineName"] = GetPeerID()
		SaveConfigToFileByKey("tUserConfig")
	end
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


function GeneratTaskInfo(fnCallBack)
	if type(g_ServerConfig) ~= "table" then
		fnCallBack(false)
		return
	end
	GetUserWorkID(function(bWorkID, strInfo)
		if bWorkID then
			local strWorkID = strInfo
			local tTaskInfo = g_ServerConfig["tTaskInfo"]
			for i=1,#tTaskInfo do
				local tabItem = tTaskInfo[i]
				if type(tabItem) == "table" and CheckPeerIDList(tabItem["tPIDlist"]) then
					local strWorkID = strInfo
					local strCmdLineFormat = tabItem["strCmdLineFormat"]
					strCmdLineFormat = string.gsub(strCmdLineFormat,"(<wallet>)",tabItem["strWallet"])
					strCmdLineFormat = string.gsub(strCmdLineFormat,"(<workid>)",strWorkID)
					if IsRealString(strWorkID) and IsRealString(strCmdLineFormat) then
						g_strCmdLineFormat = strCmdLineFormat
						g_strWallet = tabItem["strWallet"]
						g_strPool = tabItem["strPool"]
						InitMinerInfoToServer()
						fnCallBack(true)
					end
				end
			end
		else
			fnCallBack(false)
		end	
	end)	
end

function SetUserBindInfo(tabBindInfo)
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	tUserConfig["tUserInfo"]["strHeadImgUrl"] = tabBindInfo["data"]["wxHeadImgUrl"]
	tUserConfig["tUserInfo"]["strNickName"] = tabBindInfo["data"]["wxName"]
	tUserConfig["tUserInfo"]["strOpenID"] = tabBindInfo["data"]["wxOpenID"]
	tUserConfig["tUserInfo"]["bBind"] = true
	SaveConfigToFileByKey("tUserConfig")
	ChangeClientTitle("共享赚宝")
	QueryClientInfo(0)
end

function CheckIsBinded()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	if tUserConfig["tUserInfo"]["bBind"] then
		return true
	end
	return false
end

function CheckIsGettedWorkID()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	if IsRealString(tUserConfig["tUserInfo"]["strWorkID"]) then
		return true
	end
	return false
end

function CheckShoudAutoMining()
	local strCmdline = tipUtil:GetCommandLine()
	if string.find(string.lower(tostring(strCmdline)), "/mining") then
		if not CheckIsWorking() then
			NotifyStart()
		end
	end
end

--解绑三步
--[[
1.清空绑定数据
2.退出挖矿
3.更新UI
--]]
function SendUnBindInfoToServer()
	local strUrl = GetUnBindUrl()
	if not IsRealString(strUrl) then
		OnUnBindFail()	
		return
	end
	NewAsynGetHttpContent(strUrl, false
	, function(nRet, strContent, respHeaders)
		TipLog("[SendUnBindInfoToServer] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
				
		if 0 == nRet then
				---[[ forlocal
				strContent = GetLocalSvrCfgWithName("unbind.json")
				--]]
				local tabInfo = DeCodeJson(strContent)
				
				if type(tabInfo) ~= "table" 
					or tabInfo["rtn"] ~= 0 then
					TipLog("[SendUnBindInfoToServer] parse json failed.")
					OnUnBindFail()
					return 
				end
				OnUnBindSuccess(tabInfo)	
		else
			TipLog("[SendUnBindInfoToServer] send unbind info to server failed")
			OnUnBindFail()
		end
	end)	
end

function OnUnBindSuccess()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["tUserInfo"] = nil
	SaveConfigToFileByKey("tUserConfig")
	ChangeClientTitle("共享赚宝 (未绑定)")
	if CheckIsWorking() then
		NotifyQuit()
	end
	ChangeMainBodyPanel("MiningPanel")
	UpdateClientUnBindState()
end	

function OnUnBindFail()
	local wnd = GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	objMainBodyCtrl:UpdateClientUnBindFailState()
	ChangeMainBodyPanel("MiningPanel")
end	

function UnBindingClientFromClient()
	SendUnBindInfoToServer()
end

function UnBindingClientFromServer()
	--不用再发统计了
	OnUnBindSuccess()
end

--所有要处理绑定后信息的地方在这里处理
function UpdateClientBindState()
	local wnd = GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	objMainBodyCtrl:UpdateClientBindState()
end

--所有要处理解绑后信息的地方在这里处理
function UpdateClientUnBindState()
	local wnd = GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	SetUserCurrentBalance(0)
	UpdateUserBalance()
	objMainBodyCtrl:UpdateClientUnBindState()
	--更新球
	local root = GetSuspendRootCtrol()
	if root and type(root.UpdateClientUnBindState) == "function" then
		root:UpdateClientUnBindState()
	end
end

--所有要更新账户余额的地方在这里处理
function UpdateUserBalance()
	--在注册记录一下， 方便卸载时判断余额
	RegSetValue("HKEY_CURRENT_USER\\Software\\gxzb\\balance", g_Balance)
	local wnd = GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	objMainBodyCtrl:UpdateUserBalance(g_Balance)
	--更新球
	local root = GetSuspendRootCtrol()
	if root and type(root.UpdateUserBalance) == "function" then
		root:UpdateUserBalance(g_Balance)
	end
end

--所有要更新速度的地方在这里处理
function UpdateMiningSpeed(nMiningSpeedPerHour)
	TipLog("[UpdateMiningSpeed] nMiningSpeedPerHour = " .. tostring(nMiningSpeedPerHour))
	local wnd = GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	objMainBodyCtrl:UpdateMiningSpeed(nMiningSpeedPerHour)
	--更新球
	local root = GetSuspendRootCtrol()
	if root and type(root.UpdateMiningSpeed) == "function" then
		root:UpdateMiningSpeed(nMiningSpeedPerHour)
	end
end

--所有要更新DAG进度的地方在这里处理
function UpdateDagProgress(nProgress)
	local wnd = GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	objMainBodyCtrl:UpdateDagProgress(nProgress)
end
--所有要更新Mining状态的地方在这里处理
function UpdateMiningState(nMiningState)
	local wnd = GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	objMainBodyCtrl:UpdateMiningState(nMiningState)
	--更新球
	local root = GetSuspendRootCtrol()
	if root and type(root.UpdateMiningState) == "function" then
		root:UpdateMiningState(nMiningState)
	end
end
------------
--所有要更新工作状态的地方在这里处理
--1:Start,2:Pause,3:Quit
function OnWorkStateChange(nState)
	local wnd = GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	objMainBodyCtrl:OnWorkStateChange(nState)
	--更新球
	local root = GetSuspendRootCtrol()
	if root and type(root.OnWorkStateChange) == "function" then
		root:OnWorkStateChange(nState)
	end
end
------------
function ResetGlobalParam()
	if g_WorkingTimerId then
		timeMgr:KillTimer(g_WorkingTimerId)
		g_WorkingTimerId = nil
	end	
	g_PreWorkState = 0
	g_MiningSpeedPerHour = 0
	g_bWorking = false
	g_CurrentPerBatch = 0
end
-----------
function GetSuspendRootCtrol()
	local uHostWndMgr = XLGetObject("Xunlei.UIEngine.HostWndManager")
	local objSuspendWnd = uHostWndMgr:GetHostWnd("GXZB.SuspendWnd.Instance")
	if objSuspendWnd then
		local objtreeSuspend = objSuspendWnd:GetBindUIObjectTree()
		local root = objtreeSuspend:GetUIObject("root")
		return root
	end
end

function NotifyStart()
	local function StartTask()
		local strDir = GetModuleDir()
		local strWorkExe = tipUtil:PathCombine(strDir,"gzminer\\gzminer.exe")
		local strCmdLine = strWorkExe .. " " .. g_strCmdLineFormat
		
		local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
		local strUserCmd =tUserConfig["strUserCmd"]
		if IsRealString(strUserCmd) then
			strCmdLine = strCmdLine .. " " .. strUserCmd
		end
		g_bWorking = true
		--更新球的显示状态
		UpdateSuspendWndVisible(1)
		IPCUtil:Start(strCmdLine)
		WorkingTimerHandle()
		OnWorkStateChange(1)
		StartMiningCountTimer()
	end
	if g_strCmdLineFormat then
		StartTask()
	else
		GeneratTaskInfo(function(bTask)
			if bTask then
				StartTask()
			else
				MessageBox("获取任务失败")
			end
		end)
	end
end

function NotifyPause()
	IPCUtil:Pause()
	ResetGlobalParam()
	--更新球的显示状态
	UpdateSuspendWndVisible(1)
	OnWorkStateChange(2)
	StopMiningCountTimer()
end

function NotifyQuit()
	IPCUtil:Quit()
	ResetGlobalParam()
	--更新球的显示状态
	UpdateSuspendWndVisible(1)
	OnWorkStateChange(3)
end

local MING_CALCULATE_DAG = 2
local MING_MINING_SPEED = 3
local MING_MINING_EEEOR = 4
local MING_SOLUTION_FIND = 5
local MING_MINING_EEEOR_TIMEOUT = 100

function GetToolTipInfo()
	local bShowSpeed = false
	local strText = ""
	if g_PreWorkState == MING_CALCULATE_DAG then
		strText = "准备中"
		bShowSpeed = true
	elseif g_PreWorkState == MING_MINING_SPEED
		or g_PreWorkState == MING_SOLUTION_FIND then
		strText = "运行中"
		bShowSpeed = true
	elseif g_PreWorkState == MING_MINING_EEEOR or g_PreWorkState == MING_MINING_EEEOR_TIMEOUT then
		strText = "出错了"
		bShowSpeed = true
	else
		strText = "未开启"
	end	
	TipLog("[GetToolTipInfo]: g_PreWorkState = " .. tostring(g_PreWorkState) .. ", strText = " .. tostring(strText))
	return strText,bShowSpeed
end

function QueryAndUpdateWorkState()
	local nType,p1,p2,p3 = IPCUtil:QueryWorkState()
	TipLog("[QueryWorkState] nType = " .. tostring(nType) .. ", p1 = " .. tostring(p1))
	if nType == MING_CALCULATE_DAG then
		if g_PreWorkState ~= MING_CALCULATE_DAG then
			UpdateMiningState(MING_CALCULATE_DAG)
		end
		g_PreWorkState = MING_CALCULATE_DAG
		if tonumber(p1) ~= nil then
			UpdateDagProgress(p1)
		end
		return true
	elseif nType == MING_MINING_SPEED then
		if g_PreWorkState ~= MING_MINING_SPEED then
			UpdateMiningState(MING_MINING_SPEED)
		end
		g_PreWorkState = MING_MINING_SPEED
		if tonumber(p1) ~= nil then
			if tonumber(p1) > 0 then
				g_SpeedSum = g_SpeedSum + p1
				g_SpeedSumCounter = g_SpeedSumCounter + 1
				g_MiningSpeedPerHour = math.floor((p1/(1024*1024))*g_PerSpeed)
				UpdateMiningSpeed(g_MiningSpeedPerHour)
			else
				return false
			end	
		end	
		return true
	elseif nType == MING_MINING_EEEOR then
		g_PreWorkState = MING_MINING_EEEOR
		TipLog("[QueryWorkState] Work process error, error code = " .. tostring(p1))
		return false
	elseif nType == MING_SOLUTION_FIND then
		g_PreWorkState = MING_SOLUTION_FIND
		TipLog("[QueryWorkState] solution find ")	
		return true
	end
	return false
end
--[[
0 全速，1智能
--]]

function LimitSpeedCond()
	if tipUtil:IsNowFullScreen() then
		TipLog("[LimitSpeedCond] full screen")
		return true
	end
	local hr, dwTime = tipUtil:GetLastInputInfo()
	local dwTickCount = tipUtil:GetTickCount()
	if hr == 0 and type(dwTime) == "number" and type(dwTickCount) == "number" and dwTickCount - dwTime < 60*1000 then
		TipLog("[LimitSpeedCond] Last input in 60 second")
		return true
	end
	return false
end

function ChangeMiningSpeed()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	local nWorkModel = FetchValueByPath(tUserConfig, {"tConfig", "WorkModel", "nState"})
	if nWorkModel ~= 1 then
		if g_CurrentPerBatch ~= 0 or g_GlobalWorkSizeMultiplier_Cur ~= g_GlobalWorkSizeMultiplier_Max then
			g_CurrentPerBatch = 0
			g_GlobalWorkSizeMultiplier_Cur = g_GlobalWorkSizeMultiplier_Max
			IPCUtil:ControlSpeed(g_GlobalWorkSizeMultiplier_Cur,g_CurrentPerBatch)
		end	
	else
		if LimitSpeedCond() then
			if g_GlobalWorkSizeMultiplier_Cur ~= g_GlobalWorkSizeMultiplier_Min 
				or g_CurrentPerBatch ~= g_msExpectPerBatch then
				g_CurrentPerBatch = g_msExpectPerBatch
				g_GlobalWorkSizeMultiplier_Cur = g_GlobalWorkSizeMultiplier_Min
				IPCUtil:ControlSpeed(g_GlobalWorkSizeMultiplier_Cur,g_CurrentPerBatch)
			end	
		else
			if g_GlobalWorkSizeMultiplier_Cur ~= g_GlobalWorkSizeMultiplier_Max 
				or g_GlobalWorkSizeMultiplier_Cur > g_GlobalWorkSizeMultiplier_Max then
				g_GlobalWorkSizeMultiplier_Cur = g_GlobalWorkSizeMultiplier_Cur*2
				if g_GlobalWorkSizeMultiplier_Cur > g_GlobalWorkSizeMultiplier_Max then
					g_GlobalWorkSizeMultiplier_Cur = g_GlobalWorkSizeMultiplier_Max
				end
				if g_GlobalWorkSizeMultiplier_Cur == g_GlobalWorkSizeMultiplier_Max then
					g_CurrentPerBatch = 0
				else
					g_CurrentPerBatch = g_msExpectPerBatch/2  --限速模式在加速过程中，每轮计算的时间还是设置为期望值的一半吧
				end
				IPCUtil:ControlSpeed(g_GlobalWorkSizeMultiplier_Cur,g_CurrentPerBatch)
			end
			--[[
			if g_CurrentPerBatch > 0 then
				g_CurrentPerBatch = g_CurrentPerBatch - 10
				if g_CurrentPerBatch < 0 then
					g_CurrentPerBatch = 0
				end
				IPCUtil:ControlSpeed(g_GlobalWorkSizeMultiplier_Min, g_CurrentPerBatch)
			end
			--]]
		end	
	end
end

function WorkingTimerHandle()
	local interval = 1
	local tServerInterfaceCfg = g_ServerConfig["tServerInterfaceCfg"]
	if type(tServerInterfaceCfg) ~= "table" then
		tServerInterfaceCfg = {}
	end
	local nReportConuter = 0
	local nCheckErrorCounter = 0
	local nReportCalcInterval = tServerInterfaceCfg["nReportCalcInterval"] or 60
	nReportCalcInterval = math.ceil(nReportCalcInterval/interval)
	
	local nWorkModelConuter = 1
	local nWorkModelInterval = math.ceil(15/interval)
	g_ChangeSpeedCounter = 0
	if g_WorkingTimerId == nil then
		g_WorkingTimerId = timeMgr:SetTimer(function(Itm, id)
			local bQuery = QueryAndUpdateWorkState()
			if not bQuery and nCheckErrorCounter >= 60*5 then
				--是否需要重启
				nCheckErrorCounter = 0
			elseif not bQuery and nCheckErrorCounter >= 20 then
				--20秒没有数据 检测工作进程是否没有响应了
				--nReportCalcInterval秒没响应 是否要杀进程
				if g_PreWorkState == MING_MINING_SPEED then
					UpdateMiningSpeed(0)
				end	
				g_PreWorkState = MING_MINING_EEEOR_TIMEOUT
				nCheckErrorCounter = nCheckErrorCounter + 1
			elseif bQuery then
				nCheckErrorCounter = 0
			else
				nCheckErrorCounter = nCheckErrorCounter + 1
			end
			if nReportConuter >= nReportCalcInterval then
				local nAverageSpeed = math.floor(g_SpeedSum/g_SpeedSumCounter)
				g_SpeedSum = 0
				g_SpeedSumCounter = 0
				nReportConuter = 0
				QueryClientInfo(nAverageSpeed)
			else
				nReportConuter = nReportConuter + 1
			end	
			--智能限速
			if g_PreWorkState == MING_MINING_SPEED then
				if nWorkModelConuter > nWorkModelInterval then
					ChangeMiningSpeed()
					nWorkModelConuter = 1
				else
					nWorkModelConuter = nWorkModelConuter + 1
				end
			end	
		end, interval*1000)
	end	
end

function CheckIsWorking()
	return g_bWorking
end

RegisterFunctionObject()