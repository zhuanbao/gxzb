local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local IPCUtil = XLGetObject("IPC.Util")

--矿池配置文件名字
local g_PoolCfgName = "cpcfg.json"
local g_DefaultPoolType = "x_cc"
local g_nPlatformId = 0
--常量
local CLIENT_XMR_X = nil
local CLIENT_XMR_X_REAL = nil
local CLIENT_PATH = "Share4Peer\\"

local COUTAGENT_PATH = "ShareCout.exe"
--上报速度
local WP_XMR_SPEED = 1

--share提交结果
local WP_XMR_SHARE = 2
--连接矿次结果
local WP_XMR_CONNECT_POOL = 3
--错误
--进程自动退出
local WP_XMR_AUTOEXIT = 5
--解析到错误信息
local WP_XMR_ERROR_INFO = 9


--客户端状态
local CLIENT_STATE_CALCULATE = 0
local CLIENT_STATE_PREPARE = 1
local CLIENT_STATE_EEEOR = 2
local CLIENT_STATE_AUTO_EXIT = 3

--全局参数
local g_PreWorkState = nil
local g_HashRateSum = 0 --累加速度，一分钟上报一次时，取这一分钟的平均速度
local g_HashRateSumCounter = 0 --速度累加的计数器
local g_PerSpeed = 10 --服务端返回的平均速度((元宝/Hour)/SOL)
local g_MiningSpeedPerHour = 0 --根据矿工当前速度计算的挖矿平均速度(元宝/Hour)

local g_bFullSpeed = false

local g_ConnectFailCnt = 0
--链接矿次失败只会输出一次信息
local g_MaxConnectFailCnt = 1

local g_strHost = nil --矿池地址
local g_strAccount = nil
local g_strPool = nil  --这个只是上报时用到的矿池代号
local g_PoolIndex = 0

local g_XmrWorkingTimerId = nil 
local g_ClientReTryCnt = 0 
local g_ClientMaxReTryCnt = 3 
local g_LastClientOutputRightInfoTime = 0

--local g_LastGetSpeedTime = 0
local g_LastGetRealTimeIncomeTime = 0
local g_LastRealTimeIncome = 0
local g_LastAverageHashRate = 0

local g_XmrDAGTimerId = nil

local g_XmrRealTimeIncomeTimerId = nil
local g_ClientOutputSpeed = 0 --0H/s

local g_bNoPrepare = false

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
	if type(tipUtil.Log) == "function" then
		tipUtil:Log("XmrClient: " .. tostring(strLog))
	end
end

function GTV(obj)
	return "[" .. type(obj) .. "`" .. tostring(obj) .. "]"
end

