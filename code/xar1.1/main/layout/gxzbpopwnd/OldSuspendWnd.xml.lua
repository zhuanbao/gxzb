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

local gPosAnim = nil
function MoveWithAnimi(obj, xOffset, yOffset)
	if not obj or (xOffset == 0 and yOffset == 0) then
		return 
	end
	if gPosAnim then
		return
		--gPosAnim:ForceStop()
	end
	local caption = obj:GetObject("tree:SuspendWnd.Caption")
	if caption and not caption:GetCaption() then
		caption:SetCaption(false)
	end
	local sl, st, sr, sb = obj:GetObjPos()
	local dl, dt, dr, db = sl + xOffset, st + yOffset, sr + xOffset, sb + yOffset
	local aniFactory = XLGetObject("Xunlei.UIEngine.AnimationFactory")
	gPosAnim = aniFactory:CreateAnimation("PosChangeAnimation")
	gPosAnim:SetTotalTime(300)
	gPosAnim:BindLayoutObj(obj)
	gPosAnim:SetKeyFrameRect(sl, st, sr, sb, dl, dt, dr, db)
	local ownerTree = obj:GetOwner()
	ownerTree:AddAnimation(gPosAnim)
	local wnd = ownerTree:GetBindHostWnd() 
	local wndL, wndT, wndR, wndB = wnd:GetWindowRect()
	function onAniFinish(ani,old,new)
		if new == 4 or new == 3 then
			wnd:Move(wndL + xOffset, wndT + yOffset, wndR-wndL, wndB-wndT)
			obj:SetObjPos(sl, st, sr, sb)
			caption:SetCaption(true)
			gPosAnim = nil
		end
	end
	gPosAnim:AttachListener(true,onAniFinish)
	gPosAnim:Resume()
end

local staypos = "null"
function OnLButtonDownSuspend(self)
	local caption = self:GetObject("tree:SuspendWnd.Caption")
	if caption and not caption:GetCaption() then
		caption:SetCaption(true)
	end
	if gPosAnim then
		gPosAnim:Stop()
	end
	staypos = "null"
end

function OnMouseMoveSuspend(self, x, y)
	--[[local l, t, r, b = self:GetObjPos()
	if x < 0 or y < 0 or x > r-l or y > b-t then
		return
	end]]
	local workleft, worktop, workright, workbottom = Helper.tipUtil:GetWorkArea()
	local tree = self:GetOwner()
	local wnd = tree:GetBindHostWnd() 
	local wndL, wndT, wndR, wndB = wnd:GetWindowRect()
	wndL = wndL + 75
	wndR = wndR - 75
	wndB = wndB - 75
	local wndW, wndH = wndR - wndL, wndB - wndT
	--FunctionObj.TipLog("OnMouseMoveSuspend workleft = "..tostring(workleft)..", worktop = "..tostring(worktop)..", wndL = "..wndL..", wndT = "..wndT)
	local xoffset, yoffset = 0, 0
	if wndL < workleft then
		xoffset = workleft - wndW/2 - wndL
		staypos = "left"
	end
	if wndR > workright then
		xoffset = workright - wndW/2 - wndL
		staypos = "right"
	end
	if wndT <= worktop then
		yoffset = worktop - wndH/2 - wndT
		staypos = "top"
	end
	if wndB >= workbottom then
		yoffset = workbottom - wndH/2 - wndT
		staypos = "bottom"
	end
	--[[if staypos ~= "null" then
		local caption = self:GetObject("tree:SuspendWnd.Caption")
		if caption and caption:GetCaption() then
			caption:SetCaption(false)
		end
	end]]
	if xoffset ~= 0 or yoffset ~= 0 then
		MoveWithAnimi(self, xoffset, yoffset)
	end
	--wnd:Move(wndL, wndT, wndW, wndH)
end

local timeridLeave = nil
function OnMouseLeaveSuspend(self, x, y)
	local tree = self:GetOwner()
	local wnd = tree:GetBindHostWnd() 
	local wndL, wndT, wndR, wndB = wnd:GetWindowRect()
	wndL = wndL + 75
	wndR = wndR - 75
	wndB = wndB - 75
	local wndW, wndH = wndR - wndL, wndB - wndT
	local workleft, worktop, workright, workbottom = Helper.tipUtil:GetWorkArea()
	if timeridLeave then
		KillTimer(timeridLeave)
		timeridLeave = nil
	end
	local xoffset, yoffset = 0, 0
	if staypos == "left" and wndL >= -wndW*0.6 then
		xoffset = -wndW*0.3
		timeridLeave = SetTimer(
			function(item, id) 
				if not gPosAnim then 
					item:KillTimer(id)
					timeridLeave = nil
					wndL, wndT, wndR, wndB = wnd:GetWindowRect()
					wndL = wndL + 75
					wndR = wndR - 75
					wndB = wndB - 75
					wndW, wndH = wndR - wndL, wndB - wndT
					if wndL >= -wndW*0.6 then
						MoveWithAnimi(self, xoffset, yoffset)
					end
				end
			end, 100)
	elseif staypos == "top" and wndT >= -wndH*0.6 then
		yoffset = -wndH*0.3
		timeridLeave = SetTimer(
			function(item, id) 
				if not gPosAnim then 
					item:KillTimer(id)
					timeridLeave = nil
					wndL, wndT, wndR, wndB = wnd:GetWindowRect()
					wndL = wndL + 75
					wndR = wndR - 75
					wndB = wndB - 75
					wndW, wndH = wndR - wndL, wndB - wndT
					if wndT >= -wndH*0.6 then
						MoveWithAnimi(self, xoffset, yoffset)
					end
				end
			end, 100)
	elseif staypos == "right" and wndL <= workright - wndW*0.4 then
		xoffset = wndW*0.3
		timeridLeave = SetTimer(
			function(item, id) 
				if not gPosAnim then 
					item:KillTimer(id)
					timeridLeave = nil
					wndL, wndT, wndR, wndB = wnd:GetWindowRect()
					wndL = wndL + 75
					wndR = wndR - 75
					wndB = wndB - 75
					wndW, wndH = wndR - wndL, wndB - wndT
					if wndL <= workright - wndW*0.4 then
						MoveWithAnimi(self, xoffset, yoffset)
					end
				end
			end, 100)
	end
	staypos = "null"
end