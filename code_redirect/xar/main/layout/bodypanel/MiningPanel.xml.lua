local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local objGraphicFac = XLGetObject("Xunlei.XLGraphic.Factory.Object")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local g_UnBindFailTimerId = nil
local g_bShowBindEntry = false

function TipLog(strLog)
	if type(tipUtil.Log) == "function" then
		tipUtil:Log("MiningPanel: " .. tostring(strLog))
	end
end

function ChangeBindEntryVisible(OwnerCtrl)
	if not ClientWorkModule:CheckIsBinded() then
		--ObjBindWeiXinEntry:Show(true)
        ShowBindWeiXin(OwnerCtrl, true)
	else
		--ObjBindWeiXinEntry:Show(false)
        ShowBindWeiXin(OwnerCtrl, false)
	end
end

function UpdateClientBindState(self)
	ChangeBindEntryVisible(self)
end

function UpdateClientUnBindState(self)
	ResetUIVisible(self)
end

function UpdateClientUnBindFailState(self)
    SetStateInfoToUser(self, "解除绑定失败，请稍后重试！")
	g_UnBindFailTimerId = timeMgr:SetTimer(function(Itm, id)
		timeMgr:KillTimer(g_UnBindFailTimerId)
		g_UnBindFailTimerId = nil
		SetStateInfoToUser(self, nil)
	end,3*1000)
end

function UpdateUserBalance(self, nBalance)
	local ObjTextNum = self:GetControlObject("MiningPanel.Panel.Amount.Num")
	ObjTextNum:SetText(tFunctionHelper.NumberToFormatMoney(nBalance))
	local ObjTextRealTimeIncome = self:GetControlObject("MiningPanel.Panel.Amount.RealTimeIncome")
	ObjTextRealTimeIncome:SetText("")
	
	AdjustAmountTextPosition(self)
end

function UpdateRealTimeIncome(self, nBalance, nRealTimeIncome)
	local ObjTextNum = self:GetControlObject("MiningPanel.Panel.Amount.Num")
	ObjTextNum:SetText(tFunctionHelper.NumberToFormatMoney(nBalance))
	
	local ObjTextRealTimeIncome = self:GetControlObject("MiningPanel.Panel.Amount.RealTimeIncome")
	local strRealTimeIncome = tFunctionHelper.NumberToFormatMoney(nRealTimeIncome)
	strRealTimeIncome = "+" .. strRealTimeIncome
	ObjTextRealTimeIncome:SetText(strRealTimeIncome)
	AdjustAmountTextPosition(self)
end

function UpdateMiningSpeed(self, nSpeed)
	local ObjMiningSpeed = self:GetControlObject("MiningPanel.Panel.MiningSpeed")
	if not ObjMiningSpeed:GetVisible() then
		ObjMiningSpeed:SetChildrenVisible(true)
		ObjMiningSpeed:SetVisible(true)
		ShowAnim(self, true)
		local ObjReboot = self:GetControlObject("MiningPanel.Panel.RemindReboot.Icon")
		if tFunctionHelper.IsNeedRebootAfterUpdateDriver() then
			ObjReboot:SetVisible(true)
		else
			ObjReboot:SetVisible(false)
		end	
	end	
	local ObjMiningState = self:GetControlObject("MiningPanel.Panel.MiningState")	
	local ObjTextSpeed = self:GetControlObject("MiningPanel.Panel.MiningSpeed.Speed")
	local strSpeed = tostring(nSpeed) .. "元宝/小时"
	ObjTextSpeed:SetText(strSpeed)
	AdjustSpeedTextPosition(self)
end

