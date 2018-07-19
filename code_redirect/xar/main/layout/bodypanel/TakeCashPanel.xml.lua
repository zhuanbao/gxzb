local tFunctionHelper = XLGetGlobal("FunctionHelper")
local gCanTakeMoney = 0
local gBalance = 0
--提现错误码
local ERROR_INPUT = -1
local ERROR_EXCEEDING_TAKE_TIME = -2
local ERROR_WORKID = -3
local ERROR_NO_ENOUGH_MONEY = -4
local ERROR_BIND = -5
local gOwnerCtrl = nil

function SetMsgToUser(strText)
	local ObjMsgToUser = gOwnerCtrl:GetControlObject("TakeCashPanel.Panel.MsgToUser")
	ObjMsgToUser:SetText(strText)
	if not ObjMsgToUser:GetVisible() then
		ObjMsgToUser:SetVisible(true)
	end
end

function OnTakeCashToServerCallBack(obj, event, bSuccess, tabInfo)
	if not bSuccess and type(tabInfo) ~= "table" then
		SetMsgToUser("连接服务器失败，请重试")
		--self:Enable(true)
	elseif tabInfo["rtn"] == 0 then	
		local nBalance = tabInfo["data"]["balance"] 
		local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
		tUserConfig["nLastTakeCashUTC"] = tFunctionHelper.GetCurrentServerTime()
		tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
		MainWorkModule:SetUserCurrentBalance(nBalance)
		UIInterface:UpdateUserBalance()
		SetMsgToUser("恭喜您，提现成功，请查看微信")
		--Statistic:SendUIReport("takecash","success")
		local tStatInfo = {}
		tStatInfo.fu1 = "takecash"
		tStatInfo.fu5 = "success"
		StatisticClient:SendEventReport(tStatInfo)
	else
		local nErrorCode = tabInfo["data"]["errCode"]
		if nErrorCode == ERROR_WORKID or nErrorCode == ERROR_BIND then
			SetMsgToUser("绑定信息错误，无法提现")
		elseif nErrorCode == ERROR_NO_ENOUGH_MONEY then
			local nBalance = tabInfo["data"]["balance"] or 0
			--self:Enable(true)
			MainWorkModule:SetUserCurrentBalance(nBalance)
			UIInterface:UpdateUserBalance()
			SetMsgToUser("余额不足，无法提现")
		elseif nErrorCode == ERROR_EXCEEDING_TAKE_TIME then
			local nBalance = tabInfo["data"]["balance"] 
			MainWorkModule:SetUserCurrentBalance(nBalance)
			UIInterface:UpdateUserBalance()
			SetMsgToUser("今天已提现，请明天再来~")
		else
			if nErrorCode == ERROR_INPUT then
				SetMsgToUser("输入金额错误，请重新输入")
			else
				SetMsgToUser("服务器未知错误，请重试")
			end	
			--self:Enable(true)
		end
		local tStatInfo = {}
		tStatInfo.fu1 = "takecash"
		tStatInfo.fu5 = "fail"
		tStatInfo.fu6 = nErrorCode
		StatisticClient:SendEventReport(tStatInfo)
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
	ApiInterfaceModule:AddListener("OnTakeCashToServer", OnTakeCashToServerCallBack, ApiInterfaceModule)
	ApiInterfaceModule:TakeCashToServer(nTakeMoney)
	
	local tStatInfo = {}
	tStatInfo.fu1 = "takecash"
	StatisticClient:SendClickReport(tStatInfo)
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

function OnClickSupperPCLink(self)
	local strLink = "http://www.eastredm.com/supercomputer"
	Helper.tipUtil:OpenURL(strLink)
	local tStatInfo = {}
	tStatInfo.fu1 = "opensupperpc"
	tStatInfo.fu5 = "takecash"
	StatisticClient:SendClickReport(tStatInfo)
end

function OnInitControl(self)
	gOwnerCtrl = self
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
	local Integer,Decimal = math.modf(nBalance/10000)
	Decimal = math.floor(Decimal*100)/100
	nTakeMoney = Integer+Decimal
	if nTakeMoney < 1 then
		nTakeMoney = 0
	end	
	if nTakeMoney > 200 then
		nTakeMoney = 200
	end
	gCanTakeMoney = nTakeMoney
	if CheckCanTakeCash() and nTakeMoney > 0 then
		ObjEdit:SetEnable(true)
		if not ObjEdit:GetFocus() then
			ObjBtnTake:Enable(false)
			ObjEdit:SetText("可提现"..tostring(gCanTakeMoney).."元")
		end	
	else
		ObjEdit:SetEnable(false)
		ObjBtnTake:Enable(false)
		ObjEdit:SetText("可提现"..tostring(gCanTakeMoney).."元")
	end
	if not CheckCanTakeCash() then
		SetMsgToUser("今天已提现，请明天再来~")
    else
        local ObjMsgToUser = gOwnerCtrl:GetControlObject("TakeCashPanel.Panel.MsgToUser")
        ObjMsgToUser:SetVisible(false)
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

