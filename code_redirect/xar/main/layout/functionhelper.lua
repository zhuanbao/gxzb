local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local IPCUtil = XLGetObject("IPC.Util")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
--local g_ServerConfig = nil

local g_WorkClient = nil
local g_bShowWndByTray = false
local gStatCount = 0

local gnLastReportRunTmUTC = tipUtil:GetCurrentUTCTime()
local gnLastReportMiningTmUTC = tipUtil:GetCurrentUTCTime()
local g_MiningReportTimerId = nil

local gTimeoutTimerId = nil

local gbLoadCfgSucc = false
local g_tipNotifyIcon = nil
local g_bIsUpdating = false
local JsonFun = nil

local g_strSeverInterfacePrefix = "http://www.eastredm.com/pc"

-- 工作中用到的
--local g_bWorking = false

--UI界面工作状态
--
local UI_STATE_STOPPED = 0
local UI_STATE_STARTING = 1
local UI_STATE_PREPARE_WORKID = 2
local UI_STATE_PREPARE_POOL = 3
local UI_STATE_CALCULATE = 4

local g_UIWorkState = UI_STATE_STOPPED
--

local g_WorkingTimerId = nil
local g_SvrAverageMiningSpeed = 0

local g_Balance = 0

--常量
--客户端状态
local CLIENT_STATE_CALCULATE = 0
local CLIENT_STATE_PREPARE = 1
local CLIENT_STATE_EEEOR = 2
local CLIENT_STATE_AUTO_EXIT = 3


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

function LoadGenOilClient()
	local strClientPath = __document.."\\..\\GenOilClient.lua"
	local Module = XLLoadModule(strClientPath)
