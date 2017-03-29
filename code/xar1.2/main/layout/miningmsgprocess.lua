local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")

local g_ConnectFailCnt = 0
local g_MaxConnectFailCnt = 7
local g_MiningThreads = 1
local g_tabDeviceDagState = {}
local g_PoolIndex = 0

local g_strCmdLineFormat = nil
local g_strWallet = nil
local g_strPool = nil

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
		tipUtil:Log("@@File=miningmsgprocess: " .. tostring(strLog))
	end
end

function GTV(obj)
	return "[" .. type(obj) .. "`" .. tostring(obj) .. "]"
end

function OnMiningCount(tParam)
	local nMiningThreads = tParam[1]
	if type(nMiningThreads) == "number" then
		g_MiningThreads = nMiningThreads
		TipLog("[OnMiningCount] g_MiningThreads = " .. tostring(g_MiningThreads))
	end	
end

function OnConnectFail(tParam)
	local nConnectFail = tParam[1]
	if type(nConnectFail) == "number" then
		g_ConnectFailCnt = nConnectFail
		TipLog("[OnConnectFail] g_ConnectFailCnt = " .. tostring(g_ConnectFailCnt))
	end	
end

--1: 成功，0：失败
function OnInitDagRet(tParam)
	local nDeviceIndex, nInitState = tParam[1],tParam[2]
	TipLog("[OnInitDagRet] nDeviceIndex = " .. GTV(nDeviceIndex) .. ", nInitState = " .. GTV(nInitState))
	if type(nDeviceIndex) == "number" and type(nInitState) == "number" then
		g_tabDeviceDagState[tostring(nDeviceIndex)] = nInitState
	end	
end

function CheckIsConnectPoolFail()
	if g_ConnectFailCnt >= g_MaxConnectFailCnt then
		return true
	end
	return false
end

function CheckIsAllDeviceInitDagFail()
	if type(g_tabDeviceDagState) ~= "table" then
		g_tabDeviceDagState = {}
	end
	local nCnt = 0
	for index, state in pairs(g_tabDeviceDagState) do
		if state == 1 then
			return false
		end
		nCnt = nCnt + 1
	end
	TipLog("[CheckIsAllDeviceInitDagFail] nCnt = " .. tostring(nCnt))
	if nCnt < g_MiningThreads then
		return false
	end
	return true
end

function GetNewMiningCmdInfo()
	local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
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
					local strCmdLineFormat = tabPoolItem["strCmdLineFormat"]
					strCmdLineFormat = string.gsub(strCmdLineFormat,"(<wallet>)",tabPoolItem["strWallet"])
					strCmdLineFormat = string.gsub(strCmdLineFormat,"(<workid>)",strWorkID)
					if IsRealString(strCmdLineFormat) then
						g_strCmdLineFormat = strCmdLineFormat
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

function GetCurrentWallet()
	return g_strWallet
end

function GetCurrentPool()
	return g_strPool
end

function GetCurrentMiningCmdLine()
	if g_strCmdLineFormat == nil then
		return GetNewMiningCmdInfo()
	end
	return g_strCmdLineFormat
end

function ResetGlobalParam()
	g_ConnectFailCnt = 0
	g_MiningThreads = 1
	g_tabDeviceDagState = {}
	--g_strCmdLineFormat = nil
	--g_strWallet = nil
	--g_strPool = nil
end

function RegisterFunctionObject(self)
	local obj = {}
	obj.OnMiningCount = OnMiningCount
	obj.OnConnectFail = OnConnectFail
	obj.OnInitDagRet = OnInitDagRet
	obj.CheckIsConnectPoolFail = CheckIsConnectPoolFail
	obj.CheckIsAllDeviceInitDagFail = CheckIsAllDeviceInitDagFail
	obj.CheckIsAllDeviceInitDagFail = CheckIsAllDeviceInitDagFail
	obj.GetNewMiningCmdInfo = GetNewMiningCmdInfo
	obj.GetCurrentWallet = GetCurrentWallet
	obj.GetCurrentPool = GetCurrentPool
	obj.GetCurrentMiningCmdLine = GetCurrentMiningCmdLine
	obj.ResetGlobalParam = ResetGlobalParam
	XLSetGlobal("Global.MiningMsgProc", obj)
end
RegisterFunctionObject()