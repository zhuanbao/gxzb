local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
local gBalance = 0
local gHasChange = false

function OnClickClose(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:EndDialog(0)
end

function OnClickTiXianBtn(self)
	local editobj = self:GetObject("tree:TiXianWnd.Caption.Edit")
	local strMsg = "输入了错误的金额"
	if editobj then
		local strText = editobj:GetText()
		if strText then
			local _, _, strBalance = string.find(strText, "^可提现(%d+)")
			local nBalance = 0
			if strBalance then
				nBalance = tonumber(strBalance)
			else
				nBalance = tonumber(strText)
			end
			if type(nBalance) == "number" then
				if nBalance > gBalance then
					strMsg = "输入了的金额大于可提现值"
				elseif gBalance == 0 then
					strMsg = "您的可提现余额为0， 不可提现"
				elseif nBalance == 0 then
					strMsg = "需要输入大于0的金额，才可提现"
				else
					strMsg = "ok"
				end
			end
		end
	end
	if strMsg ~= "ok" then
		local msgobj = self:GetObject("tree:TiXianWnd.Caption.Msg")
		if msgobj then
			msgobj:SetTextColorResID("system.red")
			msgobj:SetText(strMsg)
		end
	end
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
	local msgobj = self:GetObject("tree:TiXianWnd.Caption.Msg")
	if msgobj then
		msgobj:SetTextColorResID("333333")
		msgobj:SetText("今日还可以免费提现一次")
	end
	local text = self:GetText()
	if text ~= tostring(gBalance) and text ~= "可提现"..tostring(gBalance).."元" then
		local nBalance = tonumber(text)
		if type(nBalance) == "number" then
			if nBalance > gBalance then
				self:SetText(tostring(gBalance))
				gHasChange = false
			elseif nBalance < 0 then
				self:SetText("0")
				if gBalance == 0 then
					gHasChange = false
				else
					gHasChange = true
				end
			else
				gHasChange = true
			end
		else
			self:SetText(tostring(gBalance))
			gHasChange = false
		end
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
			if not bRet or type(tab) ~= "table" or type(tab["data"]) ~= "table" or not tonumber(tab["data"]["balance"]) then
				msgobj:SetText("很抱歉，加载失败")
				return
			end
			gBalance = tab["data"]["balance"]
			editobj:SetEnable(true)
			local realeditobj = objtree:GetUIObject("TiXianWnd.Caption.Edit")
			realeditobj:SetText("可提现"..tostring(gBalance).."元")
			editobj:SetChildrenEnable(true)
			btnobj:Show(true)
			msgobj:SetText("今日还可以免费提现一次")
		end)
	end
end