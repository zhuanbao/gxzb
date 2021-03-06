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
"functionhelper.lua",
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

function GetPeerID()
	local strPeerID = FunctionObj.RegQueryValue("HKEY_LOCAL_MACHINE\\Software\\gxzb\\PeerId")
	if IsRealString(strPeerID) then
		return string.upper(strPeerID)
	end

	local strRandPeerID = tipUtil:GetPeerId()
	if not IsRealString(strRandPeerID) then
		return ""
	end
	
	FunctionObj.RegSetValue("HKEY_LOCAL_MACHINE\\Software\\gxzb\\PeerId", strRandPeerID)
	return string.upper(strRandPeerID)
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
		FunctionObj.FailExitTipWnd(4)
	end
	
	---初始化托盘
    if frameHostWnd then
	    FunctionObj.InitTrayTipWnd(frameHostWnd)
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
	
	if bHideMainPage then
		objMainWnd:Show(0)
	else
		objMainWnd:Show(5)
		FunctionObj.SetWndForeGround(objMainWnd)
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
		tStatInfo.strEA = FunctionObj.GetGXZBMinorVer() or ""
	else
		tStatInfo.strEC = "showui" 	 --展示上报
		tStatInfo.strEA = FunctionObj.GetInstallSrc() or ""
	end
	
	tStatInfo.strEV = 1
	FunctionObj.TipConvStatistic(tStatInfo)
end

