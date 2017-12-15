local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")

function TipLog(strLog)
	tipUtil:Log("SuspendWnd: " .. tostring(strLog))
end

function PopupInDeskRightTop(self)
	local workleft, worktop, workright, workbottom = Helper.tipUtil:GetWorkArea()
	local wndL, wndT, wndR, wndB = self:GetWindowRect()
	self:Move( workright - 225 - 100, 200, wndR-wndL, wndB-wndT)
	return true
end

function OnCreate(self)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local tSuspend = tFunctionHelper.FetchValueByPath(tUserConfig, {"tWindow", "tSuspend"})
	if type(tSuspend) == "table" and type(tSuspend.nLeft) == "number" and type(tSuspend.nTop) == "number" and type(tSuspend.nWidth) == "number" and type(tSuspend.nHeight) == "number" then
		--写死高和宽
		self:Move(tSuspend.nLeft, tSuspend.nTop, 154, 82)
	else	
		PopupInDeskRightTop(self)
	end
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

local g_bSpeedMeterLeft = true


local UIDecor = function(obj)
	return {
		_obj = obj,
		SetVisible = function(self, isVisible)
			self._obj:SetVisible(isVisible)
			self._obj:SetChildrenVisible(isVisible)
		end, 
		SetAlpha = function(self, value)
			self._obj:SetAlpha(value)
			local child1 = self._obj:GetChildByIndex(0)
			if child1 then
				child1:SetAlpha(value)
			end
		end,
		SetTextColorResID = function(self, value)
			local child1 = self._obj:GetChildByIndex(0)
			if child1 then
				child1:SetTextColorResID(value)
			end
		end,
		SetTextFontResID = function(self, value)
			self._obj:SetTextFontResID(value)
			local child1 = self._obj:GetChildByIndex(0)
			if child1 then
				child1:SetTextFontResID(value)
			end
		end,
		SetZorder = function(self, value)
			self._obj:SetZorder(value)
		end,
		GetZorder = function(self)
			return self._obj:GetZorder()
		end,
		SetText = function(self, value)
			self._obj:SetText(value)
			local child1 = self._obj:GetChildByIndex(0)
			if child1 then
				child1:SetText(value)
			end
		end,
		SetResID = function(self, value)
			self._obj:SetResID(value)
			if value == "suspend-gold-light" then
				self._obj:SetObjPos(0, 13+1, 82, 61+1)
			else
				self._obj:SetObjPos(0, 13, 82, 61)
			end
		end,
	}
end

function GoldBank_Click(self)
	local attr = self:GetAttribute()
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	objHostWnd:BringWindowToTop(true)
end

function GoldBank_SetState(self, state)
	local attr = self:GetAttribute()
	if state == attr.currentstate then
		return
	end
	local needDelay = false
	if (attr.currentstate == nil or attr.currentstate == 0 or attr.currentstate == 3) and (state == 1 or state == 4) then
		needDelay = true
	end
	attr.currentstate = state
	local goldicon = UIDecor(self:GetObject("goldicon"))
	local goldtexthead = UIDecor(self:GetObject("goldtextheadconta"))
	local goldtextnumber = UIDecor(self:GetObject("goldtextnumberconta"))
	if state == 3 then
		self:SetVisible(false)
		self:SetChildrenVisible(false)
		SetShowWndTimer(false)
	else
		self:SetVisible(true)
		self:SetChildrenVisible(true)
	end
end