function UpdateMiningState(self,nMiningState)
	if ClientWorkModule:CheckIsCalculate() then
		local ObjMiningSpeed = self:GetControlObject("MiningPanel.Panel.MiningSpeed")
		if not ObjMiningSpeed:GetVisible() then
			ObjMiningSpeed:SetChildrenVisible(true)
			ObjMiningSpeed:SetVisible(true)
			ShowAnim(self, true)
			local ObjReboot = self:GetControlObject("MiningPanel.Panel.RemindReboot.Icon")
			if tFunctionHelper.IsNeedRebootAfterUpdateDriver() then
				ObjReboot:SetVisible(true)
			else
				ObjReboot:SetVisible(false)
			end
		end
	elseif ClientWorkModule:CheckIsPrepare() then
		ResetUIVisible(self, true)
		local ObjStopBtn = self:GetControlObject("MiningPanel.Panel.StopBtn")
		--ObjStopBtn:Show(true)
		local ObjStartBtn = self:GetControlObject("MiningPanel.Panel.StartBtn")
		ObjStartBtn:Enable(false)
		local ObjStartBtnText = self:GetControlObject("MiningPanel.Panel.StartBtn.Text")
		ObjStartBtnText:SetText("准备中......")
	end
end

function UpdateDagProgress(self,nProgress)
	local ObjStartBtnText = self:GetControlObject("MiningPanel.Panel.StartBtn.Text")
	local strText = ("准备中 "..tostring(nProgress).."%")
	ObjStartBtnText:SetText(strText)
end
--1:正在运行,2:不在运行
function OnWorkStateChange(self)
	if ClientWorkModule:CheckIsWorking() then
		local ObjStopBtn = self:GetControlObject("MiningPanel.Panel.StopBtn")
		--ObjStopBtn:Show(true)
		local ObjStartBtn = self:GetControlObject("MiningPanel.Panel.StartBtn")
		ObjStartBtn:Enable(false)
		local ObjStartBtnText = self:GetControlObject("MiningPanel.Panel.StartBtn.Text")
		ObjStartBtnText:SetText("准备中......")
	else
		ResetUIVisible(self)
	end
end

local imageOpenAni = nil
function ShowAnim(OwnerCtrl, bShow)
	local ObjAnimImg = OwnerCtrl:GetObject("MiningPanel.Panel.ShowAnim")
	local ObjStartBtn = OwnerCtrl:GetObject("MiningPanel.Panel.StartBtn")
	local ObjStartBtnText = OwnerCtrl:GetObject("MiningPanel.Panel.StartBtn.Text")
	if bShow then
		ObjStartBtn:Show(false)
		ObjStartBtnText:SetVisible(false)
		if not ObjAnimImg then
			local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")
			ObjAnimImg = objFactory:CreateUIObject("MiningPanel.Panel.ShowAnim", "ImageObject")
			OwnerCtrl:AddChild(ObjAnimImg)
			local l, t, r, b = ObjStartBtn:GetObjPos()
			TipLog("[ShowAnim] StartBtn pos, left=" .. tostring(l) .. ", top=" .. tostring(t) .. ", right=" .. tostring(r) .. ", buttom=" .. tostring(b))
			local w, h = r-l, b-t
			local offsetW, offsetH = (280-w)/2, (280-h)/2 
			TipLog("[ShowAnim] Anim pos, left=" .. tostring(l-offsetW) .. ", top=" .. tostring(t-offsetH) .. ", right=" .. tostring(r+offsetW) .. ", buttom=" .. tostring(b+offsetH))
			ObjAnimImg:SetObjPos(l-offsetW, t-offsetH, r+offsetW, b+offsetH)
			ObjAnimImg:AttachListener("OnMouseEnter", false, OnMouseEnterMiningAnim)		
			ObjAnimImg:AttachListener("OnMouseLeave", false, OnMouseLeaveMiningAnim)
		end
		ObjAnimImg:SetVisible(true)
		imageOpenAni = Helper.Ani:RunSeqFrameAni(ObjAnimImg, "GXZB.MainPanel.WorkingAnim", nil, 8000, true)
	else
		if imageOpenAni then
			imageOpenAni:Stop()
			imageOpenAni = nil
		end
		if ObjAnimImg then
			ObjAnimImg:SetVisible(false)
		end
		ObjStartBtn:Show(true)
		ObjStartBtnText:SetVisible(true)
	end
