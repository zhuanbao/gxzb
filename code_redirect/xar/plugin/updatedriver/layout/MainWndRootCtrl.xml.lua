local tFunctionHelper = XLGetGlobal("FunctionHelper")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local tipUtil = XLGetObject("API.Util")
local objFactory = XLGetObject("APIListen.Factory")
local hostWndManager = XLGetObject("Xunlei.UIEngine.HostWndManager")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")

local g_objListen = objFactory:CreateInstance()
local g_strUpdateDriverVer = nil
local g_strDriverLink = nil
local g_nFileSize = 0
local g_OwnerCtrl = nil

local g_nState = 0
local g_strPackagePath = nil

local g_hInstProcPID = nil
local g_hSetupProcPID = nil

--[[
	1:下载中
	2:下载完成
	3:解压中
	4:找到安装进程
	5:注入成功
	6:拦截重启成功
	7:安装进程退出
--]]
function IsRealString(str)
	return type(str) == "string" and str ~= ""
end

function SetCloseBtnEnable(bEnable)
	local btnClose = g_OwnerCtrl:GetControlObject("RootCtrl.Title.CloseBtn")
	btnClose:Enable(bEnable)
end

function SetIgnoreMark()
	tFunctionHelper.RegSetValue("HKEY_CURRENT_USER\\Software\\Share4Money\\RecommendDriver\\Ignore", 1)
end

function GetHookDllPath()
	local strHookName = "zbmonreboot.dll"
	local strDir = tFunctionHelper.GetModuleDir()
	local strDllPath = tipUtil:PathCombine(strDir, strHookName)
	return strDllPath
end

--http://cn.download.nvidia.com/Windows/390.77/390.77-desktop-win10-32bit-international-whql.exe
function FormatDriverUrl(strDriverVer)
	--local strPreFix = "http://cn.download.nvidia.com/"
	local strSystem = "Windows"
	local iMajor,iMinor = tipUtil:NewGetOSVersion()
	local strWinVer = nil
	if iMajor == 6 and (iMinor == 1 or iMinor == 2 or iMinor == 3) then
		strWinVer = "win8-win7"
	elseif iMajor == 10 then
		strWinVer = "win10"
	else
		return
	end
	local strSystemBits = nil
	local iBits = tFunctionHelper.GetSystemBits()
	if iBits == 64 then
		strSystemBits = "64bit"
	elseif iBits == 32 then
		strSystemBits = "32bit"
	else
		return
	end
	g_strDriverLink = string.format("http://cn.download.nvidia.com/%s/%s/%s-desktop-%s-%s-international-whql.exe", strSystem, strDriverVer, strDriverVer, strWinVer, strSystemBits)
	return
end

function AnsyKillInstProc()
	if g_hInstProcPID then
		tipAsynUtil:AsynKillProcess(g_hInstProcPID, 1000, function(nErrCode)
			tFunctionHelper.TipLog("[AnsyKillInstProc] g_hInstProcPID: " .. tostring(g_hInstProcPID) .. ", nErrCode: " .. tostring(nErrCode))
			g_hInstProcPID = nil
		end)
	end
	if g_hSetupProcPID then
		tipAsynUtil:AsynKillProcess(g_hSetupProcPID, 1000, function(nErrCode)
			tFunctionHelper.TipLog("[AnsyKillInstProc] g_hSetupProcPID: " .. tostring(g_hSetupProcPID) .. ", nErrCode: " .. tostring(nErrCode))
			g_hSetupProcPID = nil
		end)
	end
end

function OnMouseEnterTitleBtn(self)
	local strID = self:GetID()
	local ObjImg = self:GetObject(strID..".HoverImg")
	if ObjImg then
		ObjImg:SetVisible(true)
	end
end

function OnMouseLeaveTitleBtn(self)
	local strID = self:GetID()
	local ObjImg = self:GetObject(strID..".HoverImg")
	if ObjImg then
		ObjImg:SetVisible(false)
	end
end

function OnClickMinBtn(self)
	local objTree = self:GetOwner()
	if nil == objTree then
		return
	end
	
	local objHostWnd = objTree:GetBindHostWnd()
	if nil == objHostWnd then
		return
	end
	
	objHostWnd:Min()	
end

