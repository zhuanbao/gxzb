local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local IPCUtil = XLGetObject("IPC.Util")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local hostwndManager = XLGetObject("Xunlei.UIEngine.HostWndManager")
local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")
local tFunctionHelper = XLGetGlobal("FunctionHelper")

ObjectBase = XLGetGlobal("ObjectBase")
OpenBox = ObjectBase:New()
XLSetGlobal("OpenBox", OpenBox)

OpenBox._strOpenBoxInterfacePrefix = "http://api.eastredm.com"
--OpenBox._strOpenBoxInterfacePrefix = "http://api-test.eastredm.com"

OpenBox._tOpenBoxCfg = nil
OpenBox._bInit = false
OpenBox._CalcTimerId = nil
OpenBox._PrepareNextDayTimerId = nil
OpenBox._StartActivityTimerId = nil
OpenBox._PopupTipTimerId = nil
OpenBox._bHasOpenedWeb = false

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
	tipUtil:Log("OpenBox: " .. tostring(strLog))
end

function OpenBox:Init()
	if not self._bInit then
		self:AddListener("OnGetWhiteListInfo", self.OnGetWhiteListInfo, self)
		self._bInit = true
	end
end

function OpenBox:OpenWeb()
	self._bHasOpenedWeb = true
	local tUserConfig = WorkModuleHelper:GetUserConfig()
	local strWorkID = tFunctionHelper.FetchValueByPath(tUserConfig, {"tUserInfo", "strWorkID"})
	local strWebUrl = "http://www.eastredm.com/activity/treasure-box?workerID=" .. tostring(strWorkID)
	Helper.tipUtil:OpenURL(strWebUrl)
	
	if type(tUserConfig["tActive"]) ~= "table" then
		tUserConfig["tActive"] = {}
	end
	if type(tUserConfig["tActive"]["tOpenBox"]) ~= "table" then
		tUserConfig["tActive"]["tOpenBox"] = {}
	end
	tUserConfig["tActive"]["tOpenBox"]["nLastOpenWebTime"] = tFunctionHelper.GetCurrentServerTime()
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
end

