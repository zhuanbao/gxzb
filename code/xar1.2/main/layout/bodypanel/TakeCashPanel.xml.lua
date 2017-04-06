local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
local gCanTakeMoney = 0
local gBalance = 0
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
	local nTakeMoney = tFunctionHelper.FormatMoneyToNumber(strText)
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
		tabInfo["data"]["balance"]  = 87980
		--]]
		if not bRet then
			SetMsgToUser(OwnerCtrl, "连接服务器失败，请重试")
			self:Enable(true)
		elseif tabInfo["rtn"] == NOENOUGHMONEY then
			local nBalance = tabInfo["data"]["balance"] 
			tFunctionHelper.SetUserCurrentBalance(nBalance)
			tFunctionHelper.UpdateUserBalance(nBalance)
		elseif tabInfo["rtn"] == EXCEEDINGTAKETIME then
			local nBalance = tabInfo["data"]["balance"] 
			tFunctionHelper.SetUserCurrentBalance(nBalance)
			tFunctionHelper.UpdateUserBalance(nBalance)
			SetMsgToUser(OwnerCtrl, "今天已提现，请明天再来~")
		elseif tabInfo["rtn"] == 0 then	
			local nBalance = tabInfo["data"]["balance"] 
			local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
			tUserConfig["nLastTakeCashUTC"] = tFunctionHelper.GetCurrentServerTime()
			tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
			tFunctionHelper.SetUserCurrentBalance(nBalance)
			tFunctionHelper.UpdateUserBalance(nBalance)
			SetMsgToUser(OwnerCtrl, "恭喜您，提现成功，请查看微信")
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

local g_strLastInput = "" 
function OnEditTextChange(self)
	local bTakeEnable = false
	local ObjBtnTake = self:GetObject("control:TakeCashPanel.Panel.Take")
	local strText = self:GetText()
	if tonumber(strText) ~= nil then
		--修正只可以小数点后2位
		local strTakeMoney = nil
		if string.find(strText,"%.") then
			local _,_,strInteger,strDecimal = string.find(strText,"^(%d+)%.(%d+)$")
			if strDecimal ~= nil and string.len(strDecimal) > 2 then
				strDecimal = string.sub(strDecimal,1,2)
				strTakeMoney = strInteger ..tostring(".") .. strDecimal
			else
				strTakeMoney = strText
			end	
		else
			strTakeMoney = strText
		end
		local nTakeMoney = tonumber(strTakeMoney)
		--到这里表示可以提现，纠正提现金额
		if nTakeMoney < 1 then
			strTakeMoney = "1"
		elseif nTakeMoney > gCanTakeMoney then 
			strTakeMoney = tostring(gCanTakeMoney)
		elseif nTakeMoney > 200 then
			strTakeMoney = "200"
		end
		bTakeEnable = true
		self:SetText(tostring(strTakeMoney))
		g_strLastInput = strTakeMoney
	elseif string.find(strText,"可提现") == nil and strText ~= "" then
		self:SetText(g_strLastInput)
		bTakeEnable = true
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

function OnClickUnBindWeiXin(self)
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	objHostWnd:Show(1)
	Helper:CreateModalWnd("GXZB.UnBindWnd", "GXZB.UnBindWndTree", objHostWnd:GetWndHandle(), {["parentWnd"] = objHostWnd})
end

function OnInitControl(self)
	
end

function CheckCanTakeCash()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local nLastTime = tUserConfig["nLastTakeCashUTC"] or 0
	local nCurrentTime = tFunctionHelper.GetCurrentServerTime()
	return tFunctionHelper.CheckIsAnotherDay(nLastTime, nCurrentTime)
end

function UpdateTakeRule(self)
	local ObjTakeRule = self:GetControlObject("TakeCashPanel.Panel.TakeRule")
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	local strNickName = tUserConfig["tUserInfo"]["strNickName"]
	if Helper:IsRealString(strNickName) then
		strNickName = Helper.tipUtil:GetLastWord(strNickName)
	else
		strNickName = "*"
	end
	local strText = "提现规则 ：\r\n"
	strText = strText .. "1. 提现通过微信红包发放，10000元宝可提现1元人民币\r\n"
	strText = strText .. "2. 提现金额最小1元，最大200元，每天只能提现1次\r\n"
	strText = strText .. "3. 红包将发到您已绑定的微信账号（*"..tostring(strNickName).."）中,"
	ObjTakeRule:SetText(strText)
end

function UpdateUIByBalance(self, nBalance)
	UpdateTakeRule(self)
	local ObjEdit = self:GetControlObject("TakeCashPanel.Panel.Edit")
	local ObjBtnTake = self:GetControlObject("TakeCashPanel.Panel.Take")
	ObjBtnTake:Enable(false)
	local Integer,Decimal = math.modf(nBalance/10000)
	Decimal = math.floor(Decimal*100)/100
	nTakeMoney = Integer+Decimal
	if nTakeMoney < 1 then
		nTakeMoney = 0
		ObjEdit:SetEnable(false)
	end	
	if CheckCanTakeCash() then
		ObjEdit:SetEnable(true)
	else
		ObjEdit:SetEnable(false)
	end
	if nTakeMoney > 200 then
		nTakeMoney = 200
	end
	gCanTakeMoney = nTakeMoney
	ObjEdit:SetText("可提现"..tostring(gCanTakeMoney).."元")
	if not CheckCanTakeCash() then
		--local OwnerCtrl = self:GetOwnerControl()
		--SetMsgToUser(OwnerCtrl, "今天已提现，请明天再来~")
		SetMsgToUser(self, "今天已提现，请明天再来~")
	end
end

function UpdateUserBalance(self, nBalance)
	gBalance = nBalance
	local ObjTextNum = self:GetControlObject("TakeCashPanel.Panel.Amount.Num")
	local strFormatBalance = tFunctionHelper.NumberToFormatMoney(nBalance)
	ObjTextNum:SetText(strFormatBalance)
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
	else
		g_strLastInput = ""
	end
	UpdateUIByBalance(self,gBalance)
end

