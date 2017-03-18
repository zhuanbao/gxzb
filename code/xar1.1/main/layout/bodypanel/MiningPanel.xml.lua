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

local imageOpenAni = nil
function StartAnim(self, bstart)
	local father = self:GetOwnerControl()
	local animimage = father:GetObject("MiningPanel.Panel.StartAnim")
	local startbtn = father:GetObject("MiningPanel.Panel.StartBtn")
	local Preparing = father:GetObject("MiningPanel.Panel.Preparing")
	if bstart and not imageOpenAni then
		startbtn:Show(false)
		Preparing:SetVisible(false)
		if not animimage then
			local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")
			animimage = objFactory:CreateUIObject("MiningPanel.Panel.StartAnim", "ImageObject")
			father:AddChild(animimage)
			local l, t, r, b = startbtn:GetObjPos()
			local w, h = r-l, b-t
			local offsetW, offsetH = (280-w)/2, (280-h)/2 
			animimage:SetObjPos(l-offsetW, t-offsetH, r+offsetW, b+offsetH)
		end
		animimage:SetVisible(true)
		imageOpenAni = Helper.Ani:RunSeqFrameAni(animimage, "GXZB.MainPanel.WorkingAnim", nil, 4000, true)
	else
		if imageOpenAni then
			imageOpenAni:Stop()
			imageOpenAni = nil
		end
		if animimage then
			animimage:SetVisible(false)
		end
		startbtn:Show(true)
		Preparing:SetVisible(true)
	end
end

function OnClickStopMining(self)
	if tFunctionHelper.CheckIsWorking() then
		local OwnerCtrl = self:GetOwnerControl()
		ResetUIVisible(OwnerCtrl)
		tFunctionHelper.NotifyPause()
		StartAnim(self, false)
	else
		tFunctionHelper.NotifyStart()
		StartAnim(self, true)
	end
end

function OnClickStartMining(self)
	if not tFunctionHelper.CheckIsWorking() then
		tFunctionHelper.NotifyStart()
		StartAnim(self, true)
	end
end

function OnClickBindWeiXin(self)
	tFunctionHelper.ChangeMainBodyPanel("QRCodePanel")
end


function OnInitControl(self)
	local ObjMiningSpeed = self:GetControlObject("MiningPanel.Panel.MiningSpeed")
	--ObjMiningSpeed:SetChildrenVisible(false)
	--ObjMiningSpeed:SetVisible(false)
	
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
	ResetUIVisible(self)
	
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

local MING_MINING_SPEED = 3
local MING_MINING_EEEOR = 4
local MING_SOLUTION_FIND = 5
local MING_MINING_EEEOR_TIMEOUT = 100


function ShowPreparingText(self)
	if g_TimeIDPreparing ~= nil then
		return
	end
	local ObjPreparingText = self:GetControlObject("MiningPanel.Panel.Preparing")
	if not ObjPreparingText:GetVisible() then
		ObjPreparingText:SetVisible(true)
	end
	local objstopbtn = OwnerCtrl:GetControlObject("MiningPanel.Panel.StopBtn")
	local objstopattr = objstopbtn:GetAttribute()
	objstopattr.NormalBkgID = "texture.MainPanel.StopMining.normal"
	objstopattr.HoverBkgID = "texture.MainPanel.StopMining.hover"
	objstopattr.DownBkgID = "texture.MainPanel.StopMining.down"
	objstopattr.DisableBkgID = "texture.MainPanel.StopMining.normal"
	objstopbtn:Updata()
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

function UpdateMiningState(self, nState, nParam)
	local ObjMiningState = self:GetControlObject("MiningPanel.Panel.MiningState")
	local strText = ""
	if nState == MING_MINING_SPEED then
		--g_CanShowBindEntry = true
	end
end

function ResetUIVisible(OwnerCtrl)
	if g_TimeIDPreparing ~= nil then
		timeMgr:KillTimer(g_TimeIDPreparing)
		g_TimeIDPreparing = nil
	end
	local ObjPreparingText = OwnerCtrl:GetControlObject("MiningPanel.Panel.Preparing")
	ObjPreparingText:SetVisible(true)
	ObjPreparingText:SetText("开始赚宝")
	local ObjMiningState = OwnerCtrl:GetControlObject("MiningPanel.Panel.MiningState")
	ObjMiningState:SetVisible(false)
	ObjMiningState:SetText("")
	local objstopbtn = OwnerCtrl:GetControlObject("MiningPanel.Panel.StopBtn")
	local objstopattr = objstopbtn:GetAttribute()
	objstopattr.NormalBkgID = "texture.MainPanel.MiniStartMining.normal"
	objstopattr.HoverBkgID = "texture.MainPanel.MiniStartMining.hover"
	objstopattr.DownBkgID = "texture.MainPanel.MiniStartMining.down"
	objstopattr.DisableBkgID = "texture.MainPanel.MiniStartMining.normal"
	objstopbtn:Updata()
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












