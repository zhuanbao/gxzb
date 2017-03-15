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

-------------------------------
--------以下是控件逻辑---------
-------------------------------
function LeftGoldBalance_SetState(self, state)
	local attr = self:GetAttribute()
	if state == attr.currentstate then
		return
	end
	local needDelay = false
	if (attr.currentstate == nil or attr.currentstate == 0 or attr.currentstate == 3) and (state == 1 or state == 4) then
		needDelay = true
	end
	attr.currentstate = state
	local goldicon = self:GetObject("goldicon")
	local goldtexthead = self:GetObject("goldtexthead")
	local goldtextnumber = self:GetObject("goldtextnumber")
	if state == 0 or state == 3 then
		self:SetVisible(false)
		self:SetChildrenVisible(false)
	elseif state == 1 or state == 4 then
		local function hoverright()
			self:SetVisible(true)
			self:SetChildrenVisible(true)
			goldtextnumber:SetVisible(true)
			goldtexthead:SetVisible(true)
			goldicon:SetResID("suspend-gold-gray")
			goldtextnumber:SetTextColorResID("color.suspend.balance")
			goldtextnumber:SetAlpha(255)
			goldtexthead:SetTextColorResID("color.suspend.balance")
			goldtexthead:SetAlpha(255)
			local goldzorder = goldicon:GetZorder()
			if type(goldzorder) == "number" then
				goldtexthead:SetZorder(goldzorder+1)
				goldtextnumber:SetZorder(goldzorder+1)
			end
		end
		--停右边
		if needDelay then
			SetOnceTimer(hoverright, 100)
		else
			hoverright()
		end
	elseif state == 2 then
		self:SetVisible(true)
		self:SetChildrenVisible(true)
		goldtextnumber:SetVisible(true)
		goldtexthead:SetVisible(true)
		goldtextnumber:SetTextColorResID("color.suspend.balance.lower")
		goldtextnumber:SetAlpha(117)
		goldtexthead:SetTextColorResID("color.suspend.balance.lower")
		goldtexthead:SetAlpha(117)
		goldicon:SetResID("suspend-gold-light")
		local textzorder = goldtexthead:GetZorder()
		if type(textzorder) == "number" then
			goldicon:SetZorder(textzorder+1)
		end
	else
		self:SetVisible(true)
		self:SetChildrenVisible(true)
		goldtextnumber:SetVisible(false)
		goldtexthead:SetVisible(false)
		goldicon:SetResID("suspend-gold-light")
	end
end

function SuspendRightDisk_SetState(self, state)
	local attr = self:GetAttribute()
	if state == attr.currentstate then
		return
	end
	attr.currentstate = state
	local goldicon = self:GetObject("goldicon")
	local graydisk = self:GetObject("graydisk")
	local starticon = graydisk:GetObject("starticon")
	local lightdisk = self:GetObject("lightdisk")
	local stopicon = lightdisk:GetObject("stopicon")
	if state == 0 then
		goldicon:SetVisible(true)
		graydisk:SetVisible(false)
		graydisk:SetChildrenVisible(false)
		lightdisk:SetVisible(false)
		lightdisk:SetChildrenVisible(false)
	elseif state == 1 then
		goldicon:SetVisible(false)
		lightdisk:SetVisible(false)
		lightdisk:SetChildrenVisible(false)
		graydisk:SetVisible(true)
		graydisk:SetChildrenVisible(true)
		starticon:SetVisible(true)
	elseif state == 2 then
		goldicon:SetVisible(false)
		lightdisk:SetVisible(false)
		lightdisk:SetChildrenVisible(false)
		graydisk:SetVisible(true)
		graydisk:SetChildrenVisible(true)
		starticon:SetVisible(false)
	elseif state == 4 then
		goldicon:SetVisible(false)
		graydisk:SetVisible(false)
		graydisk:SetChildrenVisible(false)
		lightdisk:SetVisible(true)
		lightdisk:SetChildrenVisible(true)
		stopicon:SetVisible(true)
	else
		goldicon:SetVisible(false)
		graydisk:SetVisible(false)
		graydisk:SetChildrenVisible(false)
		lightdisk:SetVisible(true)
		lightdisk:SetChildrenVisible(true)
		stopicon:SetVisible(false)
	end
end

