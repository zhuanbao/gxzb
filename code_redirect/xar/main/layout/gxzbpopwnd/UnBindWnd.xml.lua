local tFunctionHelper = XLGetGlobal("FunctionHelper")
local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}

function DestoryDialog(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:EndDialog(0)
end

function OnClickCloseDialog(self)
	DestoryDialog(self)
end

function OnClickUnBind(self)
	--tFunctionHelper.UnBindingClientFromClient()
	local tStatInfo = {}
	tStatInfo.fu1 = "unbindwx"
	--tStatInfo.fu5 = "client"
	StatisticClient:SendClickReport(tStatInfo)
	DestoryDialog(self)
end

function OnClickCancel(self)
	DestoryDialog(self)
end

function OnCreate(self)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local userData = self:GetUserData()
	if userData and userData.parentWnd then
		local objTree = self:GetBindUIObjectTree()
		local objRootLayout = objTree:GetUIObject("root")
		local nLayoutL, nLayoutT, nLayoutR, nLayoutB = objRootLayout:GetObjPos()
		local nLayoutWidth  = nLayoutR - nLayoutL
		local nLayoutHeight = nLayoutB - nLayoutT
	
		local parentLeft, parentTop, parentRight, parentBottom = userData.parentWnd:GetWindowRect()
		local parentWidth  = parentRight - parentLeft
		local parentHeight = parentBottom - parentTop
		self:Move( parentLeft + (parentWidth - nLayoutWidth)/2, parentTop + (parentHeight - nLayoutHeight)/2, nLayoutWidth, nLayoutHeight)
		
		local ObjText = objTree:GetUIObject("UnBindWnd.Content.Text")
		
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
		
		local strText = "当前绑定微信账号是（*" .. tostring(strNickName) .. "）。\r\n"
		strText = strText .. "解除绑定后，赚宝收益无法提现，除非\r\n"
		strText = strText .. "您重新绑定。确定解绑吗？\r\n"
		ObjText:SetText(strText)
	end
end