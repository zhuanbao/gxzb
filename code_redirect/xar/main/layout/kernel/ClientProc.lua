local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local IPCUtil = XLGetObject("IPC.Util")
local tFunctionHelper = XLGetGlobal("FunctionHelper")

local EtcClient = XLGetGlobal("EtcClient")
local UtClient = XLGetGlobal("UtClient")
local ZcashNClient = XLGetGlobal("ZcashNClient")
local ZcashAClient = XLGetGlobal("ZcashAClient")
local XmrCClient = XLGetGlobal("XmrCClient")
local XmrNClient = XLGetGlobal("XmrNClient")
local XmrAClient = XLGetGlobal("XmrAClient")

--客户端状态
local CLIENT_STATE_CALCULATE = 0
local CLIENT_STATE_PREPARE = 1
local CLIENT_STATE_EEEOR = 2
local CLIENT_STATE_AUTO_EXIT = 3
local CLIENT_STATE_CONNECT_FAILED = 4
local CLIENT_STATE_TIMEOUT = 5

--上报速度
local _MsgType_SPEED = 1
--不同的客户端不一样
local _MsgType_UNKNOW= 2
--share提交结果
local _MsgType_SHARE = 3
--连接矿次结果
local _MsgType_CONNECT_POOL = 4
--错误
--进程自动退出
local _MsgType_AUTOEXIT = 5
--解析到错误信息
local _MsgType_ERROR_INFO = 9

local g_tabWorkMode = nil

local g_MaxConnectFailCnt = 7

function IsRealString(str)
	return type(str) == "string" and str ~= ""
end

function TipLog(strLog)
	tipUtil:Log("ClientProc: " .. tostring(strLog))
end

function GTV(obj)
	return "[" .. type(obj) .. "`" .. tostring(obj) .. "]"
end

function GetModeByClient(nMsgClient)
	--TipLog("[GetModeByClient] nMsgClient = " ..  GTV(nMsgClient))
	for Idx=1, #g_tabWorkMode do
		local nModeClientIdx = g_tabWorkMode[Idx]["nModeClientIdx"] 
		local nClient = g_tabWorkMode[Idx]["tabClient"][nModeClientIdx]
		--TipLog("[GetModeByClient] Idx = " .. GTV(Idx) .. ", nClient = " ..  GTV(nClient))
		if nMsgClient == nClient and g_tabWorkMode[Idx]["bWorking"] then
			return Idx
		end
	end
	return nil
end

function OnClientMsg(tParam)
	local nClient, nMsgType, nDetail = tParam[1], tParam[2], tParam[3]
	TipLog("[OnClientMsg] nClient = " .. GTV(nClient) .. ", nMsgType = " .. GTV(nMsgType) .. ", nDetail = " .. GTV(nDetail))
	local nMode = GetModeByClient(nClient)
	if nMode == nil then
		return
	end
	if nMsgType == _MsgType_SPEED then
		SupportClientType:SetNoCrashFlag(nClient)
		MainWorkModule:ClearPrepareProgress()
		MainWorkModule:UpdateState(MainWorkModule.STATE.CALCULATE)
		g_tabWorkMode[nMode]["nLastOutputCorrectTime"] = tipUtil:GetCurrentUTCTime()
		g_tabWorkMode[nMode]["nCurConnectFailCnt"] = 0
		if type(nDetail) == "number" and nDetail > 0 then
			--多乘了nSpeedMultiplier
			local nSpeedMultiplier = g_tabWorkMode[nMode]["tabClientData"]["tabParam"]["nSpeedMultiplier"]
			nDetail = nDetail/nSpeedMultiplier
			g_tabWorkMode[nMode]["nHashSpeed"] = nDetail
			MainWorkModule:UpdateMiningSpeed()
		end
	elseif nMsgType == _MsgType_SHARE then
		g_tabWorkMode[nMode]["nLastOutputCorrectTime"] = tipUtil:GetCurrentUTCTime()
	elseif nMsgType == _MsgType_CONNECT_POOL then
		if nDetail == 0 then
			g_tabWorkMode[nMode]["nLastOutputCorrectTime"] = tipUtil:GetCurrentUTCTime()
			g_tabWorkMode[nMode]["nCurConnectFailCnt"] = 0
		else
			g_tabWorkMode[nMode]["nCurConnectFailCnt"] = g_tabWorkMode[nMode]["nCurConnectFailCnt"] + 1
			if g_tabWorkMode[nMode]["nCurConnectFailCnt"] > g_MaxConnectFailCnt then
				StartModeClientNextPool(nMode)
			end
		end
	elseif nMsgType == _MsgType_AUTOEXIT then
		local tStatInfo = {}
		tStatInfo.fu1 = "runerror"
		tStatInfo.fu5 = "autoexit"
		tStatInfo.fu6 = tostring(nClient)
		tStatInfo.fu7 = tostring(nDetail)
		StatisticClient:SendClientErrorReport(tStatInfo)
		StartModeNextClient(nMode)
	elseif nMsgType == _MsgType_ERROR_INFO then
	
	end	
