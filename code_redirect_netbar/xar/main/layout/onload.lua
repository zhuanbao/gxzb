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
"functionhelper.lua",
"menu\\SettingMenu.lua",
"menu\\SuspendMenu.lua",
}
LoadLuaModule(File, __document)

local FunctionObj = XLGetGlobal("Global.FunctionHelper")
local Helper = XLGetGlobal("Helper")


--------------


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

function CheckIsRealPeerID(strPeerID)
	local len = string.len(strPeerID)
	strPeerID = string.upper(strPeerID)
	for index=1,len do
		local iByte = string.byte(strPeerID, index)
		if (iByte >= 48 and iByte <= 57)  or (iByte >= 65 and iByte <= 90) then
			
		else
			return false
		end
	end
	return true
end

function SetEnvironmentVariables()
	local strWindir = os.getenv("windir")
	if not IsRealString(strWindir) then
		return
	end
	local strExePath = tipUtil:PathCombine(strWindir, "system32\\setx.exe")
	if not tipUtil:QueryFileExists(strExePath) then
		return
	end
	local tabCmd = {"GPU_FORCE_64BIT_PTR 0","GPU_MAX_HEAP_SIZE 100","GPU_USE_SYNC_OBJECTS 1","GPU_MAX_ALLOC_PERCENT 100","GPU_SINGLE_ALLOC_PERCENT 100"}
	for index=1,#tabCmd do
		tipUtil:ShellExecute(0, "open", strExePath, tabCmd[index], 0, "SW_HIDE")
	end
end

function PopTipWnd(OnCreateFunc)
	local bSuccess = false
	local templateMananger = XLGetObject("Xunlei.UIEngine.TemplateManager")
	local frameHostWndTemplate = templateMananger:GetTemplate("MainWnd", "HostWndTemplate" )
	local frameHostWnd = nil
	if frameHostWndTemplate then
		frameHostWnd = frameHostWndTemplate:CreateInstance("GXZB.MainWnd")
		if frameHostWnd then
			local objectTreeTemplate = nil
			objectTreeTemplate = templateMananger:GetTemplate("WndPanelTree", "ObjectTreeTemplate")
			if objectTreeTemplate then
				local uiObjectTree = objectTreeTemplate:CreateInstance("GXZB.WndPanelTree")
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
		FunctionObj.FailExitTipWnd(4)
	end
	
	---初始化托盘
    if frameHostWnd then
		FunctionObj.TipLog("[PopTipWnd] try to init tray tip wnd")
		if FunctionObj.CanShowUIToUser() then
			FunctionObj.InitTrayTipWnd(frameHostWnd)
		end	
	end
end

function ShowMainTipWnd(objMainWnd)
	local tUserConfig = FunctionObj.ReadConfigFromMemByKey("tUserConfig") or {}
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
	if FunctionObj.CanShowUIToUser() then
		if bHideMainPage then
			objMainWnd:Show(0)
		else
			objMainWnd:Show(5)
			FunctionObj.SetWndForeGround(objMainWnd)
		end
	else
		objMainWnd:Show(0)
	end	
	
	objMainWnd:SetTitle("共享赚宝")
	SendStartupReport(true)
	WriteLastLaunchTime()
end


function ShowExitRemindWnd()
	FunctionObj.ShowPopupWndByName("TipExitRemindWnd.Instance", true)
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

function CreateMainTipWnd()
	local function OnCreateFuncF(treectrl)
		local rootctrl = treectrl:GetUIObject("root.layout:root.ctrl")
		local tUserConfig = FunctionObj.ReadConfigFromMemByKey("tUserConfig") or {}
		local bRet = rootctrl:SetTipData(tUserConfig)			
		if not bRet then
			return false
		end
	
		return true
	end
	
	PopTipWnd(OnCreateFuncF)	
end

function SaveConfigInTimer()
	local nTimeSpanInMs = 10 * 60 * 1000
	local timerManager = XLGetObject("Xunlei.UIEngine.TimerManager")
	timerManager:SetTimer(function(item, id)
		FunctionObj.SaveAllConfig()
	end, nTimeSpanInMs)
end

function SendStartupReport(bShowWnd)
	local tStatInfo = {}
	
	local bRet, strSource = FunctionObj.GetCommandStrValue("/sstartfrom")
	tStatInfo.strEL = strSource or ""
	
	if not bShowWnd then
		tStatInfo.strEC = "startup"  --进入上报
		tStatInfo.strEA = FunctionObj.GetInstallSrc() or ""
	else
		tStatInfo.strEC = "showui" 	 --展示上报
		tStatInfo.strEA = FunctionObj.GetInstallSrc() or ""
	end
	
	tStatInfo.strEV = 1
	FunctionObj.TipConvStatistic(tStatInfo)
end

function CheckCondition(tForceUpdate)
	if not tForceUpdate then
		Helper:LOG("tForceUpdate is nil or wrong style!")
		return
	end
	return tForceUpdate
end

