local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
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
		tipUtil:Log("@@QRCodePanel: " .. tostring(strLog))
	end
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
	if tFunctionHelper.GetUserCurrentBalance() >= gMinTakeCashBalance then
		strPanle = "TakeCashPanel"
		strInfo = "秒后开始提现"
	end
	local nTotalTime = 3
	local strText = nTotalTime .. strInfo
	textActiveTime:SetText(strText)
	textActiveTime:SetVisible(true)
	gChangePanelTimeoutId = timerManager:SetTimer(function(Itm, id)
		if nTotalTime <= 0 and gBinding then
			ResetGlobalParam()
			tFunctionHelper.ChangeMainBodyPanel(strPanle)
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
	local ObjTextLinkUnBind= OwnerCtrl:GetControlObject("QRCodePanel.Panel.UnBind")
	ObjTextLinkUnBind:Show(true)
end

function CycleQueryBindState(OwnerCtrl,tabInfo,ObjBitmap)
	local nExpire = math.floor(tabInfo["data"]["expire"]/1000)
	local ImgTmpCode= OwnerCtrl:GetControlObject("QRCodePanel.Panel.QRCode.TmpCode")
	ImgTmpCode:SetBitmap(ObjBitmap)
	local tServerConfig = g_ServerConfig
	local tServerInterfaceCfg = tServerConfig["tServerInterfaceCfg"]
	if type(tServerInterfaceCfg) ~= "table" then
		tServerInterfaceCfg = {}
	end
	local nQueryInterval = tabInfo["data"]["interval"] or tServerInterfaceCfg["nQueryBindInterval"] or 10
	local textActiveTime= OwnerCtrl:GetControlObject("QRCodePanel.Panel.ActiveTime")
	local bQuerying = false
	local nTimerCounter = 0
	local function TimerHandle()
		if not gBinding then
			return	
		end
		if nExpire < 1 then
			bQuerying = false
			ResetGlobalParam()
			ShowCtrl(OwnerCtrl,"QRCodePanel.Panel.QRCode.Expire")
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
			tFunctionHelper.CycleQuerySeverForBindResult(function(bRet,tabBindInfo)
				if not gBinding or not bQuerying then
					return
				end
				if not bRet then
					TipLog("Cycle query  sever for bind result return false")
					bQuerying = false
					ResetGlobalParam()
					ShowCtrl(OwnerCtrl,"QRCodePanel.Panel.QRCode.BindFailed")
					return 
				end
				if type(tabBindInfo["data"]) == "table" and tabBindInfo["data"]["wxOpenID"] ~= nil then
					ResetGlobalParam()
					UpdateBindSuccessUI(OwnerCtrl)
					tFunctionHelper.SetUserBindInfo(tabBindInfo)
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
	tFunctionHelper.DownLoadTempQrcode(function(bRet,info)
		if not bRet then
			TipLog("Download temp qrcode failed.")
			ShowCtrl(OwnerCtrl,"QRCodePanel.Panel.QRCode.GenFailed")
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
	tFunctionHelper.ChangeMainBodyPanel("MiningPanel")
	if not tFunctionHelper.CheckIsWorking() then
		tFunctionHelper.NotifyStart()
	end
end

function OnClickUnBindWeiXin(self)
	local OwnerCtrl = self:GetOwnerControl()
	tFunctionHelper.ChangeMainBodyPanel("MiningPanel")
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
--如果上一个二维码的有效期超过20秒 则继续用
function GetGetQRCode(self)
	if gLastQRCodeBitmap ~= nil 
		and type(gLastTabInfo) == "table" 
		and type(gLastTabInfo["data"]) == "table"
		and gLastExpireTime - tFunctionHelper.GetCurrentServerTime() >= 20 then
		gLastTabInfo["data"]["expire"] = (gLastExpireTime - tFunctionHelper.GetCurrentServerTime())*1000
		ResetGlobalParam()
		CycleQueryBindState(self,gLastTabInfo,gLastQRCodeBitmap)
		return
	end	
	gLastQRCodeBitmap = nil
	gLastTabInfo = {}
	gLastExpireTime = 0
	GetQRCodeFromServer(self)
end

function OnShowPanel(self, bShow)
	gBinding = bShow
	if bShow then
		ResetUIVisible(self)
		GetGetQRCode(self)
	else
		ResetGlobalParam()
		ResetUIVisible(self)
	end
end