function IsExistOtherUserWnd()
	local nWndCoverMinPercent = 2
	local function CheckWindowCond(hWnd)
		if not tipUtil:IsWindowVisible(hWnd) or tipUtil:IsWindowIconic(hFrontHandle) then
			return false
		end
		local strFileName = nil 
		local dwPId = tipUtil:GetWndProcessThreadId(hWnd)
		local strExePath = tipUtil:GetProcessModulePathByPID(dwPId)
		TipLog("[strExePath]  strExePath = " .. GTV(strExePath))
		if IsRealString(strExePath) then
			local strFileName = tFunctionHelper.GetFileNameFromPath(strExePath)
			local strWndClassName = tipUtil:GetWndClassName(hWnd)
			TipLog("[CheckWindowCond] strWndClassName = " .. GTV(strWndClassName) .. ", strFileName = " .. GTV(strFileName))
			if not IsRealString(strWndClassName)
				or not IsRealString(strFileName) then
				TipLog("[CheckWindowCond] Get name fail")
				return false
			end
			if string.lower(strFileName) == "share4money.exe" 
				or (string.lower(strFileName) == "explorer.exe" and (string.lower(strWndClassName) ~= "cabinetwclass" and string.lower(strWndClassName) ~= "explorewclass" ))
				or (string.lower(strWndClassName) == string.lower("Windows.UI.Core.CoreWindow"))
				then
				TipLog("[CheckWindow] name or class name match")
				return false
			end
		end	
		local sl,st,sr,sb = tipUtil:GetScreenArea()
		local bRet,wndl,wndt,wndr,wndb = tipUtil:GetWndRect(hWnd)
		if not bRet then
			TipLog("[CheckWindowCond] Get wnd rect fail")
			return false
		end
		TipLog("[CheckWindowCond] wndl = " .. GTV(wndl) .. ", wndt = " .. GTV(wndt) .. ", wndr = " .. GTV(wndr) .. ", wndb = " .. GTV(wndb))
		local areal, areat, arear, areab= wndl,wndt,wndr,wndb
		if wndl < sl then
			areal = sl
		end
		if wndt < st then
			areat = st
		end
		if arear > sr then
			arear = sr
		end
		if wndb > sb then
			areab = sb
		end
		TipLog("[CheckWindowCond] areal = " .. GTV(areal) .. ", areat = " .. GTV(areat) .. ", arear = " .. GTV(arear) .. ", areab = " .. GTV(areab))
		if areal > arear or areat > areab then
			TipLog("[CheckWindowCond] area error")
			return false
		end
		local nScreenArea = (sb-st)*(sr-sl)
		local nWindArea = (areab-areat)*(arear-areal)
		local nCoverPercent = nWindArea/nScreenArea*100
		TipLog("[CheckWindowCond] nScreenArea = " .. GTV(nScreenArea) .. ", nWindArea = " .. GTV(nWindArea))
		if nCoverPercent < nWndCoverMinPercent then	
			return false
		end
		TipLog("[CheckWindowCond] find active wnd")
		return true
	end
	
	local hWnd = tipUtil:FindWindow(nil, nil) 
	while hWnd do
		if CheckWindowCond(hWnd) then
			return true
		else
			hWnd = tipUtil:FindWindowEx(nil, hWnd, nil, nil)
		end
	end
	
	return false
end

function LimitSpeedCond()
	if tipUtil:IsNowFullScreen() then
		TipLog("[LimitSpeedCond] full screen")
		return true
	end
	local hr, dwTime = tipUtil:GetLastInputInfo()
	local dwTickCount = tipUtil:GetTickCount()
	if hr == 0 and type(dwTime) == "number" and type(dwTickCount) == "number" and dwTickCount - dwTime < 3*60*1000 then
		TipLog("[LimitSpeedCond] Last input in 3*60 second")
		return true
	end
	--判断是否有用户窗口(比如用户正在非全屏看电影)
	--[[
	if IsExistOtherUserWnd() then
		TipLog("[LimitSpeedCond] exist other visiable wnd")
		return true
	end
	--]]
	TipLog("[LimitSpeedCond] not need speed limit")
	return false
end

function GetNewMiningCmdInfo()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	local strWorkID = tUserConfig["tUserInfo"]["strWorkID"]
	local strPoolKey = GetPoolCfgName()
	local tPoolList = tUserConfig["tSvrPoolInfo"][strPoolKey]
	g_strHost = nil
	g_strAccount = nil
	g_strPool = nil
	g_PoolIndex = g_PoolIndex + 1
	if g_PoolIndex <= #tPoolList then
		local tabPoolItem = tPoolList[g_PoolIndex]
		if type(tabPoolItem) == "table" then
			if IsRealString(tabPoolItem["host"]) then
				g_strHost = tabPoolItem["host"]
				g_strAccount = tabPoolItem["account"]
				g_strPool = tabPoolItem["p"]
			end
		end	
	end
	if g_strHost == nil then
		g_PoolIndex = 0
	end
	return g_strHost
end

function GetCurrentMiningCmdLine()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	local strWorkID = tUserConfig["tUserInfo"]["strWorkID"]
	if not IsRealString(strWorkID) then
		return nil
	end
	if g_strHost == nil then
		GetNewMiningCmdInfo()
	end
	if g_strHost == nil then
		return nil
	end
	local strExeName, nRealMiningType = XmrHelper:InitXmr(CLIENT_XMR_X, g_bFullSpeed, g_strHost, g_strAccount, strWorkID, g_nPlatformId)
	CLIENT_XMR_X_REAL = nRealMiningType
	return strExeName