function SpeedoMeter_Click(self)
	--0未开始正常态，1未开始停右边，2未开始停左边，3开始正常态 4开始停右边， 5开始停左边
	local attr = self:GetAttribute()
	TipLog("SuspendWnd SuspendRightDisk_Click can call click, attr.currentstate="..tostring(attr.currentstate)..", tFunctionHelper.CheckIsWorking()="..tostring(ClientWorkModule:CheckIsWorking()))
	if attr.currentstate == 2 or attr.currentstate == 1 then
		if not ClientWorkModule:CheckIsWorking() then
			UIInterface:SetStateInfoToUser(nil)
			ClientWorkModule:NotifyStart()
			local tStatInfo = {}
			tStatInfo.fu1 = "startworking"
			tStatInfo.fu5 = "ball"
			StatisticClient:SendClickReport(tStatInfo)
		end
	elseif attr.currentstate == 5 or attr.currentstate == 4 then
		if ClientWorkModule:CheckIsWorking() then
			UIInterface:SetStateInfoToUser(nil)
			ClientWorkModule:NotifyQuit()
			local tStatInfo = {}
			tStatInfo.fu1 = "stopworking"
			tStatInfo.fu5 = "ball"
			StatisticClient:SendClickReport(tStatInfo)
		end
	end
end

function SpeedoMeter_SetState(self, state)
	local attr = self:GetAttribute()
	if state == attr.currentstate then
		return
	end
	attr.currentstate = state
	local objSpeedoMeterGray = self:GetObject("SpeedoMeterGray")
	local objStart = objSpeedoMeterGray:GetObject("SpeedoMeterGray.Start")
	local objSpeedoMeterLight = self:GetObject("SpeedoMeterLight")
	local objStop = objSpeedoMeterLight:GetObject("SpeedoMeterLight.Stopicon")
	local objOwner = self:GetOwnerControl()
	if state == 0 then
		objSpeedoMeterGray:SetVisible(false)
		objSpeedoMeterGray:SetChildrenVisible(false)
		objSpeedoMeterLight:SetVisible(false)
		objSpeedoMeterLight:SetChildrenVisible(false)
	elseif (not g_bSpeedMeterLeft and state == 2)
		or (g_bSpeedMeterLeft and state == 1) then
		objSpeedoMeterLight:SetVisible(false)
		objSpeedoMeterLight:SetChildrenVisible(false)
		objSpeedoMeterGray:SetVisible(true)
		objSpeedoMeterGray:SetChildrenVisible(true)
		objStart:SetVisible(false)
	elseif (not g_bSpeedMeterLeft and state == 1)
		or (g_bSpeedMeterLeft and state == 2) then
		objSpeedoMeterLight:SetVisible(false)
		objSpeedoMeterLight:SetChildrenVisible(false)
		objSpeedoMeterGray:SetVisible(true)
		objSpeedoMeterGray:SetChildrenVisible(true)
		objStart:SetVisible(true)
	elseif state == 3 then
		objSpeedoMeterGray:SetVisible(false)
		objSpeedoMeterGray:SetChildrenVisible(false)
		objSpeedoMeterLight:SetVisible(true)
		objSpeedoMeterLight:SetChildrenVisible(true)
		objStop:SetVisible(false)
	elseif (not g_bSpeedMeterLeft and state == 5)
		or (g_bSpeedMeterLeft and state == 4) then
		objSpeedoMeterGray:SetVisible(false)
		objSpeedoMeterGray:SetChildrenVisible(false)
		objSpeedoMeterLight:SetVisible(true)
		objSpeedoMeterLight:SetChildrenVisible(true)
		objStop:SetVisible(false)
	elseif (not g_bSpeedMeterLeft and state == 4)
		or (g_bSpeedMeterLeft and state == 5) then
		TipLog("[SpeedoMeter_SetState] state = " .. tostring(state) .. ", g_bSpeedMeterLeft = " .. tostring(g_bSpeedMeterLeft))
		objSpeedoMeterGray:SetVisible(false)
		objSpeedoMeterGray:SetChildrenVisible(false)
		objSpeedoMeterLight:SetVisible(true)
		objSpeedoMeterLight:SetChildrenVisible(true)
		objStop:SetVisible(true)
	end
	--重置指针
	if state < 3 then
		self:UpdateSpeed(1)
	end
end

