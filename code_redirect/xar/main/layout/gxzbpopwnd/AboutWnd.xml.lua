local tFunctionHelper = XLGetGlobal("FunctionHelper")
local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")

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
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:EndDialog(0)
end

function OnCreate(self)
	local userData = self:GetUserData()
	if userData and userData.parentWnd then
		local objTree = self:GetBindUIObjectTree()
		local objContent = objTree:GetUIObject("AboutWnd.Content")
		local nContentL, nContentT, nContentR, nContentB = objContent:GetObjPos()
		local nContentWidth  = nContentR - nContentL
		local nContentHeight = nContentB - nContentT
	
		local parentLeft, parentTop, parentRight, parentBottom = userData.parentWnd:GetWindowRect()
		local parentWidth  = parentRight - parentLeft
		local parentHeight = parentBottom - parentTop
		self:Move( parentLeft + (parentWidth - nContentWidth)/2, parentTop + (parentHeight - nContentHeight)/2, nContentWidth, nContentHeight)
		
		local objVerValue = objTree:GetUIObject("AboutWnd.Version.Value")
		local objDateValue = objTree:GetUIObject("AboutWnd.Date.Value")
		local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
		local strLastUTC =  Helper.tipUtil:QueryRegValue("HKEY_LOCAL_MACHINE", "Software\\Share4Money", "InstallTimes")
		if not tonumber(strLastUTC) then
			strLastUTC = tUserConfig["nLastCommonUpdateUTC"]
		end
		local nLastUTC = tonumber(strLastUTC)
		if nLastUTC then
			objDateValue:SetText(os.date("%Y-%m-%d"), nLastUTC)
		end
		local strVersion = tFunctionHelper.GetGXZBVersion()
		if strVersion then
			objVerValue:SetText(tostring(strVersion))
		end
	end
end

function OnClickLink(self)
	Helper.tipUtil:OpenURL(self:GetText())
	local tStatInfo = {}
	tStatInfo.fu1 = "openhomepage"
	StatisticClient:SendClickReport(tStatInfo)
end