end

function UpdateSpeed(nHashRate)
	 g_MiningSpeedPerHour = math.floor(nHashRate * ClientWorkModule:GetSvrAverageMiningSpeed())
end

function GetRealTimeIncome(nSpeed,nSpanTime)
	if nSpanTime <= 0 or nSpeed <= 0 then
		TipLog("[GetRealTimeIncome] nSpanTime = " .. GTV(nSpanTime) .. ", nSpeed = " .. GTV(nSpeed))
		return 0
	end
	local nIncome = nSpeed*nSpanTime*ClientWorkModule:GetSvrAverageMiningSpeed()/3600
	
	local nLastRealTimeIncome = g_LastRealTimeIncome
	local nNewRealTimeIncome = g_LastRealTimeIncome + nIncome
	g_LastRealTimeIncome = nNewRealTimeIncome
	TipLog("[GetRealTimeIncome] nIncome = " .. GTV(nIncome) .. ", nLastRealTimeIncome = " .. GTV(nLastRealTimeIncome) .. ", nNewRealTimeIncome = " .. GTV(nNewRealTimeIncome))
	if math.floor(nNewRealTimeIncome) > nLastRealTimeIncome then
		return math.floor(nNewRealTimeIncome)
	end
	TipLog("[GetRealTimeIncome] no new income")
	return 0
end

function WhenGetShare()
	local nMaxQueryCnt = 2
	local nInterval = 3
	local nQueryCnt = 0
	local nReportCalcInterval = ClientWorkModule:GetHeartbeatInterval()
	local nLastQueryBalanceTime = ClientWorkModule:GetLastQueryBalanceTime()
	local nLastBalance = ClientWorkModule:GetUserCurrentBalance()
	local function DoQueryTimer()
		nQueryCnt = nQueryCnt + 1
		if nQueryCnt > nMaxQueryCnt then
			return
		end
		local nCurrentUTCTime = tipUtil:GetCurrentUTCTime()
		if nCurrentUTCTime > nLastQueryBalanceTime + nReportCalcInterval - 3 then
			return
		end
		local nBalance = ClientWorkModule:GetUserCurrentBalance()
		if nLastBalance ~= nBalance then
			return
		end
		SetOnceTimer(function()
			ClientWorkModule:QueryWorkerInfo()
			DoQueryTimer()
		end, nInterval*1000)	
	end
	DoQueryTimer()
end

function GenerateVirtualDAG()
	if g_XmrDAGTimerId == nil then
		TipLog("[GenerateVirtualDAG] start virtual dag")
		local nProgress = 1
		g_XmrDAGTimerId = timeMgr:SetTimer(function(Itm, id)
			if nProgress >= 100 then
				timeMgr:KillTimer(g_XmrDAGTimerId)
				g_XmrDAGTimerId = nil
				return 
			end
			nProgress = nProgress + 3
			if nProgress > 100 then
				nProgress = 100
				KillVirtualDAG()
			end
			TipLog("[GenerateVirtualDAG] nProgress = " .. GTV(nProgress))
			UIInterface:UpdateDagProgress(nProgress)
		end, 1000)
	end
end

function KillVirtualDAG()
	if g_XmrDAGTimerId then
		timeMgr:KillTimer(g_XmrDAGTimerId)
		g_XmrDAGTimerId = nil
	end
end

function StartRealTimeIncomeTimer()
	if g_XmrRealTimeIncomeTimerId ~= nil then
		return
	end
	g_XmrRealTimeIncomeTimerId = timeMgr:SetTimer(function(Itm, id)
		local nSpanTime = 0
		if g_LastGetRealTimeIncomeTime == 0 then
			nSpanTime = 5
		else
			nSpanTime = tipUtil:GetCurrentUTCTime() - g_LastGetRealTimeIncomeTime
		end	
		g_LastGetRealTimeIncomeTime = tipUtil:GetCurrentUTCTime()
		local nRealTimeIncome = GetRealTimeIncome(g_ClientOutputSpeed, nSpanTime)
		
		if nRealTimeIncome > 0 then
			UIInterface:UpdateRealTimeIncome(nRealTimeIncome)
		end
	end, 5000)	
