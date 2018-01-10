local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local Helper = XLGetGlobal("Helper")
local objGraphicFac = XLGetObject("Xunlei.XLGraphic.Factory.Object")
local timerManager = XLGetObject("Xunlei.UIEngine.TimerManager")

local gBinding = false
local gQRTimeoutId = nil
local gChangePanelTimeoutId = nil
local gMinTakeCashBalance = 10000

local gLastExpireTime = 0
local gLastQRCodeBitmap = nil
local gLastTabInfo = {}

local tabCtrl = {
	"QRCodePanel.Panel.QRCode.GenFailed",
	"QRCodePanel.Panel.QRCode.Success",
	"QRCodePanel.Panel.QRCode.Expire",
	"QRCodePanel.Panel.QRCode.BindFailed",
}
function TipLog(strLog)
	if type(tipUtil.Log) == "function" then
		tipUtil:Log("QRCodePanel: " .. tostring(strLog))
	end
end

function ResetLastQRCodeInfo()
	gLastExpireTime = 0
	gLastQRCodeBitmap = nil
	gLastTabInfo = {}
end

function ResetGlobalParam()
	if gQRTimeoutId ~= nil then
		timerManager:KillTimer(gQRTimeoutId)
		gQRTimeoutId = nil
	end
	if gChangePanelTimeoutId ~= nil then
		timerManager:KillTimer(gChangePanelTimeoutId)
		gChangePanelTimeoutId = nil
	end
end

function ShowCtrl(OwnerCtrl,strCtrlID)
	for index=1, #tabCtrl do
		local objCtrl= OwnerCtrl:GetControlObject(tabCtrl[index])
		if strCtrlID ~= tabCtrl[index] then
			objCtrl:SetVisible(false)
			objCtrl:SetChildrenVisible(false)
		else
			objCtrl:SetChildrenVisible(true)
			objCtrl:SetVisible(true)
		end	
	end	
end

function AutoJumpToPanel(OwnerCtrl)
	local textActiveTime= OwnerCtrl:GetControlObject("QRCodePanel.Panel.ActiveTime")
	local strPanle = "MiningPanel"
	local strInfo = "秒后跳转到赚宝界面"
	if ClientWorkModule:GetUserCurrentBalance() >= gMinTakeCashBalance then
		strPanle = "TakeCashPanel"
		strInfo = "秒后开始提现"
	end
	local nTotalTime = 5
	local strText = nTotalTime .. strInfo
	textActiveTime:SetText(strText)
	textActiveTime:SetVisible(true)
	gChangePanelTimeoutId = timerManager:SetTimer(function(Itm, id)
		if nTotalTime <= 0 and gBinding then
			ResetGlobalParam()
			UIInterface:ChangeMainBodyPanel(strPanle)
			return
		end
		nTotalTime = nTotalTime - 1
		local strText = nTotalTime .. strInfo
		textActiveTime:SetText(strText)
		end, 1000)
end

function UpdateBindSuccessUI(OwnerCtrl)
	ShowCtrl(OwnerCtrl,"QRCodePanel.Panel.QRCode.Success")
	local textActiveTime= OwnerCtrl:GetControlObject("QRCodePanel.Panel.ActiveTime")
	textActiveTime:SetVisible(false)
	--local ObjBtnBegainMining= OwnerCtrl:GetControlObject("QRCodePanel.Panel.BegainMining")
	--ObjBtnBegainMining:Show(true) 
	local ObjTextLinkUnBind= OwnerCtrl:GetControlObject("QRCodePanel.Panel.UnBind")
	ObjTextLinkUnBind:Show(false)
	AutoJumpToPanel(OwnerCtrl)
end