end

function OnClickStopMining(self)
	local OwnerCtrl = self:GetOwnerControl()
	SetStateInfoToUser(OwnerCtrl,nil)
	if ClientWorkModule:CheckIsWorking() then
		ClientWorkModule:NotifyQuit()
	end
	local tStatInfo = {}
	tStatInfo.fu1 = "stopworking"
	tStatInfo.fu5 = "workingbtn"
	StatisticClient:SendClickReport(tStatInfo)
end

function OnMouseEnterStopBtn(self)
	if not self:IsVisible() then
		self:Show(true)
	end
end

function OnMouseLeaveStopBtn(self)
	if self:IsVisible() then
		--self:Show(false)
	end
end

function OnClickStartMining(self)
	local OwnerCtrl = self:GetOwnerControl()
	SetStateInfoToUser(OwnerCtrl,nil)
	if not ClientWorkModule:CheckIsWorking() then
		ClientWorkModule:NotifyStart()
	end
	local tStatInfo = {}
	tStatInfo.fu1 = "startworking"
	tStatInfo.fu5 = "workingbtn"
	StatisticClient:SendClickReport(tStatInfo)
end

function OnMouseEnterMiningAnim(self)
	if ClientWorkModule:CheckIsWorking() then
		local OwnerCtrl = self:GetOwnerControl()
		local ObjStopBtn = OwnerCtrl:GetControlObject("MiningPanel.Panel.StopBtn")
		if not ObjStopBtn:IsVisible() then
			ObjStopBtn:Show(true)
		end	
	end
end

function OnMouseLeaveMiningAnim(self)
	if ClientWorkModule:CheckIsWorking() then
		local OwnerCtrl = self:GetOwnerControl()
		local ObjStopBtn = OwnerCtrl:GetControlObject("MiningPanel.Panel.StopBtn")
		if ObjStopBtn:IsVisible() then
			ObjStopBtn:Show(false)
		end	
	end
end

function OnMouseEnterStartBtn(self)
	if ClientWorkModule:CheckIsWorking() then
		local OwnerCtrl = self:GetOwnerControl()
		local ObjStopBtn = OwnerCtrl:GetControlObject("MiningPanel.Panel.StopBtn")
		if not ObjStopBtn:IsVisible() then
			ObjStopBtn:Show(true)
		end	
	end
end

function OnMouseLeaveStartBtn(self)
	if ClientWorkModule:CheckIsWorking() then
		local OwnerCtrl = self:GetOwnerControl()
		local ObjStopBtn = OwnerCtrl:GetControlObject("MiningPanel.Panel.StopBtn")
		if ObjStopBtn:IsVisible() then
			ObjStopBtn:Show(false)
		end	
	end
end

function OnMouseEnterStartText(self)
	if ClientWorkModule:CheckIsWorking() then
		local OwnerCtrl = self:GetOwnerControl()
		local ObjStopBtn = OwnerCtrl:GetControlObject("MiningPanel.Panel.StopBtn")
		ObjStopBtn:Show(true)
	end
end

function OnMouseLeaveStartText(self)
	if ClientWorkModule:CheckIsWorking() then
		local OwnerCtrl = self:GetOwnerControl()
		local ObjStopBtn = OwnerCtrl:GetControlObject("MiningPanel.Panel.StopBtn")
		ObjStopBtn:Show(false)
	end
end

function OnClickBindWeiXin(self)
	UIInterface:ChangeMainBodyPanel("QRCodePanel")
	local tStatInfo = {}
	tStatInfo.fu1 = "showpanel"
	tStatInfo.fu5 = "qrcode"
	tStatInfo.fu6 = "link"
	StatisticClient:SendClickReport(tStatInfo)
end

