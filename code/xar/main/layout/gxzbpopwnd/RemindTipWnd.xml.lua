local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}

function OnClickClose(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:Show(0)
end

function PopupInDeskRight(self)
	local objtree = self:GetBindUIObjectTree()
	local objRootLayout = objtree:GetUIObject("root")
    local templateMananger = XLGetObject("Xunlei.UIEngine.TemplateManager")
	
	local nLayoutL, nLayoutT, nLayoutR, nLayoutB = objRootLayout:GetObjPos()
	local nLayoutWidth = nLayoutR - nLayoutL
	local nLayoutHeight = nLayoutB - nLayoutT
	
	local workleft, worktop, workright, workbottom = Helper.tipUtil:GetWorkArea()
	self:Move( workright - nLayoutWidth, workbottom - nLayoutHeight, nLayoutWidth, nLayoutHeight)
	return true
end

function OnShowWindow(self, bShow)
	if bShow then
		local objtree = self:GetBindUIObjectTree()
		PopupInDeskRight(self)
		
		local TextContent = objtree:GetUIObject("RemindTipWnd.Content")
		local nMoneyCount = tUserConfig["nMoneyPer4Hour"] or 0
		if tonumber(nMoneyCount) and nMoneyCount > 0 then
			TextContent:SetText("你很努力哟， 又赚取了"..tostring(nMoneyCount).."个\n元宝， 加油！")
		else
			self:Show(0)
		end
		SetOnceTimer(function(item, id)
			self:Show(0)
		end, 15000)
	end
end