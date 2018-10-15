local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local IPCUtil = XLGetObject("IPC.Util")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local hostwndManager = XLGetObject("Xunlei.UIEngine.HostWndManager")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")
local tClientProc = XLGetGlobal("ClientProc")

ObjectBase = XLGetGlobal("ObjectBase")
UIInterface = ObjectBase:New()
XLSetGlobal("UIInterface", UIInterface)

UIInterface._bShowWndByTray = false
UIInterface._bInitPopWnd = false
UIInterface._tipNotifyIcon = nil

--配置默认值
UIInterface._cfgDefaultWorkModel = 1

--
UIInterface._bBossKeyHide = false
UIInterface._tHideWnd = {}


UIInterface._tPopupWndList = {
	"GXZB.IncomeRemindTipWnd",
	"GXZB.MachineCheckWnd",
	"GXZB.ProfitShareWnd",
	"GXZB.RecommandUpdateWnd",
	"GXZB.AutoRunTipWnd",
}

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
	tipUtil:Log("UIInterfaceModule: " .. tostring(strLog))
end

function UIInterface:GetDefaultWorkModel()
	return self._cfgDefaultWorkModel
end

function UIInterface:GetCurrentWorkModel()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local nWorkModel = tFunctionHelper.FetchValueByPath(tUserConfig, {"tConfig", "WorkModel", "nState"}) or self:GetDefaultWorkModel()
	return nWorkModel
end

function UIInterface:HideAllWnd()
	hostwndManager:BeginEnumHostWnd()
	local hostwnd = hostwndManager:GetNextHostWnd()
	while hostwnd do
		if hostwnd:GetVisible() then
			table.insert(self._tHideWnd, hostwnd)
			hostwnd:SetVisible(false)
		end
		hostwnd = hostwndManager:GetNextHostWnd()
	end
	self._tipNotifyIcon:Hide()
end

function UIInterface:ShowAllWnd()
	for i = 1, #self._tHideWnd do
		self._tHideWnd[i]:SetVisible(true)
	end
	self._tHideWnd = {}
	self._tipNotifyIcon:Show()
end


function UIInterface:CheckBossKey(nCurValue)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tConfig"]) ~= "table" then
		return
	end
	if type(tUserConfig["tConfig"]["BossKey"]) ~= "table" then
		return
	end
	local bCheck = tUserConfig["tConfig"]["BossKey"]["bCheck"]
	local nValue = tUserConfig["tConfig"]["BossKey"]["nValue"]
	if not bCheck or nValue < 0 or nValue ~= nCurValue then
		return
	end
	local objMainWnd = self:GetMainHostWnd()
	if self._bBossKeyHide then
		self:ShowAllWnd()
		
		self._bBossKeyHide = false
	else
		self:HideAllWnd()
		self._bBossKeyHide = true
	end
end

function UIInterface:SaveLastRemindBindUTC()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["nLastRemindBindUTC"] = tFunctionHelper.GetCurrentServerTime()
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
end

function UIInterface:SaveCommonUpdateUTC()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["nLastCommonUpdateUTC"] = tipUtil:GetCurrentUTCTime()
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
end

function UIInterface:CheckShouldRemindBind()
	if WorkModuleHelper:CheckIsBinded() then
		return false
	end
	local strCmdline = tipUtil:GetCommandLine()
	if true then
		return false
	end
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if tUserConfig["nLastRemindBindUTC"] ~= nil then
		return false
	end
	return true
end

function UIInterface:GetMainHostWnd()
	return Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
end

function UIInterface:DestroyMainWnd()
	local objHostWnd = self:GetMainHostWnd()
	if objHostWnd then
		Helper.hostWndManager:RemoveHostWnd("GXZB.MainWnd")
	end
end

function UIInterface:SetWndForeGround(objHostWnd)
	if not objHostWnd then
		return
	end

	if not tFunctionHelper.IsUserFullScreen() then
		-- objHostWnd:SetTopMost(true)
		if type(tipUtil.SetWndPos) == "function" then
			local hWnd = objHostWnd:GetWndHandle()
			if hWnd ~= nil then
				TipLog("[SetWndForeGround] success")
				tipUtil:SetWndPos(hWnd, 0, 0, 0, 0, 0, 0x0043)
			end
		end
	elseif type(tipUtil.GetForegroundProcessInfo) == "function" then
		local hFrontHandle, strPath = tipUtil:GetForegroundProcessInfo()
		if hFrontHandle ~= nil then
			objHostWnd:BringWindowToBack(hFrontHandle)
		end
	end
