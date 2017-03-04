local tipUtil = XLGetObject("API.Util")
local FunctionObj = XLGetGlobal("Global.FunctionHelper")

function PopupInDeskRightTop(self)
	local workleft, worktop, workright, workbottom = Helper.tipUtil:GetWorkArea()
	local wndL, wndT, wndR, wndB = self:GetWindowRect()
	self:Move( workright - 225 - 100, 200, wndR-wndL, wndB-wndT)
	return true
end

function OnCreate( self )
	local objtree = self:GetBindUIObjectTree()
	PopupInDeskRightTop(self)
	SetTimer(function(item, id)
		self:SetTopMost(false)
		self:SetTopMost(true)
	end, 5000)
end

function OnRButtonUpSuspend(self)
	local tree = self:GetOwner()
	local wnd = tree:GetBindHostWnd()
	local curX, curY = Helper.tipUtil:GetCursorPos()
	local menuTable = GXZBMenu.SuspendMenu.menuTable
	local menuFunTable = GXZBMenu.SuspendMenu.menuFunTable
	local userData = {}
	Helper:CreateMenu(curX, curY+10, wnd:GetWndHandle(), menuTable, menuFunTable, userData)
end

function OnLButtonDbClickSuspend(self, x, y)
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	objHostWnd:BringWindowToTop(true)
end

function OnLButtonDown(self, x, y)
	local attr = self:GetAttribute()
	if not attr.anim then
		attr.hitpoint = {x, y}
		self:SetCaptureMouse(true)
	end
end

function OnLButtonUp(self, x, y)
	local attr = self:GetAttribute()
	attr.hitpoint = nil
	self:SetCaptureMouse(false)
end

function OnMouseMove(self, x, y)
	CheckStripAnim(self, false)
	local attr = self:GetAttribute()
	--动画放完了且需要反向
	if not attr.anim and attr.reverse then
		AnimHide(self, attr.reverse[1], attr.reverse[2], false)
		return
	end
	if not attr.hitpoint then
		return
	end
	local tree = self:GetOwner()
	local wnd = tree:GetBindHostWnd() 
	local wndL, wndT, wndR, wndB = wnd:GetWindowRect()
	local workleft, worktop, workright, workbottom = Helper.tipUtil:GetWorkArea()
	local dx, dy = math.floor(x - attr.hitpoint[1]),  math.floor(y - attr.hitpoint[2])
	local tarL, tarT, tarR, tarB = wndL + dx, wndT + dy,  wndR + dx, wndB + dy
	if tarL < workleft then
		tarR = tarR + workleft - tarL
		tarL = workleft
	elseif tarR > workright then
		tarL = math.floor(tarL - (tarR - workright))
		tarR = workright
	end
	if tarT < worktop then
		tarB = tarB + worktop - tarT
		tarT = worktop
	elseif tarB > workbottom then
		tarT = tarT - (tarB - workbottom)
		tarB = workbottom
	end
	wnd:Move(tarL, tarT, tarR - tarL, tarB - tarT)
end

function OnMouseLeave(self)
	CheckStripAnim(self, true)
	local tree = self:GetOwner()
	local wnd = tree:GetBindHostWnd() 
	local wndL, wndT, wndR, wndB = wnd:GetWindowRect()
	local workleft, worktop, workright, workbottom = Helper.tipUtil:GetWorkArea()
	if wndL == workleft then
		AnimHide(self, -235, 0, true)
	elseif worktop == wndT then
		AnimHide(self, 0, -60, true)
	elseif workright == wndR then
		AnimHide(self, 60, 0, true)
	end 
end

function AnimHide(self, xoffset, yoffset, isHide)
	local attr = self:GetAttribute()
	if attr.anim then
		return
	end
	local sl, st, sr, sb = self:GetObjPos()
	local dl, dt, dr, db = sl + xoffset, st + yoffset, sr + xoffset, sb + yoffset
	local aniFactory = XLGetObject("Xunlei.UIEngine.AnimationFactory")
	attr.anim = aniFactory:CreateAnimation("PosChangeAnimation")
	attr.anim:SetTotalTime(300)
	attr.anim:BindLayoutObj(self)
	attr.anim:SetKeyFrameRect(sl, st, sr, sb, dl, dt, dr, db)
	local ownerTree = self:GetOwner()
	ownerTree:AddAnimation(attr.anim)
	local wnd = ownerTree:GetBindHostWnd() 
	local wndL, wndT, wndR, wndB = wnd:GetWindowRect()
	function onAniFinish(ani,old,new)
		--XLMessageBox(""..tostring(old)..", "..tostring(new))
		if new == 4 or new == 3 then
			attr.anim = nil
			if isHide then
				attr.reverse = {-xoffset, -yoffset}
			else
				attr.reverse = nil
				local curX, curY = Helper.tipUtil:GetCursorPos()
				if curX < wndL or  curX > wndR or curY < wndT or curY > wndB then
					OnMouseLeave(self)
				end
			end
		end
	end
	attr.anim:AttachListener(true,onAniFinish)
	attr.anim:Resume()
end

function CheckStripAnim(self, isHide)
	local attr = self:GetAttribute()
	if attr.animstrip then
		return
	end
	local strip = self:GetObject("strip")
	local l, t, r, b = strip:GetObjPos()
	--需要显示且已经显示， 需要隐藏且已经隐藏， 则不处理
	if (isHide and l == r) or (not isHide and l == 0)  then
		return
	end
	local aniFactory = XLGetObject("Xunlei.UIEngine.AnimationFactory")
	attr.animstrip = aniFactory:CreateAnimation("PosChangeAnimation")
	attr.animstrip:SetTotalTime(300)
	attr.animstrip:BindLayoutObj(strip)
	--右边不变只变左边
	if isHide then
		attr.animstrip:SetKeyFrameRect(l, t, r, b, r, t, r, b)
	else
		attr.animstrip:SetKeyFrameRect(l, t, r, b, 0, t, r, b)
	end
	local ownerTree = self:GetOwner()
	ownerTree:AddAnimation(attr.animstrip)
	local wnd = ownerTree:GetBindHostWnd() 
	local wndL, wndT, wndR, wndB = wnd:GetWindowRect()
	function onAniFinish(ani,old,new)
		if new == 4 or new == 3 then
			attr.animstrip = nil
			if not isHide then
				local curX, curY = Helper.tipUtil:GetCursorPos()
				--显示出来后发现鼠标不在里面了， 则再缩进去
				if curX < wndL or  curX > wndR or curY < wndT or curY > wndB then
					CheckStripAnim(self, true)
				end
			end
		end
	end
	attr.animstrip:AttachListener(true,onAniFinish)
	attr.animstrip:Resume()
end