end

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
	--通用功能函数
	obj.TipLog = TipLog
	obj.FetchValueByPath = FetchValueByPath
	obj.NumberToFormatMoney = NumberToFormatMoney
	obj.FormatMoneyToNumber = FormatMoneyToNumber
	obj.FailExitTipWnd = FailExitTipWnd
	obj.GetCommandStrValue = GetCommandStrValue
	obj.TipConvStatistic = TipConvStatistic
	obj.ReportAndExit = ReportAndExit
	obj.LoadTableFromFile = LoadTableFromFile
	obj.RegQueryValue = RegQueryValue
	obj.RegSetValue = RegSetValue
	obj.RegDeleteValue = RegDeleteValue
	obj.GetPeerID = GetPeerID
	obj.GetSystemBits = GetSystemBits
	obj.FormatByteUnit = FormatByteUnit
	obj.CheckTimeIsAnotherDay = CheckTimeIsAnotherDay
	obj.NewAsynGetHttpFile = NewAsynGetHttpFile
	obj.GetFileSaveNameFromUrl = GetFileSaveNameFromUrl
	obj.DownLoadFileWithCheck = DownLoadFileWithCheck
	obj.CheckMD5 = CheckMD5
	obj.GetTimeStamp = GetTimeStamp
	obj.IsUACOS = IsUACOS
	obj.GetCurrentServerTime = GetCurrentServerTime
	obj.CheckIsAnotherDay = CheckIsAnotherDay
	obj.CheckPeerIDList = CheckPeerIDList
	
	--业务辅助函数
	obj.GetModuleDir = GetModuleDir
	obj.GetExePath = GetExePath
	obj.GetGXZBVersion = GetGXZBVersion
	obj.GetGXZBMinorVer = GetGXZBMinorVer
	obj.GetInstallSrc = GetInstallSrc
	obj.DownLoadServerConfig = DownLoadServerConfig
	obj.CheckIsNewVersion = CheckIsNewVersion
	obj.CheckCommonUpdateTime = CheckCommonUpdateTime
	obj.CheckAutoUpdateTime = CheckAutoUpdateTime
	obj.SaveCommonUpdateUTC = SaveCommonUpdateUTC
	obj.SaveConfigToFileByKey = SaveConfigToFileByKey
	obj.ReadConfigFromMemByKey = ReadConfigFromMemByKey
	obj.CheckIsUpdating = CheckIsUpdating
	obj.SetIsUpdating = SetIsUpdating
	obj.CheckForceVersion = CheckForceVersion
	obj.ReadAllConfigInfo = ReadAllConfigInfo
	obj.StartRunCountTimer = StartRunCountTimer
	obj.SaveAllConfig = SaveAllConfig
	obj.DownLoadNewVersion = DownLoadNewVersion
	
	
	obj.TryToConnectServer = TryToConnectServer
	obj.InitMiningClient = InitMiningClient
	--UI函数
	obj.GetMainHostWnd = GetMainHostWnd
	obj.ShowPopupWndByName = ShowPopupWndByName
	obj.GetCfgPathWithName = GetCfgPathWithName
	obj.ShowExitRemindWnd = ShowExitRemindWnd
	obj.SetNotifyIconState = SetNotifyIconState
	obj.SetWndForeGround = SetWndForeGround
	obj.PopupNotifyIconTip = PopupNotifyIconTip
	obj.InitTrayTipWnd = InitTrayTipWnd 
	obj.CreatePopupTipWnd = CreatePopupTipWnd
	obj.ShowIntroduceOnce = ShowIntroduceOnce
	obj.PopRemindUpdateWnd = PopRemindUpdateWnd
	obj.UpdateSuspendWndVisible = UpdateSuspendWndVisible
	obj.DestroyPopupWnd = DestroyPopupWnd
	obj.ChangeMainBodyPanel = ChangeMainBodyPanel
	obj.ChangeClientTitle = ChangeClientTitle
	obj.CheckShouldRemindBind = CheckShouldRemindBind
	obj.SaveLastRemindBindUTC = SaveLastRemindBindUTC
	obj.SetStateInfoToUser = SetStateInfoToUser
	
	
	--服务器相关函数
	obj.InitMachName = InitMachName
	obj.GetUserWorkID = GetUserWorkID
	obj.CheckIsGettedWorkID = CheckIsGettedWorkID
	obj.DownLoadTempQrcode = DownLoadTempQrcode
	obj.CycleQuerySeverForBindResult = CycleQuerySeverForBindResult
	obj.SetUserBindInfo = SetUserBindInfo
	obj.ReportClientInfoToServer = ReportClientInfoToServer
	obj.ReportMiningPoolInfoToServer = ReportMiningPoolInfoToServer
	obj.QueryClientInfo = QueryClientInfo
	obj.TakeCashToServer = TakeCashToServer
	obj.GetHistoryToServer = GetHistoryToServer
	obj.PopTipPre4Hour = PopTipPre4Hour
	obj.SetMachineNameChangeInfo = SetMachineNameChangeInfo
	obj.UnBindingClientFromClient = UnBindingClientFromClient
	obj.UnBindingClientFromServer = UnBindingClientFromServer
	obj.CheckIsBinded = CheckIsBinded
	
	--挖矿ing相关	
	obj.GetSvrAverageMiningSpeed = GetSvrAverageMiningSpeed
	obj.GetClientCurrentState = GetClientCurrentState
	obj.GetUIWorkState = GetUIWorkState
	obj.CheckIsWorking = CheckIsWorking
	obj.CheckIsPrepare = CheckIsPrepare
	obj.CheckIsCalculate = CheckIsCalculate
	obj.GetUserCurrentBalance = GetUserCurrentBalance
	obj.SetUserCurrentBalance = SetUserCurrentBalance
	obj.CheckShoudAutoMining = CheckShoudAutoMining
	obj.GetWorkClient = GetWorkClient
	
	obj.UpdateMiningSpeed = UpdateMiningSpeed
	obj.UpdateMiningState = UpdateMiningState
	obj.UpdateDagProgress = UpdateDagProgress
	obj.UpdateUserBalance = UpdateUserBalance
	obj.UpdateRealTimeIncome = UpdateRealTimeIncome

	obj.NotifyStart = NotifyStart
	obj.NotifyQuit = NotifyQuit
	obj.NotifyPause = NotifyPause
	obj.NotifyResume = NotifyResume
	obj.HandleOnStart = HandleOnStart
	obj.HandleOnQuit = HandleOnQuit

	XLSetGlobal("Global.FunctionHelper", obj)
end

function NumberToFormatMoney(Num)
	local strNum = tostring(Num)
	if string.len(strNum) <= 4 then
		return Num
	end
	local strLeft = string.sub(strNum, 1, string.len(strNum)-4);
	local strRight = string.sub(strNum, -4); 
	local strFormat = strLeft .. "," .. strRight
	TipLog("[NumberToFormatMoney] strFormat = "..tostring(strFormat))
	return strFormat
