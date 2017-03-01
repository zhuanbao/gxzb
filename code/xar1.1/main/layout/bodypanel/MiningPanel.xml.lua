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

end

function ChangeBindEntryVisible(self, bVisible)
	local ObjBindWeiXinEntry = self:GetControlObject("MiningPanel.Panel.BindWeiXin")
	ObjBindWeiXinEntry:Show(bVisible)
end

function OnVisibleChange(self, bVisible)
	if bVisible then
		if not tFunctionHelper.CheckIsBinded() then
			ChangeBindEntryVisible(self,true)
		else
			ChangeBindEntryVisible(self,false)
		end
	end
end












