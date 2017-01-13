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

end

function UpdateWeixinInfo(self, tUserConfig)
	local strImagePath = tUserConfig["tUserInfo"]["wxHeadImgPath"]
	local objBitmap = objGraphicFac:CreateBitmap(strImagePath, "ARGB32")
	if not objBitmap then
		TipLog("[UpdateWeixinInfo] create Head Img bitmap failed")
		return false
	end
	local objHeadImg= self:GetControlObject("ChildCtrl_MinerInfo.UserInfo.HeadImg")
	local objNickName= self:GetControlObject("ChildCtrl_MinerInfo.UserInfo.NickName")
	
	if objHeadImg ~= nil then
		objHeadImg:SetBitmap(objBitmap)
	end
	if objNickName ~= nil then
		objNickName:SetText(tUserConfig["tUserInfo"]["strNickName"])
	end
end


function OnInitControl(self)
	local objMachineName= self:GetControlObject("ChildCtrl_MinerInfo.MachineName")
	if not objMachineName then
		return
	end
	local strText = "机器名称："
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	local strText = "机器名称：" .. (tUserConfig["tUserInfo"]["strMachineName"] or tFunctionHelper.GetPeerID())
	objMachineName:SetText(strText)
end