end

--1 GPU 2 CPU
function InitWorkMode()
	IPCUtil:Init()
	g_tabWorkMode = {}
	--g_tabWorkMode["bStart"] = false
	g_tabWorkMode[1] = {}
	g_tabWorkMode[1]["tabClient"] = SupportClientType:GetGpuClient() or {}
	g_tabWorkMode[1]["bWorking"] = false
	g_tabWorkMode[1]["nModeClientIdx"] = 0
	g_tabWorkMode[1]["nHashSpeed"] = 0
	g_tabWorkMode[1]["nLastOutputCorrectTime"] = 0
	g_tabWorkMode[1]["nCurConnectFailCnt"] = 0
	g_tabWorkMode[1]["OutputCorrectTimeID"] = nil
	g_tabWorkMode[2] = {}
	g_tabWorkMode[2]["tabClient"] = SupportClientType:GetCpuClient() or {}
	g_tabWorkMode[2]["bWorking"] = false
	g_tabWorkMode[2]["nModeClientIdx"] = 0
	g_tabWorkMode[2]["nHashSpeed"] = 0
	g_tabWorkMode[2]["nLastOutputCorrectTime"] = 0
	g_tabWorkMode[2]["nCurConnectFailCnt"] = 0
	g_tabWorkMode[2]["OutputCorrectTimeID"] = nil
	InitModeClient(1)
	InitModeClient(2)
end

function InitModeClient(nMode)
	local tabClient =  g_tabWorkMode[nMode]["tabClient"]
	if type(tabClient) == "table" and #tabClient > 0 then
		for Idx=1, #tabClient do
			local nModeClient = tabClient[Idx]
			local tabClientData = InitClient(nMode, nModeClient)
			if tabClientData["tabFun"]["funCheckFile"]() then
				g_tabWorkMode[nMode]["nModeClientIdx"]  = Idx
				g_tabWorkMode[nMode]["tabClientData"] = tabClientData
				break
			end	
		end	
	end
end

function CheckIsModeWroking(nMode)
	return g_tabWorkMode[nMode]["bWorking"]
end

function GetModeWrokingHashSpeed()
	return g_tabWorkMode[1]["nHashSpeed"] or 0, g_tabWorkMode[2]["nHashSpeed"] or 0
end

function GetModeWrokingClient()
	local nGPUClient, nCPUClient = 0, 0
	if g_tabWorkMode[1]["bWorking"] then
		local nModeClientIdx = g_tabWorkMode[1]["nModeClientIdx"] 
		nGPUClient = g_tabWorkMode[1]["tabClient"][nModeClientIdx]
	end
	if g_tabWorkMode[2]["bWorking"] then
		local nModeClientIdx = g_tabWorkMode[2]["nModeClientIdx"] 
		nCPUClient = g_tabWorkMode[2]["tabClient"][nModeClientIdx]
	end
	return nGPUClient, nCPUClient
end

