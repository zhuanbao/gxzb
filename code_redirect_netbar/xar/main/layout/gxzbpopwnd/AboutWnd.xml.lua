local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")

function OnClickClose(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:EndDialog(0)
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
		
		local TextVersion = objtree:GetUIObject("AboutWnd.Content.VersionValue")
		local TextDate = objtree:GetUIObject("AboutWnd.Content.DateValue")
		local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
		local strLastUTC =  Helper.tipUtil:QueryRegValue("HKEY_LOCAL_MACHINE", "Software\\Share4Money", "InstallTimes")
		if not tonumber(strLastUTC) then
			strLastUTC = tUserConfig["nLastCommonUpdateUTC"]
		end
		local nLastUTC = tonumber(strLastUTC)
		if nLastUTC then
			TextDate:SetText(os.date("%Y-%m-%d"), nLastUTC)
		end
		local strVersion = tFunctionHelper.GetGXZBVersion()
		if strVersion then
			TextVersion:SetText(tostring(strVersion))
		end
	end
end

function OnClickLink(self)
	Helper.tipUtil:OpenURL(self:GetText())
end