function OpenBox:QuerySvrForUserInWhiteList()
	local tUserConfig = WorkModuleHelper:GetUserConfig()
	local strWorkID = tFunctionHelper.FetchValueByPath(tUserConfig, {"tUserInfo", "strWorkID"})
	if not IsRealString(strWorkID) then
		return
	end
	local strInterfaceName = "p/v1/treasure-box/in-white-list"
    local strInterfaceParam = "workerID=" .. Helper:UrlEncode(strWorkID)
    if IsRealString(tUserConfig["tUserInfo"]["strOpenID"]) then
		strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strOpenID"])))
	end
	strInterfaceParam = strInterfaceParam .. "&peerid=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetPeerID()))
	local strParam = ApiInterfaceModule:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  self._strOpenBoxInterfacePrefix .. strParam
	TipLog("[QuerySvrForUserInWhiteList] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function OpenBox:GetUserWhiteListInfo()
	self:RemoveSuspendWndLayer()
	self:RemoveOpenBoxWnd()
	self:RemoveMainWndAni()
	local strUrl = self:QuerySvrForUserInWhiteList()
	if not IsRealString(strUrl) then
		self:PrepareNextDay()
		TipLog("[GetUserWhiteListInfo] Make reguest url fail")
		return 
	end
	local tUserConfig = WorkModuleHelper:GetUserConfig()
	if type(tUserConfig["tActive"]) ~= "table" then
		tUserConfig["tActive"] = {}
	end
	if type(tUserConfig["tActive"]["tOpenBox"]) ~= "table" then
		tUserConfig["tActive"]["tOpenBox"] = {}
	end
	
	local nLeftSecond = self:GetDayLeftSecond()
	local nLastWorkingDayTime =  tFunctionHelper.FetchValueByPath(tUserConfig, {"tActive", "tOpenBox", "nLastWorkingDayTime"}) or 0
	local nCurrentTime = tFunctionHelper.GetCurrentServerTime()
	if tFunctionHelper.CheckIsAnotherDay(nLastWorkingDayTime, nCurrentTime) then
		tUserConfig["tActive"]["tOpenBox"]["nLastWorkingDayTime"] = nCurrentTime
		tUserConfig["tActive"]["tOpenBox"]["nLastWorkingSecond"] = 0
		tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
	end
	local nLastWorkingSecond = tonumber(tUserConfig["tActive"]["tOpenBox"]["nLastWorkingSecond"]) or 0
	local nLeastWorKingTime = self._tOpenBoxCfg["nLeastWorKingTime"] or 30*60
	if nLeastWorKingTime - nLastWorkingSecond > nLeftSecond then
		self:PrepareNextDay()
		TipLog("[GetUserWhiteListInfo] left time is not enough")
		return 
	end
	
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[GetUserWhiteListInfo] strUrl = " .. strUrl)
	
	local function fnCallBack(bRet, tabInfo)
		self:DispatchEvent("OnGetWhiteListInfo", bRet, tabInfo)
	end
	ApiInterfaceModule:GetServerJsonData(strUrl, fnCallBack)
end

function OpenBox:RemoveMainWndAni()
	if self.imageOpenAni then
		self.imageOpenAni:Stop()
		self.imageOpenAni = nil
	end
	local wndMain = UIInterface:GetMainHostWnd()
	local Objtree = wndMain:GetBindUIObjectTree()
	local ObjRootCtrl = Objtree:GetUIObject("root.layout:root.ctrl")
	local ObjMainBodyCtrl = ObjRootCtrl:GetControlObject("WndPanel.MainBody")
	local ObjMiningPanel = ObjMainBodyCtrl:GetChildObjByCtrlName("MiningPanel")
	local ObjAnimImg = ObjMiningPanel:GetObject("Activity.OpenBox.MainWndAni")
	if ObjAnimImg then
		ObjMiningPanel:RemoveChild(ObjAnimImg)
	end
	
	local ObjCloseBtn = ObjMiningPanel:GetObject("Activity.OpenBox.MainWndAni.CloseBtn")
	if ObjCloseBtn then
		ObjMiningPanel:RemoveChild(ObjCloseBtn)
	end
end

function OpenBox:RemoveStaticEntry()
	local wndMain = UIInterface:GetMainHostWnd()
	local Objtree = wndMain:GetBindUIObjectTree()
	local ObjRootCtrl = Objtree:GetUIObject("root.layout:root.ctrl")
	local ObjMainBodyCtrl = ObjRootCtrl:GetControlObject("WndPanel.MainBody")
	local ObjMiningPanel = ObjMainBodyCtrl:GetChildObjByCtrlName("MiningPanel")
	local ObjStaticEntry = ObjMiningPanel:GetObject("Activity.OpenBox.StaticEntry")
	if ObjStaticEntry then
		ObjMiningPanel:RemoveChild(ObjStaticEntry)
	end
	
	local ObjCloseBtn = ObjMiningPanel:GetObject("GXZB.OpenBox.CloseEntry.Btn")
	if ObjCloseBtn then
		ObjMiningPanel:RemoveChild(ObjCloseBtn)
	end
end

function OpenBox:AddMainWndAni()
	local wndMain = UIInterface:GetMainHostWnd()
	local Objtree = wndMain:GetBindUIObjectTree()
	local ObjRootCtrl = Objtree:GetUIObject("root.layout:root.ctrl")
	local ObjMainBodyCtrl = ObjRootCtrl:GetControlObject("WndPanel.MainBody")
	local ObjMiningPanel = ObjMainBodyCtrl:GetChildObjByCtrlName("MiningPanel")
	
	local ObjAnimImg = ObjMiningPanel:GetObject("Activity.OpenBox.MainWndAni")
	if ObjAnimImg == nil then
		ObjAnimImg = objFactory:CreateUIObject("Activity.OpenBox.MainWndAni", "ImageObject")
		ObjAnimImg:SetCursorID("IDC_HAND")
		ObjMiningPanel:AddChild(ObjAnimImg)
		local nFLeft, nFTop, nFRight, nFButtom = ObjMiningPanel:GetObjPos()
		ObjAnimImg:SetObjPos2("father.width-25-69", 66-29, 69, 66)
		
		ObjAnimImg:AttachListener("OnLButtonUp", false, function()
									self:OpenWeb()
									local tStatInfo = {}
									tStatInfo.fu1 = "openbox"
									tStatInfo.fu5 = "openweb"
									tStatInfo.fu6 = "mainwnd"
									StatisticClient:SendClickReport(tStatInfo)
								end)							
		
		local ObjCloseBtn = objFactory:CreateUIObject("Activity.OpenBox.MainWndAni.CloseBtn", "TipAddin.Button")
		local attrBtn = ObjCloseBtn:GetAttribute()
		attrBtn.NormalBkgID = "GXZB.OpenBox.CloseAni.Btn.normal"
		attrBtn.DownBkgID = "GXZB.OpenBox.CloseAni.Btn.down"
		attrBtn.HoverBkgID = "GXZB.OpenBox.CloseAni.Btn.down"
		attrBtn.DisableBkgID = "GXZB.OpenBox.CloseAni.Btn.down"
		ObjCloseBtn:Updata()
		ObjMiningPanel:AddChild(ObjCloseBtn)
		ObjCloseBtn:SetObjPos2("father.width-15-16", 66-29, 16, 16)	
		ObjCloseBtn:AttachListener("OnClick", false, function()
									local tStatInfo = {}
									tStatInfo.fu1 = "openbox"
									tStatInfo.fu5 = "closemainwndbox"
									StatisticClient:SendClickReport(tStatInfo)
									OpenBox:RemoveMainWndAni()
								end)		
	end
	if not self.imageOpenAni then
		self.imageOpenAni = Helper.Ani:RunSeqFrameAni(ObjAnimImg, "GXZB.OpenBox.MainWndAni", nil, 800, true)
	end	

end

function OpenBox:GetDayLeftSecond()
	local nCurrentTime = tFunctionHelper.GetCurrentServerTime()
	local nYear, nMonth, nDay, nHour, nMinute, nSecond = tipUtil:FormatCrtTime(nCurrentTime)
	local nNextDayUTC = tipUtil:DateTime2Seconds(nYear, nMonth, nDay, 0, 0, 0)+86400
	local nLeftSecond = nNextDayUTC - nCurrentTime
	return nLeftSecond
end

function OpenBox:RemoveSuspendWndLayer()
	local wndSuspend = hostwndManager:GetHostWnd("GXZB.SuspendWnd.Instance")
	local objTree = wndSuspend:GetBindUIObjectTree()
	local objRoot = objTree:GetUIObject("root")
	local objSpeedoMeter = objRoot:GetControlObject("SpeedoMeter")
	local objLayer = objSpeedoMeter:GetControlObject("Activity.OpenBox.SuspendLayer")
	if objLayer then
		objSpeedoMeter:RemoveChild(objLayer)
	end
end

function OpenBox:RemoveOpenBoxWnd()
	self:RemoveSuspendRootListener()
	self:RemoveSuspendWndListener()
	self:KillDestoryOpenBoxWndTimerId()
	Helper:DestoryModelessWnd("GXZB.OpenBoxWnd")
end

function OpenBox:RemoveSuspendRootListener()
	local wndSuspend = hostwndManager:GetHostWnd("GXZB.SuspendWnd.Instance")
	local objTree = wndSuspend:GetBindUIObjectTree()
	local objRoot = objTree:GetUIObject("root")
	if self._nCookieRootMouseEnter then
		objRoot:RemoveListener("OnMouseMove", self._nCookieRootMouseEnter)
		self._nCookieRootMouseEnter = nil
	end	
	if self._nCookieRootMouseLeave then
		objRoot:RemoveListener("OnMouseLeave", self._nCookieRootMouseLeave)
		self._nCookieRootMouseLeave = nil
	end	
end

function OpenBox:RemoveSuspendWndListener()
	local wndSuspend = hostwndManager:GetHostWnd("GXZB.SuspendWnd.Instance")
	if self._nCookieWndShow then
		wndSuspend:RemoveListener("OnShowWindow", self._nCookieWndShow)
		self._nCookieWndShow = nil
	end	
	if self._nCookieWndMove then
		wndSuspend:RemoveListener("OnMove", self._nCookieWndMove)
		self._nCookieWndMove = nil 
	end	
end


function OpenBox:SetWndPosUnderSuspendWnd(wndOpenBox)
	local wndSuspend = hostwndManager:GetHostWnd("GXZB.SuspendWnd.Instance")
	local l, t, r, b = wndSuspend:GetWindowRect()
	wndOpenBox:Move( r-180-8, b-8, 180, 60)
end

function OpenBox:FollowSuspendWnd(wndOpenBox)
	self:SetWndPosUnderSuspendWnd(wndOpenBox)
	local wndSuspend = hostwndManager:GetHostWnd("GXZB.SuspendWnd.Instance")
	self._nCookieWndShow = wndSuspend:AttachListener("OnShowWindow", false, function(wnd, bShow)
		if not bShow then
			--Helper:DestoryModelessWnd("GXZB.OpenBoxWnd")
		end
	end)
	self._nCookieWndMove = wndSuspend:AttachListener("OnMove", false, function(wnd, bShow)
		self:SetWndPosUnderSuspendWnd(wndOpenBox)
	end)
end

function OpenBox:KillDestoryOpenBoxWndTimerId()
	if self._DestoryOpenBoxWndTimerId then
		timeMgr:KillTimer(self._DestoryOpenBoxWndTimerId)
		self._DestoryOpenBoxWndTimerId = nil
	end
end

function OpenBox:SetDestoryOpenBoxWndTimerId()
	self:KillDestoryOpenBoxWndTimerId()
	self._DestoryOpenBoxWndTimerId = SetOnceTimer(function()
		self._DestoryOpenBoxWndTimerId = nil
		Helper:DestoryModelessWnd("GXZB.OpenBoxWnd")
	end, 1*1000)
end

function OpenBox:AttachSuspendWnd()
	local wndSuspend = hostwndManager:GetHostWnd("GXZB.SuspendWnd.Instance")
	local objTree = wndSuspend:GetBindUIObjectTree()
	local objRoot = objTree:GetUIObject("root")
	local objSpeedoMeter = objRoot:GetControlObject("SpeedoMeter")
	local objLayer = objSpeedoMeter:GetControlObject("Activity.OpenBox.SuspendLayer")
	
	local wndTemplateID = "GXZB.OpenBoxWnd"
	self._nCookieRootMouseEnter = objRoot:AttachListener("OnMouseMove", false, function(obj)
		self:KillDestoryOpenBoxWndTimerId()
		objLayer:SetVisible(false)
		objLayer:SetChildrenVisible(false)
		local strWndInstName = wndTemplateID .. ".Instance"
		local wndOpenBox = hostwndManager:GetHostWnd(strWndInstName)
		if wndOpenBox then
			wndOpenBox:Show(5)
			return
		end
		local treeTemplateID = wndTemplateID .. "Tree"
		wndOpenBox = Helper:CreateModelessWnd(wndTemplateID, treeTemplateID)
		wndOpenBox:Show(5)
		self:FollowSuspendWnd(wndOpenBox)
	end)		
	self._nCookieRootMouseLeave = objRoot:AttachListener("OnMouseLeave", false, function(obj)
		self:SetDestoryOpenBoxWndTimerId()
		objLayer:SetVisible(true)
		objLayer:SetChildrenVisible(true)
	end)
end

function OpenBox:UpdateSuspendWndOpenBoxState(nState, param)
	local nLeastWorKingTime = self._tOpenBoxCfg["nLeastWorKingTime"] or 30*60
	
	local wndSuspend = hostwndManager:GetHostWnd("GXZB.SuspendWnd.Instance")
	local objTree = wndSuspend:GetBindUIObjectTree()
	local objRoot = objTree:GetUIObject("root")
	local objSpeedoMeter = objRoot:GetControlObject("SpeedoMeter")
	local objLayer = objSpeedoMeter:GetControlObject("Activity.OpenBox.SuspendLayer")
	if objLayer == nil then
		objLayer = objFactory:CreateUIObject("Activity.OpenBox.SuspendLayer", "OpenBox.SuspendLayer")
		objSpeedoMeter:AddChild(objLayer)
		objLayer:SetObjPos2(0, 5, 82, "father.height-5")	
		objLayer:SetZorder(100)
		
		local objStart = objSpeedoMeter:GetControlObject("SpeedoMeterGray.Start")
		objStart:SetZorder(201)
		local objStop = objSpeedoMeter:GetControlObject("SpeedoMeterLight.Stopicon")
		objStop:SetZorder(201)
	end	
	local objLayerText = objLayer:GetControlObject("SuspendLayer.Text")
	if nState == 0 then
		objLayerText:SetText("激活宝箱")
	elseif nState == 1 then
		local nLeftSecond = nLeastWorKingTime - param
		if nLeftSecond < 0 then
			nLeftSecond = 0
		end
		local strSecond = os.date("%M:%S", nLeftSecond)
		objLayerText:SetText(strSecond)
	elseif nState == 2 then
		if self._CalcTimerId then
			timeMgr:KillTimer(self._CalcTimerId)
			self._CalcTimerId = nil
		end
		objLayerText:SetText("我的宝箱")
		self:RemoveOpenBoxWnd()
		self:AttachSuspendWnd()
	end
	
end

function OpenBox:PrepareNextDay()
	local nLeastWorKingTime = self._tOpenBoxCfg["nLeastWorKingTime"] or 30*60
	
	local nLeftSecond = self:GetDayLeftSecond()
	TipLog("[PrepareNextDay] nLeftSecond = " .. tostring(nLeftSecond))
	if nLeftSecond > 86400 or nLeftSecond < 0 then
		nLeftSecond = 86400
	end
	--[[
	local nCurrentTime = tFunctionHelper.GetCurrentServerTime()
	local nEndTime = tonumber(self._tOpenBoxCfg["nEndTime"]) or 9999999999
	if  nEndTime < nCurrentTime+nLeftSecond+30*60 then
		TipLog("[PrepareNextDay] prepare next day fail")
		return
	end
	--]]
	--[[
	local nLastWorkingDayTime =  tFunctionHelper.FetchValueByPath(tUserConfig, {"tActive", "tOpenBox", "nLastWorkingDayTime"}) or 0
	local nLYear, nLMonth, nLDay, nLHour, nLMinute, nLSecond = tipUtil:FormatCrtTime(nLastWorkingDayTime)
	local nNextDayUTC = tipUtil:DateTime2Seconds(nLYear, nLMonth, nLDay, 0, 0, 0)+86400
	
	local nCurrentTime = tFunctionHelper.GetCurrentServerTime()
	local nTimerSecond = nNextDayUTC - nCurrentTime
	--]]
	
	
	self._PrepareNextDayTimerId = SetOnceTimer(function()
		self:ClearTimerId()
		local nEndTime = tonumber(self._tOpenBoxCfg["nEndTime"]) or 9999999999
		local nCurrentTime = tFunctionHelper.GetCurrentServerTime()
		if  nEndTime > nCurrentTime + nLeastWorKingTime then
			self:GetUserWhiteListInfo()
		else
			self:RemoveSuspendWndLayer()
			self:RemoveOpenBoxWnd()
			self:RemoveMainWndAni()
			TipLog("[PrepareNextDay] open box active finish")
		end
	end, nLeftSecond*1000)
end

function OpenBox:CalcWorkingTime()
	local nLeastWorKingTime = self._tOpenBoxCfg["nLeastWorKingTime"] or 30*60
	local tUserConfig = WorkModuleHelper:GetUserConfig()
	if type(tUserConfig["tActive"]) ~= "table" then
		tUserConfig["tActive"] = {}
	end
	if type(tUserConfig["tActive"]["tOpenBox"]) ~= "table" then
		tUserConfig["tActive"]["tOpenBox"] = {}
	end
	if self._CalcTimerId then
		timeMgr:KillTimer(self._CalcTimerId)
		self._CalcTimerId = nil
	end
	self._CalcTimerId = timeMgr:SetTimer(function(Itm, id)
		local nLastWorkingDayTime =  tFunctionHelper.FetchValueByPath(tUserConfig, {"tActive", "tOpenBox", "nLastWorkingDayTime"}) or 0
		local nCurrentTime = tFunctionHelper.GetCurrentServerTime()
		if tFunctionHelper.CheckIsAnotherDay(nLastWorkingDayTime, nCurrentTime) then
			tUserConfig["tActive"]["tOpenBox"]["nLastWorkingDayTime"] = nCurrentTime
			tUserConfig["tActive"]["tOpenBox"]["nLastWorkingSecond"] = 0
			tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
		end
		local nLastWorkingSecond = tonumber(tUserConfig["tActive"]["tOpenBox"]["nLastWorkingSecond"]) or 0
		if nLastWorkingSecond >= nLeastWorKingTime then
			--打开宝箱
			OpenBox:UpdateSuspendWndOpenBoxState(2)
		else
			if MainWorkModule:CheckIsWorking() then
				--宝箱倒计时
				tUserConfig["tActive"]["tOpenBox"]["nLastWorkingDayTime"] = nCurrentTime
				tUserConfig["tActive"]["tOpenBox"]["nLastWorkingSecond"] = nLastWorkingSecond + 1
				tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
				OpenBox:UpdateSuspendWndOpenBoxState(1,tUserConfig["tActive"]["tOpenBox"]["nLastWorkingSecond"])
			else
				--激活宝箱
				OpenBox:UpdateSuspendWndOpenBoxState(0)
			end
		end
        
	end, 1*1000)
	self:PrepareNextDay()
end

function OpenBox:AddStaticEntry()
	local wndMain = UIInterface:GetMainHostWnd()
	local objTree = wndMain:GetBindUIObjectTree()
	local objRootCtrl = objTree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	local objMiningPanel = objMainBodyCtrl:GetChildObjByCtrlName("MiningPanel")
	local objStaticEntry = objMiningPanel:GetObject("Activity.OpenBox.StaticEntry")
	if objStaticEntry == nil then
		objStaticEntry = objFactory:CreateUIObject("Activity.OpenBox.StaticEntry", "ImageObject")
		objStaticEntry:SetCursorID("IDC_HAND")
		objStaticEntry:SetResID("GXZB.OpenBox.StaticEntry")
		objMiningPanel:AddChild(objStaticEntry)
		local nFLeft, nFTop, nFRight, nFButtom = objMiningPanel:GetObjPos()
		objStaticEntry:SetObjPos2("father.width-27-83", 65-29, 83, 78)						
		objStaticEntry:AttachListener("OnLButtonUp", false, function()
									self:OpenWeb()
									local tStatInfo = {}
									tStatInfo.fu1 = "openbox"
									tStatInfo.fu5 = "openweb"
									tStatInfo.fu6 = "mainwnd"
									StatisticClient:SendClickReport(tStatInfo)
								end)
								
		local objCloseBtn = objFactory:CreateUIObject("GXZB.OpenBox.CloseEntry.Btn", "TipAddin.Button")
		local attrBtn = objCloseBtn:GetAttribute()
		attrBtn.NormalBkgID = "GXZB.OpenBox.CloseEntry.Btn.normal"
		attrBtn.DownBkgID = "GXZB.OpenBox.CloseEntry.Btn.down"
		attrBtn.HoverBkgID = "GXZB.OpenBox.CloseEntry.Btn.down"
		attrBtn.DisableBkgID = "GXZB.OpenBox.CloseEntry.Btn.down"
		objCloseBtn:Updata()
		objMiningPanel:AddChild(objCloseBtn)
		objCloseBtn:SetObjPos2("father.width-27-14", 65-29, 14, 14)	
		objCloseBtn:AttachListener("OnClick", false, function()
									local tStatInfo = {}
									tStatInfo.fu1 = "openbox"
									tStatInfo.fu5 = "closemainwndbox"
									StatisticClient:SendClickReport(tStatInfo)
									OpenBox:RemoveStaticEntry()
									if not self._bHasOpenedWeb then
										self:SaveCloseEnterTime()
									end	
								end)		
	end
end

function OpenBox:OnGetWhiteListInfo(event, bSuccess, tabInfo)
	local nValue = tipUtil:QueryRegValue("HKEY_CURRENT_USER", "SOFTWARE\\Share4Money", "nOpenBoxInWhiteList")
	if nValue ~= 1 then
		---[[
		if not bSuccess or type(tabInfo["data"]) ~= "table" then
			self:PrepareNextDay()
			return
		end
		if tabInfo["data"]["in_white_list"] ~= 1 then
			self:PrepareNextDay()
			return
		end
		--]]
	else
		TipLog("[OnGetWhiteListInfo] debug workid")
	end
	
	local tStatInfo = {}
	tStatInfo.fu1 = "openbox"
	tStatInfo.fu5 = "showactivity"
	StatisticClient:SendEventReport(tStatInfo)
	--减少骚扰换静态入口
	--[[
	if self:CheckPopupWndCond() then
		self:DoPopupTip()
	end	
	self:AddMainWndAni()
	self:CalcWorkingTime()
	--]]
	if self:CheckStaticEntryCond() then
		self:AddStaticEntry()
	end
end

function OpenBox:SaveCloseEnterTime()
	local tUserConfig = WorkModuleHelper:GetUserConfig()
	if type(tUserConfig["tActive"]) ~= "table" then
		tUserConfig["tActive"] = {}
	end
	if type(tUserConfig["tActive"]["tOpenBox"]) ~= "table" then
		tUserConfig["tActive"]["tOpenBox"] = {}
	end
	if type(tUserConfig["tActive"]["tOpenBox"]["tCloseEnterTime"]) ~= "table" then
		tUserConfig["tActive"]["tOpenBox"]["tCloseEnterTime"] = {}
	end
	tUserConfig["tActive"]["tOpenBox"]["tCloseEnterTime"][3] = tUserConfig["tActive"]["tOpenBox"]["tCloseEnterTime"][2]
	tUserConfig["tActive"]["tOpenBox"]["tCloseEnterTime"][2] = tUserConfig["tActive"]["tOpenBox"]["tCloseEnterTime"][1]
	tUserConfig["tActive"]["tOpenBox"]["tCloseEnterTime"][1] = tFunctionHelper.GetCurrentServerTime()
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
end

function OpenBox:GetDayStartTime(nTime)
	local nYear, nMonth, nDay = tipUtil:FormatCrtTime(nTime)
	local utc = tipUtil:DateTime2Seconds(nYear,nMonth,nDay,0,0,0)
	return utc
end

--[[
当天没有打开活动页直接关闭的，当天不再展示，
连续三天不打开活动页直接关闭的，后面不再显示。
--]]
function OpenBox:CheckStaticEntryCond()
	local tUserConfig = WorkModuleHelper:GetUserConfig()
	local tCloseEnterTime =  tFunctionHelper.FetchValueByPath(tUserConfig, {"tActive", "tOpenBox", "tCloseEnterTime"}) or 0
	if type(tCloseEnterTime) ~= "table" or  type(tCloseEnterTime[1]) ~= "number" then
		TipLog("[CheckStaticEntryCond] no last close time")
		return true
	end
	local nCurrentTime = tFunctionHelper.GetCurrentServerTime()
	if not tFunctionHelper.CheckIsAnotherDay(nCurrentTime, tCloseEnterTime[1]) then
		TipLog("[CheckStaticEntryCond] last close time is the same day")
		return false
	end
	local nCurStartTime = self:GetDayStartTime(nCurrentTime)
	if (type(tCloseEnterTime[1]) == "number" and tCloseEnterTime[1] < nCurStartTime and tCloseEnterTime[1] >= nCurStartTime-86400)
		and (type(tCloseEnterTime[2]) == "number" and tCloseEnterTime[2] < nCurStartTime-86400 and tCloseEnterTime[2] >= nCurStartTime-86400*2)
		and (type(tCloseEnterTime[3]) == "number" and tCloseEnterTime[3] < nCurStartTime-86400*2 and tCloseEnterTime[3] >= nCurStartTime-86400*3) then
		TipLog("[CheckStaticEntryCond] continuity 3 days close")
		return false
	end
	return true
end

function OpenBox:CheckPopupWndCond()
	local tUserConfig = WorkModuleHelper:GetUserConfig()
	local nLastPopupTipTime =  tFunctionHelper.FetchValueByPath(tUserConfig, {"tActive", "tOpenBox", "nLastPopupTipTime"}) or 0
	local nCurrentTime = tFunctionHelper.GetCurrentServerTime()
	if not tFunctionHelper.CheckIsAnotherDay(nLastPopupTipTime, nCurrentTime) then
		TipLog("[CheckPopupWndCond] popup fail, the same day")
		return false
	end
	local nLastOpenWebTime =  tFunctionHelper.FetchValueByPath(tUserConfig, {"tActive", "tOpenBox", "nLastOpenWebTime"}) or 0
	if not tFunctionHelper.CheckIsAnotherDay(nLastOpenWebTime, nCurrentTime) then
		TipLog("[CheckPopupWndCond] popup fail, has open web")
		return false
	end
	return true
end

function OpenBox:DoPopupTip(tOpenBoxCfg)
	if self._PopupTipTimerId then
		timeMgr:KillTimer(self._PopupTipTimerId)
		self._PopupTipTimerId = nil
	end
	local nDelaySec = self._tOpenBoxCfg["nDelaySec"] or  15*60
	TipLog("[DoPopupTip] try to popup openbox wnd, after " .. tostring(nDelaySec) .. "second")
	self._PopupTipTimerId = SetOnceTimer(function()
		TipLog("[DoPopupTip] time up")
		local wndSuspend = hostwndManager:GetHostWnd("GXZB.SuspendWnd.Instance")
		if wndSuspend == nil or wndSuspend:GetVisible() then
			TipLog("[DoPopupTip] popup fail, suspend wnd cond")
			return
		end
		if not self:CheckPopupWndCond() then
			TipLog("[DoPopupTip] popup fail, check popup wnd cond")
			return
		end
		
		local userData = {}
		userData["tOpenBoxCfg"] = self._tOpenBoxCfg
		if not UIInterface:CreatePopUpWnd("GXZB.RemindOpenBoxWnd", userData) then
			TipLog("[CheckPopupWndCond] CreatePopUpWnd fail")
			return
		end
		local tUserConfig = WorkModuleHelper:GetUserConfig()
		if type(tUserConfig["tActive"]) ~= "table" then
			tUserConfig["tActive"] = {}
		end
		if type(tUserConfig["tActive"]["tOpenBox"]) ~= "table" then
			tUserConfig["tActive"]["tOpenBox"] = {}
		end
		tUserConfig["tActive"]["tOpenBox"]["nLastPopupTipTime"] = tFunctionHelper.GetCurrentServerTime()
		tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
		
	end, nDelaySec*1000)
end

function OpenBox:ClearTimerId()
	if self._CalcTimerId then
		timeMgr:KillTimer(self._CalcTimerId)
		self._CalcTimerId = nil
	end
	if self._PrepareNextDayTimerId then
		timeMgr:KillTimer(self._PrepareNextDayTimerId)
		self._PrepareNextDayTimerId = nil
	end
	if self._StartActivityTimerId then
		timeMgr:KillTimer(self._StartActivityTimerId)
		self._StartActivityTimerId = nil
	end
	if self._PopupTipTimerId then
		timeMgr:KillTimer(self._PopupTipTimerId)
		self._PopupTipTimerId = nil
	end
end

function OpenBox:PrepareActivity(tOpenBoxCfg)
	self:Init()
	self:ClearTimerId()
    if type(tOpenBoxCfg) ~= "table" and type(self._tOpenBoxCfg) ~= "table" then
		TipLog("[PrepareActivity] no config")
        return
    end
	
	if type(tOpenBoxCfg) == "table" then
		self._tOpenBoxCfg = tOpenBoxCfg
	end
	local tabVer = self._tOpenBoxCfg["tVersion"]
	if type(tabVer) == "table" and not tFunctionHelper.CheckForceVersion(tabVer) then
		TipLog("[PrepareActivity] not pass version check")
        return
	end 
	local nCurrentTime = tFunctionHelper.GetCurrentServerTime()
    local nBeginTime = tonumber(tOpenBoxCfg["nBeginTime"]) or 0
    local nEndTime = tonumber(tOpenBoxCfg["nEndTime"]) or 9999999999
    if nCurrentTime < nBeginTime then
		local nLeftSecond = nBeginTime - nCurrentTime
		TipLog("[PrepareActivity] wait for " .. tostring(nLeftSecond) .. " seconds, for start activity")
		self._StartActivityTimerId = SetOnceTimer(function()
			self:GetUserWhiteListInfo()
		end, nLeftSecond*1000)
        return
	end	
	if nCurrentTime > nEndTime then
		TipLog("[PrepareActivity] activity finished")
		return
    end
	self:GetUserWhiteListInfo()
end




















