local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local IPCUtil = XLGetObject("IPC.Util")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local hostwndManager = XLGetObject("Xunlei.UIEngine.HostWndManager")
local tFunctionHelper = XLGetGlobal("FunctionHelper")

ObjectBase = XLGetGlobal("ObjectBase")
RewardBindWX = ObjectBase:New()
XLSetGlobal("RewardBindWX", RewardBindWX)

RewardBindWX._bShouldReward = false
--进入入口
--1：赚宝界面
--2：提现按钮
RewardBindWX._nEnterScene = 0

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
	tipUtil:Log("rewardbindweixin: " .. tostring(strLog))
end

function RewardBindWX:Init()
	self:InitListener()
end

function RewardBindWX:InitListener()
	self:AddListener("OnRewardInfo", self.OnRewardInfo, self)
end

function RewardBindWX:SetEnterScene(nScene)
	self._nEnterScene = nScene
end

function RewardBindWX:AddEnterListener()
	local wnd = UIInterface:GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
    local objBtnTakeCash = objMainBodyCtrl:GetControlObject("MainPanel.Buttom.TakeCash.Btn")
    objBtnTakeCash:AttachListener("OnLButtonUp", false, function()
                                           self:SetEnterScene(2)
                                        end)
     
    local objMiningPanel = objMainBodyCtrl:GetChildObjByCtrlName("MiningPanel")
    local ObjBindWeiXinEntry = objMiningPanel:GetControlObject("MiningPanel.Panel.BindWeiXin")
    ObjBindWeiXinEntry:AttachListener("OnClick", false, function()
                                           self:SetEnterScene(1)
                                        end)
end

function RewardBindWX:UpdateBindWeixinEntry()
	local wnd = UIInterface:GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	local objMiningPanel = objMainBodyCtrl:GetChildObjByCtrlName("MiningPanel")
	local ObjBindWeiXinEntry = objMiningPanel:GetControlObject("MiningPanel.Panel.BindWeiXin")
    ObjBindWeiXinEntry:SetText("绑定微信立得9999元宝")
    ObjBindWeiXinEntry:SetTextColorID("FF0000")
    ObjBindWeiXinEntry:SetTextHoverColorID("FF0000")
end

function RewardBindWX:RestoreBindWeixinEntry()
	local wnd = UIInterface:GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	local objMiningPanel = objMainBodyCtrl:GetChildObjByCtrlName("MiningPanel")
	local ObjBindWeiXinEntry = objMiningPanel:GetControlObject("MiningPanel.Panel.BindWeiXin")
    ObjBindWeiXinEntry:SetText("点这里扫微信提人民币")
    ObjBindWeiXinEntry:SetTextColorID("AF8656")
    ObjBindWeiXinEntry:SetTextHoverColorID("AF8656")
end

function RewardBindWX:CheckCanShowRewardEnter(tabInfo)
    local tabRewardPID = tabInfo["tRBindPID"]
    if type(tabRewardPID) ~= "table" then
        return
    end
    if not tFunctionHelper.CheckPeerIDList(tabRewardPID) then
        return
    end
    self._bShouldReward = true
    self:UpdateBindWeixinEntry()
end

function RewardBindWX:HasShowedRewardEnter()
   return self._bShouldReward
end

function RewardBindWX:QuerySvrForRewardInfo()
	local tUserConfig = ClientWorkModule:GetUserConfig()
	local strInterfaceName = "eventBind"
    local strInterfaceParam = "workerID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strWorkID"]))
    if IsRealString(tUserConfig["tUserInfo"]["strOpenID"]) then
		strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strOpenID"])))
	end
	strInterfaceParam = strInterfaceParam .. "&peerid=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetPeerID()))
    local strGUID = tFunctionHelper.GetMachineID()
    if IsRealString(strGUID) then
		strInterfaceParam = strInterfaceParam .. "&param1=" .. Helper:UrlEncode(strGUID)
	end
    
	local strParam = ClientWorkModule:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  ClientWorkModule:FormatRequestUrl(strParam)
	TipLog("[QuerySvrForRewardInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function RewardBindWX:GetBindWeiXinRewardInfo()
	local strUrl = self:QuerySvrForRewardInfo()
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[GetRewardInfo] strUrl = " .. strUrl)
	
	local function fnRewardInfoCallBack(bRet, tabInfo)
		self:DispatchEvent("OnRewardInfo", bRet, tabInfo)
	end
	ClientWorkModule:GetServerJsonData(strUrl, fnRewardInfoCallBack)
end

function RewardBindWX:OnRewardInfo(event, bSuccess, tabInfo)
    local objRewardFail = self:GetQrCodePanleObjectByID("QRCodePanel.Panel.Reward.Fail")
    local objRewardSuccess = self:GetQrCodePanleObjectByID("QRCodePanel.Panel.Reward.Success")
	if bSuccess and type(tabInfo["data"]) == "table" then
        if tabInfo["data"]["errCode"] == -1 then
            objRewardFail:SetText("您已经领取过该福利，一个微信ID仅能领取一次！")
            objRewardFail:SetVisible(true)
            return
        end
        local strRewardSuccessText = ""
        nBalance = tabInfo["data"]["balance"]
        ClientWorkModule:SetUserCurrentBalance(nBalance)
		UIInterface:UpdateUserBalance()
        if nBalance < 10000 then
            strRewardSuccessText = "您已成功获得9999元宝，再赚1元宝即可提现！"
        else
            if self._nEnterScene == 1 then
                strRewardSuccessText = "您已成功获得9999元宝！您已满足提现条件，立即体验！"
            else
                strRewardSuccessText = "您已成功获得9999元宝！您已满足提现条件！"
            end
        end
        objRewardSuccess:SetText(strRewardSuccessText)
        objRewardSuccess:Show(true)
        objRewardSuccess:AttachListener("OnClick", false, function()
                                            if nBalance < 10000 then
                                                UIInterface:ChangeMainBodyPanel("MiningPanel")
                                            else
                                                UIInterface:ChangeMainBodyPanel("TakeCashPanel")
                                            end
                                        end)
	else
        objRewardFail:SetText("请求奖励失败!")
        objRewardFail:SetVisible(true)
        if type(tabInfo) == "table" then
            TipLog("[OnRewardInfo] Query reward fail, rtn = " .. tostring(tabInfo["rtn"]) .. ", data = " .. tostring(tabInfo["data"]))
        end
	end
    --self:RestoreBindWeixinEntry()
end

function RewardBindWX:GetQrCodePanleObjectByID(strObjID)
    local wnd = UIInterface:GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	local objMiningPanel = objMainBodyCtrl:GetChildObjByCtrlName("QRCodePanel")
	local ObjCtrl = objMiningPanel:GetControlObject(strObjID)
    return ObjCtrl
end



