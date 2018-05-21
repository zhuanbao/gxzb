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

RewardBindWX._nBindIdx = nil

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

end

function RewardBindWX:InitListener()
	self:AddListener("OnRewardInfo", self.OnRewardInfo, self)
    self:AddListener("OnShowQRCode", self.OnShowQRCode, self)
end

function RewardBindWX:UpdateQrCodePanel()
    if not self._bShouldReward then
        return
    end
	local wnd = UIInterface:GetMainHostWnd()
	if not wnd then
		if self._CycleTimerId then
			timeMgr:KillTimer(self._CycleTimerId)
			self._CycleTimerId = nil
		end
		return
	end
	
    local tBindInfo = self._tabContent["tDescInfo"]["tBindText"][self._nBindIdx]
    local nScanTextIdx = tBindInfo[3]
    local tabScanText = self._tabContent["tDescInfo"]["tScanText"][nScanTextIdx]
    
	local ObjDescBkg = self:GetQrCodePanleObjectByID("QRCodePanel.Panel.Reward.Desc.Bkg")
    local ObjDescText = self:GetQrCodePanleObjectByID("QRCodePanel.Panel.Reward.Desc.Text")
    local ObjUnbind = self:GetQrCodePanleObjectByID("QRCodePanel.Panel.UnBind")
	
    local nType = tBindInfo[2]
    if type(nType) == "number" and nType > 0 then
        local strRecvId = "GXZB.Activity.BindReward.Recv" .. tostring(nType)
        ObjDescBkg:SetResID(strRecvId)
        ObjDescBkg:SetVisible(true)
    end
    if type(tabScanText) == "table" then
        if IsRealString(tabScanText[1]) then
            ObjDescText:SetText(tabScanText[1])
            ObjDescBkg:SetVisible(true)
            ObjUnbind:Show(false)
            
        end
        if IsRealString(tabScanText[2]) then
            if self._dwCookie_DescBkg_OnLButtonUp then
                ObjDescBkg:RemoveListener("OnLButtonUp", self._dwCookie_DescBkg_OnLButtonUp)
            end
            self._dwCookie_DescBkg_OnLButtonUp = ObjDescBkg:AttachListener("OnLButtonUp", false, function()
                                                    ObjDescText:SetText(tabScanText[2])
                                                    local tStatInfo = {}
                                                    tStatInfo.fu1 = "qrcodereward"
                                                    tStatInfo.fu5 = "redpacket"
                                                    tStatInfo.fu6 = self._nBindIdx
                                                    StatisticClient:SendClickReport(tStatInfo)
                                                end)
            if self._dwCookie_DescText_OnLButtonUp then
                ObjDescText:RemoveListener("OnLButtonUp", self._dwCookie_DescText_OnLButtonUp)
            end
            self._dwCookie_DescText_OnLButtonUp = ObjDescText:AttachListener("OnLButtonUp", false, function()
                                                    ObjDescText:SetText(tabScanText[2])
                                                    local tStatInfo = {}
                                                    tStatInfo.fu1 = "qrcodereward"
                                                    tStatInfo.fu5 = "redpacket"
                                                    tStatInfo.fu6 = self._nBindIdx
                                                    StatisticClient:SendClickReport(tStatInfo)
                                                end)
            if self._dwCookie_DescText_OnVisibleChange then
                ObjDescText:RemoveListener("OnLButtonUp", self._dwCookie_DescText_OnVisibleChange)
            end
            self._dwCookie_DescText_OnVisibleChange = ObjDescText:AttachListener("OnVisibleChange", false, function(Obj, bVisible)
                                                    if bVisible then
                                                        ObjDescText:SetText(tabScanText[1])
                                                    end 
                                                end)
        end
    end
end

function RewardBindWX:UpdateBindWeixinEntry()
    if not self._bShouldReward then
        return
    end
    local tBindInfo = self._tabContent["tDescInfo"]["tBindText"][self._nBindIdx]
    local strEntryText = tBindInfo[1]
    local nType = tBindInfo[2]
    local nScanTextIdx = tBindInfo[3]
    local tabScanText = self._tabContent["tDescInfo"]["tScanText"][nScanTextIdx]
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
    
    ObjBindText:SetText(strEntryText)
    if type(nType) == "number" and nType > 0 then
        local strIconId = "GXZB.Activity.BindReward.Icon" .. tostring(nType)
        ObjBindIcon:SetResID(strIconId)
    else
        ObjBindIcon:SetResID("")
    end
    if not ClientWorkModule:CheckIsBinded() then
        ObjBindIcon:SetVisible(true)
        ObjMiningPanel:ShowBindWeiXin(true)
        if self._dwCookie_BindEntry_OnClick then
            ObjBindText:RemoveListener("OnClick", self._dwCookie_BindEntry_OnClick)
        end    
        self._dwCookie_BindEntry_OnClick = ObjBindText:AttachListener("OnClick", false, function()
                                                    local tStatInfo = {}
                                                    tStatInfo.fu1 = "bindentry"
                                                    tStatInfo.fu5 = "redpacket"
                                                    tStatInfo.fu6 = self._nBindIdx
                                                    StatisticClient:SendClickReport(tStatInfo)
                                                end)
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

