local tFunctionHelper = XLGetGlobal("FunctionHelper")
local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")
local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
local g_CheckBoxState = true

function OnMouseEnter(self)
	local objBtnHover = self:GetObject("BtnHover")
	if not objBtnHover then
		objBtnHover = objFactory:CreateUIObject("BtnHover", "ImageObject")
		self:AddChild(objBtnHover)
		objBtnHover:SetObjPos(-5, -9, 20, -6)
		objBtnHover:SetResID("GXZB.PopUpWnd.Btn.Hover")
	end
	objBtnHover:SetVisible(true)
end

function OnMouseLeave(self)
	local objBtnHover = self:GetObject("BtnHover")
	if objBtnHover then
		objBtnHover:SetVisible(false)
	end
end

function DoWorkOnHideWnd()
	if g_CheckBoxState then	
		tFunctionHelper.WriteCfgSetBoot()
		tFunctionHelper.WriteSysSetBoot()
	end	
end

function OnClickClose(self)
	Helper:DestoryModelessWnd("GXZB.IncomeRemindTipWnd")
	DoWorkOnHideWnd()
end

function OnClickCancel(self)
	Helper:DestoryModelessWnd("GXZB.IncomeRemindTipWnd")
	DoWorkOnHideWnd()
end

function PopupInDeskRight(self)
	local objtree = self:GetBindUIObjectTree()
	local objRootLayout = objtree:GetUIObject("IncomeRemindTipWnd.Content")
    local templateMananger = XLGetObject("Xunlei.UIEngine.TemplateManager")
	
	local nLayoutL, nLayoutT, nLayoutR, nLayoutB = objRootLayout:GetObjPos()
	local nLayoutWidth = nLayoutR - nLayoutL
	local nLayoutHeight = nLayoutB - nLayoutT
	
	local workleft, worktop, workright, workbottom = Helper.tipUtil:GetWorkArea()
	self:Move( workright - nLayoutWidth, workbottom - nLayoutHeight, nLayoutWidth, nLayoutHeight)
	return true
end

function OnClickBind(self)
	--[[
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:Show(0)
	--]]
	Helper:DestoryModelessWnd("GXZB.IncomeRemindTipWnd")
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
		local objTree = self:GetBindUIObjectTree()
		PopupInDeskRight(self)
		local nMoneyCount = tUserConfig["nMoneyPer4Hour"] or 0
		if tonumber(nMoneyCount) == nil or nMoneyCount <= 0 then 
			--self:Show(0)
			Helper:DestoryModelessWnd("GXZB.IncomeRemindTipWnd")
			return
		end
		
		local objDesc = objTree:GetUIObject("IncomeRemindTipWnd.Desc")
		local objCheckAutoRun = objTree:GetUIObject("IncomeRemindTipWnd.CheckAutoRun")
		local objCancel = objTree:GetUIObject("IncomeRemindTipWnd.Cancel")
		local objBind = objTree:GetUIObject("IncomeRemindTipWnd.Bind")
		local strText = ""
		if ClientWorkModule:CheckIsBinded() then
			strText = "哇~又赚了" .. tostring(nMoneyCount) .. "个元宝，\r\n继续加油保存哟~"
			objCancel:Show(false)
			objBind:Show(false)
		else
			strText = "哇~您已赚取了" .. tostring(nMoneyCount) .. "个元宝，\r\n绑定微信一秒提现到账。"
			objCancel:Show(true)
			objBind:Show(true)
		end
		objDesc:SetText(strText)
		if tFunctionHelper.CheckSysSetBoot() then
			g_CheckBoxState = false
			objCheckAutoRun:SetCheck(false, true)
			objCheckAutoRun:SetChildrenVisible(false)
			objCheckAutoRun:SetVisible(false)
		else
			g_CheckBoxState = true
			objCheckAutoRun:SetCheck(true, true)
			objCheckAutoRun:SetChildrenVisible(true)
			objCheckAutoRun:SetVisible(true)
		end
		local nTipHolds = tonumber(ServerCfg:GetServerCfgData({"tRemindCfg","nHolds"})) or 10
		SetOnceTimer(function(item, id)
			Helper:DestoryModelessWnd("GXZB.IncomeRemindTipWnd")
			DoWorkOnHideWnd()
		end, nTipHolds*1000)
	end
end