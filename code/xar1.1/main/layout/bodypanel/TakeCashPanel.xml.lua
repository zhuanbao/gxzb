local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
local gCanTakeMoney = 0
--提现错误码
local NOENOUGHMONEY = 401
local EXCEEDINGTAKETIME = 402

function SetMsgToUser(OwnerCtrl, strText)
	local ObjMsgToUser = OwnerCtrl:GetControlObject("TakeCashPanel.Panel.MsgToUser")
	ObjMsgToUser:SetText(strText)
	if not ObjMsgToUser:GetVisible() then
		ObjMsgToUser:SetVisible(true)
	end
end

function OnClickTakeCash(self)
	local ObjEdit = self:GetObject("control:TakeCashPanel.Panel.Edit")
	local OwnerCtrl = self:GetOwnerControl()
	local strText = ObjEdit:GetText()
	local nTakeMoney = tonumber(strText)
	if nTakeMoney == nil then
		return
	end
	self:Enable(false)
	--local bSuccess = tFunctionHelper.ReadAllConfigInfo()
	tFunctionHelper.TakeCashToServer(nTakeMoney,function(bRet, tabInfo)
		--for test
		--[[
		bRet = true
		tabInfo = {}
		tabInfo["rtn"] = 0
		tabInfo["data"] = {}
		tabInfo["data"]["balance"]  = 8798
		--]]
		if not bRet then
			SetMsgToUser(OwnerCtrl, "连接服务器失败，请重试")
			self:Enable(true)
		elseif tabInfo["rtn"] == NOENOUGHMONEY then
			local nBalance = tabInfo["data"]["balance"] 
			tFunctionHelper.UpdateUserBalance(nBalance)
		elseif tabInfo["rtn"] == EXCEEDINGTAKETIME then
			tFunctionHelper.UpdateUserBalance(nBalance)
			SetMsgToUser(OwnerCtrl, "今天已提现，请明天再来~")
		elseif tabInfo["rtn"] == 0 then	
			local nBalance = tabInfo["data"]["balance"] 
			tFunctionHelper.UpdateUserBalance(nBalance)
			SetMsgToUser(OwnerCtrl, "恭喜您，提现成功，请查看微信")
			local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
			tUserConfig["nLastTakeCashUTC"] = tFunctionHelper.GetCurrentServerTime()
			tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
		else
			SetMsgToUser(OwnerCtrl, "服务器未知错误，请重试")
			self:Enable(true)
		end
	end)
end

function OnEditFocusChange(self, isFocus)
	local bTakeEnable = false
	local ObjBtnTake = self:GetObject("control:TakeCashPanel.Panel.Take")
	if isFocus then
		local strText = self:GetText()
		if tonumber(strText) == nil then
			self:SetText("")
		else
			bTakeEnable = true
		end	
	else
		local strText = self:GetText()
		if tonumber(strText) ~= nil then
			local nTakeMoney = tonumber(strText)
			if nTakeMoney < 1 then
				nTakeMoney = 1
			elseif nTakeMoney > 200 then 
				nTakeMoney = 200
			end
			bTakeEnable = true
			self:SetText(tostring(nTakeMoney))
		else
			self:SetText("可提现"..tostring(gCanTakeMoney).."元")
		end	
	end
	ObjBtnTake:Enable(bTakeEnable)
end

function OnEditTextChange(self)
	local bTakeEnable = false
	local ObjBtnTake = self:GetObject("control:TakeCashPanel.Panel.Take")
	local strText = self:GetText()
	if tonumber(strText) ~= nil then
		local nTakeMoney = tonumber(strText)
		if nTakeMoney < 1 then
			nTakeMoney = 1
		elseif nTakeMoney > 200 then 
			nTakeMoney = 200
		end
		bTakeEnable = true
		self:SetText(tostring(nTakeMoney))
	end
	ObjBtnTake:Enable(bTakeEnable)	
end

