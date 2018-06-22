local tFunctionHelper = XLGetGlobal("FunctionHelper")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local tipUtil = XLGetObject("API.Util")
local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")
local g_objTree = nil
local g_nBtnClickCookie = nil

function TipLog(strLog)
	tipUtil:Log("RecommandUpdateWnd: " .. tostring(strLog))
end

function IsRealString(str)
	return type(str) == "string" and str ~= ""
end

function PopupInDeskRight(self)
	local objtree = self:GetBindUIObjectTree()
	local objRootLayout = objtree:GetUIObject("RecommandUpdateWnd.Content")
    local templateMananger = XLGetObject("Xunlei.UIEngine.TemplateManager")
	
	local nLayoutL, nLayoutT, nLayoutR, nLayoutB = objRootLayout:GetObjPos()
	local nLayoutWidth = nLayoutR - nLayoutL
	local nLayoutHeight = nLayoutB - nLayoutT
	
	local workleft, worktop, workright, workbottom = Helper.tipUtil:GetWorkArea()
	self:Move( workright - nLayoutWidth+9, workbottom - nLayoutHeight+9, nLayoutWidth, nLayoutHeight)
	return true
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

function OnClickClose(self)
	Helper:DestoryModelessWnd("GXZB.RecommandUpdateWnd")
end

function CheckPacketMD5(strPacketPath)
	local strServerMD5 = g_tNewVersionInfo["strMD5"]
	return tFunctionHelper.CheckMD5(strPacketPath, strServerMD5)
end

function GetPacketSavePath(strURL)
	if not IsRealString(strURL) then
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

function ShowNoNeedUpadte()
	local strCurVersion = tFunctionHelper.GetGXZBVersion()
	local strText = "您的共享赚宝已是最新版本\r\n版本号：v" .. tostring(strCurVersion)
	local objNoNeedUpadte = g_objTree:GetUIObject("RecommandUpdateWnd.NoNeedUpadte")
	objNoNeedUpadte:SetText(strText)
	objNoNeedUpadte:SetVisible(true)
	
	local objBtn = g_objTree:GetUIObject("RecommandUpdateWnd.Btn")
	objBtn:AttachListener("OnClick", false, function(self)
								Helper:DestoryModelessWnd("GXZB.RecommandUpdateWnd")
						    end)
	objBtn:SetText("确定")
	objBtn:Show(true)
end

function ShowUpdateInfo(tabNewVer)
	local objIcon = g_objTree:GetUIObject("RecommandUpdateWnd.Icon")
	local nIconL, nIconT, nIconR, nIconB = objIcon:GetObjPos()
	objIcon:SetObjPos(nIconL, 50, nIconR, 50+46)
	local nMiddle = (50+50+46)/2
	local objNewVer = g_objTree:GetUIObject("RecommandUpdateWnd.FindNewVersion")
	local strText = "发现共享赚宝新版本v" .. tostring(tabNewVer["strVersion"]) .. "\r\n"
	strText = strText .. tabNewVer["strContent"]
	objNewVer:SetText(strText)
	local nNewVerL, nNewVerT, nNewVerR, nNewVerB = objNewVer:GetObjPos()
	local nWidth, nHeight = objNewVer:GetTextExtent()
	
	objNewVer:SetObjPos(nNewVerL, nMiddle-nHeight/2, nNewVerR, nMiddle+nHeight/2)
	objNewVer:SetVisible(true)
	local objBtn = g_objTree:GetUIObject("RecommandUpdateWnd.Btn")
	if g_nBtnClickCookie then
		objBtn:RemoveListener("OnClick", g_nBtnClickCookie)
	end	
	g_nBtnClickCookie = objBtn:AttachListener("OnClick", false, function(self)
													DoUpdating(tabNewVer)
												end)
	objBtn:SetText("一键升级")
	objBtn:Show(true)
end

function DownLoadPackageFail()
	local objCloseBtn = g_objTree:GetUIObject("RecommandUpdateWnd.CloseBtn")
	objCloseBtn:Enable(true)
	
	local objUpdatingProgressCompleting = g_objTree:GetUIObject("RecommandUpdateWnd.Updating.Progress.Completing")
	objUpdatingProgressCompleting:SetTextureID("GXZB.PopUpWnd.ProcessBar.Fail")
	
	local objUpdatingProgDesc = g_objTree:GetUIObject("RecommandUpdateWnd.Updating.ProgDesc")
	objUpdatingProgDesc:SetVisible(false)
	
	local objFaillDesc = g_objTree:GetUIObject("RecommandUpdateWnd.Updating.FaillDesc")
	objFaillDesc:SetVisible(true)
	
	local objBtn = g_objTree:GetUIObject("RecommandUpdateWnd.Btn")
	if g_nBtnClickCookie then
		objBtn:RemoveListener("OnClick", g_nBtnClickCookie)
	end	
	g_nBtnClickCookie = objBtn:AttachListener("OnClick", false, function(self)
													tipUtil:OpenURL("http://www.share4money.cn/")
												end)
	objBtn:SetText("手动升级")
	objBtn:Show(true)											
end

