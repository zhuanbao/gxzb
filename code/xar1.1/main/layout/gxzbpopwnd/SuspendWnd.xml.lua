local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")

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

-------------------------------
--------以下是控件逻辑---------
-------------------------------
function LeftGoldBalance_Click(self)
	local attr = self:GetAttribute()
	if attr.currentstate == 2 or attr.currentstate == 5 then
		local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
		objHostWnd:BringWindowToTop(true)
	end
end

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
	if state == 3 then
		self:SetVisible(false)
		self:SetChildrenVisible(false)
	elseif state == 0 or state == 1 or state == 4 then
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
			goldtexthead:SetTextFontResID("font.suspend.balancehead")
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
		goldtexthead:SetTextFontResID("font.suspend.balancehead.lower")
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

function SuspendRightDisk_Click(self)
	--0未开始正常态，1未开始停右边，2未开始停左边，3开始正常态 4开始停右边， 5开始停左边
	local attr = self:GetAttribute()
	LOG("SuspendWnd SuspendRightDisk_Click can call click, attr.currentstate="..tostring(attr.currentstate)..", tFunctionHelper.CheckIsWorking()="..tostring(tFunctionHelper.CheckIsWorking()))
	if attr.currentstate == 1 then
		--self:GetOwnerControl():OnWorkStateChange(1)
		if not tFunctionHelper.CheckIsWorking() then
			tFunctionHelper.NotifyStart()
		end
	elseif attr.currentstate == 4 then
		--self:GetOwnerControl():OnWorkStateChange(2)
		if tFunctionHelper.CheckIsWorking() then
			tFunctionHelper.NotifyPause()
		end
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
	if state == 0 then
		LeftGoldBalance:SetObjPos(0, 0, 82, "father.height")
	else
		LeftGoldBalance:SetObjPos(10, 0, 82, "father.height")
	end
	LeftGoldBalance:SetState(state)
	self:UpdateLine(attr.linevalue or 0)
end

function SuspendCtrl_UpdateLine(self, nLineValue)
	local attr = self:GetAttribute()
	local strip = self:GetObject("strip")
	local strResHead = "suspend-nowork-bkg"
	if attr.currentstate >= 3 then
		strResHead = "suspend-work-bkg"
	end
	strip:SetTextureID(strResHead..tostring(nLineValue))
end

--1:Start,2:Pause,3:Quit
function SuspendCtrl_OnWorkStateChange(self, state)
	local attr = self:GetAttribute()
	attr.currentstate = attr.currentstate or 0
	local RightDisk = self:GetObject("RightDisk")
	local speedtext = RightDisk:GetObject("speedtext")
	if state == 1 then
		if attr.currentstate  <= 2 then
			local newState = attr.currentstate + 3
			self:SetState(newState)
		end
		speedtext:SetText("准备中")
	elseif state == 2 or state == 3 then
		if attr.currentstate  >= 3 then
			local newState = attr.currentstate - 3
			self:SetState(newState)
		end
	end
end

local MING_CALCULATE_DAG = 2
local MING_MINING_SPEED = 3
local MING_MINING_EEEOR = 4
local MING_SOLUTION_FIND = 5
local MING_MINING_EEEOR_TIMEOUT = 100
function SuspendCtrl_UpdateMiningState(self, nMiningState)
	local attr = self:GetAttribute()
	attr.currentstate = attr.currentstate or 0
	local RightDisk = self:GetObject("RightDisk")
	local speedtext = RightDisk:GetObject("speedtext")
	if nMiningState == MING_MINING_SPEED and  tFunctionHelper.CheckIsWorking() then
		speedtext:SetText("")
	elseif nMiningState == MING_CALCULATE_DAG and  tFunctionHelper.CheckIsWorking() then
		if attr.currentstate  <= 2 then
			local newState = attr.currentstate + 3
			self:SetState(newState)
		end
		speedtext:SetText("准备中")
	end
end

function SuspendCtrl_UpdateMiningSpeed(self, nMiningSpeedPerHour)
	if type(nMiningSpeedPerHour) ~= "number" then
		return
	end
	local attr = self:GetAttribute()
	attr.currentstate = attr.currentstate or 0
	if attr.currentstate  <= 2 then
		local newState = attr.currentstate + 3
		self:SetState(newState)
	end
	local RightDisk = self:GetObject("RightDisk")
	local speedtext = RightDisk:GetObject("speedtext")
	speedtext:SetText(tostring(nMiningSpeedPerHour).."YB/h")
	local scaleValue = {0, 1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000}
	local nScale = 13
	for i, v in ipairs(scaleValue) do
		if i < #scaleValue and nMiningSpeedPerHour >= v and nMiningSpeedPerHour < scaleValue[i+1] then
			nScale = i
			break
		end
	end
	RightDisk:UpdateSpeed(nScale)
