local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local tClientProc = XLGetGlobal("ClientProc")

ObjectBase = XLGetGlobal("ObjectBase")
MainWorkModule = ObjectBase:New()
XLSetGlobal("MainWorkModule", MainWorkModule)

--心跳接口
MainWorkModule._WorkingTimerId = nil
MainWorkModule._Balance = 0

--UI界面工作状态
MainWorkModule.STATE = {}
MainWorkModule.STATE.STOPPED = 0
MainWorkModule.STATE.STARTING = 1
MainWorkModule.STATE.PREPARE = 2
MainWorkModule.STATE.AllFAILED = 3
MainWorkModule.STATE.CALCULATE = 9
MainWorkModule._nWorkState = MainWorkModule.STATE.STOPPED

--重试
MainWorkModule.CONNECT_MAX_COUNT = 3
MainWorkModule.CONNECT_RETRY_COUNT = 0
MainWorkModule._ReConnectSvrTimerId = nil

--虚拟进度
MainWorkModule._PrepareTimerId = nil

--全速智能, 以及面板B部分的计算
MainWorkModule._bCurrentSpeedMax = false
MainWorkModule._MonitorTimerId = nil
MainWorkModule._nLastGetRealTimeIncomeTime = 0
MainWorkModule._nLastRealTimeIncome = 0

MainWorkModule._nBalance = 0
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
	tipUtil:Log("MainWorkModule: " .. tostring(strLog))
end

function GTV(obj)
	return "[" .. type(obj) .. "`" .. tostring(obj) .. "]"
end
--是否在工作
function MainWorkModule:CheckIsWorking()
	if self._nWorkState == self.STATE.STOPPED 
		or self._nWorkState == self.STATE.AllFAILED then
		return false
	else
		return true
	end
end

--是否在准备
function MainWorkModule:CheckIsPrepare()
	if self._nWorkState == self.STATE.STARTING 
		or self._nWorkState == self.STATE.PREPARE then
		return true
	else
		return false
	end
end

--是否在计算
function MainWorkModule:CheckIsCalculate()
	if self._nWorkState == self.STATE.CALCULATE then
		return true
	else
		return false
	end
end

function MainWorkModule:SetUserCurrentBalance(nBalance)
	self._nBalance = nBalance
	ApiInterfaceModule:UpdateWorkerBalance(nBalance)
end

function MainWorkModule:GetUserCurrentBalance()
	return self._nBalance
end

function MainWorkModule:GetCurrentSpeedWork()
	return self._bCurrentSpeedMax
end

function MainWorkModule:ShouldCpuMaxSpeedWork()
	local nGPUClient = tClientProc.GetModeWrokingClient()
	if nGPUClient == 1 then
		return false
	end
	return true
end

