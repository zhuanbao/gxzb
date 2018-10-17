--https://documenter.getpostman.com/view/679168/RWgoyyh5
local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local IPCUtil = XLGetObject("IPC.Util")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local hostwndManager = XLGetObject("Xunlei.UIEngine.HostWndManager")
local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")
local tFunctionHelper = XLGetGlobal("FunctionHelper")

ObjectBase = XLGetGlobal("ObjectBase")
CodeBind = ObjectBase:New()
XLSetGlobal("CodeBind", CodeBind)

CodeBind._strInterfacePrefix = "http://api.eastredm.com"

function IsNilString(AString)
	if AString == nil or AString == "" then
		return true
	end
	return false
end

function IsRealString(str)
	return type(str) == "string" and str ~= ""
end

function TipLog(strLog)
	tipUtil:Log("codebind: " .. tostring(strLog))
end

function CodeBind:Init()

end

function CodeBind:GetMachineBindStateRequestUrl()
	local tUserConfig = WorkModuleHelper:GetUserConfig()
	local strWorkID = tFunctionHelper.FetchValueByPath(tUserConfig, {"tUserInfo", "strWorkID"})
	if not IsRealString(strWorkID) then
		return
	end
	local strInterfaceName = "p/v1/user/get-inviter"
    local strInterfaceParam = "openID=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strOpenID"])))
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(strWorkID)
	strInterfaceParam = strInterfaceParam .. "&peerid=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetPeerID()))
	local strParam = ApiInterfaceModule:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  self._strInterfacePrefix .. strParam
	TipLog("[GetMachineBindStateRequestUrl] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

--[[
	是否是新用户(从没被邀请过)		当前是否有加成       是否是新设备
	can_be_invited                  has_addition		is_new_device
		1                                -                    0                    弹输入邀请码
		1                                -                    1                    弹输入邀请码
		
		0                                0                    -                    不弹框
		0                                1                    0                    弹已其他用户绑定
		0                                1                    1                    弹验证成功
--]]
function CodeBind:QuerySvrForMachineBindState(funBindFinish)
	local strUrl = self:GetMachineBindStateRequestUrl()
	if not IsRealString(strUrl) then
		funBindFinish()
		return 
	end	
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[QuerySvrForShowCodeBindState] strUrl = " .. strUrl)
	
	local function fnCallBack(bRet, tabInfo)
		if not bRet or type(tabInfo["data"]) ~= "table" or tabInfo["data"]["errCode"] ~= 0 then
			funBindFinish()	
			return
		end
		--[[
		tabInfo["data"]["can_be_invited"] = 1
		tabInfo["data"]["has_addition"] = 1
		tabInfo["data"]["is_new_device"] = 0
		--]]
		if tabInfo["data"]["can_be_invited"] == 0 and tabInfo["data"]["has_addition"] == 0 then
			funBindFinish()
			return
		end
		local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
		objHostWnd:Show(1)
		Helper:CreateModalWnd("GXZB.InviteCodeBindWnd", "GXZB.InviteCodeBindTree", objHostWnd:GetWndHandle(), {["parentWnd"] = objHostWnd, ["inviter"] = tabInfo["data"]})
		funBindFinish()
	end
	ApiInterfaceModule:GetServerJsonData(strUrl, fnCallBack)
end

function CodeBind:ShowCodeBindWnd(funBindFinish)
	if not WorkModuleHelper:CheckIsBinded() then
		return
	end
	self:QuerySvrForMachineBindState(funBindFinish)
end

function CodeBind:GetBindInviterCodeRequestUrl(strCode)
	local tUserConfig = WorkModuleHelper:GetUserConfig()
	local strWorkID = tFunctionHelper.FetchValueByPath(tUserConfig, {"tUserInfo", "strWorkID"})
	if not IsRealString(strWorkID) then
		return
	end
	local strInterfaceName = "p/v1/user/bind-inviter"
	local strInterfaceParam = "code=" .. strCode
	strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strOpenID"])))
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(strWorkID)
	strInterfaceParam = strInterfaceParam .. "&peerid=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetPeerID()))
	local strParam = ApiInterfaceModule:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  self._strInterfacePrefix .. strParam
	TipLog("[GetBindInviterCodeRequestUrl] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function CodeBind:QuerySvrForBindInviterCode(strCode, funReuslt)
	local strUrl = self:GetBindInviterCodeRequestUrl(strCode)
	if not IsRealString(strUrl) then
		return 
	end	
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[QuerySvrForBindInviterCode] strUrl = " .. strUrl)
	
	local function fnCallBack(bRet, tabInfo)
		if not bRet or type(tabInfo["data"]) ~= "table" then
			funReuslt(nil)
			return
		end
		--tabInfo["data"]["errCode"]=0
		funReuslt(tabInfo["data"])
	end
	ApiInterfaceModule:GetServerJsonData(strUrl, fnCallBack)
end