end

function SuspendCtrl_UpdateUserBalance(self, nBalance)
	if type(nBalance) ~= "number" then
		return
	end
	local scaleValue = {0, 10000, 20000, 50000, 100000, 200000, 500000, 1000000, 2000000}
	local nScale = 8
	for i, v in ipairs(scaleValue) do
		if i < #scaleValue and nBalance >= v and nBalance < scaleValue[i+1] then
			nScale = i-1
			break
		end
	end
	local attr = self:GetAttribute()
	attr.linevalue = nScale
	self:UpdateLine(nScale)
	--更新灰色余额
	local LeftGoldBalance = self:GetObject("LeftGoldBalance")
	local goldtextnumber = LeftGoldBalance:GetObject("goldtextnumber")
	local strShow
	if nBalance < 10000 then
		strShow = tostring(nBalance)
	else
		local nInte, nDeci = math.modf(nBalance/10000)
		local nDeciHold = math.floor(nDeci*10)
		strShow = tostring(nInte).."."..tostring(nDeciHold).."w"
	end
	goldtextnumber:SetText(strShow)
end

function SuspendCtrl_UpdateClientUnBindState(self)
	--先将状态变成未工作态
	local attr = self:GetAttribute()
	attr.currentstate = attr.currentstate or 0
	if attr.currentstate  > 2 then
		local newState = attr.currentstate - 3
		self:SetState(newState)
	end
	--更新余额为0
	self:UpdateLine(0)
	--清除速度显示
	local RightDisk = self:GetObject("RightDisk")
	local speedtext = RightDisk:GetObject("speedtext")
	speedtext:SetText("")
	--清除灰色余额
	local LeftGoldBalance = self:GetObject("LeftGoldBalance")
	local goldtextnumber = LeftGoldBalance:GetObject("goldtextnumber")
	goldtextnumber:SetText("")
end

local minWidth = 82
local shadowOffset = 10
function OnLButtonDown(self, x, y)
	local attr = self:GetAttribute()
	--重置点击事件标志位
	LOG("SuspendWnd OnLButtonDown x="..tostring(x)..", y="..tostring(y))
	attr.moveflag = false
	attr.lbtndown = {x, y}
	if not attr.anim then
		attr.hitpoint = {x, y}
		self:SetCaptureMouse(true)
	end
end

function OnLButtonUp(self, x, y)
	local attr = self:GetAttribute()
	LOG("SuspendWnd OnLButtonUp attr.moveflag="..tostring(attr.moveflag)..", attr.lbtndown="..tostring(attr.lbtndown))
	--按下了左键且没有拖动， 弹起时则认为是点击操作
	if not attr.moveflag and attr.lbtndown then
		LOG("SuspendWnd OnLButtonUp can call click")
		local l, t, r, b = self:GetObjPos()
		local width, height = r - l, b - t
		--在右边弹起
		if x >= width - minWidth then
			local RightDisk = self:GetObject("RightDisk")
			RightDisk:Click()
		else
			--在左边的元宝上弹起
			if x >= 28 and x <= 76 and y >= 20 and y <= 63 then
				local LeftGoldBalance = self:GetObject("LeftGoldBalance")
				LeftGoldBalance:Click()
			end
		end
	end
	attr.lbtndown = nil
	attr.hitpoint = nil
	self:SetCaptureMouse(false)
end

function OnInitControl(self)
	self:SetState(0)
end

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
			self:SetState(attr.currentstate >= 3 and 4 or 1)
		--停在左边
		else
			self:SetState(attr.currentstate >= 3 and 5 or 2)
		end
		return
	end
	if attr.lbtndown and attr.lbtndown.x ~= nil and attr.lbtndown.y ~= nil and attr.lbtndown.x ~= x and attr.lbtndown.y ~= y then
		LOG("SuspendWnd OnMouseMove x="..tostring(x)..", y="..tostring(y)..", attr.lbtndown.x="..tostring(attr.lbtndown.x)..", attr.lbtndown.y="..tostring(attr.lbtndown.y))
		attr.moveflag = true
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
	self:SetState(attr.currentstate >= 3 and 3 or 0)
	
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