function OnClickFAQ(self)
	Helper.tipUtil:OpenURL("http://www.share4money.cn/#Faq")
	local tStatInfo = {}
	tStatInfo.fu1 = "openfaq"
	StatisticClient:SendClickReport(tStatInfo)
end

function OnInitControl(self)
	--local ObjMiningSpeed = self:GetControlObject("MiningPanel.Panel.MiningSpeed")
	--ObjMiningSpeed:SetChildrenVisible(false)
	--ObjMiningSpeed:SetVisible(false)
	
	ResetUIVisible(self)
end

function AdjustSpeedTextPosition(self)
	local gap = 1
	local left,	top, right,	bottom = self:GetObjPos()
	local ObjFather= self:GetControlObject("MiningPanel.Panel.MiningSpeed")
	local left,	top, right,	bottom = ObjFather:GetObjPos()
	local width, height = right - left, bottom - top
	local ObjTextDesc = self:GetControlObject("MiningPanel.Panel.MiningSpeed.Description")
	local nLenDesc = ObjTextDesc:GetTextExtent()
	local ObjTextSpeed = self:GetControlObject("MiningPanel.Panel.MiningSpeed.Speed")
	local nLenSpeed = ObjTextSpeed:GetTextExtent()
	local nMaxLen = width - (nLenDesc+gap)
	if nLenSpeed > nMaxLen then
		nLenSpeed = nMaxLen
	end
	local nNewLeft = (width-(nLenDesc+gap)-nLenSpeed)/2
	local ObjReboot = self:GetControlObject("MiningPanel.Panel.RemindReboot.Icon")
	if tFunctionHelper.IsNeedRebootAfterUpdateDriver() then
		local nRLeft, nRTop, nRRight, nRBottom = ObjReboot:GetObjPos()
		nNewLeft = nNewLeft - ((nRRight-nRLeft)/2+2)
		
		ObjReboot:SetObjPos(98+nNewLeft+(nLenDesc+gap)+nLenSpeed+2, nRTop, 98+nNewLeft+(nLenDesc+gap)+nLenSpeed+2+(nRRight-nRLeft), nRBottom)
	else
		ObjReboot:SetVisible(false)
	end
	ObjTextDesc:SetObjPos(nNewLeft, 0, nNewLeft+nLenDesc, height)
	ObjTextSpeed:SetObjPos(nNewLeft+(nLenDesc+gap), 0, nNewLeft+(nLenDesc+gap)+nLenSpeed, height)
end

function AdjustAmountTextPosition(self)
	local gap = 1
	local left,	top, right,	bottom = self:GetObjPos()
	local ObjFather= self:GetControlObject("MiningPanel.Panel.Amount")
	local left,	top, right,	bottom = ObjFather:GetObjPos()
	local width, height = right - left, bottom - top
	local ObjTextDesc = self:GetControlObject("MiningPanel.Panel.Amount.Description")
	local nLenDesc = ObjTextDesc:GetTextExtent()
	local ObjTextNum = self:GetControlObject("MiningPanel.Panel.Amount.Num")
	local nLenNum = ObjTextNum:GetTextExtent()
	
	local ObjTextRealTimeIncome = self:GetControlObject("MiningPanel.Panel.Amount.RealTimeIncome")
	local nLenRealTimeIncome = ObjTextRealTimeIncome:GetTextExtent()
	if nLenRealTimeIncome > 0 then
		nLenRealTimeIncome = nLenRealTimeIncome + 1
	end
	local ObjTextUnit = self:GetControlObject("MiningPanel.Panel.Amount.Unit")
	local nLenUnit = ObjTextUnit:GetTextExtent()
	local nMaxLen = width - (nLenDesc+gap) - (nLenUnit+gap) - nLenRealTimeIncome
	if nLenNum > nMaxLen then
		nLenNum = nMaxLen
	else
		--修正一个像素 "11111"的时候放不下
		nLenNum = nLenNum + 1
	end

	local nNewLeft = (width-(nLenDesc+gap)-nLenNum-(nLenUnit+gap)-nLenRealTimeIncome)/2
	ObjTextDesc:SetObjPos(nNewLeft, 0, nNewLeft+nLenDesc, height)
	ObjTextNum:SetObjPos(nNewLeft+(nLenDesc+gap), 0, nNewLeft+(nLenDesc+gap)+nLenNum, height)
	ObjTextRealTimeIncome:SetObjPos(nNewLeft+(nLenDesc+gap)+nLenNum, 0, nNewLeft+(nLenDesc+gap)+nLenNum+nLenRealTimeIncome, height)
	ObjTextUnit:SetObjPos(nNewLeft+(nLenDesc+gap)+nLenNum+nLenRealTimeIncome+gap, 0, nNewLeft+(nLenDesc+gap)+nLenNum+nLenRealTimeIncome+gap+nLenUnit, height)
