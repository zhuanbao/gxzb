local tipUtil = XLGetObject("API.Util")
local FunctionObj = XLGetGlobal("Global.FunctionHelper")
local Helper =  XLGetGlobal("Helper")
-----事件----



-----方法-----
function InitPanelList(self, tPanelList)
	local objPanelCenter= self:GetControlObject("MainPanel.Center")
	if objPanelCenter == nil then
		
		TipLog("[InitPanelList] get objPanelCenter failed ")
		return false
	end
	
	if type(tPanelList) ~= "table" then
		TipLog("[InitPanelList] para invalid tPanelList")
		return false
	end

	local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")
	if nil == objFactory then
		TipLog("[InitPanelList] ObjectFactory failed")
		return false
	end
	
	for nIndex, strCtrlName in pairs(tPanelList) do 
		local strCtrlKey = GetCtrlKeyByCtrlName(strCtrlName)
		local objChild = objFactory:CreateUIObject(strCtrlKey, strCtrlName)
		if nil == objChild then
			TipLog("[InitPanelList] CreateUIObject failed, strCtrlName:"..tostring(strCtrlName))
			return false
		end
		
		objPanelCenter:AddChild(objChild)
		objChild:SetVisible(false)
		objChild:SetChildrenVisible(false)
	end
	if FunctionObj.CheckIsBinded() then
		local objButton= self:GetControlObject("MainPanel.Buttom.BindWeiXin")
		if objButton then
			objButton:SetText("解除绑定")
		end
	end
	return true	
end

function ChangePanel(self, strNewCtrlName)
	local objPanelCenter= self:GetControlObject("MainPanel.Center")
	if objPanelCenter == nil then
		
		TipLog("[InitPanelList] get objPanelCenter failed ")
		return false
	end
	if not IsRealString(strNewCtrlName) then
		TipLog("[ChangePanel] para invalid strNewCtrlName: "..tostring(strNewCtrlName))
		return false
	end

	local strCurCtrlName = GetCurrentCtrlName(self)
	local strCurCtrlKey = GetCtrlKeyByCtrlName(strCurCtrlName)
	local objCurPanel = objPanelCenter:GetObject(strCurCtrlKey)
	
	local strNewCtrlKey = GetCtrlKeyByCtrlName(strNewCtrlName)
	local objNewPanel = objPanelCenter:GetObject(strNewCtrlKey)
	if nil == objNewPanel then
		TipLog("[ChangePanel] Panel to Set is nil: "..tostring(strNewCtrlName))
		return false
	end
	
	if nil ~= objCurPanel and type(objCurPanel.OnShowPanel) == "function" then
		objCurPanel:OnShowPanel(false)
	end
	
	if nil ~= objCurPanel then
		objCurPanel:SetVisible(false)
		objCurPanel:SetChildrenVisible(false)
	end
	
	objNewPanel:SetVisible(true)
	objNewPanel:SetChildrenVisible(true)
	objNewPanel:SetObjPos(0, 0, "father.width", "father.height")
	
	if type(objNewPanel.OnShowPanel) == "function" then
		objNewPanel:OnShowPanel(true)
	end
		
	SetCurrentCtrlName(self, strNewCtrlName)
	return true
end

function GetCurrentCtrlObj(self)
	local strCurCtrlName = GetCurrentCtrlName(self)
	local objChild = GetChildObjByCtrlName(self, strCurCtrlName)
	return objChild
end


function GetChildObjByCtrlName(self, strCtrlName)
	local objPanelContainer = self:GetControlObject("MainPanel.Center")
	if objPanelContainer == nil then
		TipLog("[GetCurrentCtrlObj] get objPanelContainer failed ")
		return nil
	end
	
	local strCurCtrlKey = GetCtrlKeyByCtrlName(strCtrlName)
	local objCurPanel = objPanelContainer:GetObject(strCurCtrlKey)
	
	return objCurPanel
end

function UpdateWeiXinInfo(self, tUserConfig)
	local objPanelCenter= self:GetControlObject("MainPanel.Center")
	if objPanelCenter == nil then
		
		TipLog("[UpdateWeiXinInfo] get objPanelCenter failed ")
		return false
	end
	
	local nChildCnt = objPanelCenter:GetChildCount()
	for i=0,nChildCnt-1 do
		local objChild = objPanelCenter:GetChildByIndex(i)
		if objChild and type(objChild.UpdateWeiXinInfo) == "function" then
			objChild:UpdateWeiXinInfo(tUserConfig)
		end	
	end
	return true
