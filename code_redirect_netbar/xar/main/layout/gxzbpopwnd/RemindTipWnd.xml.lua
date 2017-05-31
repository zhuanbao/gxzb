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

function OnClickBindBtn(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:Show(0)
	local mainwnd = tFunctionHelper.GetMainHostWnd()
	if mainwnd then
		mainwnd:BringWindowToTop(true)
	end
	tFunctionHelper.ChangeMainBodyPanel("QRCodePanel")
end

function OnShowWindow(self, bShow)
	if bShow then
		local objtree = self:GetBindUIObjectTree()
		PopupInDeskRight(self)
		
		local TextContent = objtree:GetUIObject("RemindTipWnd.Content")
		local bindbtn = objtree:GetUIObject("RemindTipWnd.Bind.Btn")
		local icon = objtree:GetUIObject("RemindTipWnd.Icon")
		local nMoneyCount = tUserConfig["nMoneyPer4Hour"] or 0
		if tFunctionHelper.CheckIsBinded() then
			if tonumber(nMoneyCount) and nMoneyCount > 0 then
				icon:SetObjPos(54, 92, 54+80, 92+80)
				TextContent:SetObjPos(160, 113, 160+310, 113+40)
				TextContent:SetText("你很努力哟， 又赚取了"..tostring(nMoneyCount).."个元宝，\n继续加油！")
				bindbtn:Show(false)
			else
				self:Show(0)
			end
		else
			if tonumber(nMoneyCount) and nMoneyCount > 0 then
				icon:SetObjPos(54, 84, 54+80, 84+80)
				TextContent:SetObjPos(160, 102, 160+310, 102+40)
				TextContent:SetText("你很努力哟， 又赚取了"..tostring(nMoneyCount).."个元宝。\n收益可以通过微信红包提现，请立即绑定。")
				bindbtn:Show(true)
			else
				self:Show(0)
			end
		end
		local nTipHolds = 15
		if type(g_ServerConfig) == "table" and type(g_ServerConfig["tRemindCfg"]) == "table" and type(g_ServerConfig["tRemindCfg"]["nHolds"]) == "number" then
			nTipHolds = g_ServerConfig["tRemindCfg"]["nHolds"]
		end
		SetOnceTimer(function(item, id)
			self:Show(0)
		end, nTipHolds*1000)
	end
end