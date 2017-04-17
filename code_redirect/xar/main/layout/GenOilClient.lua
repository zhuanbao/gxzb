local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
local IPCUtil = XLGetObject("IPC.Util")

--常量
local CLIENT_GENOIL = 1
local CLIENT_PATH = "ShareGenOil\\ShareGenOil.exe"
--上报速度
local WP_GENOIL_SPEED = 1
--上报DAG进度
local WP_GENOIL_DAG	= 2
--share提交结果
local WP_GENOIL_SHARE = 3
--连接矿次结果
local WP_GENOIL_CONNECT_POOL = 4
--错误
--进程自动退出
local WP_GENOIL_AUTOEXIT = 5
--解析到错误信息
local WP_GENOIL_ERROR_INFO = 6
--特定的Opencl错误
local WP_GENOIL_ERROR_OPENCL = 7

--客户端状态
local CLIENT_STATE_CALCULATE = 0
local CLIENT_STATE_PREPARE = 1
local CLIENT_STATE_EEEOR = 2
local CLIENT_STATE_AUTO_EXIT = 3

--全局参数
local g_PreWorkState = nil
local g_HashRateSum = 0 --累加速度，一分钟上报一次时，取这一分钟的平均速度
local g_HashRateSumCounter = 0 --速度累加的计数器
local g_PerSpeed = 10 --服务端返回的平均速度((元宝/Hour)/M)
local g_MiningSpeedPerHour = 0 --根据矿工当前速度计算的挖矿平均速度(元宝/Hour)

local g_GlobalWorkSizeMultiplier_Min = 100
local g_GlobalWorkSizeMultiplier_Max = 4096
local g_GlobalWorkSizeMultiplier_Cur = g_GlobalWorkSizeMultiplier_Max

local g_ConnectFailCnt = 0
local g_MaxConnectFailCnt = 7

local g_strCmdLineFormat = nil
local g_strWallet = nil
local g_strPool = nil
local g_PoolIndex = 0

local g_GenOilWorkingTimerId = nil 
local g_ClientReTryCnt = 0 
local g_ClientMaxReTryCnt = 3 
local g_LastClientOutputRightInfoTime = 0
local g_ControlSpeedCmdLine = nil -- --cl-global-work 1000
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
		tipUtil:Log("@@File=GenOilClient: " .. tostring(strLog))
	end
end

function GTV(obj)
	return "[" .. type(obj) .. "`" .. tostring(obj) .. "]"
end

function LimitSpeedCond()
	if tipUtil:IsNowFullScreen() then
		TipLog("[LimitSpeedCond] full screen")
		return true
	end
	local hr, dwTime = tipUtil:GetLastInputInfo()
	local dwTickCount = tipUtil:GetTickCount()
	if hr == 0 and type(dwTime) == "number" and type(dwTickCount) == "number" and dwTickCount - dwTime < 5*60*1000 then
		TipLog("[LimitSpeedCond] Last input in 60 second")
		return true
	end
	return false
end

function GetNewMiningCmdInfo()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	local strWorkID = tUserConfig["tUserInfo"]["strWorkID"]
	g_strCmdLineFormat = nil
	g_strWallet = nil
	g_strPool = nil
	local tTaskInfo = g_ServerConfig["tTaskInfo"]
	for i=1,#tTaskInfo do
		local tabTaskItem = tTaskInfo[i]
		if type(tabTaskItem) == "table" and tFunctionHelper.CheckPeerIDList(tabTaskItem["tPIDlist"]) then
			local tabPoolInfo = tabTaskItem["tPool"]
			if type(tabPoolInfo) ~= "table" then
				tabPoolInfo = {}
			end
			g_PoolIndex = g_PoolIndex + 1
			TipLog("[GetNewMiningCmdInfo] g_PoolIndex = " .. tostring(g_PoolIndex))
			if g_PoolIndex <= #tabPoolInfo then
				tabPoolItem = tabPoolInfo[g_PoolIndex]
				if type(tabPoolItem) == "table" then
					--local strCmdLineFormat = tabPoolItem["strCmdLineFormat"]
					--strCmdLineFormat = string.gsub(strCmdLineFormat,"(<wallet>)",tabPoolItem["strWallet"])
					--strCmdLineFormat = string.gsub(strCmdLineFormat,"(<workid>)",strWorkID)
					--这里只是判断下 能不能正常匹配
					if IsRealString(tabPoolItem["strCmdLineFormat"]) then
						g_strCmdLineFormat = tabPoolItem["strCmdLineFormat"]
						g_strWallet = tabPoolItem["strWallet"]
						g_strPool = tabPoolItem["strPool"]
						break
					end
				end	
			end	
		end
	end
	if g_strCmdLineFormat == nil then
		g_PoolIndex = 0
	end
	return g_strCmdLineFormat
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
	if g_strCmdLineFormat == nil then
		GetNewMiningCmdInfo()
	end
	if g_strCmdLineFormat == nil then
		return nil
	end
	local strCmdLine = g_strCmdLineFormat
	strCmdLine = string.gsub(strCmdLine,"(<wallet>)",g_strWallet)
	strCmdLine = string.gsub(strCmdLine,"(<workid>)",strWorkID)
	return strCmdLine
