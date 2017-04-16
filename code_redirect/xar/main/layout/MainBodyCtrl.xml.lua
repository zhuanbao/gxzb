local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
local Helper =  XLGetGlobal("Helper")
-----事件----



-----方法-----
function InitPanelList(self, tPanelList)
	local objPanelCenter= self:GetControlObject("MainBody.Panel.Center")
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
	return true	
end

local btnids = {"MainPanel.Buttom.Earnings.Btn", "MainPanel.Buttom.Mining.Btn", "MainPanel.Buttom.TakeCash.Btn"}
function ChangeBtnState(self)
	local id = self:GetID()
	for _, vid in ipairs(btnids) do
		if vid == id then
			local attr = self:GetAttribute()
			if not attr.bakimage then
				attr.bakimage = {attr.NormalBkgID, attr.HoverBkgID, attr.DownBkgID, attr.DisableBkgID}
				attr.NormalBkgID = attr.DownBkgID
				attr.DownBkgID = attr.DownBkgID
				attr.HoverBkgID = attr.DownBkgID
				attr.DisableBkgID = attr.DownBkgID
				self:Updata()
			end
		else
			local otherobj = self:GetObject("control:"..vid)
			local otherattr = otherobj:GetAttribute()
			if otherattr.bakimage then
				otherattr.NormalBkgID = otherattr.bakimage[1]
				otherattr.HoverBkgID = otherattr.bakimage[2]
				otherattr.DownBkgID = otherattr.bakimage[3]
				otherattr.DisableBkgID = otherattr.bakimage[4]
				otherattr.bakimage = nil
				otherobj:Updata()
			end
		end
	end
end

local PanelBtnMap = {
	["EarningsPanel"] = "MainPanel.Buttom.Earnings.Btn",
	["MiningPanel"] = "MainPanel.Buttom.Mining.Btn",
	["QRCodePanel"] = "MainPanel.Buttom.TakeCash.Btn",
	["TakeCashPanel"] = "MainPanel.Buttom.TakeCash.Btn",
}
function ChangePanel(self, strNewCtrlName)
	local function changebtnstate()
		local btn = self:GetControlObject(PanelBtnMap[strNewCtrlName])
		if btn then
			ChangeBtnState(btn)
		end
	end
	changebtnstate()
	local objPanelCenter= self:GetControlObject("MainBody.Panel.Center")
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

	objNewPanel:SetObjPos(0, 0, "father.width", "father.height")
	objNewPanel:SetVisible(true)
	objNewPanel:SetChildrenVisible(true)
	
	
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
	local objPanelContainer = self:GetControlObject("MainBody.Panel.Center")
	if objPanelContainer == nil then
		TipLog("[GetCurrentCtrlObj] get objPanelContainer failed ")
		return nil
	end
	
	local strCurCtrlKey = GetCtrlKeyByCtrlName(strCtrlName)
	local objCurPanel = objPanelContainer:GetObject(strCurCtrlKey)
	
	return objCurPanel
end

function UpdateClientBindState(self)
	local objPanelCenter= self:GetControlObject("MainBody.Panel.Center")
	if objPanelCenter == nil then
		TipLog("[UpdateClientBindState] get objPanelCenter failed ")
		return false
	end
	
	local nChildCnt = objPanelCenter:GetChildCount()
	for i=0,nChildCnt-1 do
		local objChild = objPanelCenter:GetChildByIndex(i)
		if objChild and type(objChild.UpdateClientBindState) == "function" then
			objChild:UpdateClientBindState()
		end	
	end
	return true
end

function UpdateClientUnBindState(self)
	local objPanelCenter= self:GetControlObject("MainBody.Panel.Center")
	if objPanelCenter == nil then
		TipLog("[UpdateClientUnBindState] get objPanelCenter failed ")
		return false
	end
	
	local nChildCnt = objPanelCenter:GetChildCount()
	for i=0,nChildCnt-1 do
		local objChild = objPanelCenter:GetChildByIndex(i)
		if objChild and type(objChild.UpdateClientUnBindState) == "function" then
			objChild:UpdateClientUnBindState()
		end	
	end
	return true
end

