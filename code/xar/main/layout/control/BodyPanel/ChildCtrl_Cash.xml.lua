local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
local Helper = XLGetGlobal("Helper")
local objGraphicFac = XLGetObject("Xunlei.XLGraphic.Factory.Object")

function TipLog(strLog)
	if type(tipUtil.Log) == "function" then
		tipUtil:Log("@@ChildCtrl_Cash: " .. tostring(strLog))
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
	local objHeadImg= self:GetControlObject("ChildCtrl_Cash.UserInfo.HeadImg")
	local objNickName= self:GetControlObject("ChildCtrl_Cash.UserInfo.NickName")
	
	if objHeadImg ~= nil then
		objHeadImg:SetBitmap(objBitmap)
	end
	if objNickName ~= nil then
		objNickName:SetText(tUserConfig["tUserInfo"]["strNickName"])
	end
end