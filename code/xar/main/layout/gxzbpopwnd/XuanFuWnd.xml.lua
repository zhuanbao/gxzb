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