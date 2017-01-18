local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
local Helper = XLGetGlobal("Helper")
local objGraphicFac = XLGetObject("Xunlei.XLGraphic.Factory.Object")

function TipLog(strLog)
	if type(tipUtil.Log) == "function" then
		tipUtil:Log("@@ChildCtrl_MinerInfo: " .. tostring(strLog))
	end
end

function OnClickStartMiner(self)
	if not tFunctionHelper.CheckIsWorking() then
		self:SetText("暂停赚宝")
		tFunctionHelper.NotifyStart()
	else
		self:SetText("开启赚宝")
		tFunctionHelper.NotifyPause()
	end
end

function UpdateWeiXinInfo(self, tUserConfig)
	local objHeadImg= self:GetControlObject("ChildCtrl_MinerInfo.UserInfo.HeadImg")
	local objNickName= self:GetControlObject("ChildCtrl_MinerInfo.UserInfo.NickName")
	if tFunctionHelper.CheckIsBinded() then
		local strImagePath = tUserConfig["tUserInfo"]["wxHeadImgPath"]
		local objBitmap = objGraphicFac:CreateBitmap(strImagePath, "ARGB32")
		if not objBitmap then
			TipLog("[UpdateWeiXinInfo] create Head Img bitmap failed")
			return false
		end
		objHeadImg:SetBitmap(objBitmap)
		objNickName:SetText(tUserConfig["tUserInfo"]["strNickName"])
	else
		objHeadImg:SetResID("WeiXin.HeadImg.default")
		objNickName:SetText("未绑定")
	end
end

function UpdateMachineName(self, tUserConfig)
	local strMachineName = tUserConfig["tUserInfo"]["strMachineName"]

	local objMachineName= self:GetControlObject("ChildCtrl_MinerInfo.MachineName")

	if objMachineName ~= nil then
		local strText = "机器名称：" .. strMachineName
		objMachineName:SetText(strText)
	end
end

function UpdateSpeed(self, strSpeed)
	local objSpeed= self:GetControlObject("ChildCtrl_MinerInfo.Speed")

	if objSpeed ~= nil then
		local strText = "机器名称：" .. strSpeed .. "/s"
		objSpeed:SetText(strText)
	end
end

function UpdateMinerInfo(self, strText)
	local objInfo= self:GetControlObject("ChildCtrl_MinerInfo.Info")
	objInfo:SetText(strText)
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