function SpeedoMeter_UpdateSpeed(self, nspeed)
	if type(nspeed) ~= "number" or nspeed < 1 or nspeed > 13 then
		return
	end
	local attr = self:GetAttribute()
	if not attr.currentspeed then
		attr.currentspeed = 1
	end
	if attr.currentspeed == nspeed then
		return
	end
	local needleobj = self:GetObject("SpeedoMeterLight:SpeedoMeterLight.Needle")
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
	local SpeedoMeter = self:GetObject("SpeedoMeter")
	local GoldBank = strip:GetObject("GoldBank")
	SpeedoMeter:SetState(state)
	GoldBank:SetState(state)
	if state == 0 then
		GoldBank:SetObjPos(0, 0, 82, "father.height")
	else
		TipLog("[SuspendCtrl_SetState] state = " .. tostring(state) .. ",  CheckIsSpeedMeterLeft = " .. tostring(g_bSpeedMeterLeft))
		--GoldBank:SetObjPos(10, 0, 82, "father.height")
		if not g_bSpeedMeterLeft then
			GoldBank:SetObjPos(10, 0, 82, "father.height")
		else
			GoldBank:SetObjPos(67, 0, 139, "father.height")
		end
	end
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

--1:正在运行,2:不在运行t
function SuspendCtrl_OnWorkStateChange(self)
	local attr = self:GetAttribute()
	attr.currentstate = attr.currentstate or 0
	local SpeedoMeter = self:GetObject("SpeedoMeter")
	local speedtext = SpeedoMeter:GetObject("SpeedoMeterLight.SpeedText")
	if ClientWorkModule:CheckIsWorking() then
		if attr.currentstate  <= 2 then
			local newState = attr.currentstate + 3
			self:SetState(newState)
		end
		speedtext:SetText("准备中")
	else
		if attr.currentstate  >= 3 then
			local newState = attr.currentstate - 3
			self:SetState(newState)
		end
	end
end

function SuspendCtrl_UpdateMiningState(self, nMiningState)
	local attr = self:GetAttribute()
	attr.currentstate = attr.currentstate or 0
	local SpeedoMeter = self:GetObject("SpeedoMeter")
	local speedtext = SpeedoMeter:GetObject("SpeedoMeterLight.SpeedText")
	if ClientWorkModule:CheckIsCalculate() then
		speedtext:SetText("0¥฿/h")
	elseif ClientWorkModule:CheckIsPrepare() then
		if attr.currentstate  <= 2 then
			local newState = attr.currentstate + 3
			self:SetState(newState)
		end
		speedtext:SetText("准备中")
		SpeedoMeter:UpdateSpeed(1)
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
	local SpeedoMeter = self:GetObject("SpeedoMeter")
	local speedtext = SpeedoMeter:GetObject("SpeedoMeterLight.SpeedText")
	speedtext:SetText(tostring(nMiningSpeedPerHour).."¥฿/h")
	local scaleValue = {0, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000}
	local nScale = 13
	for i, v in ipairs(scaleValue) do
		if i < #scaleValue and nMiningSpeedPerHour >= v and nMiningSpeedPerHour < scaleValue[i+1] then
			nScale = i
			break
		end
	end
	SpeedoMeter:UpdateSpeed(nScale)
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
	local GoldBank = self:GetObject("GoldBank")
	local goldtextnumber = UIDecor(GoldBank:GetObject("goldtextnumberconta"))
	local strShow
	if nBalance < 10000 then
		strShow = tostring(nBalance)
	else
		local nInte, nDeci = math.modf(nBalance/10000)
		if nInte >= 1000 then
			strShow = "999+w"
		elseif nInte >=100 then
			strShow = tostring(nInte).."w"
		elseif nInte >=10 then
			local nDeciHold = math.floor(nDeci*10)
			strShow = tostring(nInte)
			if nDeciHold > 0 then
				strShow = strShow.."."..tostring(nDeciHold)
			end
			strShow = strShow.."w"
		else
			local nDeciHold = math.floor(nDeci*100)
			strShow = tostring(nInte)
			if nDeciHold > 0 then
				strShow = strShow.."."..string.format("%02d", nDeciHold)
			end
			strShow = strShow.."w"
		end
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
	attr.linevalue = 0
	self:UpdateLine(0)
	--清除速度显示
	local SpeedoMeter = self:GetObject("SpeedoMeter")
	local speedtext = SpeedoMeter:GetObject("SpeedoMeterLight.SpeedText")
	speedtext:SetText("")
	--清除灰色余额
	local GoldBank = self:GetObject("GoldBank")
	local goldtextnumber = UIDecor(GoldBank:GetObject("goldtextnumberconta"))
	goldtextnumber:SetText("0")
