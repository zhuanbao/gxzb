local tipUtil = XLGetObject("API.Util")
local FunctionObj = XLGetGlobal("Global.FunctionHelper")

function PopupInDeskRightTop(self)
	local objtree = self:GetBindUIObjectTree()
	local objRootLayout = objtree:GetUIObject("root")
    local templateMananger = XLGetObject("Xunlei.UIEngine.TemplateManager")
	
	local nLayoutL, nLayoutT, nLayoutR, nLayoutB = objRootLayout:GetObjPos()
	local nLayoutWidth = nLayoutR - nLayoutL
	local nLayoutHeight = nLayoutB - nLayoutT
	
	local workleft, worktop, workright, workbottom = Helper.tipUtil:GetWorkArea()
	self:Move( workright - nLayoutWidth - 100, 200, nLayoutWidth, nLayoutHeight)
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

function OnRButtonUpXuanFu(self)
	local tree = self:GetOwner()
	local wnd = tree:GetBindHostWnd()
	local curX, curY = Helper.tipUtil:GetCursorPos()
	local menuTable = GXZBMenu.SettingMenu.menuTable
	local menuFunTable = GXZBMenu.SettingMenu.menuFunTable
	local userData = {}
	Helper:CreateMenu(curX-50, curY+10, wnd:GetWndHandle(), menuTable, menuFunTable, userData)
end

function OnLButtonDbClickXuanFu(self, x, y)
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZBTipWnd.MainFrame")
	objHostWnd:Show(1)
end

local staypos = "null"
function OnLButtonDownXuanFu(self)
	local caption = self:GetObject("tree:XuanFuWnd.Caption")
	if caption and not caption:GetCaption() then
		caption:SetCaption(true)
	end
	staypos = "null"
end


function OnMouseMoveXuanFu(self, x, y)
	--[[local l, t, r, b = self:GetObjPos()
	if x < 0 or y < 0 or x > r-l or y > b-t then
		return
	end]]
	local workleft, worktop, workright, workbottom = Helper.tipUtil:GetWorkArea()
	local tree = self:GetOwner()
	local wnd = tree:GetBindHostWnd() 
	local wndL, wndT, wndR, wndB = wnd:GetWindowRect()
	local wndW, wndH = wndR - wndL, wndB - wndT
	--FunctionObj.TipLog("OnMouseMoveXuanFu workleft = "..tostring(workleft)..", worktop = "..tostring(worktop)..", wndL = "..wndL..", wndT = "..wndT)
	if wndL < workleft then
		wndL = workleft - wndW/2
		staypos = "left"
	end
	if wndR > workright then
		wndL = workright - wndW/2
		staypos = "right"
	end
	if wndT <= worktop then
		wndT = worktop - wndH/2
		staypos = "top"
	end
	if wndB >= workbottom then
		wndT = workbottom - wndH/2
		staypos = "bottom"
	end
	--[[if staypos ~= "null" then
		local caption = self:GetObject("tree:XuanFuWnd.Caption")
		if caption and caption:GetCaption() then
			caption:SetCaption(false)
		end
	end]]
	wnd:Move(wndL, wndT, wndW, wndH)
end

function OnMouseLeaveXuanFu(self, x, y)
	local tree = self:GetOwner()
	local wnd = tree:GetBindHostWnd() 
	local wndL, wndT, wndR, wndB = wnd:GetWindowRect()
	local wndW, wndH = wndR - wndL, wndB - wndT
	if staypos == "left" then
		wnd:Move(wndL - wndW*0.3 , wndT, wndW, wndH)
	elseif staypos == "top" then
		wnd:Move(wndL, wndT - wndH*0.3, wndW, wndH)
	elseif staypos == "right" then
		wnd:Move(wndL + wndW*0.3, wndT, wndW, wndH)
	end
	staypos = "null"
end