function OnClickCloseBtn(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:Show(0)
	hostWndManager:RemoveHostWnd("SharePlugin.UpdateDriverMainWnd")
	AnsyKillInstProc()
	local tStatInfo = {}
	tStatInfo.fu5 = "exit"
	tStatInfo.fu6 = "closebtn"
	tStatInfo.Exit = true
	StatisticClient:SendEventReport(tStatInfo)
end

function OnClickHomePage(self)
	local url = "http://www.nvidia.cn/Download/index.aspx?lang=cn"
	tipUtil:ShellExecute(0, "open", url, 0, 0, "SW_SHOWNORMAL")
	local tStatInfo = {}
	tStatInfo.fu5 = "openhomepage"
	tStatInfo.fu6 = "nvidia"
	StatisticClient:SendClickReport(tStatInfo)
end

function OnClickHandInstall(self)
	local strExe = "explorer"
	local strParam = "/select, " .. tostring(g_strPackagePath)
	tipUtil:ShellExecute(0, "open", strExe, strParam, 0, "SW_SHOWDEFAULT")
	local tStatInfo = {}
	tStatInfo.fu5 = "handleinstall"
	tStatInfo.fu6 = "nvidia"
	StatisticClient:SendClickReport(tStatInfo)
end

function OnClickReStart(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:Show(0)
	hostWndManager:RemoveHostWnd("SharePlugin.UpdateDriverMainWnd")
	AnsyKillInstProc()
	local tStatInfo = {}
	tStatInfo.fu5 = "exit"
	tStatInfo.fu6 = "restart"
	tStatInfo.Exit = true
	StatisticClient:SendEventReport(tStatInfo)
	tipUtil:RestartSystem(0, false, true);
end

function OnClickLater(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:Show(0)
	hostWndManager:RemoveHostWnd("SharePlugin.UpdateDriverMainWnd")
	AnsyKillInstProc()
	local tStatInfo = {}
	tStatInfo.fu5 = "exit"
	tStatInfo.fu6 = "later"
	tStatInfo.Exit = true
	StatisticClient:SendEventReport(tStatInfo)
end

function OnInitControl(self)
	g_OwnerCtrl = self
end

function InitCtrl(self)
	local bRet, strDriverVer = tFunctionHelper.GetCommandStrValue("/driverver")
	if not bRet or not IsRealString(strDriverVer) then
		return false
	end
	g_strUpdateDriverVer = strDriverVer
	FormatDriverUrl(strDriverVer)
	if not IsRealString(g_strDriverLink) then
		return false
	end
	local ObjRecommend = self:GetControlObject("RootCtrl.Content.Recommend")
	ObjRecommend:SetText("正在升级显卡驱动至官方推荐版本"..strDriverVer.."请稍后...")
	--CreateListener(self)
	return true
end

local g_fLastPercent = 0
function UpdateProgress(fPercent)
	local ObjProgress = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress")
	local ObjBar = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress.Bar")
	local ObjText = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress.Text")
	local nFLeft, nFTop, nFRight, nFButtom = ObjProgress:GetObjPos()
	local nMaxLen = nFRight - nFLeft
	
	local nCLeft, nCTop, nCRight, nCButtom = ObjBar:GetObjPos()
	local nCurProgress = nCRight - nCLeft
	
	local nNewProgress = math.floor(nMaxLen*fPercent)
	if nNewProgress > nCurProgress then
		ObjBar:SetObjPos(nCLeft, nCTop, nCLeft+nNewProgress, nCButtom)
	end
end

function UpdateDownProgress(fPercent)
	if g_nState ~= 1 then
		return 
	end
	if fPercent > 1 then
		fPercent = 1
	end
	if fPercent < g_fLastPercent then
		return 
	end
	g_fLastPercent = fPercent
	UpdateProgress(fPercent)
	local ObjText = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress.Text")
	local strPercent = string.format("%.2f",fPercent*100)
	if fPercent < 1 then
		ObjText:SetText("正在下载" .. strPercent .. "%")
	else
		ObjText:SetText("下载完成，正在校验")
	end
end

function OnDownLoadError(nCode)
	tFunctionHelper.TipLog("[OnDownLoadError] nCode: " .. tostring(nCode))
	if nCode ~= 1 then
		return 
	end
	local ObjProgress = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress")
	--ObjProgress:SetVisible(false)
	local ObjBar = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress.Bar")
	--ObjBar:SetVisible(false)
	local ObjText = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress.Text")
	ObjText:SetVisible(false)
	
	local ObjDownFail = g_OwnerCtrl:GetControlObject("RootCtrl.Content.DownFail")
	ObjDownFail:SetVisible(true)
	
	local ObjHomePage = g_OwnerCtrl:GetControlObject("RRootCtrl.Content.Content.DownFail.HomePage")
	ObjDownFail:SetVisible(true)

end

function OnDownLoadSuccess(strPath)
	g_nState = 2
	local ObjText = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress.Text")
	tFunctionHelper.TipLog("[OnDownLoadSuccess] strPath: " .. tostring(strPath))
	ObjText:SetText("安装包校验成功")
	g_strPackagePath = strPath
	
	local tStatInfo = {}
	tStatInfo.fu5 = "download"
	tStatInfo.fu6 = "success"
	StatisticClient:SendEventReport(tStatInfo)
	
	RunInStallExe(strPath)
end

function ShowInstallFail()
	SetCloseBtnEnable(true)
	local ObjText = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress.Text")
	ObjText:SetVisible(false)
	
	local ObjInstallFail = g_OwnerCtrl:GetControlObject("RootCtrl.Content.InstallFail")
	ObjInstallFail:SetVisible(true)
	local ObjHandInstall = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Content.InstallFail.HandInstall")
	ObjHandInstall:SetVisible(true)
end

function RunInStallExe(strPath)
	g_nState = 3
	local strCmdLine = strPath .. " " .. "-s"
	tipAsynUtil:AsynCreateProcess("", strCmdLine, strWorkingDir, 32, 1, 
		function (nRet, tProcDetail)
			if nRet ~= 0 then
				ShowInstallFail()
				return
			end
			DoUnZipInStallExe(tProcDetail)
		end)
end

function UpdateUnZipProgress(fPercent)
	if g_nState ~= 3 then
		return 
	end
	if fPercent > 1 then
		fPercent = 1
	end
	if fPercent <= g_fLastPercent then
		return 
	end
	g_fLastPercent = fPercent
	UpdateProgress(fPercent)
	local ObjText = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress.Text")
	local strPercent = string.format("%.0f",fPercent*100)
	if fPercent < 1 then
		ObjText:SetText("正在解压" .. strPercent .. "%")
	else
		ObjText:SetText("解压完成，准备安装")
	end
end

function CheckIsUnZipFinished(tProcDetail)
	local nPPID = tProcDetail.dwProcessId
	local tabProcess = tipUtil:GetProcessSnapshot()
	--tFunctionHelper.DumpObj(tabProcess, "tabProcess")
	for idx = 1, #tabProcess do
		local tabItem = tabProcess[idx]
		if tabItem["ExeName"] == "setup.exe" and tabItem["PPID"] == nPPID then
			return true, tabItem
		end
	end
	return false
end

function DoUnZipInStallExe(tProcDetail)
	SetCloseBtnEnable(false)
	g_hInstProcPID = tProcDetail.dwProcessId
	
	g_fLastPercent = 0
	local ObjBar = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress.Bar")
	ObjBar:SetObjPos(0, 0, 20, 16)
	local ObjText = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress.Text")
	ObjText:SetText("正在解压...")
	local nCnt = 0
	timeMgr:SetTimer(function(Itm, id)
		nCnt = nCnt + 1
		local bCheck, tabProcInfo =  CheckIsUnZipFinished(tProcDetail)
		if bCheck then
			g_nState = 4
			Itm:KillTimer(id)
			UpdateUnZipProgress(1)
			DoInStallExe(tProcDetail.hProcess, tabProcInfo)
		elseif nCnt <= 600 then
			local fPercent = nCnt/100
			if fPercent >= 1 then
				fPercent = 0.99
			end
			UpdateUnZipProgress(fPercent)
		else
			Itm:KillTimer(id)
			ShowInstallFail()
		end
	end, 800)
end

function UpdateInStallProgress(fPercent)
	if g_nState ~= 5 then
		return 
	end
	if fPercent > 1 then
		fPercent = 1
	end
	if fPercent <= g_fLastPercent then
		return 
	end
	g_fLastPercent = fPercent
	UpdateProgress(fPercent)
	local ObjText = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress.Text")
	local strPercent = string.format("%.0f",fPercent*100)
	if fPercent < 1 then
		ObjText:SetText("正在安装" .. strPercent .. "%")
	else
		ObjText:SetText("安装成功")
	end
end

function CheckIsInstallSuccess()
	local tabDisplayCard = tipUtil:GetAllDisplayCardInfo()
	for index=1,#tabDisplayCard do
		local tabItem = tabDisplayCard[index]
		if tabItem["vendor"] == 2 and tabItem["version"] == g_strUpdateDriverVer then
			return true
		end
	end
	return false
end

function DoInStallExe(hParentProc, tabProcInfo)
	g_hSetupProcPID = tabProcInfo["PID"]
	g_fLastPercent = 0
	local ObjBar = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress.Bar")
	ObjBar:SetObjPos(0, 0, 20, 16)
	local ObjText = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress.Text")
	ObjText:SetText("正在安装...")
	
	local strDllPath = GetHookDllPath()
	local bHook = tipUtil:InjectDllToProc(tabProcInfo["PID"], strDllPath)
	g_nState = 5
	local _InstallTimerID = nil
	tipAsynUtil:AsynWaitForSingleObject(hParentProc, nil, function(nRet)
		if _InstallTimerID then
			timeMgr:KillTimer(_InstallTimerID)
			_InstallTimerID = nil
		end	
		if nRet == 0 then
			if not CheckIsInstallSuccess() then
				ShowInstallFail()
				return
			end
			UpdateInStallProgress(1)
			DoInstallSuccess()	
		end
	end)
	
	local nCnt = 0
	_InstallTimerID = timeMgr:SetTimer(function(Itm, id)
		nCnt = nCnt + 1
		if nCnt > 300 then -- 超过1800秒 就当失败
			Itm:KillTimer(id)
			ShowInstallFail()
			_InstallTimerID	= nil		
		else
			fPercent = nCnt/100 
			if fPercent >= 1 then
				fPercent = 0.99
			end
			UpdateInStallProgress(fPercent)
		end		
	end, 6*1000)
end

function DoInstallSuccess()
	g_hInstProcPID = nil
	g_hSetupProcPID = nil
	local ObjProgress = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress")
	ObjProgress:SetVisible(false)
	local ObjBar = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress.Bar")
	ObjBar:SetVisible(false)
	local ObjText = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress.Text")
	ObjText:SetVisible(false)
	
	local ObjBtnReStart = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Btn.ReStart")
	ObjBtnReStart:Show(true)
	local ObjBtnReLater = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Btn.Later")
	ObjBtnReLater:Show(true)
	
	local ObjRecommend = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Recommend")
	ObjRecommend:SetText("已成功升级显卡驱动程序！需要重启电脑后才能生效")
	SetCloseBtnEnable(true)
	SetIgnoreMark()
	local tStatInfo = {}
	tStatInfo.fu5 = "installfinish"
	tStatInfo.fu6 = "success"
	StatisticClient:SendEventReport(tStatInfo)
end

function OnListenerFunc(strKey, ...)
	tFunctionHelper.TipLog("[OnListenerFunc] strKey: " .. tostring(strKey))
	local tParam = {...}	
	if tostring(strKey) == "OnCommandLine" then
	elseif tostring(strKey) == "OnP2SDownloadProgress" then
		tFunctionHelper.TipLog("[OnP2SDownloadProgress] strUrl["..tostring(tParam[1]).."], "
								.. "dwFileSize[" .. tostring(tParam[2]).."], "
								.. "fPercent[" .. tostring(tParam[3]).."], "
								.. "fSpeed[" .. tostring(tParam[4]).."]"
								)
		if g_nFileSize == 0 then
			g_nFileSize = tParam[2]
		end
		UpdateDownProgress(tParam[3])
	elseif tostring(strKey) == "OnP2SDownloadError" then
		OnDownLoadError(tParam[2])
	elseif tostring(strKey) == "OnP2SDownloadFinish" then
		OnDownLoadSuccess(tParam[2])
	end		
	return 
end

function Start(self)
	g_objListen:AttachListener(OnListenerFunc)
	local p2sUtil = XLGetObject("P2S.Util")
	g_nState = 1
	local ObjProgress = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress")
	local ObjBar = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress.Bar")
	local ObjText = g_OwnerCtrl:GetControlObject("RootCtrl.Content.Progress.Text")
	if not ObjProgress:GetVisible() then
		ObjProgress:SetVisible(true)
	end
	if not ObjBar:GetVisible() then
		ObjBar:SetVisible(true)
	end
	if not ObjText:GetVisible() then
		ObjText:SetVisible(true)
	end
	local strTmpDir = tipUtil:GetSystemTempPath()
	local strFileName = tFunctionHelper.GetFileSaveNameFromUrl(g_strDriverLink)
	local strDownLoadDir = tipUtil:PathCombine(strTmpDir, "nvidiadriver")
	if not tipUtil:QueryFileExists(strDownLoadDir) then
		tipUtil:CreateDir(strDownLoadDir)
	end
	local strPackagePath = tipUtil:PathCombine(strDownLoadDir, strFileName)
	
	if tipUtil:QueryFileExists(strPackagePath) and IsRealString(tipUtil:GetFileVersionString(strPackagePath)) then
		UpdateDownProgress(1)
		OnDownLoadSuccess(strPackagePath)
	else
		p2sUtil:DownloadFile(g_strDriverLink, strDownLoadDir)
	end	
end