end

function UpdateSpeed(nHashRate)
	 g_MiningSpeedPerHour = math.floor(nHashRate * tFunctionHelper.GetSvrAverageMiningSpeed())
end

function OnGenOilMsg(tParam)
	local nMsgType, nParam = tParam[1],tParam[2]
	TipLog("[OnGenOilMsg] nMsgType = " .. GTV(nMsgType) .. ", nParam = " .. GTV(nParam))
	if nMsgType == WP_GENOIL_SPEED then
		g_LastClientOutputRightInfoTime = tipUtil:GetCurrentUTCTime()
		if g_PreWorkState ~= CLIENT_STATE_CALCULATE then
			ResetGlobalErrorParam()
			g_PreWorkState = CLIENT_STATE_CALCULATE
			tFunctionHelper.UpdateMiningState(CLIENT_STATE_CALCULATE)
			tFunctionHelper.ReportMiningPoolInfoToServer()
		end
		if type(nParam) == "number" and nParam > 0 then
			--多乘了100
			nParam = nParam/100
			g_HashRateSum = g_HashRateSum + nParam
			g_HashRateSumCounter = g_HashRateSumCounter + 1
			UpdateSpeed(nParam)
			tFunctionHelper.UpdateMiningSpeed(g_MiningSpeedPerHour)
		end
	elseif nMsgType == WP_GENOIL_DAG then
		g_LastClientOutputRightInfoTime = tipUtil:GetCurrentUTCTime()
		if g_PreWorkState ~= CLIENT_STATE_PREPARE then
			g_PreWorkState = CLIENT_STATE_PREPARE
			tFunctionHelper.UpdateMiningState(CLIENT_STATE_PREPARE)
		end
		if tonumber(nParam) ~= nil then
			tFunctionHelper.UpdateDagProgress(nParam)
		end
	elseif nMsgType == WP_GENOIL_SHARE then
		g_LastClientOutputRightInfoTime = tipUtil:GetCurrentUTCTime()
		g_PreWorkState = CLIENT_STATE_CALCULATE
		--处理提交share
	elseif nMsgType == WP_GENOIL_CONNECT_POOL then
		if nParam == 0 then
			g_LastClientOutputRightInfoTime = tipUtil:GetCurrentUTCTime()
			g_ConnectFailCnt = 0
		else	
			g_ConnectFailCnt = g_ConnectFailCnt + 1
			if g_ConnectFailCnt > g_MaxConnectFailCnt then
				ReStartClientByNewPool()
			end
		end
	elseif nMsgType == WP_GENOIL_AUTOEXIT then
		g_PreWorkState = CLIENT_STATE_AUTO_EXIT
		ReStartClient()
	elseif nMsgType == WP_GENOIL_ERROR_INFO then
		g_PreWorkState = CLIENT_STATE_EEEOR
		g_LastClientOutputTime = tipUtil:GetCurrentUTCTime()
	elseif nMsgType == WP_GENOIL_ERROR_OPENCL then
		g_PreWorkState = CLIENT_STATE_EEEOR
		g_LastClientOutputTime = tipUtil:GetCurrentUTCTime()
	end	
end

--[[
0 全速，1智能
--]]
function SetControlSpeedCmdLine(nGlobalWorkSizeMultiplier)
	if nGlobalWorkSizeMultiplier ~= nil then
		g_ControlSpeedCmdLine = "--cl-global-work " .. tostring(nGlobalWorkSizeMultiplier)
	else
		g_ControlSpeedCmdLine = nil
	end
end

function ChangeMiningSpeed()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local nWorkModel = tFunctionHelper.FetchValueByPath(tUserConfig, {"tConfig", "WorkModel", "nState"})
	if nWorkModel == 0 then
		if g_GlobalWorkSizeMultiplier_Cur ~= g_GlobalWorkSizeMultiplier_Max then
			g_GlobalWorkSizeMultiplier_Cur = g_GlobalWorkSizeMultiplier_Max
			SetControlSpeedCmdLine(nil)
			Quit()
			Start()			
		end	
	else
		if LimitSpeedCond() then
			if g_GlobalWorkSizeMultiplier_Cur ~= g_GlobalWorkSizeMultiplier_Min then
				g_GlobalWorkSizeMultiplier_Cur = g_GlobalWorkSizeMultiplier_Min
				SetControlSpeedCmdLine(g_GlobalWorkSizeMultiplier_Min)
				Quit()
				Start()	
			end	
		else
			if g_GlobalWorkSizeMultiplier_Cur ~= g_GlobalWorkSizeMultiplier_Max then
				g_GlobalWorkSizeMultiplier_Cur = g_GlobalWorkSizeMultiplier_Max
				SetControlSpeedCmdLine(nil)
				Quit()
				Start()
			end
		end	
	end