end

function ResetUIVisible(OwnerCtrl, bNotResetStopBtn)
	ShowAnim(OwnerCtrl, false)
	local ObjStartBtnText = OwnerCtrl:GetControlObject("MiningPanel.Panel.StartBtn.Text")
	ObjStartBtnText:SetVisible(true)
	ObjStartBtnText:SetText("开始赚宝")
	
	local ObjTextSpeed = OwnerCtrl:GetControlObject("MiningPanel.Panel.MiningSpeed.Speed")
	local strSpeed ="0元宝/小时"
	ObjTextSpeed:SetText(strSpeed)
	AdjustSpeedTextPosition(OwnerCtrl)
	
	local ObjMiningSpeed = OwnerCtrl:GetControlObject("MiningPanel.Panel.MiningSpeed")
	ObjMiningSpeed:SetChildrenVisible(false)
	ObjMiningSpeed:SetVisible(false)
	
	local ObjReboot = OwnerCtrl:GetControlObject("MiningPanel.Panel.RemindReboot.Icon")
	ObjReboot:SetVisible(false)
		
	if not bNotResetStopBtn then
		local ObjStopBtn = OwnerCtrl:GetControlObject("MiningPanel.Panel.StopBtn")
		ObjStopBtn:Show(false)
	end	
	
	local ObjStartBtn = OwnerCtrl:GetControlObject("MiningPanel.Panel.StartBtn")
	ObjStartBtn:Enable(true)
	--[[
	local ObjMiningState = OwnerCtrl:GetControlObject("MiningPanel.Panel.MiningState")
	ObjMiningState:SetVisible(false)
	ObjMiningState:SetText("")
	--]]
	--[[
	local objstopbtn = OwnerCtrl:GetControlObject("MiningPanel.Panel.StopBtn")
	local objstopattr = objstopbtn:GetAttribute()
	objstopattr.NormalBkgID = "texture.MainPanel.MiniStartMining.normal"
	objstopattr.HoverBkgID = "texture.MainPanel.MiniStartMining.hover"
	objstopattr.DownBkgID = "texture.MainPanel.MiniStartMining.down"
	objstopattr.DisableBkgID = "texture.MainPanel.MiniStartMining.normal"
	objstopbtn:Updata()
	--]]
	if g_UnBindFailTimerId then
		timeMgr:KillTimer(g_UnBindFailTimerId)
		g_UnBindFailTimerId = nil
	end
	ChangeBindEntryVisible(OwnerCtrl)
end

function OnVisibleChange(self, bVisible)
	--[[
	
	--]]
end

function OnShowPanel(self, bShow)
	if bShow then
		AdjustAmountTextPosition(self)
		AdjustSpeedTextPosition(self)
		ChangeBindEntryVisible(self)
		ChangeMiningFailVisible(self)
	else
		ChangeBindEntryVisible(self)
        SetStateInfoToUser(self, nil)
	end
end


