local tFunctionHelper = XLGetGlobal("FunctionHelper")
local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
local g_CheckBoxState = true
--[[
local strAutoRunRegPath = "HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\Share4Money"

function CheckIsAutoRun()
	local strValue = Helper:QueryRegValue(strAutoRunRegPath)
	if Helper:IsRealString(strValue) then
		return true
	end
	return false
end

function SetAutoRun()
	local strExePath = tFunctionHelper.GetExePath()
	local strValue = "\""..strExePath.."\" /sstartfrom sysboot /embedding /mining"
	Helper:SetRegValue(strAutoRunRegPath, strValue)
end
--]]

function DoWorkOnHideWnd()
	if g_CheckBoxState then	
		tFunctionHelper.WriteCfgSetBoot()
		tFunctionHelper.WriteSysSetBoot()
	end	
end

function OnClickClose(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:Show(0)
	DoWorkOnHideWnd()
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

function OnClickBind(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:Show(0)
	local mainwnd = UIInterface:GetMainHostWnd()
	if mainwnd then
		mainwnd:BringWindowToTop(true)
	end
	UIInterface:ChangeMainBodyPanel("QRCodePanel")
	local tStatInfo = {}
	tStatInfo.fu1 = "showpanel"
	tStatInfo.fu5 = "qrcode"
	tStatInfo.fu6 = "autorun"
	StatisticClient:SendClickReport(tStatInfo)
	DoWorkOnHideWnd()
end

function OnSelectAutoRun(self, event, bSelect)
	local tStatInfo = {}
	if bSelect then
		g_CheckBoxState = true
		tStatInfo.fu5 = 1
	else
		g_CheckBoxState = false
		tStatInfo.fu5 = 0
	end	
	tStatInfo.fu1 = "autorun"
	tStatInfo.fu6 = "autorunwnd"
	StatisticClient:SendClickReport(tStatInfo)
end

function OnShowWindow(self, bShow)
	if bShow then
		if not UIInterface:CheckIsInitPopupTipWnd() then
			return
		end
		local objtree = self:GetBindUIObjectTree()
		PopupInDeskRight(self)
		
		local objIcon = objtree:GetUIObject("AutoRunTipWnd.Icon")
		local objTextContentBegain = objtree:GetUIObject("AutoRunTipWnd.Content.Begain")
		local objTextContentDesc = objtree:GetUIObject("AutoRunTipWnd.Content.Desc")
		local objTextBind = objtree:GetUIObject("AutoRunTipWnd.Bind")
		local objCheckAutoRun = objtree:GetUIObject("AutoRunTipWnd.CheckAutoRun")
		if ClientWorkModule:CheckIsBinded() then
			objTextContentBegain:SetObjPos(160, 92+20, 160+310, 92+20+20)
			objTextContentDesc:SetObjPos(160, 92+20+20, 160+310, 92+20+20+20)
			objTextBind:SetChildrenVisible(false)
			objTextBind:SetVisible(false)
		else
			objTextContentBegain:SetObjPos(160, 92+10, 160+310, 92+10+20)
			objTextContentDesc:SetObjPos(160, 92+10+20, 160+310, 92+10+20+20)
			objTextBind:SetObjPos(160, 92+10+20+20, 160+310, 92+10+20+20+20)
			objTextBind:SetChildrenVisible(true)
			objTextBind:SetVisible(true)
		end
		if tFunctionHelper.CheckSysSetBoot() then
			g_CheckBoxState = false
			objCheckAutoRun:SetCheck(false, true)
			objCheckAutoRun:SetChildrenVisible(false)
			objCheckAutoRun:SetVisible(false)
		else
			g_CheckBoxState = true
			objCheckAutoRun:SetCheck(false, true)
			objCheckAutoRun:SetChildrenVisible(true)
			objCheckAutoRun:SetVisible(true)
		end
		local nTipHolds = tonumber(ServerCfg:GetServerCfgData({"tRemindCfg","nHolds"})) or 10
		SetOnceTimer(function(item, id)
			self:Show(0)
			DoWorkOnHideWnd()
		end, nTipHolds*1000)
	end
end