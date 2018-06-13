local tipUtil = XLGetObject("API.Util")
local gRootCtrl = nil
local tFunctionHelper = XLGetGlobal("FunctionHelper")

function OnClose( self )
	self:Show(0)
	return 0, true
end


function OnMouseLeave(self, x, y)

end

function OnShowWindow(self, bShow)
	if bShow then
		local objTree = self:GetBindUIObjectTree()
		local objRootLayout = objTree:GetUIObject("MainWndCtrl")
		local objLater = objRootLayout:GetControlObject("RootCtrl.Content.Later")
		objLater:Show(false)
    end   
end


function PopupInDeskMiddle(self)
	local objTree = self:GetBindUIObjectTree()
	local objRootLayout = objTree:GetUIObject("MainWndCtrl")
    local templateMananger = XLGetObject("Xunlei.UIEngine.TemplateManager")
	
	local nLayoutL, nLayoutT, nLayoutR, nLayoutB = objRootLayout:GetObjPos()
	local nLayoutWidth = nLayoutR - nLayoutL
	local nLayoutHeight = nLayoutB - nLayoutT
	
	local workleft, worktop, workright, workbottom = tipUtil:GetWorkArea()
	self:Move( (workright - nLayoutWidth)/2, (workbottom - nLayoutHeight)/2, nLayoutWidth, nLayoutHeight)

	return true
end

function OnCreate( self )
	PopupInDeskMiddle(self)
end


function OnDestroy( self )
	local objTree = self:GetBindUIObjectTree()
	if objTree ~= nil then
		self:UnbindUIObjectTree()
		local objtreeManager = XLGetObject("Xunlei.UIEngine.TreeManager")
		objtreeManager:DestroyTree(objTree)
	end
	local wndId = self:GetID()
	if wndId ~= nil then
		local hostwndManager = XLGetObject("Xunlei.UIEngine.HostWndManager")
		local tempWnd = hostwndManager:GetHostWnd(wndId)
		if tempWnd then
			hostwndManager:RemoveHostWnd(wndId)
		end
	end
end