function SuspendRightDisk_UpdateSpeed(self, nspeed)
	if type(nspeed) ~= "number" or nspeed < 1 or nspeed > 13 then
		return
	end
	local attr = self:GetAttribute()
	if attr.currentstate ~= 3 and attr.currentstate ~= 4 then
		return
	end
	if not attr.currentspeed then
		attr.currentspeed = 1
	end
	if attr.currentspeed == nspeed then
		return
	end
	local needleobj = self:GetObject("lightdisk:lightdisk.needle")
	function killanimtimer()
		if attr.animtimer then
			KillTimer(attr.animtimer)
			attr.animtimer = nil
		end
	end
	killanimtimer()
	attr.animtimer = SetTimer(function(item, id)
		if attr.currentspeed == nspeed then
			killanimtimer()
		elseif attr.currentspeed < nspeed then
			attr.currentspeed = attr.currentspeed + 1
		else
			attr.currentspeed = attr.currentspeed - 1
		end
		needleobj:SetResID("suspend-needle-needle"..tostring(attr.currentspeed))
	end, 41)
end

function SuspendCtrl_SetState(self, state)
	local attr = self:GetAttribute()
	if state == attr.currentstate then
		return
	end
	attr.currentstate = state
	local strip = self:GetObject("strip")
	local RightDisk = strip:GetObject("RightDisk")
	local LeftGoldBalance = strip:GetObject("LeftGoldBalance")
	RightDisk:SetState(state)
	LeftGoldBalance:SetState(state)
end

function SuspendCtrl_UpdateLine(self, nLineValue)
	local attr = self:GetAttribute()
	local strip = self:GetObject("strip")
	local strResHead = "suspend-nowork-bkg"
	if attr.currentstate == 3 or attr.currentstate == 4 then
		strResHead = "suspend-work-bkg"
	end
	strip:SetTextureID(strResHead..tostring(nLineValue))
end

function OnInitControl(self)
	local attr = self:GetAttribute()
	attr.workstate = "work"
	self:SetState(attr.workstate == "work" and 3 or 0)
	local RightDisk = self:GetObject("RightDisk")
	SetTimer(function(item, id)
		local randnum = math.random(1, 14)
		RightDisk:UpdateSpeed(randnum)
	end, 1000)
end

local minWidth = 82
local shadowOffset = 10
function OnMouseMove(self, x, y)
	CheckStripAnim(self, false, x, y)
	local attr = self:GetAttribute()
	--自己处理离开事件
	--[[local L, T, R, B = self:GetObjPos()
	local W, H = R-L, B-T
	LOG("x="..tostring(x)..", y="..tostring(y)..", W="..tostring(W)..", H="..tostring(H))
	if x < 0 or x >= W or y < 0 or y >= B then
		self:SetCaptureMouse(false)
		OnMouseLeave(self)
		return
	else
		self:SetCaptureMouse(true)
	end]]
	--不拖动的时候才处理hover事件
	if not attr.hitpoint then
		--动画放完了且需要反向
		if not attr.anim and attr.reverse then
			AnimHide(self, attr.reverse[1], attr.reverse[2], false)
			return
		end
		--处理右侧圆盘显示
		local l, t, r, b = self:GetObjPos()
		local width = r - l
		--停在右边
		if x >= width - minWidth then
			self:SetState(attr.workstate == "work" and 4 or 1)
		--停在左边
		else
			self:SetState(attr.workstate == "work" and 5 or 2)
		end
		return
	end
	local tree = self:GetOwner()
	local wnd = tree:GetBindHostWnd() 
	local wndL, wndT, wndR, wndB = wnd:GetWindowRect()
	local workleft, worktop, workright, workbottom = Helper.tipUtil:GetWorkArea()
	--处理阴影
	workleft = workleft - shadowOffset
	worktop = worktop - shadowOffset
	workright = workright + shadowOffset
	workbottom = workbottom + shadowOffset
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
	--处理阴影
	workleft = workleft - shadowOffset
	worktop = worktop - shadowOffset
	workright = workright + shadowOffset
	workbottom = workbottom + shadowOffset
	if wndL == workleft then
		AnimHide(self, -103, 0, true)
	elseif worktop == wndT then
		AnimHide(self, 0, -31, true)
	elseif workright == wndR then
		AnimHide(self, 31, 0, true)
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

function CheckStripAnim(self, isHide, x, y)
	local attr = self:GetAttribute()
	if attr.animstrip then
		return
	end
	local strip = self:GetObject("strip")
	local l, t, r, b = strip:GetObjPos()
	--需要显示且已经显示， 需要隐藏且已经隐藏， 则不处理
	if (isHide and l == r-minWidth) or (not isHide and l == 0)  then
		return
	end
	--在这里处理缩回时隐藏圆盘
	self:SetState(attr.workstate == "work" and 3 or 0)
	
	local aniFactory = XLGetObject("Xunlei.UIEngine.AnimationFactory")
	attr.animstrip = aniFactory:CreateAnimation("PosChangeAnimation")
	attr.animstrip:SetTotalTime(300)
	attr.animstrip:BindLayoutObj(strip)
	--右边不变只变左边
	if isHide then
		attr.animstrip:SetKeyFrameRect(l, t, r, b, r-minWidth, t, r, b)
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