function SetStateInfoToUser(self, strInfo)
    local ObjState = self:GetControlObject("MiningPanel.Panel.State")
    local ObjBindWeixin = self:GetControlObject("MiningPanel.Panel.BindWeiXin")
	if strInfo ~= nil and g_bShowBindEntry then
        ObjBindWeixin:SetObjPos2("(father.width-370)/2", 376+40-10, 370, 28)
        ObjState:SetObjPos2("(father.width-370)/2", 376+42+15, 370, 24)
	else
        ObjState:SetObjPos2("(father.width-370)/2", 376+42, 370, 24)
        ObjBindWeixin:SetObjPos2("(father.width-370)/2", 376+40, 370, 28)
	end
    ObjState:SetText(strInfo or "")
end

function AdjustBindWeiXinPosition(self)
    local nAdjustLen = 0
    local ObjBind = self:GetControlObject("MiningPanel.Panel.BindWeiXin")
    local ObjBindText = self:GetControlObject("MiningPanel.Panel.BindWeiXin.Text")
    local ObjBindIcon = self:GetControlObject("MiningPanel.Panel.BindWeiXin.Icon")
    
    local nFLeft, nFTop, nFRight, nFBottom = ObjBind:GetObjPos()
    local nFWidth = nFRight - nFLeft
    local nTLeft, nTTop, nTRight, nTBottom = ObjBindText:GetObjPos()
    
    local nILeft, nITop, nIRight, nIBottom = ObjBindIcon:GetObjPos()
    local nIWidth = nIRight - nILeft
     
    local nTextLen = ObjBindText:GetTextExtent()
    local nTotalLen = nTextLen
    local strIconID = ObjBindIcon:GetResID()
    if Helper:IsRealString(strIconID) then
        local nGap = 2
        nTotalLen = nTotalLen+nIWidth+nGap
        ObjBindIcon:SetObjPos((nFWidth-nTotalLen)/2, nITop, (nFWidth-nTotalLen)/2+nIWidth, nIBottom) 
        nAdjustLen = nIWidth+nGap
    end
    ObjBindText:SetObjPos((nFWidth-nTotalLen)/2+nAdjustLen, nTTop, (nFWidth-nTotalLen)/2+nAdjustLen+nTextLen+1, nTBottom) 
end

function ShowBindWeiXin(self,bShow)
    g_bShowBindEntry = bShow
    local ObjState = self:GetControlObject("MiningPanel.Panel.State")
    local ObjBindWeixin = self:GetControlObject("MiningPanel.Panel.BindWeiXin")
    if bShow and Helper:IsRealString(ObjState:GetText()) then
        ObjBindWeixin:SetObjPos2("(father.width-370)/2", 376+40-10, 370, 28)
        ObjState:SetObjPos2("(father.width-370)/2", 376+42+15, 370, 24)
    else
        ObjBindWeixin:SetObjPos2("(father.width-370)/2", 376+40, 370, 28)
        ObjState:SetObjPos2("(father.width-370)/2", 376+42, 370, 24)
    end
    local ObjBindText = self:GetControlObject("MiningPanel.Panel.BindWeiXin.Text")
    ObjBindText:Show(bShow)
    
    local ObjBindIcon = self:GetControlObject("MiningPanel.Panel.BindWeiXin.Icon")
    local strIconID = ObjBindIcon:GetResID()
    if bShow and Helper:IsRealString(strIconID) then
        ObjBindIcon:SetVisible(true)
    else
        ObjBindIcon:SetVisible(false)
    end
    AdjustBindWeiXinPosition(self)
end

function ShowRemindRebootWarning(self)
	ChangeMiningFailVisible(self)
end

function OnMouseEnterRemindReboot(self)
	Helper.Tip:SetTips("显卡驱动程序已更新，请重启电脑")
end

function OnMouseLeaveRemindReboot(self)
	Helper.Tip:DestoryTipWnd()
end

