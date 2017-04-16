local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local g_tNewVersionInfo = nil
--0未更新， 1正在更新， 2弹出对话框， 3弹出对话框时已下载完成
local g_UpdateState = 0
--是否被取消
local g_UpdateCancel = false
--是否可以重新开1个下载线程
local g_CanRetry = false

function OnClickClose(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	if g_UpdateState == 1 then
		g_UpdateState = 2
		local nRet = Helper:CreateModalWnd("MessageBoxWnd", "MessageBoxWndTree", nil, 
			{
				["parentWnd"] = objHostWnd, 
				["Text"] = "您正在升级，是否退出？",
				["ChangeUI"] = function(objWnd)
					local objtree = objWnd:GetBindUIObjectTree()
					local root = objtree:GetUIObject("PanelCaption")
					if root then
						root:SetObjPos(73, 38, 73+373, 38+221)
					end
					local MainText = objtree:GetUIObject("MainText")
					MainText:SetObjPos(100, 62, 100+300, 62+20)
					local btnyes = objtree:GetUIObject("yes")
					local btnno = objtree:GetUIObject("no")
					btnyes:SetText("确定")
					btnno:SetText("取消")
				end,
			}
		)
		--点了取消或关闭
		if nRet == 1 then
			if g_UpdateState == 3 then
				OnClickUpdateBtn(self:GetObject("tree:UpdateWnd.OneKeyUpdate.Btn"))
			else
				g_UpdateState = 1
			end
			return
		--点了退出
		else
			g_UpdateState = 0
			g_UpdateCancel = true
		end
	end
	if type(objHostWnd.EndDialog) == "function" then
		objHostWnd:EndDialog(0)
	else
		objHostWnd:Show(0)
	end
end

function CheckPacketMD5(strPacketPath)
	local strServerMD5 = g_tNewVersionInfo["strMD5"]
	return tFunctionHelper.CheckMD5(strPacketPath, strServerMD5)
end


local progress, progrBar, progrText
local needSetPos = true
function OnClickUpdateBtn(self)
	if not g_tNewVersionInfo then 
		return 
	end
	local TextBig = self:GetObject("tree:UpdateWnd.Content.TextBig")
	local TextVersion = self:GetObject("tree:UpdateWnd.Content.TextVersion")
	local BtnUpdate = self:GetObject("tree:UpdateWnd.OneKeyUpdate.Btn")
	progress = self:GetObject("tree:UpdateWnd.Progress.bkg")
	progrBar = self:GetObject("tree:UpdateWnd.Progress.bar")
	progrText = self:GetObject("tree:UpdateWnd.Progress.text")
	TextVersion:SetVisible(false)
	BtnUpdate:Show(false)
	progress:SetVisible(true)
	progress:SetChildrenVisible(true)
	progrBar:SetVisible(true)
	progrText:SetVisible(true)
	TextBig:SetObjPos(144, 100, 159+260, 107+25)
	local bigicon = self:GetObject("tree:UpdateWnd.Icon")
	bigicon:SetObjPos(50, 70, 50+80, 70+80)
	if needSetPos then
		needSetPos = false
		local wnd = self:GetOwner():GetBindHostWnd()
		local wndL, wndT, wndR, wndB = wnd:GetWindowRect()
		wnd:Move(wndL+70, wndT, 450, 298)
		local root = self:GetOwner():GetUIObject("root")
		root:SetObjPos(0, 0, 450, 298)
		wnd:SetMaxTrackSize(450, 298)
	end
	--正在更新
	g_UpdateState = 1
	if not g_CanRetry and g_UpdateCancel then
		g_UpdateCancel = false
		return
	end
	local strCurVersion = tFunctionHelper.GetGXZBVersion()
	local strNewVersion = g_tNewVersionInfo.strVersion		
	if not Helper:IsRealString(strCurVersion) or not Helper:IsRealString(strNewVersion)
		or not tFunctionHelper.CheckIsNewVersion(strNewVersion, strCurVersion) then
		tFunctionHelper.TipLog("[OnClickUpdateBtn] strCurVersion is nil or is not New Version")
		return
	end
	local strUrl = g_tNewVersionInfo["strPacketURL"]
	local strFileName = tFunctionHelper.GetFileSaveNameFromUrl(strUrl)
	if not string.find(strFileName, "%.exe$") then
		strFileName = strFileName..".exe"
	end
	local strSaveDir = Helper.tipUtil:GetSystemTempPath()
	local strSavePath = Helper.tipUtil:PathCombine(strSaveDir, strFileName)
	
	g_UpdateCancel = false
	g_CanRetry = false
	tFunctionHelper.TipLog("[OnClickUpdateBtn] strUrl = "..tostring(strUrl)..", strSavePath = "..tostring(strSavePath))
	tipAsynUtil:AsynGetHttpFileWithProgress(strUrl, strSavePath, false, function(nRet, savepath, ulProgress, ulProgressMax)
		if nRet == 0 then
			g_CanRetry = true
		end
		if g_UpdateCancel then
			if nRet == 0 then
				g_UpdateCancel = false
			end
			tFunctionHelper.TipLog("[OnClickUpdateBtn] AsynGetHttpFileWithProgress g_UpdateCancel = "..tostring(g_UpdateCancel))
			return
		end
		if g_UpdateState == 2 then
			if nRet == 0 then
				g_UpdateState = 3
			end
			return
		end
		local l, t, r, b = progrBar:GetObjPos()
		local fl, ft, fr, fb = progress:GetObjPos()
		local w = fr - fl
		tFunctionHelper.TipLog("[OnClickUpdateBtn] AsynGetHttpFileWithProgress nRet = "..tostring(nRet)..", ulProgress = "..tostring(ulProgress)..", ulProgressMax = "..tostring(ulProgressMax))
		if nRet == -2 and type(ulProgress) == "number" and type(ulProgressMax) == "number" and ulProgress < ulProgressMax and ulProgress > 0 then
			local rate = ulProgress/ulProgressMax
			local rateText = tostring(math.floor(rate*100)).."%"
			progrBar:SetObjPos(l, t, l + w*rate, b)
			progrText:SetText("正在下载"..rateText)
		elseif nRet == 0 then
			progrBar:SetObjPos(l, t, l + w, b)
			progrText:SetText("下载完成")
			if Helper.tipUtil:QueryFileExists(savepath) and CheckPacketMD5(savepath) then
				Helper.tipUtil:ShellExecute(0, "open", savepath, 0, 0, "SW_SHOWNORMAL")
			end
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

function PopupInDeskRight(self)
	local objtree = self:GetBindUIObjectTree()
	local objRootLayout = objtree:GetUIObject("root")
    local templateMananger = XLGetObject("Xunlei.UIEngine.TemplateManager")
	
	local nLayoutL, nLayoutT, nLayoutR, nLayoutB = objRootLayout:GetObjPos()
	local nLayoutWidth = nLayoutR - nLayoutL
	local nLayoutHeight = nLayoutB - nLayoutT
	
	local workleft, worktop, workright, workbottom = Helper.tipUtil:GetWorkArea()
	self:Move( workright - nLayoutWidth+9, workbottom - nLayoutHeight+9, nLayoutWidth, nLayoutHeight)
	return true
end

function FetchValueByPath(obj, path)
	if obj == nil then return end
	local cursor = obj
	for i = 1, #path do
		cursor = cursor[path[i]]
		if cursor == nil then
			return nil
		end
	end
	return cursor
end

local isAutoPopFirstEntry = true
function OnShowWindow(self, isShow)
	if not isShow then return end
	--是否是自动弹出提醒
	local isAutoPop = type(self.EndDialog) ~= "function"
	if isAutoPopFirstEntry and isAutoPop then
		isAutoPopFirstEntry = false
		return
	end
	local objtree = self:GetBindUIObjectTree()
	local objRootLayout = objtree:GetUIObject("root")
	if isAutoPop then
		PopupInDeskRight(self)
	else
		local userData = self:GetUserData()
		if userData and userData.parentWnd then
			local nLayoutL, nLayoutT, nLayoutR, nLayoutB = objRootLayout:GetObjPos()
			local nLayoutWidth  = nLayoutR - nLayoutL
			local nLayoutHeight = nLayoutB - nLayoutT
		
			local parentLeft, parentTop, parentRight, parentBottom = userData.parentWnd:GetWindowRect()
			local parentWidth  = parentRight - parentLeft
			local parentHeight = parentBottom - parentTop
			self:Move( parentLeft + (parentWidth - nLayoutWidth)/2, parentTop + (parentHeight - nLayoutHeight)/2, nLayoutWidth, nLayoutHeight)
		end
	end
	
	local TextBig = objtree:GetUIObject("UpdateWnd.Content.TextBig")
	local TextMain = objtree:GetUIObject("UpdateWnd.Content.TextMain")
	local TextVersion = objtree:GetUIObject("UpdateWnd.Content.TextVersion")
	local BtnUpdate = objtree:GetUIObject("UpdateWnd.OneKeyUpdate.Btn")
	TextMain:SetMultilineTextLimitWidth(260)
	--查询更新
	TextBig:SetVisible(false)
	BtnUpdate:Show(false)
	--TextVersion:SetVisible(false)
	TextMain:SetText("正在为您检查更新，请稍后...")
	
	local function ShowNoUpdate()
		if not isAutoPop then
			--已经是最新
			TextMain:SetObjPos(159, 107, 159+260, 107+25)
			TextMain:SetText("您的共享赚宝已经是最新版本。")
		else
			self:Show(0)
		end
	end
	
	local function ShowReadyUpdate(strVersion, strContent)
		--发现新版本
		TextBig:SetVisible(true)
		TextBig:SetText("发现共享赚宝新版本v"..tostring(strVersion))
		TextMain:SetVisible(false)
		TextVersion:SetVisible(true)
		BtnUpdate:Show(true)
		TextVersion:SetText(strContent)
		local w, h = TextVersion:GetTextExtent()
		local Hoffset =  h - 130
		if Hoffset > 0 then
			TextVersion:SetObjPos(158, 98, 158+260, 95 + h + 10)
			local wndL, wndT, wndR, wndB = self:GetWindowRect()
			self:Move(wndL, wndT, wndR - wndL, wndB - wndT + Hoffset+10)
			objRootLayout:SetObjPos(0, 0, wndR - wndL, wndB - wndT + Hoffset+10)
			self:SetMaxTrackSize(wndR - wndL, wndB - wndT + Hoffset+10)
		end
		if isAutoPop then
			local nHolds  = FetchValueByPath(g_ServerConfig, {"tNewVersionInfo", "tRemindUpdate", "nHolds"}) or 30
			SetOnceTimer(
				function(item, id)
					self:Show(0)
				end, 
				nHolds*1000)
		end
	end
	
	local function InitMainWnd(nRet, strCfgPath)			
		--[[local tNewVersionInfo = {
			strVersion = "1.0.0.2",
			strContent = "1、修改了XX\n2、优化了xx\n3、see more",
			strPacketURL = "http://xmp.down.sandai.net/xmp/XMPSetup_5.2.14.5672-dl.exe",
			strMD5 = "1221212",
		}
		g_tNewVersionInfo = tNewVersionInfo
		ShowReadyUpdate(tNewVersionInfo["strVersion"] or "3.4.56.1", tNewVersionInfo["strContent"] or "1、修改了XX\n2、优化了xx\n3、see more")
		if true then return end]]
		if 0 ~= nRet then
			ShowNoUpdate()
			return
		end	

		local tServerConfig = tFunctionHelper.LoadTableFromFile(strCfgPath) or {}
		local tNewVersionInfo = tServerConfig["tNewVersionInfo"] or {}
		local strPacketURL = tNewVersionInfo["strPacketURL"]
		if not Helper:IsRealString(strPacketURL) or
			not Helper:IsRealString(tNewVersionInfo["strVersion"]) or
			not Helper:IsRealString(tNewVersionInfo["strContent"] ) then
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
		--[[local strSavePath = GetPacketSavePath(strPacketURL)
		if Helper:IsRealString(tNewVersionInfo.strMD5) 
			and tFunctionHelper.CheckMD5(strSavePath, tNewVersionInfo.strMD5) then
			Helper.tipUtil:ShellExecute(0, "open", strSavePath, 0, 0, "SW_SHOWNORMAL")
			return
		end]]
		g_tNewVersionInfo = tNewVersionInfo
		ShowReadyUpdate(tNewVersionInfo["strVersion"] or "3.4.56.1", tNewVersionInfo["strContent"] or "1、修改了XX\n2、优化了xx\n3、see more")
	end
	tFunctionHelper.DownLoadServerConfig(InitMainWnd)
end