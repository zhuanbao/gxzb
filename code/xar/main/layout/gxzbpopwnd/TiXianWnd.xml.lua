local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
local gBalance = 0
local gHasChange = false

function OnClickClose(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:EndDialog(0)
end

function OnClickTiXianBtn(self)
end

function OnFocusChangeEdit(self, isFocus)
	if gHasChange then
		return
	end
	if isFocus then
		self:SetIsNumber(true)
		self:SetText(tostring(gBalance))
	else
		self:SetIsNumber(false)
		self:SetText("可提现"..tostring(gBalance).."元")
	end
end

function OnTextChangeEdit(self)
	local text = self:GetText()
	if text ~= tostring(gBalance) and text ~= "可提现"..tostring(gBalance).."元" then
		gHasChange = true
	else
		gHasChange = false
	end
end

function OnLButtonDownCaption(self, x, y)
	local edit = self:GetObject("tree:TiXianWnd.Caption.Edit")
	local editL, editT, editR, editB = edit:GetAbsPos()
	if x > editL and x < editR and y > editT and y < editB then
		edit:SetFocus(true)
	else
		edit:SetFocus(false)
	end
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
		local editobj = objtree:GetUIObject("TiXianWnd.Caption.EditBkg")
		local msgobj = objtree:GetUIObject("TiXianWnd.Caption.Msg")
		local btnobj = objtree:GetUIObject("TiXianWnd.CkickTiXian")
		editobj:SetEnable(false)
		editobj:SetChildrenEnable(false)
		btnobj:Show(false)
		msgobj:SetText("正在努力加载中...")
		local timerID = SetTimer(function(item, id) 
			local text = msgobj:GetText()
			if text == "正在努力加载中..." then
				msgobj:SetText("正在努力加载中.")
			elseif text == "正在努力加载中." then
				msgobj:SetText("正在努力加载中..")
			else
				msgobj:SetText("正在努力加载中...")
			end
		end, 
		1000)
		tFunctionHelper.QueryClientInfo(function(bRet, tab)
			KillTimer(timerID)
			if not bRet or type(tab) ~= "table" or not tonumber(tab["balance"]) then
				msgobj:SetText("很抱歉，加载失败")
				return
			end
			gBalance = tab["balance"]
			editobj:SetEnable(true)
			local realeditobj = objtree:GetUIObject("TiXianWnd.Caption.Edit")
			realeditobj:SetText("可提现"..tostring(gBalance).."元")
			editobj:SetChildrenEnable(true)
			btnobj:Show(true)
			msgobj:SetText("今日还可以免费提现一次")
		end)
	end
end