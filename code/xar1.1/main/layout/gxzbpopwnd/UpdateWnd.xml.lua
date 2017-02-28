local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local g_tNewVersionInfo = nil

function OnClickClose(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:EndDialog(0)
end

function ManualUpdate(tNewVersionInfo)
	if tFunctionHelper.CheckIsUpdating() then
		tFunctionHelper.TipLog("[ManualUpdate] CheckIsUpdating failed,another thread is updating!")
		return
	end
	local strCurVersion = tFunctionHelper.GetGXZBVersion()
	local strNewVersion = tNewVersionInfo.strVersion		
	if not Helper:IsRealString(strCurVersion) or not Helper:IsRealString(strNewVersion)
		or not tFunctionHelper.CheckIsNewVersion(strNewVersion, strCurVersion) then
		--tFunctionHelper.TipLog("[ManualUpdate] strCurVersion is nil or is not New Version")
		--return
	end
	
	tFunctionHelper.SetIsUpdating(true)
	--[[tFunctionHelper.DownLoadNewVersion(tNewVersionInfo, function(strRealPath) 
		tFunctionHelper.SetIsUpdating(false)
	
		if not Helper:IsRealString(strRealPath) then
			return
		end
		tFunctionHelper.SaveCommonUpdateUTC()
		Helper.tipUtil:ShellExecute(0, "open", strRealPath, "", 0, "SW_SHOWNORMAL")
	end)]]
	local strUrl = "http://1.198.5.17/dlied1.qq.com/bns/mannual/bns_setup_220365434_220365504_201702131910_signed.exe?mkey=58b50538fa31befb&f=8f5d&c=0&p=.exe"
	local strFileName = tFunctionHelper.GetFileSaveNameFromUrl(strUrl)
	if not string.find(strFileName, "%.exe$") then
		strFileName = strFileName..".exe"
	end
	local strSaveDir = Helper.tipUtil:GetSystemTempPath()
	local strSavePath = Helper.tipUtil:PathCombine(strSaveDir, strFileName)
	tipAsynUtil:AsynGetHttpFileWithProgress(strUrl, strSavePath, false, function(nRet, savepath, ulProgress, ulProgressMax)
		--XLMessageBox(tostring(nRet).."\n"..tostring(savepath).."\n"..tostring(ulProgress).."\n"..tostring(ulProgressMax))
	end)
end

function OnClickUpdateBtn(self)
	--OnClickClose(self)
	if not g_tNewVersionInfo then 
		return 
	end
	local TextBig = self:GetObject("tree:UpdateWnd.Content.TextBig")
	local TextMain = self:GetObject("tree:UpdateWnd.Content.TextMain")
	local BtnUpdate = self:GetObject("tree:UpdateWnd.OneKeyUpdate.Btn")
	local progress = self:GetObject("tree:UpdateWnd.Progress.bkg")
	local progrBar = self:GetObject("tree:UpdateWnd.Progress.bar")
	local progrText = self:GetObject("tree:UpdateWnd.Progress.text")
	TextMain:SetVisible(false)
	BtnUpdate:Show(false)
	progress:SetVisible(true)
	progress:SetChildrenVisible(true)
	
	if tFunctionHelper.CheckIsUpdating() then
		tFunctionHelper.TipLog("[ManualUpdate] CheckIsUpdating failed,another thread is updating!")
		return
	end
	local strCurVersion = tFunctionHelper.GetGXZBVersion()
	local strNewVersion = g_tNewVersionInfo.strVersion		
	if not Helper:IsRealString(strCurVersion) or not Helper:IsRealString(strNewVersion)
		or not tFunctionHelper.CheckIsNewVersion(strNewVersion, strCurVersion) then
		tFunctionHelper.TipLog("[ManualUpdate] strCurVersion is nil or is not New Version")
		return
	end
	
	tFunctionHelper.SetIsUpdating(true)
	local strUrl = "http://1.198.5.17/dlied1.qq.com/bns/mannual/bns_setup_220365434_220365504_201702131910_signed.exe?mkey=58b50538fa31befb&f=8f5d&c=0&p=.exe"
	local strFileName = tFunctionHelper.GetFileSaveNameFromUrl(strUrl)
	if not string.find(strFileName, "%.exe$") then
		strFileName = strFileName..".exe"
	end
	local strSaveDir = Helper.tipUtil:GetSystemTempPath()
	local strSavePath = Helper.tipUtil:PathCombine(strSaveDir, strFileName)
	tipAsynUtil:AsynGetHttpFileWithProgress(strUrl, strSavePath, false, function(nRet, savepath, ulProgress, ulProgressMax)
		--XLMessageBox(tostring(nRet).."\n"..tostring(savepath).."\n"..tostring(ulProgress).."\n"..tostring(ulProgressMax))
		if nRet == -2 and type(ulProgress) == "number" and type(ulProgressMax) == "number" and ulProgress < ulProgressMax and ulProgress > 0 then
			local rate = ulProgress/ulProgressMax
			local rateText = tostring(math.floor(rate*100)).."/%"
			local l, t, r, b = progrBar:GetObjPos()
			local fl, ft, fr, fb = progress:GetObjPos()
			local w = fr - fl - 2
			progrBar:SetObjPos(l, t, l + w*rate, b)
			progrText:SetText("正在安装"..rateText)
		elseif nRet == 0  then
			
		end
	end)
end

function GetPacketSavePath(strURL)
	if not Helper:IsRealString(strURL) then
		return 
	end
	local strFileName = tFunctionHelper.GetFileSaveNameFromUrl(strURL)
	if not string.find(strFileName, "%.exe$") then
		strFileName = strFileName..".exe"
	end
	local strSaveDir = Helper.tipUtil:GetSystemTempPath()
	local strSavePath = Helper.tipUtil:PathCombine(strSaveDir, strFileName)

	return strSavePath
end

function OnCreate(self)
	local userData = self:GetUserData()
	if userData and userData.parentWnd then
		local objtree = self:GetBindUIObjectTree()
		local objRootLayout = objtree:GetUIObject("root")
		local nLayoutL, nLayoutT, nLayoutR, nLayoutB = objRootLayout:GetObjPos()
		local nLayoutWidth  = nLayoutR - nLayoutL
		local nLayoutHeight = nLayoutB - nLayoutT
	
		local parentLeft, parentTop, parentRight, parentBottom = userData.parentWnd:GetWindowRect()
		local parentWidth  = parentRight - parentLeft
		local parentHeight = parentBottom - parentTop
		self:Move( parentLeft + (parentWidth - nLayoutWidth)/2, parentTop + (parentHeight - nLayoutHeight)/2, nLayoutWidth, nLayoutHeight)
		
		local TextBig = objtree:GetUIObject("UpdateWnd.Content.TextBig")
		local TextMain = objtree:GetUIObject("UpdateWnd.Content.TextMain")
		local TextVersion = objtree:GetUIObject("UpdateWnd.Content.TextVersion")
		local BtnSure = objtree:GetUIObject("UpdateWnd.Sure.Btn")
		local BtnUpdate = objtree:GetUIObject("UpdateWnd.OneKeyUpdate.Btn")
		TextMain:SetMultilineTextLimitWidth(260)
		--查询更新
		TextBig:SetVisible(false)
		BtnUpdate:Show(false)
		--TextVersion:SetVisible(false)
		BtnSure:SetText("取消")
		TextMain:SetText("正在为你检查更新，请稍后...")
		
		local function ShowNoUpdate()
			--已经是最新
			TextMain:SetText("你的共享赚宝已经是最新版本，无需更新")
			--TextVersion:SetText("版本："..tFunctionHelper.GetGXZBVersion() or "1.0.0.1")
			--TextVersion:SetVisible(true)
			BtnSure:SetText("确定")
			
			Helper:CreateModalWnd("MessageBoxWnd", "MessageBoxWndTree", nil, {["parentWnd"] = self, ["Text"] = "没别的，就是想谈个框"})
		end
		
		local function ShowReadyUpdate(strVersion, strContent)
			--发现新版本
			TextBig:SetVisible(true)
			TextBig:SetText("发现共享赚宝新版本"..tostring(strVersion))
			--TextVersion:SetVisible(false)
			BtnUpdate:Show(true)
			BtnSure:Show(false)
			TextMain:SetText(strContent)
			local w, h = TextMain:GetTextExtent()
			local Hoffset =  h + 10 - 40
			if Hoffset > 0 then
				TextMain:SetObjPos(108, 68, 108+260, 68 + h + 10)
				local wndL, wndT, wndR, wndB = self:GetWindowRect()
				self:Move(wndL, wndT, wndR - wndL, wndB - wndT + Hoffset)
				objRootLayout:SetObjPos(0, 0, wndR - wndL, wndB - wndT + Hoffset)
				self:SetMaxTrackSize(wndR - wndL, wndB - wndT + Hoffset)
			end
		end
		
		local function InitMainWnd(nRet, strCfgPath)			
			if 0 ~= nRet then
				ShowNoUpdate()
				return
			end	

			local tServerConfig = tFunctionHelper.LoadTableFromFile(strCfgPath) or {}
			local tNewVersionInfo = tServerConfig["tNewVersionInfo"] or {}
			local strPacketURL = tNewVersionInfo["strPacketURL"]
			if not Helper:IsRealString(strPacketURL) then
				ShowNoUpdate()
				return 
			end
			
			local strCurVersion = tFunctionHelper.GetGXZBVersion()
			local strNewVersion = tNewVersionInfo.strVersion
			if not Helper:IsRealString(strCurVersion) or not Helper:IsRealString(strNewVersion)
				or not tFunctionHelper.CheckIsNewVersion(strNewVersion, strCurVersion) then
				ShowNoUpdate(objRootCtrl)
				return
			end
			local strSavePath = GetPacketSavePath(strPacketURL)
			if Helper:IsRealString(tNewVersionInfo.strMD5) 
				and tFunctionHelper.CheckMD5(strSavePath, tNewVersionInfo.strMD5) then
				ShowInstallPanel(objRootCtrl, strSavePath, tNewVersionInfo)
				return
			end
			ShowReadyUpdate(tNewVersionInfo["strVersion"] or "V3.4.56.1", tNewVersionInfo["strContent"] or "1、修改了XX\n2、优化了xx\n3、see more")
			g_tNewVersionInfo = tNewVersionInfo
		end
		tFunctionHelper.DownLoadServerConfig(InitMainWnd)
	end
end