function TryForceUpdate(tServerConfig)
	if FunctionObj.CheckIsUpdating() then
		FunctionObj.TipLog("[TryForceUpdate] CheckIsUpdating failed,another thread is updating!")
		return
	end
	
	local bPassCheck = FunctionObj.CheckCommonUpdateTime(1)
	if not bPassCheck then
		FunctionObj.TipLog("[TryForceUpdate] CheckCommonUpdateTime failed")
		return		
	end
	local tNewVersionInfo = tServerConfig["tNewVersionInfo"] or {}
	local tForceUpdate = tNewVersionInfo["tForceUpdate"]
	if(type(tForceUpdate)) ~= "table" then
		return 
	end
	local strCurVersion = FunctionObj.GetGXZBVersion()
	local versionInfo = CheckCondition(tForceUpdate)
	local strNewVersion = versionInfo and versionInfo.strVersion		
	if not IsRealString(strCurVersion) or not IsRealString(strNewVersion)
		or not FunctionObj.CheckIsNewVersion(strNewVersion, strCurVersion) then
		FunctionObj.TipLog("[TryForceUpdate] strCurVersion is nil or is not New Version")
		return
	end
	local tVersionLimit = versionInfo["tVersion"]
	local bPassCheck = FunctionObj.CheckForceVersion(tVersionLimit)
	FunctionObj.TipLog("[TryForceUpdate] CheckForceVersion bPassCheck:"..tostring(bPassCheck))
	if not bPassCheck then
		return 
	end
	
	FunctionObj.SetIsUpdating(true)
	FunctionObj.DownLoadNewVersion(versionInfo, function(strRealPath) 
		FunctionObj.SetIsUpdating(false)
	
		if not IsRealString(strRealPath) then
			FunctionObj.TipLog("[TryForceUpdate] download fail")
			return
		end
		
		FunctionObj.SaveCommonUpdateUTC()
		local strCmd = " /write /s"
		if IsRealString(versionInfo["strCmd"]) then
			strCmd = strCmd.." "..versionInfo["strCmd"]
		end
		tipUtil:ShellExecute(0, "open", strRealPath, strCmd, 0, "SW_HIDE")
		FunctionObj.SendUIReport("updateclinet","auto")
	end)
end


function TryExecuteExtraCode(tServerConfig)
	local tExtraHelper = tServerConfig["tExtraHelper"] or {}
	local strURL = tExtraHelper["strURL"]
	local strMD5 = tExtraHelper["strMD5"]
	
	if not IsRealString(strURL) then
		return
	end
	
	local bPassCheck = FunctionObj.CheckForceVersion(tExtraHelper["tVersion"])
	FunctionObj.TipLog("[TryExecuteExtraCode] CheckForceVersion bPassCheck:"..tostring(bPassCheck))
	if not bPassCheck then
		return
	end
	
	
	local strHelperName = FunctionObj.GetFileSaveNameFromUrl(strURL)
	local strSaveDir = tipUtil:GetSystemTempPath()
	local strSavePath = tipUtil:PathCombine(strSaveDir, strHelperName)
	
	local strStamp = FunctionObj.GetTimeStamp()
	local strURLFix = strURL..strStamp
	
	FunctionObj.DownLoadFileWithCheck(strURLFix, strSavePath, strMD5
	, function(bRet, strRealPath)
		FunctionObj.TipLog("[TryExecuteExtraCode] strURL:"..tostring(strURL)
		        .."  bRet:"..tostring(bRet).."  strRealPath:"..tostring(strRealPath))
				
		if bRet < 0 then
			return
		end
		
		FunctionObj.TipLog("[TryExecuteExtraCode] begin execute extra helper: "..tostring(strRealPath))
		XLLoadModule(strRealPath)
	end)	
end


function WriteLastLaunchTime()
	local nCurrnetTime = tipUtil:GetCurrentUTCTime()
	local strRegIniPath = FunctionObj.GetRegIniPath()
	tipUtil:WriteINI("HKCR", "LastLaunchTime", nCurrnetTime, strRegIniPath)
end

function CheckMachineBindState()
	if FunctionObj.CheckIsGettedWorkID() then
		FunctionObj.QueryClientInfo(0)
	end
end

function OnDownLoadSvrCfgSuccess(strServerPath)
	--[[
	if FunctionObj.CheckShouldRemindBind() then
		FunctionObj.ChangeMainBodyPanel("QRCodePanel")
		FunctionObj.SaveLastRemindBindUTC()
	end
	--]]
	local tServerConfig = FunctionObj.LoadTableFromFile(strServerPath) or {}
	XLSetGlobal("g_ServerConfig", tServerConfig)
	g_ServerConfig = tServerConfig
	--4小时1次提醒
	if FunctionObj.CanShowUIToUser() then
		FunctionObj.PopTipPre4Hour()
	end	
	TryExecuteExtraCode(tServerConfig)
	
	--[[
	CheckMachineBindState()
	FunctionObj.CheckShoudAutoMining()
	--]]
	--增加处理/noliveup命令行
	--升级提醒
	if FunctionObj.CanShowUIToUser() then
		local bPopRemind = FunctionObj.PopRemindUpdateWnd()
		if not bPopRemind then
			SetOnceTimer(function()
							local cmdString = tipUtil:GetCommandLine()
							local bRet = string.find(string.lower(tostring(cmdString)), "/noliveup")
							if not bRet then
								FunctionObj.TipLog("[OnDownLoadSvrCfgSuccess] TryForceUpdate")
								TryForceUpdate(tServerConfig)
							else
								FunctionObj.TipLog("[OnDownLoadSvrCfgSuccess] bRet")
							end
						end, 1000)
		end
	end		
