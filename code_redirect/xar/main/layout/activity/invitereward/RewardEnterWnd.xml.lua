local tFunctionHelper = XLGetGlobal("FunctionHelper")
local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")
local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}

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

function OnClickClose(self)
	Helper:DestoryModelessWnd("GXZB.RewardEnterWnd")
end

function PopupInDeskRight(self)
	local objtree = self:GetBindUIObjectTree()
	local objRootLayout = objtree:GetUIObject("RewardEnterWnd.Content")
    local templateMananger = XLGetObject("Xunlei.UIEngine.TemplateManager")
	
	local nLayoutL, nLayoutT, nLayoutR, nLayoutB = objRootLayout:GetObjPos()
	local nLayoutWidth = nLayoutR - nLayoutL
	local nLayoutHeight = nLayoutB - nLayoutT
	
	local workleft, worktop, workright, workbottom = Helper.tipUtil:GetWorkArea()
	self:Move( workright - nLayoutWidth, workbottom - nLayoutHeight, nLayoutWidth, nLayoutHeight)
	return true
end

function OnSelect(self, event, bSelect)
	local ObjAttr = self:GetAttribute()
    if ObjAttr.Select then
		local tStatInfo = {}
		tStatInfo.fu1 = "invotecode"
		tStatInfo.fu5 = "inviteenterwnd"
		tStatInfo.fu6 = "selectnopop"
		StatisticClient:SendClickReport(tStatInfo)
		
		local tUserConfig = WorkModuleHelper:GetUserConfig()
		if type(tUserConfig["tActive"]) ~= "table" then
			tUserConfig["tActive"] = {}
		end
		if type(tUserConfig["tActive"]["tInvite"]) ~= "table" then
			tUserConfig["tActive"]["tInvite"] = {}
		end
		tUserConfig["tActive"]["tInvite"]["bNoPopRewardEnterWnd"] = true
		tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
	end
end

function OnClickEnter(self)
	Helper:DestoryModelessWnd("GXZB.RewardEnterWnd")
	local mainwnd = UIInterface:GetMainHostWnd()
	if mainwnd then
		mainwnd:BringWindowToTop(true)
	end
	local tStatInfo = {}
	tStatInfo.fu1 = "invotecode"
	tStatInfo.fu5 = "showinvotereward"
	tStatInfo.fu6 = "remindwnd"
	StatisticClient:SendClickReport(tStatInfo)
	
	local objInviteRewardInfoWnd = Helper.hostWndManager:GetHostWnd("GXZB.InviteRewardInfo.ModalInstance")
	if objInviteRewardInfoWnd then return end
	
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	objHostWnd:Show(1)
	Helper:CreateModalWnd("GXZB.InviteRewardInfo", "GXZB.InviteRewardInfoTree", objHostWnd:GetWndHandle(), {["parentWnd"] = objHostWnd})
end

function OnShowWindow(self, bShow)
	if bShow then
		local objTree = self:GetBindUIObjectTree()
		PopupInDeskRight(self)
		local nTipHolds = tonumber(ServerCfg:GetServerCfgData({"tRemindCfg","nHolds"})) or 10
		SetOnceTimer(function(item, id)
			Helper:DestoryModelessWnd("GXZB.RewardEnterWnd")
		end, nTipHolds*1000)
		local tUserConfig = WorkModuleHelper:GetUserConfig()
		if type(tUserConfig["tActive"]) ~= "table" then
			tUserConfig["tActive"] = {}
		end
		if type(tUserConfig["tActive"]["tInvite"]) ~= "table" then
			tUserConfig["tActive"]["tInvite"] = {}
		end
		tUserConfig["tActive"]["tInvite"]["nLastPopupRewardEnterWndTime"] = tFunctionHelper.GetCurrentServerTime()
		tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
		
		local tStatInfo = {}
		tStatInfo.fu1 = "invotecode"
		tStatInfo.fu5 = "showinviteremindwnd"
		StatisticClient:SendEventReport(tStatInfo)
	end
end