function ChangeMiningFailVisible(self)
	local ObjMiningFail = self:GetControlObject("MiningPanel.Panel.MiningFail")
	local ObjMiningFailDesc = self:GetControlObject("MiningPanel.Panel.MiningFail.Description")
	if tFunctionHelper.CheckIsUpdatingDriver() and not ClientWorkModule:CheckIsWorking() then
		ObjMiningFailDesc:SetText("正在更新显卡驱动程序，请稍后重试...")
		ObjMiningFail:SetChildrenVisible(true)
		ObjMiningFail:SetVisible(true)
		return
	end
	if tFunctionHelper.IsNeedRebootAfterUpdateDriver() and not ClientWorkModule:CheckIsWorking() then
		ObjMiningFailDesc:SetText("显卡驱动程序已更新，请重启电脑")
		ObjMiningFail:SetChildrenVisible(true)
		ObjMiningFail:SetVisible(true)
		return
	end
	ObjMiningFailDesc:SetText("")
	ObjMiningFail:SetChildrenVisible(false)
	ObjMiningFail:SetVisible(false)
end

local gCookieTipClick = nil
function ShowNoticeTip(self, tabNotice)
	
	local objFAQ = self:GetControlObject("MiningPanel.Panel.FAQ")
	local objNotice = self:GetControlObject("MiningPanel.Panel.Notice")
	local objIcon = self:GetControlObject("MiningPanel.Panel.Notice.Icon")
	local objTipText = self:GetControlObject("MiningPanel.Panel.Notice.Tip")
	local objFather = self:GetControlObject("MiningPanel.Panel")

	if gCookieTipClick then
		objTipText:RemoveListener("OnLButtonUp", gCookieTipClick)
		gCookieTipClick = nil
	end	
	
	if type(tabNotice) ~= "table" or not Helper:IsRealString(tabNotice["strTip"]) then
		objFAQ:Show(true)
		objNotice:SetChildrenVisible(false)
		objNotice:SetVisible(false)
	else
		objFAQ:Show(false)
		local nTextMaxLen = 246-(24+10+12)
		local nTextMinLen = 160-(24+10+12)
		local nFLeft, nFTop, nFRight, nFBottom = objFather:GetObjPos()
		local nFWidth = nFRight - nFLeft
		
		local nTipLeft,	nTipTop, nTipRight,	nTipBottom = objTipText:GetObjPos()
		objTipText:SetObjPos(nTipLeft, nTipTop, nTipLeft+nTextMaxLen, nTipBottom)
		objTipText:SetText(tabNotice["strTip"])
		local nLenDesc = objTipText:GetTextExtent()
		nLenDesc = nLenDesc
		if nLenDesc > nTextMaxLen then
			nLenDesc = nTextMaxLen
		end
		if nLenDesc < nTextMinLen then
			nLenDesc = nTextMinLen
		end
		local nBkgWidth = nLenDesc+(24+10+12)
		local nBkgLeft,	nBkgTop, nBkgRight,	nBkgBottom = objNotice:GetObjPos()
		objNotice:SetObjPos((nFWidth-nBkgWidth)/2, nBkgTop, (nFWidth+nBkgWidth)/2, nBkgBottom)
		
		objIcon:SetObjPos2(0, 0, 24, 24)
		objTipText:SetObjPos2(24+10, 0, "father.width-(24+10+12)", 24)
		if Helper:IsRealString(tabNotice["strLink"]) then
			objTipText:SetCursorID("IDC_HAND")
			gCookieTipClick = objTipText:AttachListener("OnLButtonUp", false, function()
				Helper.tipUtil:OpenURL(tabNotice["strLink"])
				local tStatInfo = {}
				tStatInfo.fu1 = "noticetip"
				tStatInfo.fu5 = tabNotice["strLink"]
				StatisticClient:SendClickReport(tStatInfo)
			end)
		else
			objTipText:SetCursorID("IDC_ARROW")
		end
		objNotice:SetChildrenVisible(true)
		objNotice:SetVisible(true)
	end
end