end

--悬浮窗
function UIInterface:CreateSuspendWnd()
	local wnd = Helper:CreateModelessWnd("GXZB.SuspendWnd", "GXZB.SuspendWndTree")
	wnd:Show(0)
end

function UIInterface:DestroySuspendWnd()
	Helper:DestoryModelessWnd("GXZB.SuspendWnd")
end

--弹出窗体
function UIInterface:CheckIsExistPopupWnd()
	for key, strID in pairs(self._tPopupWndList) do
		local strWndInstName = strID .. ".Instance"
		local wnd = hostwndManager:GetHostWnd(strWndInstName)
		if wnd then
			return true
		end
	end
	return false
end

function UIInterface:CreatePopUpWnd(wndTemplateID, userData)
	if self._bBossKeyHide then
		TipLog("[CreatePopUpWnd] BossKey is Hide, so not popup")
		return false
	end
	local strWndInstName = wndTemplateID .. ".Instance"
	local wnd = hostwndManager:GetHostWnd(strWndInstName)
	if wnd then
		TipLog("[CreatePopUpWnd] wndTemplateID = " .. tostring(wndTemplateID) .. " is exist")
		return false
	end
	if self:CheckIsExistPopupWnd() then
		TipLog("[CreatePopUpWnd] exist other popup wnd")
		return false
	end
	
	local treeTemplateID = wndTemplateID .. "Tree"
	wnd = Helper:CreateModelessWnd(wndTemplateID, treeTemplateID, nil, userData)
	self:ShowPopUpWnd(wnd, true)
	return true
end

function UIInterface:DestroyPopupWnd()
	for key, strID in pairs(self._tPopupWndList) do
		Helper:DestoryModelessWnd(strID)
	end
end

function UIInterface:ShowPopUpWnd(wnd, bSetTop)
	if not tFunctionHelper.IsUserFullScreen() then
		if type(tipUtil.SetWndPos) == "function" then
			local hWnd = wnd:GetWndHandle()
			if hWnd ~= nil then
				TipLog("[ShowPopUpWnd] success")
				if bSetTop then
					wnd:SetTopMost(true)
					tipUtil:SetWndPos(hWnd, 0, 0, 0, 0, 0, 0x0043)
				else
					tipUtil:SetWndPos(hWnd, -2, 0, 0, 0, 0, 0x0043)
				end
			end
		end
	end
	wnd:Show(5)
end

function UIInterface:DestroyAllWnd()
	self:DestroySuspendWnd()
	self:DestroyPopupWnd()
end
--
UIInterface._tabErrorMsg = nil
UIInterface._bShowUpdateDriveWnd = false


--弹出窗体

function UIInterface:ShowMaxSpeedWnd(nHashRate)
	local wndMain = self:GetMainHostWnd()
	local objMaxSpeedWnd = hostwndManager:GetHostWnd("GXZB.MaxSpeedDriveWnd.ModalInstance")
	if objMaxSpeedWnd == nil then
		Helper:CreateModalWnd("GXZB.MaxSpeedDriveWnd", "GXZB.MaxSpeedDriveWndTree", wndMain:GetWndHandle(), {["parentWnd"] = wndMain, ["nCurHashRate"] = nHashRate})
	end
end

function UIInterface:ShowUpdateDriveWnd()
	if not self._bShowUpdateDriveWnd then
		return false
	end
	local wndMain = self:GetMainHostWnd()
	
	
	if wndMain:GetVisible() then
		self._tipNotifyIcon:CancleFlashTray() 
		if ProfitMax:CanShowMaxSpeedWndNow() then
			UIInterface:ShowMaxSpeedWnd(0)
		else
			local objUpdateCardDriveWnd = hostwndManager:GetHostWnd("GXZB.UpdateCardDriveWnd.ModalInstance")
			if objUpdateCardDriveWnd == nil then
				Helper:CreateModalWnd("GXZB.UpdateCardDriveWnd", "GXZB.UpdateCardDriveWndTree", wndMain:GetWndHandle(), {["parentWnd"] = wndMain})
			end	
		end
	else
		self._tipNotifyIcon:FlashTray()
	end	
	return true
end

