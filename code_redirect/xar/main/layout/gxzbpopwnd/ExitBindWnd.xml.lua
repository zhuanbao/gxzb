local tFunctionHelper = XLGetGlobal("FunctionHelper")
local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
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

function DestoryDialog(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:EndDialog(0)
end

function OnClickClose(self)
	DestoryDialog(self)
	local wndMain = UIInterface:GetMainHostWnd()
	UIInterface:ReportAndExit()
end

function OnClickBind(self)
	local wndMain = UIInterface:GetMainHostWnd()
	wndMain:BringWindowToTop(true)
	UIInterface:ChangeMainBodyPanel("QRCodePanel")
	DestoryDialog(self)
end

function OnClickCancel(self)
	local wndMain = UIInterface:GetMainHostWnd()
	UIInterface:ReportAndExit()
end

function OnCreate(self)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local userData = self:GetUserData()
	if userData and userData.parentWnd then
		local objTree = self:GetBindUIObjectTree()
		local objRootLayout = objTree:GetUIObject("ExitBindWnd.Content")
		local nLayoutL, nLayoutT, nLayoutR, nLayoutB = objRootLayout:GetObjPos()
		local nLayoutWidth  = nLayoutR - nLayoutL
		local nLayoutHeight = nLayoutB - nLayoutT
	
		local parentLeft, parentTop, parentRight, parentBottom = userData.parentWnd:GetWindowRect()
		local parentWidth  = parentRight - parentLeft
		local parentHeight = parentBottom - parentTop
		self:Move( parentLeft + (parentWidth - nLayoutWidth)/2, parentTop + (parentHeight - nLayoutHeight)/2, nLayoutWidth, nLayoutHeight)
		
		local ObjText = objTree:GetUIObject("ExitBindWnd.Desc")
		
		local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
		if type(tUserConfig["tUserInfo"]) ~= "table" then
			tUserConfig["tUserInfo"] = {}
		end
		local strNickName = tUserConfig["tUserInfo"]["strNickName"]
		if Helper:IsRealString(strNickName) then
			strNickName = Helper.tipUtil:GetLastWord(strNickName)
		else
			strNickName = "*"
		end
		local nCurBalance = ClientWorkModule:GetUserCurrentBalance()
		local strText = "您已赚了" .. tostring(tFunctionHelper.NumberToFormatMoney(nCurBalance)) .. "元宝，\r\n"
		strText = strText .. "不绑定微信，元宝可能会被人领走哦"
		ObjText:SetText(strText)
	end
end