function OnLButtonDownPanel(self, x, y)
	local ObjEdit = self:GetObject("TakeCashPanel.Panel.Edit")
	local panleL, panleT, panleR, panleB = self:GetAbsPos()
	local editL, editT, editR, editB = ObjEdit:GetAbsPos()
	if x > editL and x < editR and y > editT and y < editB then
	--if x > editL-panleL and x < editR-panleL and y > editT-panleT and y < editB-panleT then
		ObjEdit:SetFocus(true)
	else
		ObjEdit:SetFocus(false)
	end
end

function OnInitControl(self)
	
end

function CheckCanTakeCash()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local nLastTime = tUserConfig["nLastTakeCashUTC"] or 0
	local nCurrentTime = tFunctionHelper.GetCurrentServerTime()
	return tFunctionHelper.CheckIsAnotherDay(nLastTime, nCurrentTime)
end

function UpdateUIByBalance(self, nBalance)
	local ObjEdit = self:GetControlObject("TakeCashPanel.Panel.Edit")
	local ObjBtnTake = self:GetControlObject("TakeCashPanel.Panel.Take")
	ObjBtnTake:Enable(false)
	local nTakeMoney = math.floor(nBalance/1000)
	if nTakeMoney < 1 then
		nTakeMoney = 0
		ObjEdit:SetEnable(false)
	elseif CheckCanTakeCash() then
		ObjEdit:SetEnable(true)
		--ObjBtnTake:Enable(true)
	end
	if nTakeMoney > 200 then
		nTakeMoney = 200
	end
	gCanTakeMoney = nTakeMoney
	ObjEdit:SetText("可提现"..tostring(gCanTakeMoney).."元")
	if not CheckCanTakeCash() then
		local OwnerCtrl = self:GetOwnerControl()
		SetMsgToUser(OwnerCtrl, "今天已提现，请明天再来~")
	end
end

function UpdateUserBalance(self, nBalance)
	local ObjTextNum = self:GetControlObject("TakeCashPanel.Panel.Amount.Num")
	ObjTextNum:SetText(nBalance)
	AdjustAmountTextPosition(self)
	UpdateUIByBalance(self, nBalance)
end

function AdjustAmountTextPosition(self)
	local gap = 1
	local left,	top, right,	bottom = self:GetObjPos()
	local ObjFather= self:GetControlObject("TakeCashPanel.Panel.Amount")
	local left,	top, right,	bottom = ObjFather:GetObjPos()
	local width, height = right - left, bottom - top
	local ObjTextDesc = self:GetControlObject("TakeCashPanel.Panel.Amount.Description")
	local nLenDesc = ObjTextDesc:GetTextExtent()
	local ObjTextNum = self:GetControlObject("TakeCashPanel.Panel.Amount.Num")
	local nLenNum = ObjTextNum:GetTextExtent()
	local ObjTextUnit = self:GetControlObject("TakeCashPanel.Panel.Amount.Unit")
	local nLenUnit = ObjTextUnit:GetTextExtent()
	local nMaxLen = width - (nLenDesc+gap) - (nLenUnit+gap)
	if nLenNum > nMaxLen then
		nLenNum = nMaxLen
	end
	local nNewLeft = 0
	ObjTextDesc:SetObjPos(nNewLeft, 0, nNewLeft+nLenDesc, height)
	ObjTextNum:SetObjPos(nNewLeft+(nLenDesc+gap), 0, nNewLeft+(nLenDesc+gap)+nLenNum, height)
	ObjTextUnit:SetObjPos(nNewLeft+(nLenDesc+gap)+(nLenNum+gap), 0, nNewLeft+(nLenDesc+gap)+(gap+nLenNum)+nLenUnit, height)
end

function OnVisibleChange(self, bVisible)
	
end


function OnShowPanel(self, bShow)
	if bShow then
		AdjustAmountTextPosition(self)
		if not CheckCanTakeCash() then
			SetMsgToUser(self, "今天已提现，请明天再来~")
		end
	end
end