end

local minWidth = 82
local shadowOffset = 10
function OnLButtonDown(self, x, y)
	local attr = self:GetAttribute()
	--重置点击事件标志位
	TipLog("SuspendWnd OnLButtonDown x="..tostring(x)..", y="..tostring(y))
	attr.moveflag = false
	attr.lbtndown = {x, y}
	if not attr.anim then
		attr.hitpoint = {x, y}
		self:SetCaptureMouse(true)
	end
end

function OnLButtonUp(self, x, y)
	local attr = self:GetAttribute()
	TipLog("SuspendWnd OnLButtonUp attr.moveflag="..tostring(attr.moveflag)..", attr.lbtndown="..tostring(attr.lbtndown))
	--按下了左键且没有拖动， 弹起时则认为是点击操作
	if not attr.moveflag and attr.lbtndown then
		TipLog("SuspendWnd OnLButtonUp can call click")
		local l, t, r, b = self:GetObjPos()
		local width, height = r - l, b - t
		--在右边弹起
		TipLog("[OnLButtonUp] g_bSpeedMeterLeft = "..tostring(g_bSpeedMeterLeft)..", x="..tostring(x))
		if (g_bSpeedMeterLeft and x <= width - minWidth) 
			 or (not g_bSpeedMeterLeft and x >= minWidth) then
			local SpeedoMeter = self:GetObject("SpeedoMeter")
			SpeedoMeter:Click()
		else
			--在左边的元宝上弹起
			--[[
			if x >= 90 and x <= 118 and y >= 22 and y <= 54 then
				local GoldBank = self:GetObject("GoldBank")
				GoldBank:Click()
			end
			--]]
			local GoldBank = self:GetObject("GoldBank")
			GoldBank:Click()
		end
	end
	attr.lbtndown = nil
	attr.hitpoint = nil
	self:SetCaptureMouse(false)
end

function OnInitControl(self)
	self:SetState(0)
end

function SaveWindowPos(l, t, w, h)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	--local tSuspend = FetchValueByPath(tUserConfig, {"tWindow", "tSuspend"})
	tUserConfig["tWindow"] = tUserConfig["tWindow"] or {}
	tUserConfig["tWindow"]["tSuspend"] = tUserConfig["tWindow"]["tSuspend"] or {}
	tUserConfig["tWindow"]["tSuspend"].nLeft = l
	tUserConfig["tWindow"]["tSuspend"].nTop = t
	--这里写死高和宽
	tUserConfig["tWindow"]["tSuspend"].nWidth  = 154  
	tUserConfig["tWindow"]["tSuspend"].nHeight = 82
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
end

local g_ShowWndTimerId = nil
function SetShowWndTimer(bSet)
	if bSet then
		if g_ShowWndTimerId then
			return
		end
		g_ShowWndTimerId = timeMgr:SetTimer(function(Itm, id)
			timeMgr:KillTimer(g_ShowWndTimerId)
			g_ShowWndTimerId = nil
			local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
			objHostWnd:BringWindowToTop(true)
		end,2*1000)
	else
		if not g_ShowWndTimerId then
			return
		end
		timeMgr:KillTimer(g_ShowWndTimerId)
		g_ShowWndTimerId = nil
	end	
