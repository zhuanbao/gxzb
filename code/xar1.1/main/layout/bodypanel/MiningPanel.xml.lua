local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
local Helper = XLGetGlobal("Helper")
local objGraphicFac = XLGetObject("Xunlei.XLGraphic.Factory.Object")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local g_TimeIDPreparing = nil
local g_CanShowBindEntry = true
function TipLog(strLog)
	if type(tipUtil.Log) == "function" then
		tipUtil:Log("@@ChildCtrl_MinerInfo: " .. tostring(strLog))
	end
end

function OnClickStopMining(self)
	if tFunctionHelper.CheckIsWorking() then
		local OwnerCtrl = self:GetOwnerControl()
		ResetUIVisible(OwnerCtrl)
		tFunctionHelper.NotifyPause()
	end
end

function OnClickStartMining(self)
	if tFunctionHelper.CheckCanMine() then
		if not tFunctionHelper.CheckIsWorking() then
			tFunctionHelper.NotifyStart()
		end
	end	
end

function OnClickBindWeiXin(self)
	tFunctionHelper.ChangeMainBodyPanel("QRCodePanel")
end


function OnInitControl(self)
	local ObjMiningSpeed = self:GetControlObject("MiningPanel.Panel.MiningSpeed")
	ObjMiningSpeed:SetChildrenVisible(false)
	ObjMiningSpeed:SetVisible(false)
	
	ResetUIVisible(self)
end

function ChangeBindEntryVisible(self)
	local ObjBindWeiXinEntry = self:GetControlObject("MiningPanel.Panel.BindWeiXin")
	if not tFunctionHelper.CheckIsBinded() and g_CanShowBindEntry then
		ObjBindWeiXinEntry:Show(true)
	else
		ObjBindWeiXinEntry:Show(false)
	end
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

function UpdateMiningSpeed(self, nSpeed)
	local ObjMiningState = self:GetControlObject("MiningPanel.Panel.MiningState")
	--[[
	if ObjMiningState:GetVisible() then
		strText = ""
		ObjMiningState:SetText(strText)
		ObjMiningState:SetVisible(false)
		--隐藏
	end
	--]]
	SetDAGCacheFlag(nFlag)
	ResetUIVisible(self)
	local ObjPreparingText = OwnerCtrl:GetControlObject("MiningPanel.Panel.Preparing")
	ObjPreparingText:SetVisible(false)
	
	local ObjTextSpeed = self:GetControlObject("MiningPanel.Panel.MiningSpeed.Speed")
	local strSpeed = tostring(nSpeed) .. "元宝/小时"
	ObjTextSpeed:SetText(strSpeed)
	AdjustSpeedTextPosition(self)
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


local MING_CHECK_DAG = 1
local MING_CALCULATE_DAG = 2
local MING_MINING_SPEED = 3
local MING_MINING_EEEOR = 4
local MING_SOLUTION_FIND = 5
local MING_MINING_EEEOR_TIMEOUT = 100

local MING_DAG_CHECKING = 1
local MING_DAG_SUNCCESS = 2
local MING_DAG_FAIL = 3


function ShowPreparingText(self)
	if g_TimeIDPreparing ~= nil then
		return
	end
	local ObjPreparingText = self:GetControlObject("MiningPanel.Panel.Preparing")
	if not ObjPreparingText:GetVisible() then
		ObjPreparingText:SetVisible(true)
	end
	local strText = "准备中"
	local nCounter = 0
	g_TimeIDPreparing = timeMgr:SetTimer(function(Itm, id)
		if nCounter >= 3 then
			strText = "准备中"
			nCounter = 0
		else
			strText = strText .. "."
			nCounter = nCounter+1
		end
		ObjPreparingText:SetText(strText)
	end, 1000)
end

function GetDAGCacheFlag() 
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	return tUserConfig["nChangeDAGCache"] or 0
end
function SetDAGCacheFlag(nFlag) 
	if GetDAGCacheFlag() ~= 1 then
		local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
		tUserConfig["nChangeDAGCache"] = nFlag
		tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
	end	
end

function UpdateMiningState(self, nState, nParam)
	local ObjMiningState = self:GetControlObject("MiningPanel.Panel.MiningState")
	local strText = ""
	if nState == MING_CHECK_DAG then
		if nParam == MING_DAG_CHECKING then
			strText = "正在向服务器请求赚宝所需要的数据参数"
		elseif nParam == MING_DAG_SUNCCESS then
			strText = "生成基础数据块成功，开始赚宝..."
			SetDAGCacheFlag(1)
		else
			strText = "生成基础数据块失败，请重新开始..."
		end
		ObjMiningState:SetText(strText)
		ObjMiningState:SetVisible(true)
		g_CanShowBindEntry = false
		ChangeBindEntryVisible(self)
	elseif nState == MING_CALCULATE_DAG then
		local strCurrentText = ObjMiningState:GetText()
		if string.find(strCurrentText,"正在生成赚宝所需要的基础数据块") == nil and string.find(strCurrentText,"本地基础数据块已过期，正在重新生成") == nil then
			if GetDAGCacheFlag() == 0 then
				strText = "正在生成赚宝所需要的基础数据块。根据你的设备配置情况，该过程大概需要10-30分钟，请耐心等待..."
			else
				strText = "本地基础数据块已过期，正在重新生成。根据你的设备配置情况，该过程大概需要10-30分钟，请耐心等待..."
			end	
			ObjMiningState:SetText(strText)
			ObjMiningState:SetVisible(true)
			g_CanShowBindEntry = false
			ChangeBindEntryVisible(self)
		end	
	elseif nState == MING_MINING_SPEED then
		--g_CanShowBindEntry = true
	end
end

function ResetUIVisible(OwnerCtrl)
	if g_TimeIDPreparing ~= nil then
		timeMgr:KillTimer(g_TimeIDPreparing)
		g_TimeIDPreparing = nil
	end
	local ObjPreparingText = OwnerCtrl:GetControlObject("MiningPanel.Panel.Preparing")
	ObjPreparingText:SetVisible(false)
	local ObjMiningState = OwnerCtrl:GetControlObject("MiningPanel.Panel.MiningState")
	ObjMiningState:SetVisible(false)
	ObjMiningState:SetText("")
	g_CanShowBindEntry = true
	ChangeBindEntryVisible(OwnerCtrl)
end

function OnVisibleChange(self, bVisible)
	--[[
	
	--]]
end

function OnShowPanel(self, bShow)
	if bShow then
		AdjustAmountTextPosition(self)
		--AdjustSpeedTextPosition(self)
		ChangeBindEntryVisible(self)
	end
end












