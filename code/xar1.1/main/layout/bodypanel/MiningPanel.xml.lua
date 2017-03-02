local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
local Helper = XLGetGlobal("Helper")
local objGraphicFac = XLGetObject("Xunlei.XLGraphic.Factory.Object")

function TipLog(strLog)
	if type(tipUtil.Log) == "function" then
		tipUtil:Log("@@ChildCtrl_MinerInfo: " .. tostring(strLog))
	end
end

function OnClickStopMining(self)
	if tFunctionHelper.CheckIsWorking() then
		tFunctionHelper.NotifyPause()
	end
end

function OnClickStartMining(self)
	if not tFunctionHelper.CheckIsWorking() then
		tFunctionHelper.NotifyStart()
	end
end

function OnClickBindWeiXin(self)
	tFunctionHelper.ChangeMainBodyPanel("QRCodePanel")
end


function OnInitControl(self)
	--AdjustAmountTextPosition(self)
end

function ChangeBindEntryVisible(self, bVisible)
	local ObjBindWeiXinEntry = self:GetControlObject("MiningPanel.Panel.BindWeiXin")
	ObjBindWeiXinEntry:Show(bVisible)
end

function UpdateUserBalance(self, nBalance)
	local ObjTextNum = self:GetControlObject("MiningPanel.Panel.Amount.Num")
	ObjTextNum:SetText(nBalance)
	AdjustAmountTextPosition(self)
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
	local ObjTextUnit = self:GetControlObject("MiningPanel.Panel.Amount.Unit")
	local nLenUnit = ObjTextUnit:GetTextExtent()
	local nMaxLen = width - (nLenDesc+gap) - (nLenUnit+gap)
	if nLenNum > nMaxLen then
		nLenNum = nMaxLen
	end
	
	local nNewLeft = (width-(nLenDesc+gap)-nLenNum-(nLenUnit+gap))/2
	ObjTextDesc:SetObjPos(nNewLeft, 0, nNewLeft+nLenDesc, height)
	ObjTextNum:SetObjPos(nNewLeft+(nLenDesc+gap), 0, nNewLeft+(nLenDesc+gap)+nLenNum, height)
	ObjTextUnit:SetObjPos(nNewLeft+(nLenDesc+gap)+(nLenNum+gap), 0, nNewLeft+(nLenDesc+gap)+(gap+nLenNum)+nLenUnit, height)
end

function OnVisibleChange(self, bVisible)
	--[[
	if bVisible then
		AdjustAmountTextPosition(self)
		if not tFunctionHelper.CheckIsBinded() then
			ChangeBindEntryVisible(self,true)
		else
			ChangeBindEntryVisible(self,false)
		end
	end
	--]]
end

function OnShowPanel(self, bShow)
	if bShow then
		AdjustAmountTextPosition(self)
		if not tFunctionHelper.CheckIsBinded() then
			ChangeBindEntryVisible(self,true)
		else
			ChangeBindEntryVisible(self,false)
		end
	end
end












