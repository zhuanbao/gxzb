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
	
end


function OnInitControl(self)
	local objMachineName= self:GetControlObject("ChildCtrl_MinerInfo.MachineName")
	if not objMachineName then
		return
	end
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	local strText = "机器名称：" .. (tUserConfig["tUserInfo"]["strMachineName"] or tFunctionHelper.GetPeerID())
	objMachineName:SetText(strText)
	
	local objInfo= self:GetControlObject("ChildCtrl_MinerInfo.Info")
	objInfo:SetText("余额\r\n0元宝")
end