end
--3分钟还没有纠错 就当已经不能挖矿了
function StartGenOilTimer()
	if g_GenOilWorkingTimerId then
		timeMgr:KillTimer(g_GenOilWorkingTimerId)
		g_GenOilWorkingTimerId = nil
	end
	g_LastClientOutputRightInfoTime = tipUtil:GetCurrentUTCTime()
	g_GenOilWorkingTimerId = timeMgr:SetTimer(function(Itm, id)
		local nCurrentTime = tipUtil:GetCurrentUTCTime()
		if g_PreWorkState == CLIENT_STATE_EEEOR and  nCurrentTime - g_LastClientOutputRightInfoTime > 30 then
			ReTryStartClient()
		elseif nCurrentTime - g_LastClientOutputRightInfoTime > 60*3 then
			ReTryStartClient()
		end
		ChangeMiningSpeed()
	end, 1000)
end

function ResetGlobalParam()
	g_PreWorkState = nil
	g_MiningSpeedPerHour = 0
	if g_GenOilWorkingTimerId then
		timeMgr:KillTimer(g_GenOilWorkingTimerId)
		g_GenOilWorkingTimerId = nil
	end
end

function ResetGlobalErrorParam()
	g_ConnectFailCnt = 0
	g_ClientReTryCnt = 0
	if g_GenOilWorkingTimerId then
		timeMgr:KillTimer(g_GenOilWorkingTimerId)
		g_GenOilWorkingTimerId = nil
	end
	g_LastClientOutputErrorTime = 0
end

--外部调用函数
----------------
function InitClient()
	IPCUtil:Init(CLIENT_GENOIL)
end
function Start()
	local strPoolCmd = GetCurrentMiningCmdLine()
	if strPoolCmd == nil then
		return 1
	end
	local strDir = tFunctionHelper.GetModuleDir()
	local strWorkExe = tipUtil:PathCombine(strDir, CLIENT_PATH)
	local strCmdLine = strWorkExe .. " " .. strPoolCmd
	
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local strUserCmd =tUserConfig["strUserCmd"]
	if IsRealString(strUserCmd) then
		strCmdLine = strCmdLine .. " " .. strUserCmd
	end
	if IsRealString(g_ControlSpeedCmdLine) then
		strCmdLine = strCmdLine .. " " .. g_ControlSpeedCmdLine
	end
	IPCUtil:Start(strCmdLine)
	StartGenOilTimer()
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

function ReStartClientByNewPool()
	Quit()
	--连接下一个矿池
	GetNewMiningCmdInfo()
	if Start() ~= 0 then
		tFunctionHelper.SetStateInfoToUser("获取赚宝任务失败,请稍后再试")
		tFunctionHelper.HandleOnQuit()
		return
	end
end

function ReTryStartClient()
	Quit()
	g_ClientReTryCnt = g_ClientReTryCnt + 1
	TipLog("[ReTryStartClient] g_ClientReTryCnt = " .. GTV(g_ClientReTryCnt))
	if g_ClientReTryCnt >= g_ClientMaxReTryCnt then
		tFunctionHelper.SetStateInfoToUser("赚宝进程运行失败")
		tFunctionHelper.HandleOnQuit()
		return
	end
	if Start() ~= 0 then
		tFunctionHelper.SetStateInfoToUser("获取赚宝任务失败,请稍后再试")
		tFunctionHelper.HandleOnQuit()
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
	return nAverageHashRate
end

function GetCurrentClientWorkState()
	return g_PreWorkState
end

function GetCurrentMiningSpeed()
	return g_MiningSpeedPerHour
end

function GetCurrentWallet()
	return g_strWallet
end

function GetCurrentPool()
	return g_strPool
end

function RegisterFunctionObject(self)
	local obj = {}
	obj.InitClient = InitClient
	obj.OnGenOilMsg = OnGenOilMsg
	obj.Start = Start
	obj.Quit = Quit
	obj.Pause = Pause
	obj.Resume = Resume
	obj.ReStartClientByNewPool = ReStartClientByNewPool
	obj.ReStartClient = ReStartClient
	obj.GetAverageHashRate = GetAverageHashRate
	obj.GetCurrentClientWorkState = GetCurrentClientWorkState
	obj.GetCurrentMiningSpeed = GetCurrentMiningSpeed
	obj.GetCurrentWallet = GetCurrentWallet
	obj.GetCurrentPool = GetCurrentPool
	XLSetGlobal("Global.GenOilClient", obj)
end
RegisterFunctionObject()