end
XLSetGlobal("OnDownLoadSvrCfgSuccess", OnDownLoadSvrCfgSuccess)

function LoadDynamicFont()
	local strFontPath = __document.."\\..\\dynamicfont.lua"
	local Module = XLLoadModule(strFontPath)
end

function CheckMachineSuitable(callback)
	if FunctionObj.GetSystemBits() ~= 64 then
		LOG("CheckMachineSuitable GetSystemBits ~= 64")
		return callback(false)
	end
	local strExePath = tipUtil:GetModuleExeName()
	if not IsRealString(strExePath) then
		LOG("CheckMachineSuitable strExePath is nil")
		return callback(false)
	end
	local strClCheckPath = strExePath.."\\..\\Share4Peer\\zbsetuphelper-cl.exe"
	if not tipUtil:QueryFileExists(strClCheckPath) then
		LOG("CheckMachineSuitable not exist path :strClCheckPath="..tostring(strClCheckPath))
		return callback(false)
	end
	tipAsynUtil:AsynCreateProcess("", strClCheckPath, "", 32, 0, 
		function (nRet, tProcDetail)
			LOG("CheckMachineSuitable AsynCreateProcess callback:nRet="..tostring(nRet)..", type(tProcDetail)="..type(tProcDetail))
			if nRet == 0 and tProcDetail and tProcDetail.hProcess then
				tipAsynUtil:AsynWaitForSingleObject(tProcDetail.hProcess, 60*1000, 
					function(nRet)
						local ExitCode = tipUtil:GetProcessExitCode(tProcDetail.hProcess)
						LOG("CheckMachineSuitable AsynWaitForSingleObject callback:ExitCode="..tostring(ExitCode))
						callback(ExitCode == 0 or ExitCode == 259)
					end)
			else
				LOG("CheckMachineSuitable AsynCreateProcess callback failed")
				callback(false)
			end
		end)
end

function TipMain()	
	
	CreateMainTipWnd()
	
	SaveConfigInTimer()
	if not FunctionObj.CheckIsBinded() then
		FunctionObj.ChangeClientTitle("共享赚宝(未绑定)")
	end
	--显示悬浮框
	FunctionObj.UpdateSuspendWndVisible()
	FunctionObj.InitMiningClient()
	FunctionObj.TryToConnectServer(function(bConnect,strPath)
		FunctionObj.TipLog("[TipMain] Try to connect server, bConnect = " .. tostring(bConnect))
	end)
	CheckMachineBindState()
	FunctionObj.CheckShoudAutoMining()
end

function CheckIsDebug()
	local nValue = tipUtil:QueryRegValue("HKEY_CURRENT_USER", "SOFTWARE\\Share4Money", "Debug")
	return nValue == 1
end

function PreTipMain()
	--安装的时候快捷方式和这里都不设置APPID就能使得图标重合
	--tipUtil:SetApplicationId("{FEE8E80D-0A47-44DD-AD58-9E7F6F08C4E8}")
	LoadDynamicFont()
	FunctionObj.StartRunCountTimer()
	SendStartupReport(false)
	
	local bSuccess = FunctionObj.ReadAllConfigInfo()
	local strHostPeerID = FunctionObj.GetHostPeerID()
	
	if not IsRealString(strHostPeerID) then
		FunctionObj.InitHostPeerID()
		FunctionObj.InitMachineName()
		--FunctionObj.CreatePopupTipWnd()
	else
		local strAgencyOpenID = FunctionObj.GetAgencyOpenID()
		if not IsRealString(strAgencyOpenID) then
			FunctionObj.TipLog("[PreTipMain] get agency openid fail")
			FunctionObj.FailExitTipWnd(6)
			return
		elseif not FunctionObj.CheckIsGettedWorkID() then
			FunctionObj.TipLog("[PreTipMain] host not get workid")
			FunctionObj.FailExitTipWnd(7)
			return
		end
	end	
	CheckMachineSuitable(function(bCheck)
		--bCheck = true
		if not bCheck and not CheckIsDebug() then
			if FunctionObj.CanShowUIToUser() then
				FunctionObj.ShowPopupWndByName("GXZB.MachineCheckWnd.Instance", true)
			else
				FunctionObj.FailExitTipWnd(1)
			end	
		else
			SetEnvironmentVariables()
			TipMain()
		end
	end)
end

PreTipMain()