function RewardBindWX:RandSort()
    local tabRand = {}
    local nCnt = #self._tabCond["tShow"]
    math.randomseed(tonumber(tostring(os.time()):reverse():sub(1,6)))
    for Idx=1, nCnt do
        local index = math.random(1,#self._tabCond["tShow"]) 
        local nValue = self._tabCond["tShow"][index]
        table.remove(self._tabCond["tShow"],index)
        tabRand[Idx] = nValue
    end
    self._tabCond["tShow"] = tabRand
    tFunctionHelper.DumpObj(self._tabCond["tShow"], "tShow")
end

function RewardBindWX:CheckCondition(tabInfo)
    local nUtc = tFunctionHelper.GetCurrentServerTime()
    local nBeginTime = tonumber(tabInfo["nBeginTime"]) or 0
    local nEndTime = tonumber(tabInfo["nEndTime"]) or 9999999999
    if nUtc < nBeginTime or nUtc > nEndTime then
        return false
    end
    if not tFunctionHelper.CheckPeerIDList(tabInfo["tPID"]) then
        return false
    end
    if type(tabInfo["tShow"]) ~= "table" or #tabInfo["tShow"] < 1 then
        return false
    end
    return true
end

function RewardBindWX:CheckCanShowRewardEnter(tabInfo)
    local tabReward = tabInfo["tRBindCfg_v2"]
    if type(tabReward) ~= "table" 
        or type(tabReward["tCondition"]) ~= "table" 
        or type(tabReward["tDescInfo"]) ~= "table" 
        or type(tabReward["tDescInfo"]["tBindText"]) ~= "table" 
        or type(tabReward["tDescInfo"]["tScanText"]) ~= "table" then
        return
    end
    local tabContent = nil
    local tabCondition = tabReward["tCondition"]
    for Idx=1,#tabCondition do
        local tabItem = tabCondition[Idx]
        if type(tabItem) == "table"
            and self:CheckCondition(tabItem) then
            tabContent = tabItem
            break
        end
    end
    if type(tabContent) ~= "table" then
        return
    end
    self:InitListener()
    self._tabCond = tabContent
    self._tabContent = tabReward
    self._bShouldReward = true
    self:RandSort()
    self:CycleShowBindEnter()
end

function RewardBindWX:CycleShowBindEnter()
    if not self._bShouldReward then
        return
    end
    local nCycleTime = self._tabCond["nCycleTime"] or 10
    if self._CycleTimerId then
		timeMgr:KillTimer(self._CycleTimerId)
		self._CycleTimerId = nil
	end
    local nIdx = self._nBindIdx or 1 
    self._nBindIdx = self._tabCond["tShow"][nIdx]
    self:UpdateBindWeixinEntry()
    self:UpdateQrCodePanel()
    if self._bShowQRCode then
        return
    end
    self._CycleTimerId = timeMgr:SetTimer(function(Itm, id)
        if ClientWorkModule:CheckIsBinded() then
            if self._CycleTimerId then
                timeMgr:KillTimer(self._CycleTimerId)
                self._CycleTimerId = nil
            end
        end    
        nIdx = nIdx + 1
        if nIdx > #self._tabCond["tShow"] then
            nIdx = 1
        end
        self._nBindIdx = self._tabCond["tShow"][nIdx]
        self:UpdateBindWeixinEntry()
        self:UpdateQrCodePanel()
	end, nCycleTime*1000)
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
    local tBindInfo = self._tabContent["tDescInfo"]["tBindText"][self._nBindIdx]
    local nScanTextIdx = tBindInfo[3]
    local tabScanText = self._tabContent["tDescInfo"]["tScanText"][nScanTextIdx]
    
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
        if type(tabScanText) == "table" 
            and IsRealString(tabScanText[3]) then
            --ObjResultText:SetCursorID("IDC_HAND")
            ObjResultText:SetTextFontResID("font.text13")
            ObjResultText:SetText(tabScanText[3])
            ObjResultText:SetVisible(true)
            ObjResultBkg:SetResID("GXZB.Activity.BindReward.Result")
            ObjResultBkg:SetVisible(true)
			--[[
            if self._dwCookie_ResultText_OnLButtonUp then
                ObjResultText:RemoveListener("OnLButtonUp", self._dwCookie_ResultText_OnLButtonUp)
            end
            self._dwCookie_ResultText_OnLButtonUp = ObjResultText:AttachListener("OnLButtonUp", false, function()
                                            UIInterface:ChangeMainBodyPanel("TakeCashPanel")
                                            local tStatInfo = {}
                                            tStatInfo.fu1 = "qrcodereward"
                                            tStatInfo.fu5 = "takecash"
                                            tStatInfo.fu6 = self._nBindIdx
                                            StatisticClient:SendClickReport(tStatInfo)
                                        end)
			--]]
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
	local ObjQRCodePanel = ObjMainBodyCtrl:GetChildObjByCtrlName("QRCodePanel")
	local ObjCtrl = ObjQRCodePanel:GetControlObject(strObjID)
    return ObjCtrl
end

function RewardBindWX:OnShowQRCode(event, bShow)
    if bShow then
        self._bShowQRCode = true
        if self._CycleTimerId then
            timeMgr:KillTimer(self._CycleTimerId)
            self._CycleTimerId = nil
        end
    else
        self._bShowQRCode = false
        self:CycleShowBindEnter()
    end
end