function GetMiningSpeed()
	local nMiningSpeed = 0
	for nMode=1, #g_tabWorkMode do
		if type(g_tabWorkMode[nMode]["tabClientData"]) == "table" then
			local strCoinType = g_tabWorkMode[nMode]["tabClientData"]["tabParam"]["strCoinType"]
			local nRate = WorkModuleHelper:GetCoinRate(strCoinType)
			TipLog("[GetMiningSpeed] nMode " .. nMode .. ", nRate = " .. GTV(nRate) .. ", nHashSpeed = " .. GTV(g_tabWorkMode[nMode]["nHashSpeed"]))
			nMiningSpeed = nMiningSpeed + g_tabWorkMode[nMode]["nHashSpeed"]*nRate
		end
	end
	return math.floor(nMiningSpeed)
end

function PrepareClientPoolCfg(nMode, funResult)
	TipLog("[PrepareClientPoolCfg] nMode = " .. tostring(nMode))
	local strCoinType = g_tabWorkMode[nMode]["tabClientData"]["tabParam"]["strCoinType"]
	local strCfgName = g_tabWorkMode[nMode]["tabClientData"]["tabParam"]["strPoolFileName"]
	local nCoinNewCfgTime = g_tabWorkMode["tabNewCfgTime"][strCoinType] or tFunctionHelper.GetCurrentServerTime()
	if not WorkModuleHelper:IsPoolCfgChanged(strCfgName, nCoinNewCfgTime) then
		funResult(true)
		return
	end
	local strPoolVerKey = g_tabWorkMode[nMode]["tabClientData"]["tabParam"]["strPoolVerKey"]
	MainWorkModule:GetNewPoolCfg(strCfgName, strPoolVerKey, nCoinNewCfgTime, function(bResult)
		if bResult then
			g_tabWorkMode[nMode]["tabClientData"]["tabFun"]["funResetPool"]()
		end
		funResult(bResult)
	end)
end

function InitClient(nMode, nClient)
	local _, nPlatformId = SupportClientType:GetGpuClient()
	local tabClientInfo = nil
	
	if nClient == 1 then
		tabClientInfo = EtcClient.InitClient(nPlatformId)
	elseif nClient == 2 then
		tabClientInfo = ZcashNClient.InitClient(nPlatformId)
	elseif nClient == 3 then
		tabClientInfo = ZcashAClient.InitClient(nPlatformId)
	elseif nClient == 4 then
		tabClientInfo = XmrNClient.InitClient(nPlatformId)
	elseif nClient == 5 then
		tabClientInfo = XmrAClient.InitClient(nPlatformId, 5)
	elseif nClient == 6 then
		tabClientInfo = XmrAClient.InitClient(nPlatformId, 6)
	elseif nClient == 7 then
		tabClientInfo = XmrCClient.InitClient(nPlatformId)
	elseif nClient == 8 then
		tabClientInfo = UtClient.InitClient(nPlatformId)
	end
	return tabClientInfo
end

function UpdateSvrPoolCfg(tabNewCfgTime)
	g_tabWorkMode["tabNewCfgTime"] = tabNewCfgTime
	for nMode=1, #g_tabWorkMode do
		if type(g_tabWorkMode[nMode]["tabClientData"]) == "table" then
			local strCoinType = g_tabWorkMode[nMode]["tabClientData"]["tabParam"]["strCoinType"]
			local strCfgName = g_tabWorkMode[nMode]["tabClientData"]["tabParam"]["strPoolFileName"]
			local nCoinNewCfgTime = g_tabWorkMode["tabNewCfgTime"][strCoinType] or tFunctionHelper.GetCurrentServerTime()
			if not WorkModuleHelper:IsPoolCfgChanged(strCfgName, nCoinNewCfgTime) then
				return
			end
			local strPoolVerKey = g_tabWorkMode[nMode]["tabClientData"]["tabParam"]["strPoolVerKey"]
			MainWorkModule:GetNewPoolCfg(strCfgName, strPoolVerKey, nCoinNewCfgTime, function(bResult)
				if bResult then
					g_tabWorkMode[nMode]["tabClientData"]["tabFun"]["funResetPool"]()
					StartModeCurrentClient(nMode)
				else
					StartModeNextClient(nMode)
				end
			end)
		end
	end