function DownLoadPackageSuccess(strPackagePath)
	
	local objCloseBtn = g_objTree:GetUIObject("RecommandUpdateWnd.CloseBtn")
	objCloseBtn:Enable(true)
	
	local objUpdatingProgress = g_objTree:GetUIObject("RecommandUpdateWnd.Updating.Progress")
	local nUpdatingProgressL, nUpdatingProgressT, nUpdatingProgressR, nUpdatingProgressB = objUpdatingProgress:GetObjPos()
	local nFullLen = nUpdatingProgressR - nUpdatingProgressL
	
	local objUpdatingProgressCompleting = g_objTree:GetUIObject("RecommandUpdateWnd.Updating.Progress.Completing")
	local nCompletingL, nCompletingT, nCompletingR, nCompletingB = objUpdatingProgressCompleting:GetObjPos()
	objUpdatingProgressCompleting:SetObjPos(nCompletingL, nCompletingT, nCompletingL+nFullLen, nCompletingB)

	local objUpdatingProgDesc = g_objTree:GetUIObject("RecommandUpdateWnd.Updating.ProgDesc")	
	objUpdatingProgDesc:SetText("下载完成")
	
	local objBtn = g_objTree:GetUIObject("RecommandUpdateWnd.Btn")
	if g_nBtnClickCookie then
		objBtn:RemoveListener("OnClick", g_nBtnClickCookie)
	end	
	g_nBtnClickCookie = objBtn:AttachListener("OnClick", false, function(self)
													tipUtil:ShellExecute(0, "open", strPackagePath, 0, 0, "SW_SHOWNORMAL")
												end)
	objBtn:SetText("立即安装")
	objBtn:Show(true)	
	tipUtil:ShellExecute(0, "open", strPackagePath, 0, 0, "SW_SHOWNORMAL")	
end

function DoUpdating(tabNewVer)
	local strUrl = tabNewVer["strPacketURL"]
	local strSavePath = GetPacketSavePath(strUrl)
	local strNewMD5 = tabNewVer["strMD5"]
	local objNewVer = g_objTree:GetUIObject("RecommandUpdateWnd.FindNewVersion")
	objNewVer:SetVisible(false)
	local objBtn = g_objTree:GetUIObject("RecommandUpdateWnd.Btn")
	objBtn:Show(false)
	
	local objUpdatingVerDesc = g_objTree:GetUIObject("RecommandUpdateWnd.Updating.VerDesc")
	local strText = "正在升级至最新版本v" .. tostring(tabNewVer["strVersion"])
	objUpdatingVerDesc:SetText(strText)
	objUpdatingVerDesc:SetVisible(true)
	
	local objUpdatingProgress = g_objTree:GetUIObject("RecommandUpdateWnd.Updating.Progress")
	objUpdatingProgress:SetVisible(true)
	
	local objUpdatingProgressCompleting = g_objTree:GetUIObject("RecommandUpdateWnd.Updating.Progress.Completing")
	objUpdatingProgressCompleting:SetVisible(true)
	
	local objUpdatingProgDesc = g_objTree:GetUIObject("RecommandUpdateWnd.Updating.ProgDesc")
	objUpdatingProgDesc:SetVisible(true)
	
	if not IsRealString(strNewMD5) 
		and tFunctionHelper.CheckMD5(strSavePath, strNewMD5) then
		DownLoadPackageSuccess(strSavePath)
		return
	end
	---[[
	local objCloseBtn = g_objTree:GetUIObject("RecommandUpdateWnd.CloseBtn")
	objCloseBtn:Enable(false)
	strUrl = strUrl..tFunctionHelper.GetTimeStamp()
	
	local nUpdatingProgressL, nUpdatingProgressT, nUpdatingProgressR, nUpdatingProgressB = objUpdatingProgress:GetObjPos()
	
	local nFullLen = nUpdatingProgressR - nUpdatingProgressL
	local objFaillDesc = g_objTree:GetUIObject("RecommandUpdateWnd.Updating.FaillDesc")
	local bCancle = false
	tipAsynUtil:AsynGetHttpFileWithProgress(strUrl, strSavePath, false, function(nRet, strPath, ulProgress, ulProgressMax)
		TipLog("[DoUpdating] AsynGetHttpFileWithProgress nRet = "..tostring(nRet)..", ulProgress = "..tostring(ulProgress)..", ulProgressMax = "..tostring(ulProgressMax))
		if bCancle then
			return
		end
		if nRet == -2 and type(ulProgress) == "number" and type(ulProgressMax) == "number" and ulProgress < ulProgressMax and ulProgress > 0 then
			local nRate = ulProgress/ulProgressMax
			local strRateText = tostring(math.floor(nRate*100)).."%"
			local nCompletingL, nCompletingT, nCompletingR, nCompletingB = objUpdatingProgressCompleting:GetObjPos()
			local nNewCompletingR = nCompletingL+nFullLen*nRate
			if nNewCompletingR >  nCompletingR then
				objUpdatingProgressCompleting:SetObjPos(nCompletingL, nCompletingT, nNewCompletingR, nCompletingB)	
			end
			objUpdatingProgDesc:SetText("正在下载"..strRateText)
		elseif nRet == -1 then
			bCancle = true
			objFaillDesc:SetText("升级失败，建议您手动升级")
			DownLoadPackageFail()
		elseif nRet == 0 then
			bCancle = true
			if tipUtil:QueryFileExists(strPath) and tFunctionHelper.CheckMD5(strPath, strNewMD5) then
				DownLoadPackageSuccess(strPath)
			else
				objFaillDesc:SetText("文件检验失败，建议您手动升级")
				DownLoadPackageFail()
			end
		end
	end)
	--]]
end

function OnShowWindow(self, bShow)
	if not bShow then return end
	local objTree = self:GetBindUIObjectTree()
	g_objTree = objTree
	--local objRoot = objTree:GetUIObject("RecommandUpdateWnd.Content")
	local objIcon = objTree:GetUIObject("RecommandUpdateWnd.Icon")
	local nIconL, nIconT, nIconR, nIconB = objIcon:GetObjPos()
	objIcon:SetObjPos(nIconL, 45, nIconR, 45+46)
	
	local tabNewVer  = ServerCfg:GetServerCfgData({"tNewVersionInfo"})
	ShowUpdateInfo(tabNewVer)
end

function OnCreate(self)
	PopupInDeskRight(self)
end