function ResetUIVisible(OwnerCtrl)
	local ImgTmpCode = OwnerCtrl:GetControlObject("QRCodePanel.Panel.QRCode.TmpCode")
	local objDefault = objGraphicFac:CreateBitmap("ARGB32", 182, 182)
	local clorDefault = objGraphicFac:CreateColor(0, 0, 0, 127)
	if objDefault and clorDefault then
		objDefault:Fill(clorDefault)
		ImgTmpCode:SetBitmap(objDefault)
	end
	ShowCtrl(OwnerCtrl, nil)
	local textActiveTime= OwnerCtrl:GetControlObject("QRCodePanel.Panel.ActiveTime")
	textActiveTime:SetVisible(false)
	--local ObjBtnBegainMining= OwnerCtrl:GetControlObject("QRCodePanel.Panel.BegainMining")
	--ObjBtnBegainMining:Show(false) 

    local ObjDescBkg = OwnerCtrl:GetControlObject("QRCodePanel.Panel.Reward.Desc.Bkg")
    local ObjDescText = OwnerCtrl:GetControlObject("QRCodePanel.Panel.Reward.Desc.Text")
    ObjDescBkg:SetVisible(true)
    ObjDescText:SetVisible(true)
    
    local ObjTextLinkUnBind= OwnerCtrl:GetControlObject("QRCodePanel.Panel.UnBind")
    if Helper:IsRealString(ObjDescText:GetText())then
        ObjTextLinkUnBind:Show(false)
    else
        ObjTextLinkUnBind:Show(true)
    end
    local objResultBkg = OwnerCtrl:GetControlObject("QRCodePanel.Panel.Reward.Result.Bkg")
    local objResultText = OwnerCtrl:GetControlObject("QRCodePanel.Panel.Reward.Result.Text")
    objResultBkg:SetVisible(false)
    objResultText:SetVisible(false)
    
end

function CycleQueryBindState(OwnerCtrl,tabInfo,ObjBitmap)
	local nExpire = math.floor(tabInfo["data"]["expire"]/1000)
	local ImgTmpCode= OwnerCtrl:GetControlObject("QRCodePanel.Panel.QRCode.TmpCode")
	ImgTmpCode:SetBitmap(ObjBitmap)
	local nQueryInterval = tonumber(tabInfo["data"]["interval"]) or 10
	local textActiveTime= OwnerCtrl:GetControlObject("QRCodePanel.Panel.ActiveTime")
	local bQuerying = false
	local nTimerCounter = 0
	local function TimerHandle()
		if not gBinding then
			return	
		end
		if nExpire < 1 then
			bQuerying = false
			ResetLastQRCodeInfo()
			ResetGlobalParam()
			ShowCtrl(OwnerCtrl,"QRCodePanel.Panel.QRCode.Expire")
			
			local tStatInfo = {}
			tStatInfo.fu1 = "bindwx"
			tStatInfo.fu5 = "fail"
			tStatInfo.fu6 = "expire"
			StatisticClient:SendEventReport(tStatInfo)
			return
		end
		nExpire = nExpire - 1
		local strText = "二维码有效时间" .. nExpire .. "秒"
		textActiveTime:SetText(tostring(strText))
		textActiveTime:SetVisible(true)
		if not bQuerying and nTimerCounter > nQueryInterval then
			bQuerying = true
			TipLog("Cycle query sever for bind result in.")
			nTimerCounter = 0
			ClientWorkModule:CycleQuerySeverForBindResult(function(bRet,tabBindInfo)
				if not gBinding or not bQuerying then
					return
				end
				if not bRet then
					TipLog("Cycle query  sever for bind result return false")
					bQuerying = false
					ResetLastQRCodeInfo()
					ResetGlobalParam()
					ShowCtrl(OwnerCtrl,"QRCodePanel.Panel.QRCode.BindFailed")
					local tStatInfo = {}
					tStatInfo.fu1 = "bindwx"
					tStatInfo.fu5 = "fail"
					tStatInfo.fu6 = "svrerror"
					StatisticClient:SendEventReport(tStatInfo)
					return 
				end
				if type(tabBindInfo["data"]) == "table" and tabBindInfo["data"]["wxOpenID"] ~= nil then
					ResetGlobalParam()
					UpdateBindSuccessUI(OwnerCtrl)
					ClientWorkModule:SetUserBindInfo(tabBindInfo)
					ResetLastQRCodeInfo()
					--Statistic:SendUIReport("bindweixin","success")
					local tStatInfo = {}
					tStatInfo.fu1 = "bindwx"
					tStatInfo.fu5 = "success"
					StatisticClient:SendEventReport(tStatInfo)
                    
                    if RewardBindWX and RewardBindWX:HasShowedRewardEnter() then
                        RewardBindWX:GetBindWeiXinRewardInfo()
                    end    
				end	
				bQuerying = false
			end)
		end
		nTimerCounter = nTimerCounter + 1
	end
	TimerHandle()
	gQRTimeoutId = timerManager:SetTimer(function(Itm, id)
		TimerHandle(OwnerCtrl)
		end, 1000)
