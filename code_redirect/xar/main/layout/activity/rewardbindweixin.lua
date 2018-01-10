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
RewardBindWX._tabContent = {}

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

function RewardBindWX:UpdateQrCodePanel()
	local ObjDescBkg = self:GetQrCodePanleObjectByID("QRCodePanel.Panel.Reward.Desc.Bkg")
    local ObjDescText = self:GetQrCodePanleObjectByID("QRCodePanel.Panel.Reward.Desc.Text")
    local ObjUnbind = self:GetQrCodePanleObjectByID("QRCodePanel.Panel.UnBind")
    local nType = self._tabContent["nType"]
    if type(nType) == "number" and nType > 0 then
        local strRecvId = "GXZB.Activity.BindReward.Recv" .. tostring(nType)
        ObjDescBkg:SetResID(strRecvId)
        ObjDescBkg:SetVisible(true)
    end
    local tabScanText = self._tabContent["tScanText"]
    if type(tabScanText) == "table" then
        if IsRealString(tabScanText[1]) then
            ObjDescText:SetText(tabScanText[1])
            ObjDescBkg:SetVisible(true)
            ObjUnbind:Show(false)
            
        end
        if IsRealString(tabScanText[2]) then
            ObjDescBkg:AttachListener("OnLButtonUp", false, function()
                                                    ObjDescText:SetText(tabScanText[2])
                                                    local tStatInfo = {}
                                                    tStatInfo.fu1 = "qrcodereward"
                                                    tStatInfo.fu5 = "redpacket"
                                                    StatisticClient:SendClickReport(tStatInfo)
                                                end)
            ObjDescText:AttachListener("OnLButtonUp", false, function()
                                                    ObjDescText:SetText(tabScanText[2])
                                                    tStatInfo.fu1 = "qrcodereward"
                                                    tStatInfo.fu5 = "redpacket"
                                                    StatisticClient:SendClickReport(tStatInfo)
                                                end)
            ObjDescText:AttachListener("OnVisibleChange", false, function(Obj, bVisible)
                                                    if bVisible then
                                                        ObjDescText:SetText(tabScanText[1])
                                                    end 
                                                end)
        end
    end
end

function RewardBindWX:UpdateBindWeixinEntry()
	local wnd = UIInterface:GetMainHostWnd()
	if not wnd then
		return
	end
	local Objtree = wnd:GetBindUIObjectTree()
	local ObjRootCtrl = Objtree:GetUIObject("root.layout:root.ctrl")
	local ObjMainBodyCtrl = ObjRootCtrl:GetControlObject("WndPanel.MainBody")
	local ObjMiningPanel = ObjMainBodyCtrl:GetChildObjByCtrlName("MiningPanel")
	
    local ObjBindText = ObjMiningPanel:GetControlObject("MiningPanel.Panel.BindWeiXin.Text")
    local ObjBindIcon = ObjMiningPanel:GetControlObject("MiningPanel.Panel.BindWeiXin.Icon")
    
    ObjBindText:SetText(self._tabContent["strBindText"])
    local nType = self._tabContent["nType"]
    if type(nType) == "number" and nType > 0 then
        local strIconId = "GXZB.Activity.BindReward.Icon" .. tostring(nType)
        ObjBindIcon:SetResID(strIconId)
    end
    if not ClientWorkModule:CheckIsBinded() then
        ObjBindIcon:SetVisible(true)
        ObjMiningPanel:ShowBindWeiXin(true)
    end    
end

function RewardBindWX:RestoreBindWeixinEntry()
	local wnd = UIInterface:GetMainHostWnd()
	if not wnd then
		return
	end
	local Objtree = wnd:GetBindUIObjectTree()
	local ObjRootCtrl = Objtree:GetUIObject("root.layout:root.ctrl")
	local ObjMainBodyCtrl = ObjRootCtrl:GetControlObject("WndPanel.MainBody")
	local ObjMiningPanel = ObjMainBodyCtrl:GetChildObjByCtrlName("MiningPanel")
	local ObjBindWeiXinEntry = ObjMiningPanel:GetControlObject("MiningPanel.Panel.BindWeiXin")
    ObjBindWeiXinEntry:SetText("点这里扫微信提人民币")
    ObjBindWeiXinEntry:SetTextColorID("AF8656")
    ObjBindWeiXinEntry:SetTextHoverColorID("AF8656")