function UpdateClientUnBindFailState(self)
	local objPanelCenter= self:GetControlObject("MainBody.Panel.Center")
	if objPanelCenter == nil then
		TipLog("[UpdateClientUnBindFailState] get objPanelCenter failed ")
		return false
	end
	
	local nChildCnt = objPanelCenter:GetChildCount()
	for i=0,nChildCnt-1 do
		local objChild = objPanelCenter:GetChildByIndex(i)
		if objChild and type(objChild.UpdateClientUnBindFailState) == "function" then
			objChild:UpdateClientUnBindFailState()
		end	
	end
	return true
end

function UpdateUserBalance(self, nBalance)
	local objPanelCenter= self:GetControlObject("MainBody.Panel.Center")
	if objPanelCenter == nil then
		TipLog("[UpdateUserBalance] get objPanelCenter failed ")
		return false
	end
	
	local nChildCnt = objPanelCenter:GetChildCount()
	for i=0,nChildCnt-1 do
		local objChild = objPanelCenter:GetChildByIndex(i)
		if objChild and type(objChild.UpdateUserBalance) == "function" then
			objChild:UpdateUserBalance(nBalance)
		end	
	end
	return true
end

function UpdateMiningSpeed(self, nSpeed)
	local objPanelCenter= self:GetControlObject("MainBody.Panel.Center")
	if objPanelCenter == nil then
		TipLog("[UpdateMiningSpeed] get objPanelCenter failed ")
		return false
	end
	
	local nChildCnt = objPanelCenter:GetChildCount()
	for i=0,nChildCnt-1 do
		local objChild = objPanelCenter:GetChildByIndex(i)
		if objChild and type(objChild.UpdateMiningSpeed) == "function" then
			objChild:UpdateMiningSpeed(nSpeed)
		end	
	end
	return true
end


function UpdateMiningState(self, nMiningState)
	local objPanelCenter= self:GetControlObject("MainBody.Panel.Center")
	if objPanelCenter == nil then
		TipLog("[UpdateMiningState] get objPanelCenter failed ")
		return false
	end
	
	local nChildCnt = objPanelCenter:GetChildCount()
	for i=0,nChildCnt-1 do
		local objChild = objPanelCenter:GetChildByIndex(i)
		if objChild and type(objChild.UpdateMiningState) == "function" then
			objChild:UpdateMiningState(nMiningState)
		end	
	end
	return true
end

function UpdateDagProgress(self, nProgress)
	local objPanelCenter= self:GetControlObject("MainBody.Panel.Center")
	if objPanelCenter == nil then
		TipLog("[UpdateDagProgress] get objPanelCenter failed ")
		return false
	end
	
	local nChildCnt = objPanelCenter:GetChildCount()
	for i=0,nChildCnt-1 do
		local objChild = objPanelCenter:GetChildByIndex(i)
		if objChild and type(objChild.UpdateDagProgress) == "function" then
			objChild:UpdateDagProgress(nProgress)
		end	
	end
	return true
end

function OnWorkStateChange(self, nState)
	local objPanelCenter= self:GetControlObject("MainBody.Panel.Center")
	if objPanelCenter == nil then
		TipLog("[OnWorkStateChange] get objPanelCenter failed ")
		return false
	end
	
	local nChildCnt = objPanelCenter:GetChildCount()
	for i=0,nChildCnt-1 do
		local objChild = objPanelCenter:GetChildByIndex(i)
		if objChild and type(objChild.OnWorkStateChange) == "function" then
			objChild:OnWorkStateChange(nState)
		end	
	end
	return true
end

function OnClickMiningPanel(self)
	local OwnerCtrl = self:GetOwnerControl()
	ChangePanel(OwnerCtrl,"MiningPanel")
end

function OnClickTakeCashPanel(self)
	local OwnerCtrl = self:GetOwnerControl()
	local strPanel = "TakeCashPanel"
	if not tFunctionHelper.CheckIsBinded() then
		strPanel = "QRCodePanel"
	end
	ChangePanel(OwnerCtrl,strPanel)
end

function OnClickEarningsPanel(self)
	local objmain = self:GetOwnerControl()
	if objmain then
		objmain:ChangePanel("EarningsPanel")
	end
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