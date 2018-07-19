local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local g_tabClientInfo = {}
local g_nPoolIndex = 0

function IsRealString(str)
	return type(str) == "string" and str ~= ""
end

function TipLog(strLog)
	if type(tipUtil.Log) == "function" then
		tipUtil:Log("ZcNCfg: " .. tostring(strLog))
	end
end

function GTV(obj)
	return "[" .. type(obj) .. "`" .. tostring(obj) .. "]"
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
			if IsRealString(tabPoolItem["cmdlineformat_n"]) then
				strPoolParam = tabPoolItem["cmdlineformat_n"]
				local strAccount = tabPoolItem["account"]
				strPoolParam = string.gsub(strPoolParam,"(<account>)",strAccount)
				strPoolParam = string.gsub(strPoolParam,"(<workid>)",strWorkID)
			end
		end	
	end
	if strPoolParam == nil then
		g_nPoolIndex = 0
		return nil
	end
	g_tabClientInfo["strPoolParam"] = strPoolParam
	return strPoolParam
end

function GetClientParam()
	local strPoolParam = g_tabClientInfo["strPoolParam"]
	if strPoolParam == nil then
		g_nPoolIndex = g_nPoolIndex + 1
		strPoolParam = GetPoolParam(g_nPoolIndex)
	end
	if strPoolParam == nil then
		return
	end
	local strDir = tFunctionHelper.GetModuleDir()
	local strWorkExe = tipUtil:PathCombine(strDir, g_tabClientInfo["tabParam"]["strClientPath"])
    if not tipUtil:QueryFileExists(strWorkExe) then
        return
    end
	local strCmdLine = strWorkExe .. " " .. strPoolParam

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
	local strNewParam = nil
	if bMax then
		strNewParam = g_tabClientInfo["strMaxSpeedParam"]
	else
		strNewParam = g_tabClientInfo["strMinSpeedParam"]
	end
	if g_tabClientInfo["strSpeedControlCmd"] == strNewParam then
		return false
	end
	return true
end

function InitSpeed()
	local bMax = MainWorkModule:GetCurrentSpeedWork()
	if bMax then
		g_tabClientInfo["strSpeedControlCmd"] = g_tabClientInfo["strMaxSpeedParam"]
	else
		g_tabClientInfo["strSpeedControlCmd"] = g_tabClientInfo["strMinSpeedParam"]
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
	g_tabClientInfo["strPoolParam"] = nil
end

function ResetPool()
	g_nPoolIndex = 0
	ResetPoolParam()
end

function InitClient(nPlatformId)
	g_tabClientInfo = {}
	g_tabClientInfo["tabParam"] = {
		["strCoinType"] = "cb",
		["strPoolVerKey"] = "p",
		["strDefaultPoolType"] = "x_cb",
		["strPoolFileName"] = "bpcfg.json",
		["strClientPath"] = "Share4Peer\\Share4PeerZN.exe",
		["nMaxConnectFailCnt"] = 7,
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
	g_tabClientInfo["strMinSpeedParam"] = "--intensity 1"
	g_tabClientInfo["strMaxSpeedParam"] = "--intensity 1"
	g_tabClientInfo["strPoolParam"] = nil
	g_tabClientInfo["nPlatformId"] = nPlatformId or 0
	g_tabClientInfo["strSpeedControlCmd"] = nil
	g_nPoolIndex = 0
	return g_tabClientInfo
end

function RegisterFunctionObject(self)
	local obj = {}
	obj.InitClient = InitClient
	XLSetGlobal("ZcashNClient", obj)
end
RegisterFunctionObject()