end

function RewardBindWX:CheckCanShowRewardEnter(tabInfo)
    local tabReward = tabInfo["tRBindCfg"]
    if type(tabReward) ~= "table" and type(tabReward["tInfo"]) ~= "table" then
        return
    end
    local tabContent = nil
    local tabData = tabReward["tInfo"]
    for Idx=1,#tabData do
        local tabItem = tabData[Idx]
        if type(tabItem) == "table"
            and IsRealString(tabItem["strBindText"])
            and tFunctionHelper.CheckPeerIDList(tabItem["tPID"]) then
            tabContent = tabItem
            break
        end
    end
    if type(tabContent) ~= "table" then
        return
    end
    self._tabContent = tabContent
    self._bShouldReward = true
    self:UpdateBindWeixinEntry()
    self:UpdateQrCodePanel()
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
    local ObjDescBkg = self:GetQrCodePanleObjectByID("QRCodePanel.Panel.Reward.Desc.Bkg")
    local ObjDescText = self:GetQrCodePanleObjectByID("QRCodePanel.Panel.Reward.Desc.Text")
    ObjDescBkg:SetVisible(false)
    ObjDescText:SetVisible(false)
    
    local ObjResultBkg = self:GetQrCodePanleObjectByID("QRCodePanel.Panel.Reward.Result.Bkg")
    local ObjResultText = self:GetQrCodePanleObjectByID("QRCodePanel.Panel.Reward.Result.Text")
	if bSuccess and type(tabInfo["data"]) == "table" then
        if tabInfo["data"]["errCode"] == -1 then
            --ObjResultText:SetText("                   您已领取过该福利！                   每个微信账号仅能领取一次~")
            ObjResultText:SetCursorID("IDC_ARROW")
            ObjResultText:SetTextFontResID("font.text13")
            ObjResultText:SetText("您已领取过该福利！\r\n每个微信账号仅能领取一次~")
            ObjResultText:SetVisible(true)
            ObjResultBkg:SetResID("GXZB.Activity.BindReward.Result")
            ObjResultBkg:SetVisible(true)
            return
        end
        local nBalance = tabInfo["data"]["balance"]
        if type(nBalance) == "number" then
            ClientWorkModule:SetUserCurrentBalance(nBalance)
            UIInterface:UpdateUserBalance()
        end    
        if type(self._tabContent) == "table" 
            and type(self._tabContent["tScanText"] == "table")
            and IsRealString(self._tabContent["tScanText"][3]) then
            ObjResultText:SetCursorID("IDC_HAND")
            ObjResultText:SetTextFontResID("font.text13.underline")
            ObjResultText:SetText(self._tabContent["tScanText"][3])
            ObjResultText:SetVisible(true)
            ObjResultBkg:SetResID("GXZB.Activity.BindReward.Result")
            ObjResultBkg:SetVisible(true)
            ObjResultText:AttachListener("OnLButtonUp", false, function()
                                            UIInterface:ChangeMainBodyPanel("TakeCashPanel")
                                            local tStatInfo = {}
                                            tStatInfo.fu1 = "qrcodereward"
                                            tStatInfo.fu5 = "takecash"
                                            StatisticClient:SendClickReport(tStatInfo)
                                        end)
        end
        
	else
        ObjResultBkg:SetVisible(true)
        ObjResultText:SetText("请求奖励失败!")
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
	local Objtree = wnd:GetBindUIObjectTree()
	local ObjRootCtrl = Objtree:GetUIObject("root.layout:root.ctrl")
	local ObjMainBodyCtrl = ObjRootCtrl:GetControlObject("WndPanel.MainBody")
	local ObjMiningPanel = ObjMainBodyCtrl:GetChildObjByCtrlName("QRCodePanel")
	local ObjCtrl = ObjMiningPanel:GetControlObject(strObjID)
    return ObjCtrl
end