--弹出窗体
function UIInterface:AnalysisClientErrorMsg(tParam)
	local nClientType = tParam[1]
	local strErrorMsg = tParam[2]
	if type(nClientType) ~= "number" then
		return
	end
	if IsRealString(strErrorMsg) 
		--由于字符串截断的问题暂时只匹配关键字insufficient
		--and (string.find(string.lower(strErrorMsg), string.lower("driver version is insufficient for CUDA runtime version")) ~= nil 
		and (string.find(string.lower(strErrorMsg), string.lower("insufficient")) ~= nil 
		or string.find(string.lower(strErrorMsg), string.lower("Cannot load nvml")) ~= nil  )then
		self._tabErrorMsg = tParam
		self._bShowUpdateDriveWnd = true
		self:ShowUpdateDriveWnd(tParam)
	end
end

function UIInterface:PopRemindUpdateWnd()
	local nTipPopCnt  = tonumber(ServerCfg:GetServerCfgData({"tNewVersionInfo", "tRemindUpdate", "nCnt"})) or 0
	local nTipPopInterval  = tonumber(ServerCfg:GetServerCfgData({"tNewVersionInfo", "tRemindUpdate", "nSpanSec"})) or 0
	local strVersion = tFunctionHelper.GetGXZBVersion()
	if not IsRealString(strVersion) then
		strVersion = "1.0.0.1"
	end
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local nLocalCnt = tFunctionHelper.FetchValueByPath(tUserConfig, {"tRemindUpdateCfg", strVersion, "nCnt"}) or 0
	local nLocaLastUtc = tFunctionHelper.FetchValueByPath(tUserConfig, {"tRemindUpdateCfg", strVersion, "nLastUTC"}) or 0
	local nCurrentUtc = tFunctionHelper.GetCurrentServerTime() or 0
	local strNewVersion = ServerCfg:GetServerCfgData({"tNewVersionInfo", "strVersion"}) or "1.0.0.1"
	TipLog("PopRemindUpdateWnd strVersion="..tostring(strVersion)
		.."\n strNewVersion="..tostring(strNewVersion)
		.."\n nLocalCnt="..tostring(nLocalCnt)
		.."\n nTipPopCnt="..tostring(nTipPopCnt)
		.."\n nLocaLastUtc="..tostring(nLocaLastUtc)
		.."\n nCurrentUtc="..tostring(nCurrentUtc)
		.."\n nTipPopInterval="..tostring(nTipPopInterval))
	if tFunctionHelper.CheckIsNewVersion(strNewVersion, strVersion) and nLocalCnt < nTipPopCnt and math.abs(nCurrentUtc - nLocaLastUtc) > nTipPopInterval then
		SetOnceTimer(function()
				local objCheckUpdateWnd = hostwndManager:GetHostWnd("GXZB.UpdateCardDriveWnd.ModalInstance")
				if objCheckUpdateWnd then return end
				
				if UIInterface:CreatePopUpWnd("GXZB.RecommandUpdateWnd") then
					tUserConfig["tRemindUpdateCfg"] = tUserConfig["tRemindUpdateCfg"] or {}
					tUserConfig["tRemindUpdateCfg"][strVersion] = tUserConfig["tRemindUpdateCfg"][strVersion] or {}
					tUserConfig["tRemindUpdateCfg"][strVersion]["nCnt"] = nLocalCnt + 1
					nCurrentUtc = tFunctionHelper.GetCurrentServerTime() or 0
					tUserConfig["tRemindUpdateCfg"][strVersion]["nLastUTC"] = nCurrentUtc
					tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
				end	
			end, 60*1000)
		return true
	end
	return false
end

local bFirstPop = true

function UIInterface:GetRemindTipPopInterval()
	local nTipPopIntervals = tonumber(ServerCfg:GetServerCfgData({"tRemindCfg", "nPopIntervals"})) or 4*3600
	if not bFirstPop then
		return nTipPopIntervals
	end
	if tFunctionHelper.CheckCfgSetBoot() and not tFunctionHelper.CheckSysSetBoot() then
		nTipPopIntervals = 1800
	end
	bFirstPop = false
	return nTipPopIntervals
end


function UIInterface:PopTipPre4Hour()
	local function DoPopTip(item, id)
		WorkModuleHelper:GetServerHistoryIncome("h24", function(bRet, tabInfo)
			if bRet and type(tabInfo) == "table" and #tabInfo >= 4 then
				local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
				local bRemind = tFunctionHelper.FetchValueByPath(tUserConfig, {"tConfig", "EarningRemind", "bCheck"})
				if bRemind == nil then
					bRemind = true
				end
				if not bRemind then
					return
				end
				local nNewGet = 0
				for i = 1, 4 do
					nNewGet = nNewGet + tabInfo[#tabInfo-i+1][2]
				end
				if nNewGet > 0 then
					tUserConfig["nMoneyPer4Hour"] = nNewGet
					tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
					UIInterface:CreatePopUpWnd("GXZB.IncomeRemindTipWnd")
				end	
			end
		end)
	end
		
	local nTipPopIntervals  = self:GetRemindTipPopInterval()
	SetOnceTimer(function(item, id)
					DoPopTip(item, id)
					local nNextIntervals  = self:GetRemindTipPopInterval()
					
					SetTimer(function(nextitem, nextid)
								DoPopTip(nextitem, nextid)
							 end,
					nNextIntervals*1000)
				 end,
	nTipPopIntervals*1000)
end

--托盘
function UIInterface:HideTray()
	if self._tipNotifyIcon then
		self._tipNotifyIcon:Hide()
	end
end

function UIInterface:ShowMainPanleByTray(objHostWnd)
	if objHostWnd then
		objHostWnd:BringWindowToTop(true)
		--[[
		objHostWnd:Show(5)
		SetWndForeGround(objHostWnd)
		local strState = objHostWnd:GetWindowState()
		if tostring(strState) == "min" then
			objHostWnd:BringWindowToTop(true)
		end]]--
		
		-- local strHostWndName = "TipFilterRemindWnd.Instance"
		-- local objPopupWnd = hostwndManager:GetHostWnd(strHostWndName)
		-- if objPopupWnd and objPopupWnd:GetVisible() then
			-- local hWnd = objPopupWnd:GetWndHandle()
			-- if hWnd then
				-- objHostWnd:BringWindowToBack(hWnd)
			-- end
		-- end
	end
end

function UIInterface:GetToolTipInfo()
	local bShowSpeed = false
	local strText = ""
	if MainWorkModule:CheckIsPrepare() then
		strText = "准备中"
		bShowSpeed = true
	elseif MainWorkModule:CheckIsCalculate() then
		strText = "运行中"
		bShowSpeed = true
	else
		strText = "未开启"
	end	
	--TipLog("[GetToolTipInfo]: nPreWorkState = " .. tostring(nPreWorkState) .. ", strText = " .. tostring(strText))
	return strText,bShowSpeed
end

function UIInterface:PopupNotifyIconTip(strText, bShowWndByTray)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local bBubbleRemind = tFunctionHelper.FetchValueByPath(tUserConfig, {"tConfig", "BubbleRemind", "bState"})
	
	if not bBubbleRemind then
		self._bShowWndByTray = false
		return
	end
	
	if IsRealString(strText) and self._tipNotifyIcon then
		self._tipNotifyIcon:ShowNotifyIconTip(true, strText)
	end
	
	self._bShowWndByTray = bShowWndByTray
end

function UIInterface:SetNotifyIconState(strText)
	if not self._tipNotifyIcon then
		return
	end
	self._tipNotifyIcon:ShowNotifyIconTip(false)
	
	local strState, bShowSpeed = self:GetToolTipInfo()
	
	local strShowText = "共享赚宝  状态："..strState
	
	local nBalance = MainWorkModule:GetUserCurrentBalance()
	strShowText = strShowText .. "\r\n金库余额：" .. tFunctionHelper.NumberToFormatMoney(nBalance) .. "元宝"
	if bShowSpeed then
		local nSpeed = 0
		if strState == "运行中" then
			nSpeed = tClientProc.GetMiningSpeed()
		end
		strShowText = strShowText .. "\r\n当前赚宝速度：" .. tostring(nSpeed) .. "元宝/小时"
	end

	self._tipNotifyIcon:SetIcon(nil, strShowText)
end

function UIInterface:InitTrayTipWnd(objHostWnd)
    if not objHostWnd then
	    TipLog("[InitTrayTipWnd] para error")
	    return
	end

	--创建托盘
    local tipNotifyIcon = XLGetObject("Notify.Icon")
	if not tipNotifyIcon then
		TipLog("[InitTrayTipWnd] not support NotifyIcon")
	    return
	end
	
	----托盘事件响应
	function OnTrayEvent(event1,event2,event3,event4)
		local strHostWndName = "GSTrayMenuHostWnd.MainFrame"
		local newWnd = hostwndManager:GetHostWnd(strHostWndName)	
				
		--单击右键,创建并显示菜单
		if event3 == 517 then
			if not newWnd then
        		self:CreateTrayTipWnd(objHostWnd)
			end
		end
		
		--单击左键
		if event3 == 0x0202 then
			self:ShowMainPanleByTray(objHostWnd)
			--ShowIntroduceOnce()
		end
		
		--点击气泡
		if event3 == 1029 then
			if self._bShowWndByTray then
				self:ShowMainPanleByTray(objHostWnd)	
			end
		end
		
		--mousemove
		if event3 == 512 then
			self:SetNotifyIconState()
		end
	end

	tipNotifyIcon:Attach(OnTrayEvent)
	self._tipNotifyIcon = tipNotifyIcon
	self:SetNotifyIconState()
	tipNotifyIcon:Show()
	TipLog("[InitTrayTipWnd] init success")
	return self._tipNotifyIcon
end
--托盘菜单
function UIInterface:CreateTrayTipWnd(objHostWnd)
	local uTempltMgr = XLGetObject("Xunlei.UIEngine.TemplateManager")
	local uObjTreeMgr = XLGetObject("Xunlei.UIEngine.TreeManager")

	if uTempltMgr and uObjTreeMgr then
		local uHostWnd = nil
		local strHostWndTempltName = "TipTrayWnd"
		local strHostWndTempltClass = "HostWndTemplate"
		local strHostWndName = "GSTrayMenuHostWnd.MainFrame"
		local uHostWndTemplt = uTempltMgr:GetTemplate(strHostWndTempltName, strHostWndTempltClass)
		if uHostWndTemplt then
			uHostWnd = uHostWndTemplt:CreateInstance(strHostWndName)
		end

		local uObjTree = nil
		local strObjTreeTempltName = "TrayMenuTree"
		local strObjTreeTempltClass = "ObjectTreeTemplate"
		local strObjTreeName = "GSTrayMenuWnd.MainObjectTree"
		local uObjTreeTemplt = uTempltMgr:GetTemplate(strObjTreeTempltName, strObjTreeTempltClass)
		if uObjTreeTemplt then
			uObjTree = uObjTreeTemplt:CreateInstance(strObjTreeName)
		end

		if uHostWnd and uObjTree then
			--函数会阻塞
			local bSucc = self:ShowPopupMenu(uHostWnd, uObjTree)
			
			if bSucc and uHostWnd:GetMenuMode() == "manual" then
				uObjTreeMgr:DestroyTree(strObjTreeName)
				hostwndManager:RemoveHostWnd(strHostWndName)
			end
		end
	end
end

function UIInterface:ShowPopupMenu(uHostWnd, uObjTree)
	uHostWnd:BindUIObjectTree(uObjTree)
					
	local nPosCursorX, nPosCursorY = tipUtil:GetCursorPos()
	if type(nPosCursorX) ~= "number" or type(nPosCursorY) ~= "number" then
		return false
	end
	
	local nScrnLeft, nScrnTop, nScrnRight, nScrnBottom = tipUtil:GetScreenArea()
	
	local objMainLayout = uObjTree:GetUIObject("TrayMenu.Main")
	if not objMainLayout then
	    return false
	end	
		
	local nL, nT, nR, nB = objMainLayout:GetObjPos()				
	local nMenuContainerWidth = nR - nL
	local nMenuContainerHeight = nB - nT
	local nMenuScreenLeft = nPosCursorX
	local nMenuScreenTop = nPosCursorY - nMenuContainerHeight
	TipLog("[ShowTrayCtrlPanel] about to popup menu")
	
	if nMenuScreenLeft+nMenuContainerWidth > nScrnRight - 10 then
		nMenuScreenLeft = nPosCursorX - nMenuContainerWidth
	end
	
	-- uHostWnd:SetFocus(false) --先失去焦点，否则存在菜单不会消失的bug
	
	--函数会阻塞
	local bOk = uHostWnd:TrackPopupMenu(objHostWnd, nMenuScreenLeft, nMenuScreenTop, nMenuContainerWidth, nMenuContainerHeight)
	TipLog("[ShowPopupMenu] end menu")
	
	return bOk
end

--主界面
--悬浮窗
--nState:0 总是显示;1 总是隐藏; 2 仅赚宝时显示
--nScene:0 启动场景 1赚宝场景
function UIInterface:UpdateSuspendWndVisible(nScene)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["tConfig"] = tUserConfig["tConfig"] or {}
	tUserConfig["tConfig"]["ShowBall"] = tUserConfig["tConfig"]["ShowBall"] or {}
	local nState = tUserConfig["tConfig"]["ShowBall"]["nState"] or 0
	local ObjSuspendWnd = hostwndManager:GetHostWnd("GXZB.SuspendWnd.Instance")
	if ObjSuspendWnd == nil then
		return
	end
	local bVisibale = ObjSuspendWnd:GetVisible()
	if not bVisibale then
		if nState == 0 
			or nState == 2 and MainWorkModule:CheckIsWorking() then
			--self:ShowPopupWndByName("GXZB.SuspendWnd.Instance", true)
			--Statistic:SendUIReport("showsuspendwnd",1)
			self:ShowPopUpWnd(ObjSuspendWnd, true)
			local tStatInfo = {}
			tStatInfo.fu1 = "showball"
			tStatInfo.fu5 = 1
			StatisticClient:SendEventReport(tStatInfo)
		end	
	else 
		if nState == 1 
			or nState == 2 and not MainWorkModule:CheckIsWorking() then
			ObjSuspendWnd:Show(0)
			--Statistic:SendUIReport("showsuspendwnd",0)
			local tStatInfo = {}
			tStatInfo.fu1 = "showball"
			tStatInfo.fu5 = 0
			StatisticClient:SendEventReport(tStatInfo)
		end	
	end
end

function UIInterface:OnUserChangePanel()
	if not WorkModuleHelper:CheckIsBinded() then
		--return
	end
	WorkModuleHelper:GetWorkerInfo()
end

function UIInterface:ChangeMainBodyPanel(strPanelName)
	local wnd = self:GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	objMainBodyCtrl:ChangePanel(strPanelName)
end

function UIInterface:ChangeClientTitle(strTitle)
	local wnd = self:GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objTitleCtrl = objRootCtrl:GetControlObject("WndPanel.Title")
	objTitleCtrl:ChangeTitle(strTitle)
end
--更新用户提示信息
function UIInterface:SetStateInfoToUser(strInfo)
	local wnd = self:GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	local objMiningPanel = objMainBodyCtrl:GetChildObjByCtrlName("MiningPanel")
	if IsRealString(strInfo) then
		self:ChangeMainBodyPanel("MiningPanel")
	end	
	objMiningPanel:SetStateInfoToUser(strInfo)
	TipLog("[SetStateInfoToUser] strInfo = " .. tostring(strInfo))
end
--更新B部分
function UIInterface:UpdateRealTimeIncome(nRealTimeIncome)
	local wnd = self:GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	local nBalance = MainWorkModule:GetUserCurrentBalance()
	objMainBodyCtrl:UpdateRealTimeIncome(nBalance, nRealTimeIncome)
end

function UIInterface:GetSuspendRootCtrol()
	local objSuspendWnd = hostwndManager:GetHostWnd("GXZB.SuspendWnd.Instance")
	if objSuspendWnd then
		local objtreeSuspend = objSuspendWnd:GetBindUIObjectTree()
		local root = objtreeSuspend:GetUIObject("root")
		return root
	end
end

--所有要更新账户余额的地方在这里处理
function UIInterface:UpdateUserBalance()
	--在注册记录一下， 方便卸载时判断余额
	local nBalance = MainWorkModule:GetUserCurrentBalance()
	if tonumber(nBalance) >= 0 then
		tFunctionHelper.RegSetValue("HKEY_CURRENT_USER\\Software\\Share4Money\\balance", tFunctionHelper.NumberToFormatMoney(nBalance))
	end
	local wnd = self:GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	objMainBodyCtrl:UpdateUserBalance(nBalance)
	--更新球
	local root = self:GetSuspendRootCtrol()
	if root and type(root.UpdateUserBalance) == "function" then
		root:UpdateUserBalance(nBalance)
	end
	MainWorkModule:ClearRealTimeIncome()
end

--所有要处理绑定后信息的地方在这里处理
function UIInterface:UpdateClientBindState()
	local wnd = self:GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	objMainBodyCtrl:UpdateClientBindState()
end

--所有要处理解绑后信息的地方在这里处理
function UIInterface:UpdateClientUnBindState()
	local wnd = self:GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	MainWorkModule:SetUserCurrentBalance(0)
	self:UpdateUserBalance()
	objMainBodyCtrl:UpdateClientUnBindState()
	--更新球
	local root = self:GetSuspendRootCtrol()
	if root and type(root.UpdateClientUnBindState) == "function" then
		root:UpdateClientUnBindState()
	end
end

--所有要更新速度的地方在这里处理
function UIInterface:UpdateMiningSpeed(nMiningSpeedPerHour)
	TipLog("[UpdateMiningSpeed] nMiningSpeedPerHour = " .. tostring(nMiningSpeedPerHour))
	local wnd = self:GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	objMainBodyCtrl:UpdateMiningSpeed(nMiningSpeedPerHour)
	--更新球
	local root = self:GetSuspendRootCtrol()
	if root and type(root.UpdateMiningSpeed) == "function" then
		root:UpdateMiningSpeed(nMiningSpeedPerHour)
	end
end

--所有要更新DAG进度的地方在这里处理
function UIInterface:UpdateDagProgress(nProgress)
	local wnd = self:GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	objMainBodyCtrl:UpdateDagProgress(nProgress)
end
--所有要更新Mining状态的地方在这里处理
function UIInterface:UpdateUIMiningState(nMiningState)
	local wnd = self:GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	objMainBodyCtrl:UpdateMiningState(nMiningState)
	--更新球
	local root = self:GetSuspendRootCtrol()
	if root and type(root.UpdateMiningState) == "function" then
		root:UpdateMiningState(nMiningState)
	end
end
------------
--所有要更新工作状态的地方在这里处理
--1:正在运行,2:不在运行
function UIInterface:OnWorkStateChange()
	local wnd = self:GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	objMainBodyCtrl:OnWorkStateChange()
	--更新球
	local root = self:GetSuspendRootCtrol()
	if root and type(root.OnWorkStateChange) == "function" then
		root:OnWorkStateChange()
	end
end
--解绑
function UIInterface:UnBindSuccess()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["tUserInfo"] = nil
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
	self:ChangeClientTitle("共享赚宝 (未绑定)")
	self:ChangeMainBodyPanel("MiningPanel")
	self:UpdateClientUnBindState()
	InviteReward:ClearInviteReward()
end	

function UIInterface:UnBindFail()
	--Statistic:SendUIReport("unbindclient","fail")
	local tStatInfo = {}
	tStatInfo.fu1 = "unbindwx"
	tStatInfo.fu5 = "fail"
	StatisticClient:SendEventReport(tStatInfo)
	
	local wnd = self:GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	objMainBodyCtrl:UpdateClientUnBindFailState()
	self:ChangeMainBodyPanel("MiningPanel")
end	

function UIInterface:OnStart()
	self:UpdateSuspendWndVisible()
	self:OnWorkStateChange()
	StatisticClient:StartRunTimeReport("working")
	tipUtil:StopComputerSleep(true)
end	

function UIInterface:OnQuit()
	self:ShowRemindRebootWarning()
	self:UpdateSuspendWndVisible()
	self:OnWorkStateChange()
	--Statistic:SendMiningReport(0, true)
	StatisticClient:StartRunTimeReport("noworking")
	--Statistic:StopMiningCountTimer()
	tipUtil:StopComputerSleep(false)
end	

function UIInterface:ReportAndExit()
	--记住主窗体位置
	local wnd = self:GetMainHostWnd()
	if wnd then
		local l, t, r, b = wnd:GetWindowRect()
		local w, h = r-l, b - t
		local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
		tUserConfig["tWindow"] = tUserConfig["tWindow"] or {}
		tUserConfig["tWindow"]["tMain"] = tUserConfig["tWindow"]["tMain"] or {}
		tUserConfig["tWindow"]["tMain"].nLeft = l
		tUserConfig["tWindow"]["tMain"].nTop = t
		tUserConfig["tWindow"]["tMain"].nWidth  = 420
		tUserConfig["tWindow"]["tMain"].nHeight = 652
		tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
	end
	self:DestroyMainWnd()
	self:DestroyAllWnd()
	self:HideTray()
	
	
	StatisticClient:StartRunTimeReport("noworking")
	local tStatInfo = {}
	tStatInfo.fu1 = "exit"
	tStatInfo.Exit = true
	StatisticClient:SendEventReport(tStatInfo)
end

function UIInterface:ShowRemindRebootWarning()
	local wnd = self:GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	local objMiningPanel = objMainBodyCtrl:GetChildObjByCtrlName("MiningPanel")
	objMiningPanel:ShowRemindRebootWarning()
end

function UIInterface:ShowNoticeTip(tabCfg)
	local wnd = self:GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	local objMiningPanel = objMainBodyCtrl:GetChildObjByCtrlName("MiningPanel")
	objMiningPanel:ShowNoticeTip(tabCfg)
end

--420*652  369*600
function UIInterface:CheckCanShowUserIntroduce(tabInfo)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if WorkModuleHelper:CheckIsBinded() then
		tUserConfig["tConfig"] = tUserConfig["tConfig"] or {}
		tUserConfig["tConfig"]["tUserIntroduce"] = tUserConfig["tConfig"]["tUserIntroduce"] or {}
		tUserConfig["tConfig"]["tUserIntroduce"]["nLastShowTime"] = tFunctionHelper.GetCurrentServerTime()
		tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
		
		return
	end
	local nLastShowTime = tFunctionHelper.FetchValueByPath(tUserConfig, {"tConfig", "tUserIntroduce", "nLastShowTime"})
	if nLastShowTime ~= nil then
		return
	end
	
	--[[
	local bRet, strSource = tFunctionHelper.GetCommandStrValue("/sstartfrom")
	if string.lower(tostring(strSource)) ~= "installfinish" and string.lower(tostring(strSource)) ~= "reinstallfinish" then
		return
	end
	--]]
	if type(tabInfo) ~= "table" then
		return
	end
	local strTest = nil
	if type(tabInfo["tPIDA"]) ~= "table" or not tFunctionHelper.CheckPeerIDList(tabInfo["tPIDA"]) then
        strTest = "A" 
		self._bCanShowRewardInfo = false
	elseif type(tabInfo["tPIDB"]) ~= "table" or not tFunctionHelper.CheckPeerIDList(tabInfo["tPIDB"]) then
		strTest = "B" 
    end
	if strTest == nil then
		return
	end
	
	local ObjUserIntroduce = objFactory:CreateUIObject("UserIntroduce.Instance", "UserIntroduce")
	ObjUserIntroduce:SetTestType(strTest)
	local wnd = self:GetMainHostWnd()
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainWndBkg = objRootCtrl:GetControlObject("WndPanel.MainWnd.Bkg")
	objMainWndBkg:AddChild(ObjUserIntroduce)
	ObjUserIntroduce:SetZorder(300000)
	ObjUserIntroduce:SetObjPos((420-369)/2, 18, (420-369)/2+369, 18+600)
end

function UIInterface:RemoveUserIntroduce()
	local wnd = self:GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local ObjUserIntroduce = objRootCtrl:GetControlObject("UserIntroduce.Instance")
	local objMainWndBkg = objRootCtrl:GetControlObject("WndPanel.MainWnd.Bkg")
	objMainWndBkg:RemoveChild(ObjUserIntroduce)
end

function UIInterface:AttachFirstShowMainWnd()	
	local wnd = self:GetMainHostWnd()
	self._nShowWindowCookie = wnd:AttachListener("OnShowWindow", false, function(wnd, bShow)
		if bShow then
			if not UIInterface:ShowUpdateDriveWnd() then
				if tFunctionHelper.CheckCfgSetBoot() and not tFunctionHelper.CheckSysSetBoot() then
					UIInterface:CreatePopUpWnd("GXZB.AutoRunTipWnd")
				end
			end	
			wnd:RemoveListener("OnShowWindow", self._nShowWindowCookie)
			self._nShowWindowCookie = nil
		end
	end)
end

function UIInterface:ShowSupperPC(tabInfo)	
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local wnd = self:GetMainHostWnd()
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	if type(tabInfo) ~= "table" then
		return
	end
	if type(tabInfo["tMPID"]) == "table" and tFunctionHelper.CheckPeerIDList(tabInfo["tMPID"]) then
		local nLastClickTime = tFunctionHelper.FetchValueByPath(tUserConfig, {"tConfig", "tMenuSupperPC", "nLastClickTime"})
		local objTitle = objRootCtrl:GetControlObject("WndPanel.Title")
		local objSupperPC = objTitle:GetControlObject("TitleCtrl.Caption.SupperPC")
		local objSupperPCRemind = objSupperPC:GetControlObject("TitleCtrl.Caption.SupperPC.Remind")
		objSupperPC:Show(true)
		if nLastClickTime == nil then
			objSupperPCRemind:SetVisible(true)
		else
			objSupperPCRemind:SetVisible(false)
		end
    elseif type(tabInfo["tTCPID"]) == "table" and tFunctionHelper.CheckPeerIDList(tabInfo["tTCPID"]) then
		local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
		local objTakeCashPanel = objMainBodyCtrl:GetChildObjByCtrlName("TakeCashPanel")
		local objSupperPC = objTakeCashPanel:GetControlObject("TakeCashPanel.Panel.SupperPC")
		objSupperPC:SetVisible(true)
		
		local objSupperPCLink = objTakeCashPanel:GetControlObject("TakeCashPanel.Panel.SupperPC.Link")
		objSupperPCLink:Show(true)
    end	
end

UIInterface._bCanShowRewardInfo = true
function UIInterface:CheckCanShowRewardInfo()	
	return self._bCanShowRewardInfo
end