end

function FormatMoneyToNumber(strMoney)
	if not IsRealString(strMoney) then
		return strMoney
	end
	local strNum = string.gsub(strMoney, ",","")
	return tonumber(strNum)
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
	local strPeerID = RegQueryValue("HKEY_LOCAL_MACHINE\\Software\\Share4Money\\PeerId")
	if IsRealString(strPeerID) then
		return string.upper(strPeerID)
	end

	local strRandPeerID = tipUtil:GetPeerId()
	if not IsRealString(strRandPeerID) then
		return ""
	end
	
	RegSetValue("HKEY_LOCAL_MACHINE\\Software\\Share4Money\\PeerId", strRandPeerID)
	return string.upper(strRandPeerID)
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

function GetMachineID()
	local strGUID = RegQueryValue("HKEY_LOCAL_MACHINE\\Software\\Share4Money\\machineid")
	if IsRealString(strGUID) then
		return string.upper(strGUID)
	end
end

--渠道
function GetInstallSrc()
	local strInstallSrc = RegQueryValue("HKEY_LOCAL_MACHINE\\Software\\Share4Money\\InstallSource")
	if not IsNilString(strInstallSrc) then
		return tostring(strInstallSrc)
	end
	
	return ""
end

function GetExePath()
	local strExePath = RegQueryValue("HKEY_LOCAL_MACHINE\\Software\\Share4Money\\Path")
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