end

function OnXmrMsg(tParam)
	local nMsgType, nParam = tParam[1],tParam[2]
	TipLog("[OnXmrMsg] nMsgType = " .. GTV(nMsgType) .. ", nParam = " .. GTV(nParam))
	if nMsgType == WP_XMR_SPEED then
		SupportClientType:SetNoCrashFlag(CLIENT_XMR_X_REAL)
		KillVirtualDAG()
		g_LastClientOutputRightInfoTime = tipUtil:GetCurrentUTCTime()
		if g_PreWorkState ~= CLIENT_STATE_CALCULATE then
			ResetGlobalErrorParam()
			g_PreWorkState = CLIENT_STATE_CALCULATE
			UIInterface:UpdateUIMiningState(CLIENT_STATE_CALCULATE)
			--[[
			if ClientWorkModule:GetSvrAverageMiningSpeed() == 0 then
				ClientWorkModule:QueryClientInfo(0)
			end	
			--]]
			--tFunctionHelper.ReportMiningPoolInfoToServer()
		end
		if type(nParam) == "number" and nParam > 0 then
			--多乘了100
			nParam = nParam/100
			g_ClientOutputSpeed = nParam
			g_HashRateSum = g_HashRateSum + nParam
			g_HashRateSumCounter = g_HashRateSumCounter + 1
			UpdateSpeed(nParam)
			UIInterface:UpdateMiningSpeed(g_MiningSpeedPerHour)
			StartRealTimeIncomeTimer()
			--[[
			if g_LastGetSpeedTime == 0 then
				g_LastGetSpeedTime = tipUtil:GetCurrentUTCTime()
			else
				nSpanTime = tipUtil:GetCurrentUTCTime() - g_LastGetSpeedTime
				local nRealTimeIncome = GetRealTimeIncome(nParam, nSpanTime)
				g_LastGetSpeedTime = tipUtil:GetCurrentUTCTime()
				if nRealTimeIncome > 0 then
					tFunctionHelper.UpdateRealTimeIncome(nRealTimeIncome)
				end
			end
			--]]
		end
	elseif nMsgType == WP_XMR_SHARE then
		--KillVirtualDAG()
		g_LastClientOutputRightInfoTime = tipUtil:GetCurrentUTCTime()
		g_PreWorkState = CLIENT_STATE_CALCULATE
		if nParam == 0 then
			--WhenGetShare()
			--处理提交share
		end	
	elseif nMsgType == WP_XMR_CONNECT_POOL then
		if nParam == 0 then
			g_LastClientOutputRightInfoTime = tipUtil:GetCurrentUTCTime()
			g_ConnectFailCnt = 0
			if g_PreWorkState ~= CLIENT_STATE_CALCULATE then
				if not g_bNoPrepare then
					GenerateVirtualDAG()
				end	
				if ClientWorkModule:GetSvrAverageMiningSpeed() == 0 then
					ClientWorkModule:QueryClientInfo(0)
				end	
			end	
		else	
			g_ConnectFailCnt = g_ConnectFailCnt + 1
			if g_ConnectFailCnt > g_MaxConnectFailCnt then
				ReStartClientByNextPool()
			end
		end
	elseif nMsgType == WP_XMR_AUTOEXIT then
		g_PreWorkState = CLIENT_STATE_AUTO_EXIT
		local tStatInfo = {}
		tStatInfo.fu1 = "runerror"
		tStatInfo.fu5 = "autoexit"
		tStatInfo.fu6 = tostring(2)
		tStatInfo.fu7 = tostring(nParam)
		StatisticClient:SendClientErrorReport(tStatInfo)
		ReTryStartClient()
	elseif nMsgType == WP_XMR_ERROR_INFO then
		KillVirtualDAG()
		g_PreWorkState = CLIENT_STATE_EEEOR
		g_LastClientOutputTime = tipUtil:GetCurrentUTCTime()
		if nParam == 3 then
			--UIInterface:SetStateInfoToUser("请安装最新的显卡驱动")
		end
	end	
