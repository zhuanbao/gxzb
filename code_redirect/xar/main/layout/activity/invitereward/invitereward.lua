local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local IPCUtil = XLGetObject("IPC.Util")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local hostwndManager = XLGetObject("Xunlei.UIEngine.HostWndManager")
local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")
local tFunctionHelper = XLGetGlobal("FunctionHelper")

ObjectBase = XLGetGlobal("ObjectBase")
InviteReward = ObjectBase:New()
XLSetGlobal("InviteReward", InviteReward)

InviteReward._strInterfacePrefix = "http://api.eastredm.com"
InviteReward._bShouldEnter = false

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
	tipUtil:Log("invitereward: " .. tostring(strLog))
end

function InviteReward:Init()

end

function InviteReward:AddEnterOnTakeCashPanel()
	local wndMain = UIInterface:GetMainHostWnd()
	local objtree = wndMain:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	local objTakeCashPanel = objMainBodyCtrl:GetChildObjByCtrlName("TakeCashPanel")
	
	local objEnter = objTakeCashPanel:GetObject("InviteReward.Enter.TaskCash")
	if objEnter == nil then
		objEnter = objFactory:CreateUIObject("InviteReward.Enter.TaskCash", "TakeCashRewardEnter")
		objTakeCashPanel:AddChild(objEnter)
		objEnter:SetObjPos2("(father.width-263)/2", 47, 263, 36)
	end

end

function InviteReward:GetInviteNoticeInfoRequestUrl()
	local strInterfaceName = "p/v1/site/invite-rewards"
	local strReguestUrl =  self._strInterfacePrefix .. "/" .. strInterfaceName
	TipLog("[GetInviteNoticeInfoRequestUrl] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function InviteReward:GetInviteNoticeInfo(funResult)
	local strUrl = self:GetInviteNoticeInfoRequestUrl()
	if not IsRealString(strUrl) then
		return 
	end	
	strUrl = strUrl .. "?rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[GetInviteNoticeInfo] strUrl = " .. strUrl)
	
	local function fnCallBack(bRet, tabInfo)
		if not bRet or type(tabInfo["data"]) ~= "table" or tabInfo["data"]["errCode"] ~= 0 then
			return
		end
		funResult(tabInfo["data"])
	end
	ApiInterfaceModule:GetServerJsonData(strUrl, fnCallBack)
end

function InviteReward:GetInviteCodeRequestUrl()
	local tUserConfig = WorkModuleHelper:GetUserConfig()
	local strWorkID = tFunctionHelper.FetchValueByPath(tUserConfig, {"tUserInfo", "strWorkID"})
	if not IsRealString(strWorkID) then
		return
	end
	local strInterfaceName = "p/v1/user/code"
    local strInterfaceParam = "openID=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strOpenID"])))
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(strWorkID)
	strInterfaceParam = strInterfaceParam .. "&peerid=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetPeerID()))
	local strParam = ApiInterfaceModule:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  self._strInterfacePrefix .. strParam
	TipLog("[GetInviteCodeRequestUrl] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function InviteReward:QuerySvrForInviteCode()
	local strUrl = self:GetInviteCodeRequestUrl()
	if not IsRealString(strUrl) then
		return 
	end	
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[QuerySvrForInviteCode] strUrl = " .. strUrl)
	
	local function fnCallBack(bRet, tabInfo)
		if not bRet or type(tabInfo["data"]) ~= "table" or tabInfo["data"]["errCode"] ~= 0 then
			return
		end

		if not IsRealString(tabInfo["data"]["code"]) then
			return
		end
		local tUserConfig = WorkModuleHelper:GetUserConfig()
		tUserConfig["tUserInfo"]["strInviteCode"] = tabInfo["data"]["code"]
		tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
		self:ShowInviteReward()
	end
	ApiInterfaceModule:GetServerJsonData(strUrl, fnCallBack)
end

function InviteReward:ShowInviteReward()
	InviteReward:AddEnterOnTakeCashPanel()
	SetOnceTimer(function(item, id)
					self:CheckAndShowRewardEnterWnd()
				 end,
	15*60*1000)
end

function InviteReward:ClearInviteReward()
	local wndMain = UIInterface:GetMainHostWnd()
	local objtree = wndMain:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	local objTakeCashPanel = objMainBodyCtrl:GetChildObjByCtrlName("TakeCashPanel")
	
	local objEnter = objTakeCashPanel:GetObject("InviteReward.Enter.TaskCash")
	if objEnter ~= nil then
		objTakeCashPanel:RemoveChild(objEnter)
	end
	self._bShouldEnter = false
end

function InviteReward:CheckAndShowRewardEnterWnd()
	if not WorkModuleHelper:CheckIsBinded() then
		return
	end
	local tUserConfig = WorkModuleHelper:GetUserConfig()
	local strInviteCode = tFunctionHelper.FetchValueByPath(tUserConfig, {"tUserInfo", "strInviteCode"})
	if not IsRealString(strInviteCode) then
		TipLog("[CheckAndShowRewardEnterWnd] popup fail, get invite code fail")
		return
	end
	local bNoPopRewardEnterWnd =  tFunctionHelper.FetchValueByPath(tUserConfig, {"tActive", "tInvite", "bNoPopRewardEnterWnd"}) or false
	if bNoPopRewardEnterWnd then
		TipLog("[CheckAndShowRewardEnterWnd] popup fail, config no pop")
		return
	end
	local objInviteRewardInfoWnd = Helper.hostWndManager:GetHostWnd("GXZB.InviteRewardInfo.ModalInstance")
	if objInviteRewardInfoWnd then 
		TipLog("[CheckAndShowRewardEnterWnd] popup fail, is showing")
		return 
	end
	local nLastPopupTime =  tFunctionHelper.FetchValueByPath(tUserConfig, {"tActive", "tInvite", "nLastPopupRewardEnterWndTime"}) or 0
	local nCurrentTime = tFunctionHelper.GetCurrentServerTime()
	if not tFunctionHelper.CheckIsAnotherDay(nLastPopupTime, nCurrentTime) then
		TipLog("[CheckAndShowRewardEnterWnd] popup fail, the same day")
		return false
	end
	UIInterface:CreatePopUpWnd("GXZB.RewardEnterWnd")
	
end
	
function InviteReward:PrepareInviteReward()
	if self._bShouldEnter then
		return
	end
	if not WorkModuleHelper:CheckIsBinded() then
		return
	end
	self._bShouldEnter = true
	local tUserConfig = WorkModuleHelper:GetUserConfig()
	local strInviteCode = tFunctionHelper.FetchValueByPath(tUserConfig, {"tUserInfo", "strInviteCode"})
	if IsRealString(strInviteCode) then
		self:ShowInviteReward(strInviteCode)
		return 
	end	
	self:QuerySvrForInviteCode()
end