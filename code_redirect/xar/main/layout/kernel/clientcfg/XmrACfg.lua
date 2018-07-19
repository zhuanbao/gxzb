local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local g_tabClientInfo = {}
local g_nPoolIndex = 0

function IsRealString(str)
	return type(str) == "string" and str ~= ""
end

function TipLog(strLog)
	if type(tipUtil.Log) == "function" then
		tipUtil:Log("XmACfg: " .. tostring(strLog))
	end
end

function GTV(obj)
	return "[" .. type(obj) .. "`" .. tostring(obj) .. "]"
end

function GetCfgTable(strWorkID)
	local tabCfg = {}
	tabCfg["algo"] = "cryptonight"
	tabCfg["print-time"] = 10
	tabCfg["retries"] = 5
	tabCfg["retry-pause"] = 5
	tabCfg["opencl-platform"] = g_tabClientInfo["nPlatformId"]
	tabCfg["threads"] = nil
	tabCfg["pools"] = {}
	tabCfg["pools"][1] = {}
	tabCfg["pools"][1]["url"] = g_tabClientInfo["tabPoolParam"]["host"]
	tabCfg["pools"][1]["user"] = g_tabClientInfo["tabPoolParam"]["account"]
	tabCfg["pools"][1]["pass"] = strWorkID
	tabCfg["pools"][1]["keepalive"] = true
	tabCfg["pools"][1]["nicehash"] = true
	tabCfg["pools"][1]["variant"] = -1
	tabCfg["sharehelper"] = {}
	tabCfg["sharehelper"]["intensity"] = 512
	tabCfg["sharehelper"]["worksize"] = 8
	tabCfg["sharehelper"]["sleep"] = 500
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
				g_tabClientInfo["tabPoolParam"]["host"] = tabPoolItem["host"]
				g_tabClientInfo["tabPoolParam"]["account"] = tabPoolItem["account"]
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
	if g_tabClientInfo["tabSpeedControlParam"]["bRun"] then
		return
	end
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
	if bMax then
		tabNewParam = g_tabClientInfo["tabMaxParam"]
	else
		tabNewParam = g_tabClientInfo["tabMinParam"]
	end
	if tabNewParam["bRun"] == g_tabClientInfo["tabSpeedControlParam"]["bRun"] then
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

function InitClient(nPlatformId, nClient)
	
	g_tabClientInfo = {}
	g_tabClientInfo["tabParam"] = {
		["strCoinType"] = "cc",
		["strPoolVerKey"] = "pv2",
		["strDefaultPoolType"] = "x_cc",
		["strPoolFileName"] = "cpcfg.json",
		--["strClientPath"] = "Share4Peer\\Share4PeerXN64.exe",
		["nSpeedMultiplier"] = 100,
	}
	if nClient == 5 then
		g_tabClientInfo["tabParam"]["strClientPath"] = "Share4Peer\\Share4PeerXA64.exe"
	else
		g_tabClientInfo["tabParam"]["strClientPath"] = "Share4Peer\\Share4PeerXA.exe"
	end
	g_tabClientInfo["tabFun"] = {
		["funGetClientParam"] = GetClientParam,
		["funChangeSpeed"] = ChangeSpeed,
		["funResetPoolParam"] = ResetPoolParam,
		["funInitSpeed"] = InitSpeed,
		["funCheckFile"] = CheckFile,
		["funResetPool"] = ResetPool,
	}
	g_tabClientInfo["tabMinParam"] = {
		["bRun"] = false,
	}
	g_tabClientInfo["tabMaxParam"] = {
		["bRun"] = true,
	}
	g_tabClientInfo["tabPoolParam"] = nil
	g_tabClientInfo["nPlatformId"] = nPlatformId or 0
	g_tabClientInfo["tabSpeedControlParam"] = nil
	g_tabClientInfo["strCfgName"] = "configxa.json"
	g_nPoolIndex = 0
	return g_tabClientInfo
end

function RegisterFunctionObject(self)
	local obj = {}
	obj.InitClient = InitClient
	XLSetGlobal("XmrAClient", obj)
end
RegisterFunctionObject()