end

function UpdatePriority()  
	for nMode=1, #g_tabWorkMode do
		local tabOld = g_tabWorkMode[nMode]["tabClient"] 
		local tabNew = {}
		if nMode == 1 then
			tabNew = SupportClientType:GetGpuClient()
		else
			tabNew = SupportClientType:GetCpuClient()
		end
		for Idx=1,#tabNew do
			if tabNew[Idx] ~= tabOld[Idx] then
				TipLog("[CheckIsPriorityChange] Priority has change")
				g_tabWorkMode[nMode]["tabClient"]  = tabNew
				g_tabWorkMode[nMode]["nModeClientIdx"] = 0
				StartModeNextClient(nMode)
				break
			end
		end
	end
end

--
function ResetModeClientParam(nMode)
	--g_tabWorkMode[1]["nHashSpeed"] = 0
	g_tabWorkMode[nMode]["nLastOutputCorrectTime"] = 0
	g_tabWorkMode[nMode]["nCurConnectFailCnt"] = 0
	if g_tabWorkMode[nMode]["OutputCorrectTimeID"] then
		timeMgr:KillTimer(g_tabWorkMode[nMode]["OutputCorrectTimeID"])
		g_tabWorkMode[nMode]["OutputCorrectTimeID"] = nil
	end
	local nModeClientIdx = g_tabWorkMode[nMode]["nModeClientIdx"] 
	local nModeClient = g_tabWorkMode[nMode]["tabClient"][nModeClientIdx]
	SupportClientType:ClearCrashDebugFlag(nModeClient)
end

--3分钟还没有纠错 就当已经不能挖矿了
function StartOutputCorrectimer(nMode)
	if g_tabWorkMode[nMode]["OutputCorrectTimeID"] then
		timeMgr:KillTimer(g_tabWorkMode[nMode]["OutputCorrectTimeID"])
		g_tabWorkMode[nMode]["OutputCorrectTimeID"] = nil
	end
	g_tabWorkMode[nMode]["nLastOutputCorrectTime"] = tipUtil:GetCurrentUTCTime()
	g_tabWorkMode[nMode]["OutputCorrectTimeID"] = timeMgr:SetTimer(function(Itm, id)
		local nCurrentTime = tipUtil:GetCurrentUTCTime()
		if nCurrentTime - g_tabWorkMode[nMode]["nLastOutputCorrectTime"] > 1.5*60 then
			TipLog("[StartOutputCorrectimer] output time out, try to restart")
			StartModeNextClient(nMode) 
		end
	end, 1000)
end

function StartModeClientNextPool(nMode)
	g_tabWorkMode[nMode]["tabClientData"]["tabFun"]["funResetPoolParam"]()
	StartModeCurrentClient(nMode)
end

