local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local objGraphicFac = XLGetObject("Xunlei.XLGraphic.Factory.Object")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local g_UnBindFailTimerId = nil

function TipLog(strLog)
	if type(tipUtil.Log) == "function" then
		tipUtil:Log("MiningPanel: " .. tostring(strLog))
	end
end

function ChangeBindEntryVisible(OwnerCtrl)
	local ObjTextState = OwnerCtrl:GetControlObject("MiningPanel.Panel.State")
	if Helper:IsRealString(ObjTextState:GetText()) then
		return
	end
	local ObjBindWeiXinEntry = OwnerCtrl:GetControlObject("MiningPanel.Panel.BindWeiXin")
	if not ClientWorkModule:CheckIsBinded() then
		ObjBindWeiXinEntry:Show(true)
	else
		ObjBindWeiXinEntry:Show(false)
	end
end

function UpdateClientBindState(self)
	ChangeBindEntryVisible(self)
end

function UpdateClientUnBindState(self)
	ResetUIVisible(self)
end

function UpdateClientUnBindFailState(self)
	local ObjTextState = self:GetControlObject("MiningPanel.Panel.State")
	if ObjTextState:GetVisible() then
		return
	end
	ChangeBindEntryVisible(self)
	local ObjTextState = self:GetControlObject("MiningPanel.Panel.State")
	local strPreText = ObjTextState:GetText()
	ObjTextState:SetText("解除绑定失败，请稍后重试！")
	ObjTextState:SetVisible(true)
	g_UnBindFailTimerId = timeMgr:SetTimer(function(Itm, id)
		timeMgr:KillTimer(g_UnBindFailTimerId)
		g_UnBindFailTimerId = nil
		ObjTextState:SetVisible(false)
		ObjTextState:SetText(strPreText or "")
		ChangeBindEntryVisible(self)
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
	Helper.tipUtil:OpenURL("http://www.eastredm.com/wxweb/faq.html")
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
	else
		local ObjTextState = self:GetControlObject("MiningPanel.Panel.State")
		ObjTextState:SetText("")
		ObjTextState:SetVisible(false)
		ChangeBindEntryVisible(self)
	end
end


function SetStateInfoToUser(self, strInfo)
	local ObjTextState = self:GetControlObject("MiningPanel.Panel.State")
	if strInfo ~= nil then
		local ObjBindWeiXinEntry = self:GetControlObject("MiningPanel.Panel.BindWeiXin")
		ObjBindWeiXinEntry:Show(false)
		ObjTextState:SetText(strInfo)
		ObjTextState:SetVisible(true)
	else
		ObjTextState:SetText("")
		ObjTextState:SetVisible(false)
		ChangeBindEntryVisible(self)
	end
end









