local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local g_tabClientInfo = {}
local g_nPoolIndex = 0

function IsRealString(str)
	return type(str) == "string" and str ~= ""
end

function TipLog(strLog)
	if type(tipUtil.Log) == "function" then
		tipUtil:Log("XmCCfg: " .. tostring(strLog))
	end
end

function GTV(obj)
	return "[" .. type(obj) .. "`" .. tostring(obj) .. "]"
end

function GetCfgTable(strWorkID)
	local tabCfg = {}
	tabCfg["algo"] = "cryptonight"
	tabCfg["cpu-affinity"] = nil
	tabCfg["cpu-priority"] = nil
	tabCfg["max-cpu-usage"] =  g_tabClientInfo["tabSpeedControlParam"]["nCpuUsage"]
	tabCfg["print-time"] = 10
	tabCfg["retries"] = 5
	tabCfg["retry-pause"] = 5
	tabCfg["pools"] = {}
	tabCfg["pools"][1] = {}
	tabCfg["pools"][1]["url"] = g_tabClientInfo["tabPoolParam"]["url"]
	tabCfg["pools"][1]["user"] = g_tabClientInfo["tabPoolParam"]["user"]
	tabCfg["pools"][1]["pass"] = g_tabClientInfo["tabPoolParam"]["pass"]
	tabCfg["pools"][1]["keepalive"] = true
	tabCfg["pools"][1]["nicehash"] = true
	tabCfg["pools"][1]["variant"] = -1
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
				
				g_tabClientInfo["tabPoolParam"]["user"] = strUser
				g_tabClientInfo["tabPoolParam"]["pass"] = strPass

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
	WriteCfgByName()
	local strDir = tFunctionHelper.GetModuleDir()
	local strWorkExe = tipUtil:PathCombine(strDir, g_tabClientInfo["tabParam"]["strClientPath"])
    if not tipUtil:QueryFileExists(strWorkExe) then
        return
    end
	local strCmdLine = strWorkExe
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
	if bMax and MainWorkModule:ShouldCpuMaxSpeedWork() then
		tabNewParam = g_tabClientInfo["tabMaxParam"]
	else
		tabNewParam = g_tabClientInfo["tabMinParam"]
	end
	if type(g_tabClientInfo["tabSpeedControlParam"]) == "table"
		and tabNewParam["nCpuUsage"] == g_tabClientInfo["tabSpeedControlParam"]["nCpuUsage"] then
		return false
	end
	return true
end

function InitSpeed()
	local bMax = MainWorkModule:GetCurrentSpeedWork()
	if bMax and MainWorkModule:ShouldCpuMaxSpeedWork() then
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
		["strClientPath"] = "Share4Peer\\Share4PeerXC.exe",
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
		["nCpuUsage"] = 50,
	}
	g_tabClientInfo["tabMaxParam"] = {
		["nCpuUsage"] = 75,
	}
	g_tabClientInfo["tabPoolParam"] = nil
	g_tabClientInfo["nPlatformId"] = nPlatformId or 0
	g_tabClientInfo["tabSpeedControlParam"] = nil
	g_tabClientInfo["strCfgName"] = "configxc.json"
	g_nPoolIndex = 0
	return g_tabClientInfo
end

function RegisterFunctionObject(self)
	local obj = {}
	obj.InitClient = InitClient
	XLSetGlobal("XmrCClient", obj)
end
RegisterFunctionObject()