function StartModeNextClient(nMode)
	ResetModeClientParam(nMode)
	g_tabWorkMode[nMode]["nModeClientIdx"] = g_tabWorkMode[nMode]["nModeClientIdx"]+1
	local nModeClientIdx = g_tabWorkMode[nMode]["nModeClientIdx"]
	local tabClient =  g_tabWorkMode[nMode]["tabClient"]
	--TipLog("[StartModeNextClient] nMode = " .. tostring(nMode) .. ", nModeClientIdx = " .. tostring(nModeClientIdx) .. ", tabClient cnt = " .. tostring(#tabClient))
	if nModeClientIdx > #tabClient then
		StopModeClient(nMode)
		g_tabWorkMode[nMode]["bWorking"] = false
		g_tabWorkMode[nMode]["nHashSpeed"] = 0
		g_tabWorkMode[nMode]["nModeClientIdx"] = 0
		g_tabWorkMode[nMode]["tabClientData"] = nil
		InitModeClient(nMode)
		ModeErrorOccur()
		return
	end
	local nModeClient = tabClient[nModeClientIdx]
	--这里先修改nHashSpeed速度为1，否则会造成由于新客户端的速度没出来，旧的速度会速度与新的rate相乘
	g_tabWorkMode[nMode]["nHashSpeed"] = 1
	g_tabWorkMode[nMode]["tabClientData"] = InitClient(nMode, nModeClient)
	if not g_tabWorkMode[nMode]["tabClientData"]["tabFun"]["funCheckFile"]() then
		StartModeNextClient(nMode)
		return
	end
	PrepareClientPoolCfg(nMode, function(bResult)
		if bResult then
			StartModeCurrentClient(nMode)
		else
			StartModeNextClient(nMode)
		end
	end)
end

function StartModeCurrentClient(nMode)
	ResetModeClientParam(nMode)
	g_tabWorkMode[nMode]["tabClientData"]["tabFun"]["funInitSpeed"]()
	local strCmdLine = g_tabWorkMode[nMode]["tabClientData"]["tabFun"]["funGetClientParam"]()
	if not IsRealString(strCmdLine) then
		StartModeNextClient(nMode)
		return
	end
	local nModeClientIdx = g_tabWorkMode[nMode]["nModeClientIdx"] 
	local nModeClient = g_tabWorkMode[nMode]["tabClient"][nModeClientIdx]
	SupportClientType:SetCrashDebugFlag(nModeClient)
	IPCUtil:StartModeClient(nMode, nModeClient, strCmdLine)
	StartOutputCorrectimer(nMode)
end

function StopModeClient(nMode)
	IPCUtil:QuitMode(nMode)
end

function RestartByNewSpeedCmd(bMax)
	for nMode=1, #g_tabWorkMode do
		if g_tabWorkMode[nMode]["tabClientData"]["tabFun"]["funChangeSpeed"](bMax) then
			StartModeCurrentClient(nMode)
		end
	end
end

function StartAllMode(tabNewCfgTime, funResult)
	local bStart = false
	for nMode=1, #g_tabWorkMode do
		if type(g_tabWorkMode[nMode]["tabClientData"]) == "table" then
			g_tabWorkMode[nMode]["bWorking"] = true
			bStart = true
		end
	end
	if not bStart then
		MainWorkModule:StartFail()
		return
	end
	g_tabWorkMode["tabNewCfgTime"] = tabNewCfgTime
	
	for nMode=1, #g_tabWorkMode do
		if type(g_tabWorkMode[nMode]["tabClientData"]) == "table" then
			PrepareClientPoolCfg(nMode, function(bResult)
				if bResult then
					StartModeCurrentClient(nMode)
				else
					StartModeNextClient(nMode)
				end
			end)
		end
	end
end

function QuitAllMode()
	IPCUtil:Quit()
	for nMode=1, #g_tabWorkMode do
		g_tabWorkMode[nMode]["bWorking"] = false
		g_tabWorkMode[nMode]["nHashSpeed"] = 0
		ResetModeClientParam(nMode)
	end
end

function ModeErrorOccur()
	local bAllFailed = true
	for nMode=1, #g_tabWorkMode do
		if g_tabWorkMode[nMode]["bWorking"] then
			bAllFailed = false
		end
	end	
	if bAllFailed then
		--全部都失败了，所有模式全部初始化到最初
		MainWorkModule:AllModeClienFail()
	end
end


function RegisterFunctionObject(self)
	local obj = {}
	obj.InitWorkMode = InitWorkMode
	obj.InitModeClient = InitModeClient
	obj.CheckIsModeWroking = CheckIsModeWroking
	obj.StartAllMode = StartAllMode
	obj.QuitAllMode = QuitAllMode
	obj.RestartByNewSpeedCmd = RestartByNewSpeedCmd
	obj.UpdatePriority = UpdatePriority
	obj.UpdateSvrPoolCfg = UpdateSvrPoolCfg
	obj.GetMiningSpeed = GetMiningSpeed
	obj.GetModeWrokingClient = GetModeWrokingClient
	obj.GetModeWrokingHashSpeed = GetModeWrokingHashSpeed
	obj.OnClientMsg = OnClientMsg

	
	XLSetGlobal("ClientProc", obj)
end
RegisterFunctionObject()