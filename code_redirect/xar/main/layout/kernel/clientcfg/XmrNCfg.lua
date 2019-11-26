local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local g_tabClientInfo = {}
local g_nPoolIndex = 0

function IsRealString(str)
	return type(str) == "string" and str ~= ""
end

function TipLog(strLog)
	if type(tipUtil.Log) == "function" then
		tipUtil:Log("XmNCfg: " .. tostring(strLog))
	end
end

function GTV(obj)
	return "[" .. type(obj) .. "`" .. tostring(obj) .. "]"
end

function GetCfgTable(strWorkID)
	local tabCfg = {}
	--tabCfg["algo"] = "cryptonight"
	tabCfg["cpu"] = false
	tabCfg["opencl"] = false
	tabCfg["cuda"] = true
	tabCfg["print-time"] = 10
	tabCfg["retries"] = 5
	tabCfg["retry-pause"] = 5
	--tabCfg["bfactor"] = "12"
	--tabCfg["max-gpu-threads"] = 0
	--tabCfg["max-gpu-usage"] = g_tabClientInfo["tabSpeedControlParam"]["nGpuUsage"]
	--tabCfg["bsleep"] = tostring(g_tabClientInfo["tabSpeedControlParam"]["strSleepTime"])
	tabCfg["pools"] = {}
	tabCfg["pools"][1] = {}
	tabCfg["pools"][1]["coin"] = "monero"
	tabCfg["pools"][1]["url"] = g_tabClientInfo["tabPoolParam"]["url"]
	tabCfg["pools"][1]["user"] = g_tabClientInfo["tabPoolParam"]["user"]
	tabCfg["pools"][1]["pass"] = g_tabClientInfo["tabPoolParam"]["pass"]
	if IsRealString(g_tabClientInfo["tabPoolParam"]["rig-id"]) then
		tabCfg["pools"][1]["rig-id"] = g_tabClientInfo["tabPoolParam"]["rig-id"]
	end
	tabCfg["pools"][1]["keepalive"] = true
	tabCfg["pools"][1]["nicehash"] = false
	if g_tabClientInfo["tabPoolParam"]["tls"] then
		tabCfg["pools"][1]["tls"] = true
	end
	
	--tabCfg["pools"][1]["variant"] = -1
	return tabCfg
end

function WriteCfgByName()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local strWorkID = tUserConfig["tUserInfo"]["strWorkID"]
	local tabCfg = GetCfgTable(strWorkID)
	local strFolder = tFunctionHelper.GetCfgPathWithName("ShareX")
	if not tipUtil:QueryFileExists(strFolder) then
		tipUtil:CreateDir(strFolder)
	end
	local strCfgPath = tipUtil:PathCombine(strFolder, g_tabClientInfo["strCfgName"])
	local strJson = tFunctionHelper.EnCodeJson(tabCfg)
	if tipUtil:QueryFileExists(strCfgPath) then
		tipUtil:DeletePathFile(strCfgPath)
	end
	tipUtil:WriteStringToFile(strCfgPath, strJson)
	return strCfgPath
end

function GetPoolParam(nPoolIndex)		
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	local strWorkID = tUserConfig["tUserInfo"]["strWorkID"]
	if not IsRealString(strWorkID) then
		return nil
	end
	local strPoolParam = nil
	local strPoolKey = g_tabClientInfo["tabParam"]["strPoolFileName"]
	local tPoolList = tUserConfig["tSvrPoolInfo"][strPoolKey]
	if nPoolIndex <= #tPoolList then
		local tabPoolItem = tPoolList[nPoolIndex]
		if type(tabPoolItem) == "table" then
			if IsRealString(tabPoolItem["host"]) then
				g_tabClientInfo["tabPoolParam"] = {}
				
				local strAccount = tabPoolItem["account"]
				g_tabClientInfo["tabPoolParam"]["url"] = tabPoolItem["host"]
				local strUser = tabPoolItem["user"]
				strUser = string.gsub(strUser,"(<account>)",strAccount)
				strUser = string.gsub(strUser,"(<workid>)",strWorkID)
				g_tabClientInfo["tabPoolParam"]["user"] = strUser
				
				local strPass = tabPoolItem["pass"]
				strPass = string.gsub(strPass,"(<workid>)",strWorkID)
				
				local strRigId = tabPoolItem["rig-id"]
				if IsRealString(strRigId) then
					strRigId = string.gsub(strRigId,"(<workid>)",strWorkID)
				end
				g_tabClientInfo["tabPoolParam"]["user"] = strUser
				g_tabClientInfo["tabPoolParam"]["pass"] = strPass
				g_tabClientInfo["tabPoolParam"]["rig-id"] = strRigId
				g_tabClientInfo["tabPoolParam"]["tls"] = tabPoolItem["tls"]
			end
		end	
	end
	if g_tabClientInfo["tabPoolParam"] == nil then
		g_nPoolIndex = 0
		return nil
	end
	return g_tabClientInfo["tabPoolParam"]
