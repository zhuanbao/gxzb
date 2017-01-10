function OnClickClose(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:EndDialog(0)
end

function OnClickTiXianBtn(self)
end

function OnFocusChangeEdit(self, isFocus)
	if isFocus then
		self:SetIsNumber(true)
		self:SetText("12.05")
	else
		self:SetIsNumber(false)
		self:SetText("可提现12.05元")
	end
end

function OnLButtonDownCaption(self, x, y)
	local edit = self:GetObject("control:TiXianWnd.Caption.Edit")
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
	end
end