end

function OnMouseMove(self, x, y)
	CheckStripAnim(self, false, x, y)
	local attr = self:GetAttribute()
	--自己处理离开事件
	--[[local L, T, R, B = self:GetObjPos()
	local W, H = R-L, B-T
	TipLog("x="..tostring(x)..", y="..tostring(y)..", W="..tostring(W)..", H="..tostring(H))
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
		if (g_bSpeedMeterLeft and x >= width-minWidth ) 
			 or (not g_bSpeedMeterLeft and x >= minWidth) then
			self:SetState(attr.currentstate >= 3 and 4 or 1)
			if g_bSpeedMeterLeft and x >= width-minWidth then
				SetShowWndTimer(true)
			else
				SetShowWndTimer(false)
			end
		--停在左边
		else
			self:SetState(attr.currentstate >= 3 and 5 or 2)
			if g_bSpeedMeterLeft and x < width-minWidth then
				SetShowWndTimer(false)
			else
				SetShowWndTimer(true)
			end
		end
		return
	end
	if attr.lbtndown and  attr.lbtndown[1] ~= x and attr.lbtndown[2] ~= y then
		TipLog("SuspendWnd OnMouseMove x="..tostring(x)..", y="..tostring(y)..", attr.lbtndown.x="..tostring(attr.lbtndown.x)..", attr.lbtndown.y="..tostring(attr.lbtndown.y))
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
	local saveL, saveT, saveR, saveB = tarL, tarT, tarR, tarB
	if tarL < workleft then
		tarR = tarR + workleft - tarL
		tarL = workleft
		--
		saveL = tarL + 1
		saveR = tarR + 1
	elseif tarR > workright then
		tarL = math.floor(tarL - (tarR - workright))
		tarR = workright
		--
		saveL = tarL - 1
		saveR = tarR - 1
	end
	if tarT < worktop then
		tarB = tarB + worktop - tarT
		tarT = worktop
		--
		saveB = tarB + 1
		saveT = tarT + 1
	elseif tarB > workbottom then
		tarT = tarT - (tarB - workbottom)
		tarB = workbottom
		--
		saveB = tarB - 1
		saveT = tarT - 1
	end
	wnd:Move(tarL, tarT, tarR - tarL, tarB - tarT)
	SaveWindowPos(saveL, saveT, saveR - saveL, saveB - saveT)
end

function OnMouseLeave(self)
	--鼠标没弹起不处理离开事件
	SetShowWndTimer(false)
	local attr = self:GetAttribute()
	if attr.hitpoint then
		return
	end
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
				--当动画还没放完时鼠标已经离开了，无法触发离开事件了， 所以需要主动判断并调用OnMouseLeave
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
		local SpeedoMeter = strip:GetObject("SpeedoMeter")
		--local smL, smT, smR, smB = SpeedoMeter:GetObjPos()
		local GoldBank = strip:GetObject("GoldBank")
		--local gbL, gbT, gbR, gbB = GoldBank:GetObjPos()
		if attr.currentstate == 0 then
			g_bSpeedMeterLeft = false
			GoldBank:SetObjPos2(0, 0, 82, "father.height")
			SpeedoMeter:SetObjPos2("father.width-82", 0, 82, "father.height")
		else
			g_bSpeedMeterLeft = true
			GoldBank:SetObjPos2("father.width-82", 0, 82, "father.height")
			SpeedoMeter:SetObjPos2(0, 0, 82, "father.height")
			
		end
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
			else
				--再处理一次缩回时隐藏圆盘
				self:SetState(attr.currentstate >= 3 and 3 or 0)
			end
		end
	end
	attr.animstrip:AttachListener(true,onAniFinish)
	attr.animstrip:Resume()
end