local bDownloadIng = false
local tCallBacks = {}
function DownLoadServerConfig(fnCallBack, nTimeInMs)
	local function callbackwrap(nRet, strPath)
		for _, cb in ipairs(tCallBacks) do
			cb(nRet, strPath)
		end
		tCallBacks = {}
		bDownloadIng = false
	end
	tCallBacks[#tCallBacks+1] = fnCallBack
	if bDownloadIng then
		return
	end
	bDownloadIng = true
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	
	local strConfigURL = tUserConfig["strServerConfigURL"]
	if not IsRealString(strConfigURL) then
		callbackwrap(-2)
		return
	end
	
	local strSavePath = GetCfgPathWithName("ServerConfig.dat")
	if not IsRealString(strSavePath) then
		callbackwrap(-3)
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
			--[[ forlocal
			strSavePath = GetLocalSvrCfgWithName("ServerConfig.dat", true)
			--]]
			callbackwrap(0, strSavePath)
		else
			callbackwrap(bRet)
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
		infoTable = infoTable or {}
		
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
	tipUtil:CloseSingletonMutex()
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
	local strgxzbPath = RegQueryValue("HKEY_LOCAL_MACHINE\\Software\\Share4Money\\path")
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
			if not tipUtil:QueryRegKeyExists(sRegRoot, sRegPath) then
				tipUtil:CreateRegKey(sRegRoot, sRegPath)
			end
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
	local strRegPath = "HKEY_CURRENT_USER\\SOFTWARE\\Share4Money\\ShowIntroduce"
	
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
	TipLog("[InitTrayTipWnd] init success")
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

function GetToolTipInfo()
	local nUIWorkState = GetUIWorkState()
	local bShowSpeed = false
	local strText = ""
	if CheckIsPrepare() then
		strText = "准备中"
		bShowSpeed = true
	elseif CheckIsCalculate() then
		strText = "运行中"
		bShowSpeed = true
	else
		strText = "未开启"
	end	
	TipLog("[GetToolTipInfo]: nPreWorkState = " .. tostring(nPreWorkState) .. ", strText = " .. tostring(strText))
	return strText,bShowSpeed
end

function SetNotifyIconState(strText)
	if not g_tipNotifyIcon then
		return
	end
	g_tipNotifyIcon:ShowNotifyIconTip(false)
	
	local strState, bShowSpeed = GetToolTipInfo()
	
	local strShowText = "共享赚宝  状态："..strState
	
	local nBalance = GetUserCurrentBalance()
	strShowText = strShowText .. "\r\n金库余额：" .. NumberToFormatMoney(nBalance) .. "元宝"
	if bShowSpeed then
		strShowText = strShowText .. "\r\n当前赚宝速度：" .. tostring(GetClientMiningSpeed()) .. "元宝/小时"
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
	
	local strCfgFilePath = tipUtil:PathCombine(strBaseDir, "Share4Money\\"..tostring(strCfgName))
	return strCfgFilePath or ""
end

function GetResSavePath(strName)
	local bOk, strBaseDir = QueryAllUsersDir()
	if not bOk then
		return ""
	end
	
	local strPath = tipUtil:PathCombine(strBaseDir, "Share4Money\\res\\"..tostring(strName))
	return strPath or ""
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
	
	for k, v in pairs(tOldCfg) do
		--除了strServerConfigURL，其他都用老的
		if k ~= "strServerConfigURL" then
			tCurrentCfg[k] = v
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
	gnLastReportMiningTmUTC = tipUtil:GetCurrentUTCTime()
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
	gnLastReportMiningTmUTC = 0
end

function SendMiningReport(nTimeSpanInSec, bExit)
	local tStatInfo = {}
	tStatInfo.strEC = "mining"
	tStatInfo.strEA = GetInstallSrc() or ""
	
	local nMiningTime = 0
	if bExit and gnLastReportMiningTmUTC ~= 0 then
		nMiningTime = math.abs(tipUtil:GetCurrentUTCTime() - gnLastReportMiningTmUTC)
		gnLastReportMiningTmUTC = 0
	else
		nMiningTime = nTimeSpanInSec
	end
	tStatInfo.strEV = nMiningTime
	if nMiningTime == 0 then
		return
	end
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

function CheckSvrPoolCfg(nLastCfg)
	local bRet = false
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tSvrPoolInfo"]) ~= "table" then
		tUserConfig["tSvrPoolInfo"] = {}
	end
	local tPoolList = tUserConfig["tSvrPoolInfo"]["tPoolList"]
	if type(tPoolList) ~= "table" or #tPoolList < 1 then
		return false
	end
	local nLastUpdateCfgTime = tUserConfig["tSvrPoolInfo"]["nLastUpdateCfgTime"]
	if nLastCfg ~= nLastUpdateCfgTime then
		return false
	end
	return true
end

function MakeSvrPoolCfgRequestUrl()
	local strStamp = GetTimeStamp()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tSvrPoolInfo"]) ~= "table" then
		tUserConfig["tSvrPoolInfo"] = {}
	end
	local nLastUpdateCfgTime = tUserConfig["tSvrPoolInfo"]["nLastUpdateCfgTime"]
	if nLastUpdateCfgTime ~= nil then
		strStamp = "?stamp=" .. tostring(nLastUpdateCfgTime)
	end
	local strReguestUrl = "http://www.eastredm.com/static/poolcfg.json" .. strStamp
	--[[ forlocal
	strReguestUrl = "http://www.eastredm.com/static/ServerConfig.dat" .. strStamp
	--]]
	TipLog("[QuerySvrForPoolCfg] strReguestUrl = " .. tostring(strReguestUrl))
	return strReguestUrl
end

function GetSvrPoolCfg(nLastCfg)
	local strUrl = MakeSvrPoolCfgRequestUrl()
	NewAsynGetHttpContent(strUrl, false
	, function(nRet, strContent, respHeaders)
		TipLog("[GetWorkPoolCfg] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
				
		if 0 ~= nRet then
			TipLog("[GetSvrPoolCfg] query sever failed")
			OnSvrPoolCfgUpdate(false, false, nLastCfg)
			return
		end
		--[[ forlocal
		strContent = GetLocalSvrCfgWithName("poolcfg.json")
		--]]
		local tabInfo = DeCodeJson(strContent)
		if type(tabInfo) ~= "table" 
			or type(tabInfo["data"]) ~= "table" 
			or type(tabInfo["data"]["pool"]) ~= "table" 
			or #tabInfo["data"]["pool"] == 0 then
			TipLog("[GetSvrPoolCfg] parse Json failed.")
			OnSvrPoolCfgUpdate(false, false, nLastCfg)
			return 
		end
		local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
		if type(tUserConfig["tSvrPoolInfo"]) ~= "table" then
			tUserConfig["tSvrPoolInfo"] = {}
		end
		
		local tabPool = tabInfo["data"]["pool"]
		local tabUserPool = {}
		for index = 1, #tabPool do
			if type(tabPool[index]) == "table" and CheckPeerIDList(tabPool[index]["pidlist"]) then
				tabUserPool[#tabUserPool+1] = tabPool[index]
			end
		end
		tUserConfig["tSvrPoolInfo"]["tPoolList"] = tabUserPool
		
		if nLastCfg ~= nil then
			tUserConfig["tSvrPoolInfo"]["nLastUpdateCfgTime"] = nLastCfg
		end	
		SaveConfigToFileByKey("tUserConfig")
		OnSvrPoolCfgUpdate(true, true, nLastCfg)
	end)
end

function UpdateSvrPoolCfg(tabInfo)
	local nLastCfg = tonumber(tabInfo["data"]["lastCfg"])
	local bRet = CheckSvrPoolCfg(nLastCfg)
	if bRet then
		OnSvrPoolCfgUpdate(true,false,nLastCfg)
	else
		GetSvrPoolCfg(nLastCfg)
	end
end

function OnSvrPoolCfgUpdate(bGet, bUpdated,nLastCfg)
	if GetUIWorkState() == UI_STATE_PREPARE_POOL then
		if not bGet then
			SetStateInfoToUser("连接服务器失败，重试中...")
			SetOnceTimer(function()
				GetSvrPoolCfg(nLastCfg)
			end, 5*1000)
			return
		end
		StartClient()
	elseif GetUIWorkState() == UI_STATE_CALCULATE then
		if bUpdated then
			g_WorkClient.ReStartClientByNewPoolList()
		end
	end
end


function QuerySvrForLoginInfo()
	--这里保证workID不为空
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
	strInterfaceParam = strInterfaceParam .. "&pool=" .. Helper:UrlEncode((tostring(g_WorkClient.GetCurrentPool())))
	strInterfaceParam = strInterfaceParam .. "&account=" .. Helper:UrlEncode((tostring(g_WorkClient.GetCurrentAccount())))
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
	local strSpeed = string.format("%0.2f",nSpeed)
	strInterfaceParam = strInterfaceParam .. "&speed=" .. Helper:UrlEncode((tostring(strSpeed) .. "MH/s"))
	strInterfaceParam = strInterfaceParam .. "&pool=" .. Helper:UrlEncode((tostring(g_WorkClient.GetCurrentPool())))
	strInterfaceParam = strInterfaceParam .. "&account=" .. Helper:UrlEncode((tostring(g_WorkClient.GetCurrentAccount())))
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
	local strInterfaceName = "drawout"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(GetPeerID()))
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strWorkID"]))
	if IsRealString(tUserConfig["tUserInfo"]["strOpenID"]) then
		strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strOpenID"])))
	end
	strInterfaceParam = strInterfaceParam .. "&amount=" .. Helper:UrlEncode((tostring(nMoney)))
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
			--[[ forlocal
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

function QuerySvrForGetHistoryInfo(strtype)
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
	strInterfaceParam = strInterfaceParam .. "&type=" .. Helper:UrlEncode((tostring(strtype)))
	local strParam = MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  g_strSeverInterfacePrefix .. strParam
	TipLog("[QuerySvrForGetHistoryInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

--查询收益接口,strtype = h24 最近24小时，d30 最近1个月
--不同整点才会去请求，否则使用本地
--请求失败显示上次， 颜色用灰色
function GetHistoryToServer(strtype, fnCallBack)
	local function CheckLastUTC(utc)
		if type(utc) ~= "number" then
			return true
		end
		local nCurrentUtc = tipUtil:GetCurrentUTCTime() or 0
		local nLYear, nLMonth, nLDay, nLHour, nLMin = tipUtil:FormatCrtTime(utc)
		local nCYear, nCMonth, nCDay, nCHour, nCMin = tipUtil:FormatCrtTime(nCurrentUtc)
		if nLYear ~= nCYear or nLMonth ~= nCMonth or nLDay ~= nCDay or nLHour ~= nCHour or nLMin ~= nCMin then
			return true
		end
		return false
	end
	local function UINeedTable(t)
		local tmp = {}
		local nCurrent = tipUtil:GetCurrentUTCTime() or 0
		--[[
		if strtype == "h24" then
			nCurrent = nCurrent - 3600
		else
			nCurrent = nCurrent - 86400
		end
		--]]
		for i=#t, 1, -1 do
			local _, LMonth, LDay, LHour = tipUtil:FormatCrtTime(nCurrent)
			tmp[i] = {}
			if strtype == "h24" then
				tmp[i][1] = string.format("%02d", LHour)..":00"
				nCurrent = nCurrent - 3600
			else
				tmp[i][1] = string.format("%02d", LMonth).."/".. string.format("%02d", LDay)
				nCurrent = nCurrent - 86400
			end
			tmp[i][2] = t[i]
		end
		return tmp
	end
	local function GetLocal(tLocal)
		local t = {}
		local count = 0
		tLocal = tLocal or {}
		if strtype == "h24" then
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
		tEarnings[strtype] = tEarnings[strtype] or {}
		tEarnings[strtype]["lastutc"] = tipUtil:GetCurrentUTCTime() or 0
		tEarnings[strtype == "h24" and "hour24" or "day30"] = UINeedTable(tServer)
		SaveConfigToFileByKey("tEarnings")
	end
	local tEarnings = ReadConfigFromMemByKey("tEarnings") or {}
	tEarnings[strtype] = tEarnings[strtype] or {}
	if not CheckLastUTC(tEarnings[strtype]["lastutc"]) then
		fnCallBack(true, GetLocal(tEarnings))
		return
	end
	local strReguestUrl = QuerySvrForGetHistoryInfo(strtype)
	if not strReguestUrl then
		local tDefault = GetLocal()
		fnCallBack(false, tDefault)
		return
	end
	strReguestUrl = strReguestUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[GetHistoryToServer] strReguestUrl = " .. strReguestUrl)
	NewAsynGetHttpContent(strReguestUrl, false
	, function(nRet, strContent, respHeaders)
		TipLog("[GetHistoryToServer] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
		--[[forlocal
		strContent = GetLocalSvrCfgWithName("getHistory"..strtype..".json")
		local tabInfo = DeCodeJson(strContent)
		if type(tabInfo) == "table" and type(tabInfo["data"]) == "table" then
			fnCallBack(true, UINeedTable(tabInfo["data"]))
			Save2Local(tabInfo["data"])
		else
			fnCallBack(false, GetLocal())
		end
		if true then return end
		--]]
		if 0 == nRet then
			local tabInfo = DeCodeJson(strContent)	
			if type(tabInfo) ~= "table" or type(tabInfo["data"]) ~= "table" then
				TipLog("[GetHistoryToServer] parse info error.")
				fnCallBack(false, GetLocal(tEarnings))
				return
			end
			fnCallBack(true, UINeedTable(tabInfo["data"]))
			Save2Local(tabInfo["data"])
		else
			TipLog("[GetHistoryToServer] get content failed.")
			fnCallBack(false, GetLocal(tEarnings))
		end	
	end)
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
		tUserConfig["tRemindUpdateCfg"][strVersion]["nCnt"] = nLocalCnt + 1
		tUserConfig["tRemindUpdateCfg"][strVersion]["nLastUTC"] = nCurrentUtc
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
			GetHistoryToServer("h24", function(bRet, tabInfo)
				if bRet and type(tabInfo) == "table" and #tabInfo >= 4 then
					local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
					local newgetgold = 0
					for i = 1, 4 do
						newgetgold = newgetgold + tabInfo[#tabInfo-i+1][2]
					end
					tUserConfig["nMoneyPer4Hour"] = newgetgold
					SaveConfigToFileByKey("tUserConfig")
					ShowPopupWndByName("GXZB.RemindTipWnd.Instance", true)
				end
			end)
		end,	
	nTipPopIntervals*1000)
end

--挖矿信息

function ReportClientInfoToServer()
	SendMinerInfoToServer(QuerySvrForReportClientInfo(),3)
end

function ReportMiningPoolInfoToServer()
	SendMinerInfoToServer(QuerySvrForReportPoolInfo(),3)
end

--上报并且查询客户端信息
function QueryClientInfo(nMiningSpeed, fnCallBack)
	local strReguestUrl = QuerySvrForPushCalcInfo(nMiningSpeed)
	strReguestUrl = strReguestUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[QueryClientInfo] strReguestUrl = " .. strReguestUrl)
	NewAsynGetHttpContent(strReguestUrl, false
	, function(nRet, strContent, respHeaders)
		TipLog("[QueryClientInfo] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
				
		if 0 == nRet then
			--[[ forlocal
			strContent = GetLocalSvrCfgWithName("pushCalc.json")
			--]]
			local tabInfo = DeCodeJson(strContent)
			if type(tabInfo) ~= "table" 
				or tabInfo["rtn"] ~= 0 
				or type(tabInfo["data"]) ~= "table" then
				TipLog("[QueryClientInfo] parse info error.")
				if fnCallBack ~= nil then
					fnCallBack(false)
				end
				return 
			end
			UpdateSvrPoolCfg(tabInfo)
			if fnCallBack ~= nil then
				fnCallBack(true)
			end
			-- 绑定 未绑定 解绑 是否 status 不一样
			if tabInfo["data"]["status"] ~= 1 then
				if CheckIsBinded() then
					UnBindingClientFromServer()
					--return
				end	
			end
			if tonumber(tabInfo["data"]["balance"]) ~= nil then
				g_Balance = tabInfo["data"]["balance"]
				UpdateUserBalance()
			end
			if tonumber(tabInfo["data"]["rate"]) ~= nil then
				--g_PerSpeed = tabInfo["data"]["rate"]
				g_SvrAverageMiningSpeed = tabInfo["data"]["rate"]
			end
		else
			if fnCallBack ~= nil then
				fnCallBack(false)
			end
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
	if g_WorkClient == nil then
		return nil
	end
	return g_WorkClient.GetCurrentClientWorkState()
end

--获取当前客户端挖矿速度
function GetClientMiningSpeed()
	if g_WorkClient == nil then
		return 0
	end
	return g_WorkClient.GetCurrentMiningSpeed()
end

function GetUIWorkState()
	return g_UIWorkState
end
--是否在工作
function CheckIsWorking()
	if GetUIWorkState() == UI_STATE_STOPPED then
		return false
	else
		return true
	end
end

--是否在准备
function CheckIsPrepare()
	local nUIWorkState = GetUIWorkState()
	if nUIWorkState == UI_STATE_STARTING
		or nUIWorkState == UI_STATE_PREPARE_WORKID 
		or nUIWorkState == UI_STATE_PREPARE_POOL 
		or (nUIWorkState == UI_STATE_CALCULATE and GetClientCurrentState() ~= CLIENT_STATE_CALCULATE) then
		return true
	end
	return false
end

--是否在计算
function CheckIsCalculate()
	if GetUIWorkState() == UI_STATE_CALCULATE and GetClientCurrentState() == CLIENT_STATE_CALCULATE then
		return true
	else
		return false
	end
end

--获取UI状态
function GetWorkClient()
	return g_WorkClient
end

--返回当前挖矿速度的比例系数
function GetSvrAverageMiningSpeed()
	return g_SvrAverageMiningSpeed
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
	local strGUID = GetMachineID()
	if IsRealString(strGUID) then
		strOgriParam = strOgriParam .. "&param1=" .. Helper:UrlEncode(strGUID)
	end	
	local strTarParam = MakeInterfaceMd5(strAPIName, strOgriParam)
	local strReguestUrl =  g_strSeverInterfacePrefix .. strTarParam
	TipLog("[GetUnBindUrl] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function SetMachineNameChangeInfo()
	ReportClientInfoToServer()
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

function SetStateInfoToUser(strInfo)
	local wnd = GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	local objMiningPanel = objMainBodyCtrl:GetChildObjByCtrlName("MiningPanel")
	ChangeMainBodyPanel("MiningPanel")
	objMiningPanel:SetStateInfoToUser(strInfo)
	TipLog("[SetStateInfoToUser] strInfo = " .. tostring(strInfo))
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
				--[[ forlocal
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
--
function UpdateRealTimeIncome(nRealTimeIncome)
	local wnd = GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	objMainBodyCtrl:UpdateRealTimeIncome(g_Balance, nRealTimeIncome)
end
--所有要更新账户余额的地方在这里处理
function UpdateUserBalance()
	--在注册记录一下， 方便卸载时判断余额
	if tonumber(g_Balance) > 0 then
		RegSetValue("HKEY_CURRENT_USER\\Software\\Share4Money\\balance", NumberToFormatMoney(g_Balance))
	end
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
	g_WorkClient.OnUpdateBalance()
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
--1:正在运行,2:不在运行
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
	g_bWorking = false
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
----------------
function HandleOnStart()
	g_UIWorkState = UI_STATE_CALCULATE
	--更新球的显示状态
	UpdateSuspendWndVisible(1)
	WorkingTimerHandle()
	OnWorkStateChange(1)
	StartMiningCountTimer()
end

function HandleOnQuit()
	g_UIWorkState = UI_STATE_STOPPED
	ResetGlobalParam()
	--更新球的显示状态
	UpdateSuspendWndVisible(1)
	OnWorkStateChange(2)
	SendMiningReport(0, true)
	StopMiningCountTimer()
end

function StartClient()
	SetStateInfoToUser(nil)
	local nRet = g_WorkClient.Start()
	if nRet ~= 0 then
		if nRet == 1 then
			SetStateInfoToUser("连接赚宝矿场失败,请重试")
		end	
		return
	end
	HandleOnStart()
	ReportClientInfoToServer()
end

function NotifyStart()
	g_UIWorkState = UI_STATE_STARTING
	UpdateSuspendWndVisible(1)
	OnWorkStateChange(1)
	local function OnQueryClientInfo(bRet)
		if GetUIWorkState() ~= UI_STATE_PREPARE_POOL then
			return 
		end
		if not bRet then
			SetStateInfoToUser("连接服务器失败，重试中...")
			SetOnceTimer(function()
				QueryClientInfo(0, OnQueryClientInfo)
			end, 5*1000)
			return
		end	
		SetStateInfoToUser(nil)
	end
	local function OnGetUserWorkID(bWorkID, strInfo)
		if GetUIWorkState() ~= UI_STATE_PREPARE_WORKID then
			return 
		end
		if not bWorkID then
			SetStateInfoToUser("连接服务器失败，重试中...")
			SetOnceTimer(function()
				GetUserWorkID(OnGetUserWorkID)
			end, 5*1000)
			
			return
		end
		--获取矿池信息
		g_UIWorkState = UI_STATE_PREPARE_POOL
		QueryClientInfo(0, OnQueryClientInfo)
		SetStateInfoToUser(nil)
	end
	g_UIWorkState = UI_STATE_PREPARE_WORKID
	GetUserWorkID(OnGetUserWorkID)
end

function NotifyPause()
	g_WorkClient.Pause()
	HandleOnQuit()
end

function NotifyResume()
	g_WorkClient.Resume()
	HandleOnStart()
end

function NotifyQuit()
	g_WorkClient.Quit()
	HandleOnQuit()
end

function WorkingTimerHandle()
	local interval = 1
	local nReportCalcInterval = 60
	if type(g_ServerConfig) == "table" then
		local tServerInterfaceCfg = g_ServerConfig["tServerInterfaceCfg"]
		if type(tServerInterfaceCfg) == "table" then
			nReportCalcInterval = tServerInterfaceCfg["nReportCalcInterval"] or 60
		end
	end	
	nReportCalcInterval = math.ceil(nReportCalcInterval/interval)
	g_WorkingTimerId = timeMgr:SetTimer(function(Itm, id)
		local nAverageHashRate = g_WorkClient.GetAverageHashRate()
		QueryClientInfo(nAverageHashRate)
	end, nReportCalcInterval*1000)
end

--初始化客户端,根据需要
function InitMiningClient()
	LoadGenOilClient()
	g_WorkClient = XLGetGlobal("Global.GenOilClient")
	g_WorkClient.InitClient()
end

--尝试去连接服务器获取更新信息
function TryToConnectServer(fnCallBack)
	--SetStateInfoToUser("正在连接服务器")
	DownLoadServerConfig(function(nDownServer, strServerPath)
		if nDownServer ~= 0 or not IsRealString(strServerPath) or  not tipUtil:QueryFileExists(tostring(strServerPath)) then
			--[[
			if nDownServer == -2 or nDownServer == -3 then
				SetStateInfoToUser("获取服务器配置失败")
				return
			end
			--]]
			TipLog("[TryToConnectServer] Download server config failed , try reconnect nDownServer="..tostring(nDownServer)..", strServerPath="..tostring(strServerPath))
			--处理)
			fnCallBack(false)
			SetOnceTimer(function()
				TryToConnectServer(fnCallBack)
			end, 60*1000)
			return	
		end
		TipLog("[TryToConnectServer] Download server config success")
		--SetStateInfoToUser(nil)
		OnDownLoadSvrCfgSuccess(strServerPath)
		fnCallBack(true,strServerPath)
	end)
end


RegisterFunctionObject()