end

function GetClientParam()
	local tabPoolParam = g_tabClientInfo["tabPoolParam"]
	if tabPoolParam == nil then
		g_nPoolIndex = g_nPoolIndex + 1
		tabPoolParam = GetPoolParam(g_nPoolIndex)
	end
	if tabPoolParam == nil then
		return
	end
	local strCfgPath = WriteCfgByName()
	local strDir = tFunctionHelper.GetModuleDir()
	local strWorkExe = tipUtil:PathCombine(strDir, g_tabClientInfo["tabParam"]["strClientPath"])
    if not tipUtil:QueryFileExists(strWorkExe) then
        return
    end
	local strCmdLine = strWorkExe .. " -c " .. '"' .. strCfgPath .. '"'
	--控制台输出代理
	local strCoutAgent = tipUtil:PathCombine(strDir, "ShareCout.exe")
	strCmdLine =  "\"" .. strCoutAgent .. "\" " .. strCmdLine
	
	if IsRealString(g_tabClientInfo["strSpeedControlCmd"]) then
		strCmdLine = strCmdLine .. " " .. g_tabClientInfo["strSpeedControlCmd"]
	end
	TipLog("[GetClientParam] strCmdLine = " .. GTV(strCmdLine))
	return strCmdLine
end

function ChangeSpeed(bMax)
	local tabNewParam = nil
	if bMax then
		tabNewParam = g_tabClientInfo["tabMaxParam"]
	else
		tabNewParam = g_tabClientInfo["tabMinParam"]
	end
	if type(g_tabClientInfo["tabSpeedControlParam"]) == "table"
		and tabNewParam["nGpuUsage"] == g_tabClientInfo["tabSpeedControlParam"]["nGpuUsage"] then
		return false
	end
	return true
end

function InitSpeed()
	local bMax = MainWorkModule:GetCurrentSpeedWork()
	if bMax then
		g_tabClientInfo["tabSpeedControlParam"] = g_tabClientInfo["tabMaxParam"]
	else
		g_tabClientInfo["tabSpeedControlParam"] = g_tabClientInfo["tabMinParam"]
	end
end

function CheckFile()
	local strDir = tFunctionHelper.GetModuleDir()
	local strWorkExe = tipUtil:PathCombine(strDir, g_tabClientInfo["tabParam"]["strClientPath"])
    if not tipUtil:QueryFileExists(strWorkExe) then
        return false
    end
	return true
end

function GetSpeedFormat(nSpeed)
	--必须要
end

function ResetPoolParam()
	g_tabClientInfo["tabPoolParam"] = nil
end

function ResetPool()
	g_nPoolIndex = 0
	ResetPoolParam()
end

function InitClient(nPlatformId)
	g_tabClientInfo = {}
	g_tabClientInfo["tabParam"] = {
		["strCoinType"] = "cc",
		["strPoolVerKey"] = "pv4",
		["strDefaultPoolType"] = "x_cc",
		["strPoolFileName"] = "cpcfg.json",
		["strClientPath"] = "Share4Peer\\Share4PeerXN64.exe",
		["nSpeedMultiplier"] = 100,
	}
	g_tabClientInfo["tabFun"] = {
		["funGetClientParam"] = GetClientParam,
		["funChangeSpeed"] = ChangeSpeed,
		["funResetPoolParam"] = ResetPoolParam,
		["funInitSpeed"] = InitSpeed,
		["funCheckFile"] = CheckFile,
		["funResetPool"] = ResetPool,
	}
	g_tabClientInfo["tabMinParam"] = {
		["nGpuUsage"] = 45,
		["strSleepTime"] = "98",
	}
	g_tabClientInfo["tabMaxParam"] = {
		["nGpuUsage"] = 45,
		["strSleepTime"] = "80",
	}
	g_tabClientInfo["tabPoolParam"] = nil
	g_tabClientInfo["nPlatformId"] = nPlatformId or 0
	g_tabClientInfo["tabSpeedControlParam"] = nil
	g_tabClientInfo["strCfgName"] = "configxn.json"
	g_nPoolIndex = 0
	return g_tabClientInfo
end

function RegisterFunctionObject(self)
	local obj = {}
	obj.InitClient = InitClient
	XLSetGlobal("XmrNClient", obj)
end
RegisterFunctionObject()
