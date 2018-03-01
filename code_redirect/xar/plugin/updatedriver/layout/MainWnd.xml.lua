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
		
    end   
end


function PopupInDeskMiddle(self)
	local objtree = self:GetBindUIObjectTree()
	local objRootLayout = objtree:GetUIObject("MainWndCtrl")
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
	local objtree = self:GetBindUIObjectTree()
	if objtree ~= nil then
		self:UnbindUIObjectTree()
		local objtreeManager = XLGetObject("Xunlei.UIEngine.TreeManager")
		objtreeManager:DestroyTree(objtree)
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