function MainWorkModule:GetNewPoolCfg(strCfgName, strPoolVerKey, nCoinNewCfgTime, funResult)
	WorkModuleHelper:GetSvrPoolCfg(strCfgName, function(tabInfo)
		if tabInfo == nil then
			funResult(false)
			return
		end
		local tUserConfig = WorkModuleHelper:GetUserConfig()
		if type(tUserConfig["tSvrPoolInfo"]) ~= "table" then
			tUserConfig["tSvrPoolInfo"] = {}
		end
		if type(tUserConfig["tSvrPoolInfo"][strCfgName]) ~= "table" then
			tUserConfig["tSvrPoolInfo"][strCfgName] = {}
		end
		local tabPool = tabInfo["data"][tostring(strPoolVerKey)] or {}
		local tabUserPool = {}
		for idx = 1, #tabPool do
			if type(tabPool[idx]) == "table" and tFunctionHelper.CheckPeerIDList(tabPool[idx]["pidlist"]) then
				tabUserPool[#tabUserPool+1] = tabPool[idx]
			end
		end
		if #tabUserPool <= 0 then
			funResult(false)
			return
		end	
		for key, value in pairs(tabUserPool) do
			tUserConfig["tSvrPoolInfo"][strCfgName][key] = value
		end
		tUserConfig["tSvrPoolInfo"][strCfgName]["nLastUpdateCfgTime"] = nCoinNewCfgTime
		tUserConfig["tSvrPoolInfo"][strCfgName]["strPoolVerKey"] = strPoolVerKey
		
		tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
		funResult(true)
		return
	end)
end

function MainWorkModule:UpdateSvrPoolCfg(tabNewCfgTime)
	if self._nWorkState == self.STATE.PREPARE 
		or self._nWorkState == self.STATE.CALCULATE then
		tClientProc.UpdateSvrPoolCfg(tabNewCfgTime)
	end
end

function MainWorkModule:UpdatePriority()
	SupportClientType:SortClientTable()
	tClientProc.UpdatePriority()
end

function MainWorkModule:UpdateMiningSpeed()
	local nMiningSpeedPerHour = tClientProc.GetMiningSpeed()
	UIInterface:UpdateMiningSpeed(nMiningSpeedPerHour)	
end

function MainWorkModule:ClearTimerID()
	if self._WorkingTimerId then
		timeMgr:KillTimer(self._WorkingTimerId)
		self._WorkingTimerId = nil
	end
	if self._ReConnectSvrTimerId then
		timeMgr:KillTimer(self._ReConnectSvrTimerId)
		self._ReConnectSvrTimerId = nil
	end
	if self._PrepareTimerId then
		timeMgr:KillTimer(self._PrepareTimerId)
		self._PrepareTimerId = nil
	end
	if self._MonitorTimerId then
		timeMgr:KillTimer(self._MonitorTimerId)
		self._MonitorTimerId = nil
	end
	self._nLastGetRealTimeIncomeTime = 0
end

function MainWorkModule:ClearRealTimeIncome()
	self._nLastRealTimeIncome = 0
	self._nLastGetRealTimeIncomeTime = tipUtil:GetCurrentUTCTime()
end

function MainWorkModule:StartMonitorTimer()
	if self._MonitorTimerId ~= nil then
		return
	end
	self._MonitorTimerId = timeMgr:SetTimer(function(Itm, id)
		local nSpanTime = 0
		if self._nLastGetRealTimeIncomeTime == 0 then
			nSpanTime = 5
		else
			nSpanTime = tipUtil:GetCurrentUTCTime() - self._nLastGetRealTimeIncomeTime
		end	
		self._nLastGetRealTimeIncomeTime = tipUtil:GetCurrentUTCTime()
		local nMiningSpeed = tClientProc.GetMiningSpeed()
		local nNewRealTimeIncome = self._nLastRealTimeIncome + nMiningSpeed*nSpanTime/3600
		if math.floor(nNewRealTimeIncome) > math.floor(self._nLastRealTimeIncome) then
			UIInterface:UpdateRealTimeIncome(math.floor(nNewRealTimeIncome))
		end
		self._nLastRealTimeIncome = nNewRealTimeIncome
		if WorkModuleHelper:IsSpeedWorkChanged(self._bCurrentSpeedMax) then
			TipLog("[StartMonitorTimer] change speed work")
			self._bCurrentSpeedMax = WorkModuleHelper:IsMaxSpeedWork()
			tClientProc.RestartByNewSpeedCmd(self._bCurrentSpeedMax)
		end
	end, 5000)	
end

function MainWorkModule:WorkingTimerHandle()
	if self._WorkingTimerId then
		timeMgr:KillTimer(self._WorkingTimerId)
		self._WorkingTimerId = nil
	end
	local nReportCalcInterval = ApiInterfaceModule:GetHeartbeatInterval()
	self._WorkingTimerId = timeMgr:SetTimer(function(Itm, id)
		local nMiningSpeed = tClientProc.GetMiningSpeed()
		timeMgr:KillTimer(self._WorkingTimerId)
			self._WorkingTimerId = nil
			WorkModuleHelper:PushCalcInfo(nMiningSpeed)
			self._WorkingTimerId = timeMgr:SetTimer(function(Itm, id)
				local nMiningSpeed = tClientProc.GetMiningSpeed()
				WorkModuleHelper:PushCalcInfo(nMiningSpeed)
			end, nReportCalcInterval*1000)	
	end, 60*1000)	
end

function MainWorkModule:ClearPrepareProgress()
	if self._PrepareTimerId then
		timeMgr:KillTimer(self._PrepareTimerId)
		self._PrepareTimerId = nil
	end
end

function MainWorkModule:UpdateState(nValue)
	if nValue == self.STATE.CALCULATE
		or self._nWorkState ~= self.STATE.CALCULATE then
		UIInterface:UpdateUIMiningState(self.STATE.CALCULATE)
		self:StartMonitorTimer()
	end
	self._nWorkState = nValue
end

function MainWorkModule:GeneratePrepareProgress()
	if self._PrepareTimerId == nil then
		TipLog("[GeneratePrepareProgress] start virtual dag")
		local nProgress = 1
		self._PrepareTimerId = timeMgr:SetTimer(function(Itm, id)
			if nProgress >= 100 then
				timeMgr:KillTimer(self._PrepareTimerId)
				self._PrepareTimerId = nil
				return 
			end
			nProgress = nProgress + 2
			if nProgress > 100 then
				nProgress = 100
				self:ClearPrepareProgress()
			end
			TipLog("[GeneratePrepareProgress] nProgress = " .. GTV(nProgress))
			UIInterface:UpdateDagProgress(nProgress)
		end, 1500)
	end
end

function MainWorkModule:NotifyStart()
	if not WorkModuleHelper:CheckCanStartNow() then
		return
	end
	self._nWorkState = self.STATE.STARTING
	UIInterface:OnStart()
	ApiInterfaceModule:UpdateLastPushCalcTime(tFunctionHelper.GetCurrentServerTime())
	WorkModuleHelper:WorkingPrepareWorkID(function(bSuccess)
		if self._nWorkState ~= self.STATE.STARTING then
			return 
		end
		if not bSuccess then
			self._nWorkState = self.STATE.STOPPED
			self:QuitClear()
			return
		end
		WorkModuleHelper:GetWorkerInfo(true ,function(tabInfo)
			self:StartClientProc(tabInfo)
		end)
	end)
end

function MainWorkModule:StartClientProc(tabInfo)
	self._bCurrentSpeedMax = WorkModuleHelper:IsMaxSpeedWork()
	tClientProc.StartAllMode(tabInfo["data"]["lastCfg"])
	self._nWorkState = self.STATE.PREPARE
	ApiInterfaceModule:ReportClientInfoToServer()
	ProfitMax:CheckRecommendDriver()
	self:WorkingTimerHandle()
	self:GeneratePrepareProgress()
	ShareBindWidth:StartPlugin()
end

function MainWorkModule:StartFail()
	UIInterface:SetStateInfoToUser("可执行文件不存在，可能被杀毒软件误杀，请添加信任")
	self:QuitClear()
	self._nWorkState = self.STATE.STOPPED
end

function MainWorkModule:AllModeClienFail()
	self._nWorkState = self.STATE.AllFAILED
	TipLog("[AllModeClienFail] all fail")
	self:CheckAndReTryConnectServer()
end

function MainWorkModule:QuitClear()
	TipLog("[QuitClear] clear")
	self:ClearTimerID()
	UIInterface:OnQuit()
	ProfitMax:ClearRecommendDriver()
	ShareBindWidth:StopPlugin()
	
end

function MainWorkModule:NotifyQuit()
	self._nWorkState = self.STATE.STOPPED
	self:QuitClear()
	tClientProc.QuitAllMode()
	ApiInterfaceModule:SendStopMiningInfoToServer("stop")
	
end

function MainWorkModule:SlientQuit()
	self._nWorkState = self.STATE.STOPPED
	tClientProc.QuitAllMode()
	self:QuitClear()
end

function MainWorkModule:CheckAndReTryConnectServer()
	if self._nWorkState == self.STATE.CALCULATE or self._nWorkState == self.STATE.STOPPED then
		return
	end
	tClientProc.QuitAllMode()
	self:QuitClear()
	self._nWorkState = self.STATE.STARTING
	
	UIInterface:OnStart()
	local nInterval = WorkModuleHelper:GetReconnectInterval()
	TipLog("[CheckAndReTryConnectServer] reconnect nInterval = " .. GTV(nInterval))
	UIInterface:SetStateInfoToUser("连接服务器失败，重试中...")
	self._ReConnectSvrTimerId = SetOnceTimer(function()
		self._ReConnectSvrTimerId = nil
		WorkModuleHelper:ReConnectTest(function(bRet)
			if not bRet then
				self:CheckAndReTryConnectServer()
				return
			end
			WorkModuleHelper:ResetReconnectCnt()
			WorkModuleHelper:GetWorkerInfo(true ,function(tabInfo)
				self:StartClientProc(tabInfo)
			end)
		end)
	end, nInterval)	
	return true	
end