end

--[[
0 全速，1智能
--]]
function InitCmdLine()
	local nWorkModel = UIInterface:GetCurrentWorkModel()
	if nWorkModel == 0 then
		g_bFullSpeed = true
	else
		g_bFullSpeed = false
	end
end

function ChangeMiningSpeed()
	local nWorkModel = UIInterface:GetCurrentWorkModel()
	if nWorkModel == 0 then
		if not g_bFullSpeed then
			g_bFullSpeed = true
			Quit()
			Start()		
			g_bNoPrepare = true
		end	
	else
		if LimitSpeedCond() then
			if g_bFullSpeed then
				g_bFullSpeed = false
				Quit()
				Start()	
				g_bNoPrepare = true
			end	
		else
			if not g_bFullSpeed then
				g_bFullSpeed = true
				Quit()
				Start()
				g_bNoPrepare = true
			end
		end	
	end
end
--3分钟还没有纠错 就当已经不能挖矿了
function StartXmrTimer()
	if g_XmrWorkingTimerId then
		timeMgr:KillTimer(g_XmrWorkingTimerId)
		g_XmrWorkingTimerId = nil
	end
	g_LastClientOutputRightInfoTime = tipUtil:GetCurrentUTCTime()
	g_XmrWorkingTimerId = timeMgr:SetTimer(function(Itm, id)
		local nCurrentTime = tipUtil:GetCurrentUTCTime()
		if g_PreWorkState == CLIENT_STATE_EEEOR and  nCurrentTime - g_LastClientOutputRightInfoTime > 60 then
			TipLog("[StartXmrTimer] error occur and correct time out, try to restart")
			ReTryStartClient()
		elseif nCurrentTime - g_LastClientOutputRightInfoTime > 60*5 then
			TipLog("[StartXmrTimer] output time out, try to restart")
			ReTryStartClient()
		end
		
		ChangeMiningSpeed()
	end, 1000)
end

function ResetGlobalParam()
	g_PreWorkState = nil
	g_MiningSpeedPerHour = 0
	if g_XmrWorkingTimerId then
		timeMgr:KillTimer(g_XmrWorkingTimerId)
		g_XmrWorkingTimerId = nil
	end
	--g_LastGetSpeedTime = 0
	g_LastGetRealTimeIncomeTime = 0
	g_ClientOutputSpeed = 0
	if g_XmrRealTimeIncomeTimerId then
		timeMgr:KillTimer(g_XmrRealTimeIncomeTimerId)
		g_XmrRealTimeIncomeTimerId = nil
	end
	g_LastAverageHashRate = 0
	--进程范围内 只有更新余额的时候 才清0
	--g_LastRealTimeIncome = 0
	KillVirtualDAG()
	g_bNoPrepare = false
	SupportClientType:ClearCrashDebugFlag(CLIENT_GENOIL)
end

function ResetGlobalErrorParam()
	g_ConnectFailCnt = 0
	g_ClientReTryCnt = 0
	g_LastClientOutputErrorTime = 0
end

--外部调用函数
----------------
function InitClient(nPlatformId, nMiningType)
	g_nPlatformId = nPlatformId
	CLIENT_XMR_X = nMiningType
	IPCUtil:Init(CLIENT_XMR_X)
end
function Start()
	local strExeName = GetCurrentMiningCmdLine()
	if strExeName == nil then
		return 1
	end
	local strDir = tFunctionHelper.GetModuleDir()
	local strCmdLine = tipUtil:PathCombine(strDir, CLIENT_PATH .. tostring(strExeName))
	--控制台输出代理
	local strCoutAgent = tipUtil:PathCombine(strDir, COUTAGENT_PATH)
	strCmdLine =  "\"" .. strCoutAgent .. "\" " .. strCmdLine

	TipLog("[Start] strCmdLine = " .. GTV(strCmdLine))
	SupportClientType:SetCrashDebugFlag(CLIENT_XMR_X_REAL)
	IPCUtil:Start(strCmdLine)
	StartXmrTimer()
	return 0