end

function UpdateBindButtonText(self, strText)
	local objButton= self:GetControlObject("MainPanel.Buttom.BindWeiXin")
	objButton:SetText(strText)
end

function UpdateMachineName(self, tUserConfig)
	local objPanelCenter= self:GetControlObject("MainPanel.Center")
	if objPanelCenter == nil then
		
		TipLog("[UpdateMachineName] get objPanelCenter failed ")
		return false
	end
	local nChildCnt = objPanelCenter:GetChildCount()
	for i=0,nChildCnt-1 do
		local objChild = objPanelCenter:GetChildByIndex(i)
		if objChild and type(objChild.UpdateMachineName) == "function" then
			objChild:UpdateMachineName(tUserConfig)
		end	
	end
	
	return true
end

function UpdateSpeed(self, strSpeed)
	local objPanelCenter= self:GetControlObject("MainPanel.Center")
	if objPanelCenter == nil then
		
		TipLog("[UpdateSpeed] get objPanelCenter failed ")
		return false
	end
	local nChildCnt = objPanelCenter:GetChildCount()
	for i=0,nChildCnt-1 do
		local objChild = objPanelCenter:GetChildByIndex(i)
		if objChild and type(objChild.UpdateSpeed) == "function" then
			objChild:UpdateSpeed(strSpeed)
		end	
	end
	
	return true
end

function UpdateMinerInfo(self, strText)
	local objPanelCenter= self:GetControlObject("MainPanel.Center")
	if objPanelCenter == nil then
		
		TipLog("[UpdateMinerInfo] get objPanelCenter failed ")
		return false
	end
	local nChildCnt = objPanelCenter:GetChildCount()
	for i=0,nChildCnt-1 do
		local objChild = objPanelCenter:GetChildByIndex(i)
		if objChild and type(objChild.UpdateMinerInfo) == "function" then
			objChild:UpdateMinerInfo(strText)
		end	
	end
	
	return true
end

function OnClickBindWeiXin(self)
	if not FunctionObj.CheckIsBinded() then
		local objHostWnd = FunctionObj.GetMainHostWnd()
		local maskWnd = Helper:CreateTransparentMask(objHostWnd)
		Helper:CreateModalWnd("GXZB.BindWeiXin2WeiMaWnd", "GXZB.BindWeiXin2WeiMaWndTree", maskWnd:GetWndHandle(), {["parentWnd"] = maskWnd})
		Helper:DestoryTransparentMask(objHostWnd)
	else
		FunctionObj.ClearBindInfo()
		FunctionObj.NotifyPause()
		self:SetText("绑定微信")
	end	
end

function OnClickHistoryIncome(self)
	
end

function OnClickTakeCash(self)
	--弹出绑定微信
	local objHostWnd = FunctionObj.GetMainHostWnd()
	local maskWnd = Helper:CreateTransparentMask(objHostWnd)
	Helper:CreateModalWnd("GXZB.TiXianWnd", "GXZB.TiXianWndTree", maskWnd:GetWndHandle(), {["parentWnd"] = maskWnd})
	Helper:DestoryTransparentMask(objHostWnd)
end


-----辅助函数----
function GetCurrentCtrlName(objRootCtrl)
	local attr = objRootCtrl:GetAttribute()
	TipLog("[GetCurrentCtrlName] attr.CurCtrlName:"..tostring(attr.CurCtrlName))
	return attr.CurCtrlName
end

function SetCurrentCtrlName(objRootCtrl, strCtrlName)
	local attr = objRootCtrl:GetAttribute()
	if IsRealString(strCtrlName) then
		attr.CurCtrlName = strCtrlName
	end

	TipLog("[SetCurrentCtrlName] attr.CurCtrlName :"..tostring(attr.CurCtrlName))
end

function GetCtrlKeyByCtrlName(strName)
	local CTRLKEYPREFIX = "MainBody_"
	local strCtrlKey = CTRLKEYPREFIX..tostring(strName)
	return strCtrlKey
end

function IsRealString(AString)
    return type(AString) == "string" and AString ~= ""
end

function TipLog(strLog)
	if type(tipUtil.Log) == "function" then
		tipUtil:Log("@@MainBodyCtrl: " .. tostring(strLog))
	end
end