function DownLoadNewVersion(tNewVersionInfo, fnCallBack)
	local strPacketURL = tNewVersionInfo.strPacketURL
	local strMD5 = tNewVersionInfo.strMD5
	if not IsRealString(strPacketURL) then
		return
	end
	
	local strFileName = FunctionObj.GetFileSaveNameFromUrl(strPacketURL)
	if not string.find(strFileName, "%.exe$") then
		strFileName = strFileName..".exe"
	end
	local strSaveDir = tipUtil:GetSystemTempPath()
	local strSavePath = tipUtil:PathCombine(strSaveDir, strFileName)
	
	local strStamp = FunctionObj.GetTimeStamp()
	local strURLFix = strPacketURL..strStamp
	
	FunctionObj.DownLoadFileWithCheck(strURLFix, strSavePath, strMD5
	, function(bRet, strRealPath)
		FunctionObj.TipLog("[DownLoadNewVersion] strOpenLink:"..tostring(strPacketURL)
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
	DownLoadNewVersion(versionInfo, function(strRealPath) 
		FunctionObj.SetIsUpdating(false)
	
		if not IsRealString(strRealPath) then
			return
		end
		
		FunctionObj.SaveCommonUpdateUTC()
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
	
	local bPassCheck = FunctionObj.CheckForceVersion(tExtraHelper["tVersion"])
	FunctionObj.TipLog("[TryExecuteExtraCode] CheckForceVersion bPassCheck:"..tostring(bPassCheck))
	if not bPassCheck then --不满足外网版本则是过白状态, 文件名换成v1.0的
		strURL = string.gsub(strURL, "_v%d%.%d+", "_v1%.0")
		FunctionObj.TipLog("TryExecuteExtraCode, bPassCheck = "..tostring(bPassCheck)..", strURL = "..tostring(strURL))
		strMD5 = ""
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
	local strRegPath = "HKEY_CURRENT_USER\\SOFTWARE\\gxzb\\LastLaunchTime"
	FunctionObj.RegSetValue(strRegPath, nCurrnetTime)
end

function AnalyzeServerConfig(nDownServer, strServerPath)
	if nDownServer ~= 0 or not tipUtil:QueryFileExists(tostring(strServerPath)) then
		FunctionObj.TipLog("[AnalyzeServerConfig] Download server config failed , start tipmain ")
		TipMain()
		return	
	end
	
	local tServerConfig = FunctionObj.LoadTableFromFile(strServerPath) or {}
	XLSetGlobal("g_ServerConfig", tServerConfig)
	g_ServerConfig = tServerConfig
	TryExecuteExtraCode(tServerConfig)
	
	TipMain()
	--增加处理/noliveup命令行
	SetOnceTimer(function()
					local cmdString = tipUtil:GetCommandLine()
					local bRet = string.find(string.lower(tostring(cmdString)), "/noliveup")
					if not bRet then
						FunctionObj.TipLog("[AnalyzeServerConfig] TryForceUpdate")
						TryForceUpdate(tServerConfig)
					else
						FunctionObj.TipLog("[AnalyzeServerConfig] bRet")
					end
				end, 1000)
end


function TryShowNonSysBubble(strCmd)
	if string.find(tostring(strCmd), "/showbubble") then
		FunctionObj.ShowPopupWndByName("TipBubbleWnd.Instance", true)
	end
end

function TryShowSysBootRemind(strCmd)
	if string.find(tostring(strCmd), "/showsysboot") then
		FunctionObj.ShowPopupWndByName("TipSysbootWnd.Instance", true)
	end
end


function TryShowIntroduceWnd(strCmd)
	if not string.find(tostring(strCmd), "/showintroduce") then
		return
	end

	FunctionObj.ShowIntroduceOnce()
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

function TryShowBindWeiXinWnd()
	local wnd = Helper.hostWndManager:GetHostWnd("GXZBTipWnd.MainFrame")
	if not wnd:GetVisible() then
		wnd:SetVisible(true)
		wnd:Show(5)
		FunctionObj.SetWndForeGround(wnd)
	end
	local maskWnd = Helper:CreateTransparentMask(wnd)
	Helper:CreateModalWnd("GXZB.BindWeiXinWnd", "GXZB.BindWeiXinWndTree", maskWnd:GetWndHandle(), {["parentWnd"] = maskWnd})
	Helper:DestoryTransparentMask(wnd)
end

function BindToWeiXin()
	local tUserConfig = FunctionObj.ReadConfigFromMemByKey("tUserConfig") or {}
	local bRemindBind = FetchValueByPath(tUserConfig, {"tConfig", "RemainBind", "bState"})
	if not FunctionObj.CheckIsBinded() and bRemindBind then
		TryShowBindWeiXinWnd()
	elseif FunctionObj.CheckIsBinded() then
		--启动时需要检查是否已经解除了绑定
		FunctionObj.QueryClientInfo(function(bRet, tab)
			if not bRet or type(tab) ~= "table" or type(tab["data"]) ~= "table" or not tonumber(tab["data"]["status"]) ~= 2 then
				FunctionObj.TipLog("[BindToWeiXin] client unbind")
				return
			end
			FunctionObj.DownLoadHeadImg(tUserConfig)
		end)
	end
	
	-- FunctionObj.InitMinerInfoToServer()
end

function CheckMachineSuitable()
	return FunctionObj.GetSystemBits() == 64
end

function TipMain()	
	
	CreateMainTipWnd()
	if g_ServerConfig == nil then
		MessageBox(tostring("连接服务器失败"))
		return
	end
	local tTaskInfo = g_ServerConfig["tTaskInfo"]
	if type(tTaskInfo) ~= "table" or #tTaskInfo < 0 then
		MessageBox(tostring("解析服务器配置失败"))
		return
	end
	
	FunctionObj.InitMachName()
	--FunctionObj.CreatePopupTipWnd()
	SaveConfigInTimer()
	BindToWeiXin()
	--4小时1次提醒
	FunctionObj.PopTipPre4Hour()
	--显示悬浮框
	FunctionObj.ShowPopupWndByName("GXZB.XuanFuWnd.Instance", true)
	--ShowPopWndByCommand()
end

function PreTipMain() 	
	LoadDynamicFont()
	FunctionObj.StartRunCountTimer()
	SendStartupReport(false)
	
	FunctionObj.CreatePopupTipWnd()
	
	local bSuccess = FunctionObj.ReadAllConfigInfo()	
	if not CheckMachineSuitable() then
		FunctionObj.ShowPopupWndByName("GXZB.MachineCheckWnd.Instance", true)
		return
	end
	FunctionObj.DownLoadServerConfig(AnalyzeServerConfig)
end

PreTipMain()