end

function HandleInfoData(OwnerCtrl,tabInfo)
	-- 20 for test
	-- nExpire = 20
	local ObjBitmap = objGraphicFac:CreateBitmap(tabInfo["data"]["qrcodePath"], "ARGB32")
	if not ObjBitmap then
		ResetGlobalParam()
		ShowCtrl(OwnerCtrl,"QRCodePanel.Panel.QRCode.GenFailed")
		--Statistic:SendUIReport("bindweixin","fail","getbitmap")
		local tStatInfo = {}
		tStatInfo.fu1 = "bindwx"
		tStatInfo.fu5 = "fail"
		tStatInfo.fu6 = "getbitmap"
		StatisticClient:SendEventReport(tStatInfo)
		return
	end
	
	gLastQRCodeBitmap = ObjBitmap
	gLastTabInfo = tabInfo
	local nExpire = math.floor(tabInfo["data"]["expire"]/1000)
	gLastExpireTime = nExpire + tFunctionHelper.GetCurrentServerTime()
	CycleQueryBindState(OwnerCtrl,tabInfo,ObjBitmap)
end

function GetQRCodeFromServer(OwnerCtrl)
	ResetGlobalParam()
	ClientWorkModule:DownLoadTempQrcode(function(bRet,info)
		if not bRet then
			TipLog("Download temp qrcode failed.")
			ShowCtrl(OwnerCtrl,"QRCodePanel.Panel.QRCode.GenFailed")
			--Statistic:SendUIReport("bindweixin","fail","downqrcode")
			local tStatInfo = {}
			tStatInfo.fu1 = "bindwx"
			tStatInfo.fu5 = "fail"
			tStatInfo.fu6 = "downqrcode"
			StatisticClient:SendEventReport(tStatInfo)
			return
		end
		HandleInfoData(OwnerCtrl, info)
	end)
end

function OnClickRefreshQRCode(self)
	local OwnerCtrl = self:GetOwnerControl()
	ResetUIVisible(OwnerCtrl)
	GetQRCodeFromServer(OwnerCtrl)
end

function OnClickBegainMining(self)
	UIInterface:ChangeMainBodyPanel("MiningPanel")
	if not ClientWorkModule:CheckIsWorking() then
		ClientWorkModule:NotifyStart()
	end
end

function OnClickUnBindWeiXin(self)
	local OwnerCtrl = self:GetOwnerControl()
	UIInterface:ChangeMainBodyPanel("MiningPanel")
end


function OnInitControl(self)
	ShowCtrl(self,nil)
end

function OnVisibleChange(self, bVisible)
	--[[
	gBinding = bVisible
	if bVisible then
		GetQRCodeFromServer(self)
	else
		ResetGlobalParam()
		ResetUIVisible(self)
	end
	--]]
end
--如果上一个二维码的有效期超过30秒 则继续用
function GetQRCode(self)
	if gLastQRCodeBitmap ~= nil 
		and type(gLastTabInfo) == "table" 
		and type(gLastTabInfo["data"]) == "table"
		and gLastExpireTime - tFunctionHelper.GetCurrentServerTime() >= 30 then
		gLastTabInfo["data"]["expire"] = (gLastExpireTime - tFunctionHelper.GetCurrentServerTime())*1000
		ResetGlobalParam()
		CycleQueryBindState(self,gLastTabInfo,gLastQRCodeBitmap)
		return
	end	
	ResetLastQRCodeInfo()
	GetQRCodeFromServer(self)
end

function OnShowPanel(self, bShow)
	gBinding = bShow
	if bShow then
		ResetUIVisible(self)
		GetQRCode(self)
	else
		ResetGlobalParam()
		ResetUIVisible(self)
	end
end