end

function Quit()
	ResetGlobalParam()
	IPCUtil:Quit()
end

function Pause()
	ResetGlobalParam()
	IPCUtil:Pause()
end

function Resume()
	IPCUtil:Resume()
end

function ReStartClientByNewPoolList()
	Quit()
	g_strHost = nil
	g_strAccount = nil
	g_strPool = nil
	g_PoolIndex = 0
	Start()
end

function ReStartClientByNextPool()
	Quit()
	--连接下一个矿池
	GetNewMiningCmdInfo()
	if Start() ~= 0 then
		UIInterface:SetStateInfoToUser("获取赚宝任务失败,请稍后再试")
		ClientWorkModule:QuitMinerSuccess()
		return
	end
end

function ReTryStartClient()
	Quit()
	g_ClientReTryCnt = g_ClientReTryCnt + 1
	TipLog("[ReTryStartClient] g_ClientReTryCnt = " .. GTV(g_ClientReTryCnt))
	if g_ClientReTryCnt >= g_ClientMaxReTryCnt then
		UIInterface:SetStateInfoToUser("赚宝进程运行失败")
		ClientWorkModule:QuitMinerSuccess()
		return
	end
	if Start() ~= 0 then
		UIInterface:SetStateInfoToUser("获取赚宝任务失败,请稍后再试")
		ClientWorkModule:QuitMinerSuccess()
		return
	end
end

function GetAverageHashRate()
	local nAverageHashRate = 0
	if g_HashRateSumCounter > 0 then
		nAverageHashRate = g_HashRateSum/g_HashRateSumCounter
		g_HashRateSum = 0
		g_HashRateSumCounter = 0
	end	
	g_LastAverageHashRate = nAverageHashRate
	return nAverageHashRate
end

function GetCurrentClientWorkState()
	return g_PreWorkState
end

function GetCurrentMiningSpeed()
	return g_MiningSpeedPerHour
end

function GetCurrentAccount()
	return g_strAccount
end

function GetCurrentPool()
	return g_strPool
end

function GetPoolCfgName()
	return g_PoolCfgName
end

function GetDefaultPoolType()
	return g_DefaultPoolType
end

function GetSpeedFormat(nSpeed)
	local strSpeed = string.format("%0.2f",tostring(nSpeed))
	--strSpeed = strSpeed .. "H/s"
	return strSpeed
end

function OnUpdateBalance()
	if g_LastGetSpeedTime ~= 0 then
		g_LastGetSpeedTime = tipUtil:GetCurrentUTCTime()
		g_LastRealTimeIncome = 0
	end
end

function RegisterFunctionObject(self)
	local obj = {}
	obj.InitClient = InitClient
	obj.InitCmdLine = InitCmdLine
	obj.OnXmrMsg = OnXmrMsg
	obj.Start = Start
	obj.Quit = Quit
	obj.Pause = Pause
	obj.Resume = Resume
	obj.ReStartClientByNewPoolList = ReStartClientByNewPoolList
	obj.GetAverageHashRate = GetAverageHashRate
	obj.GetCurrentClientWorkState = GetCurrentClientWorkState
	obj.GetCurrentMiningSpeed = GetCurrentMiningSpeed
	obj.GetCurrentAccount = GetCurrentAccount
	obj.GetCurrentPool = GetCurrentPool
	obj.GetPoolCfgName = GetPoolCfgName
	obj.GetDefaultPoolType = GetDefaultPoolType
	obj.GetSpeedFormat = GetSpeedFormat
	obj.OnUpdateBalance = OnUpdateBalance
	XLSetGlobal("XmrClient", obj)
end
RegisterFunctionObject()