local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local IPCUtil = XLGetObject("IPC.Util")
local tFunctionHelper = XLGetGlobal("FunctionHelper")

ObjectBase = XLGetGlobal("ObjectBase")
XmrHelper = ObjectBase:New()
XLSetGlobal("XmrHelper", XmrHelper)

XmrHelper._strCpuCfgName = "configxc.json"
XmrHelper._strGpuACfgName = "configxa.json"
XmrHelper._strGpuNCfgName = "configxn.json"

function IsRealString(str)
	return type(str) == "string" and str ~= ""
end

function XmrHelper:WriteCfgByName(tabCfg,strFileName)
	local strFolder = tFunctionHelper.GetCfgPathWithName("ShareX")
	if not tipUtil:QueryFileExists(strFolder) then
		tipUtil:CreateDir(strFolder)
	end
	local strCfgPath = tipUtil:PathCombine(strFolder, strFileName)
	local strJson = tFunctionHelper.EnCodeJson(tabCfg)
	if not IsRealString(strJson) then
		return 
	end
	if tipUtil:QueryFileExists(strCfgPath) then
		tipUtil:DeletePathFile(strCfgPath)
	end
	tipUtil:WriteStringToFile(strCfgPath, strJson)
end

function XmrHelper:GetCpuCfgTable(nMaxGpuUsage, strPool, strAccount, strWorkID)
	local tabCfg = {}
	tabCfg["algo"] = "cryptonight"
	tabCfg["cpu-affinity"] = nil
	tabCfg["cpu-priority"] = nil
	tabCfg["max-cpu-usage"] = nMaxGpuUsage
	tabCfg["print-time"] = 10
	tabCfg["retries"] = 5
	tabCfg["retry-pause"] = 5
	tabCfg["pools"] = {}
	tabCfg["pools"][1] = {}
	tabCfg["pools"][1]["url"] = strPool
	tabCfg["pools"][1]["user"] = strAccount
	tabCfg["pools"][1]["pass"] = strWorkID
	tabCfg["pools"][1]["keepalive"] = true
	tabCfg["pools"][1]["nicehash"] = true
	return tabCfg
end

function XmrHelper:GetGpuACfgTable(nPlatform, strPool, strAccount, strWorkID)
	local tabCfg = {}
	tabCfg["algo"] = "cryptonight"
	tabCfg["print-time"] = 10
	tabCfg["retries"] = 5
	tabCfg["retry-pause"] = 5
	tabCfg["opencl-platform"] = nPlatform
	tabCfg["threads"] = nil
	tabCfg["pools"] = {}
	tabCfg["pools"][1] = {}
	tabCfg["pools"][1]["url"] = strPool
	tabCfg["pools"][1]["user"] = strAccount
	tabCfg["pools"][1]["pass"] = strWorkID
	tabCfg["pools"][1]["keepalive"] = true
	tabCfg["pools"][1]["nicehash"] = true
	tabCfg["sharehelper"] = {}
	tabCfg["sharehelper"]["intensity"] = 512
	tabCfg["sharehelper"]["worksize"] = 8
	tabCfg["sharehelper"]["sleep"] = 500
	return tabCfg
end

function XmrHelper:GetGpuNCfgTable(strSleep, nMaxGpuUsage, strPool, strAccount, strWorkID)
	local tabCfg = {}
	tabCfg["algo"] = "cryptonight"
	tabCfg["print-time"] = 10
	tabCfg["retries"] = 5
	tabCfg["retry-pause"] = 5
	tabCfg["bfactor"] = "12"
	tabCfg["max-gpu-threads"] = 0
	tabCfg["max-gpu-usage"] = nMaxGpuUsage
	tabCfg["bsleep"] = tostring(strSleep)
	tabCfg["pools"] = {}
	tabCfg["pools"][1] = {}
	tabCfg["pools"][1]["url"] = strPool
	tabCfg["pools"][1]["user"] = strAccount
	tabCfg["pools"][1]["pass"] = strWorkID
	tabCfg["pools"][1]["keepalive"] = true
	tabCfg["pools"][1]["nicehash"] = true
	return tabCfg
end

--4: N卡      显存>=1*1024*1024*1024 Share4PeerXN64.exe  XMR
--5: A卡      显存>=1*1024*1024*1024 Share4PeerXA64.exe  XMR
--32位系统
--6: A卡      显存>=1*1024*1024*1024 Share4PeerXA.exe  XMR
--32+64位系统
--7: CPU      Share4PeerXC.exe  XMR
-- strHost :其实就是矿池地址
function XmrHelper:InitXmr(nMiningType, bFullSpeed, strHost, strAccount, strWorkID, nPlatform)
	local strExeName = nil
	local tabCfgJson = nil
	local strCfgName = nil
	local nRealMiningType = nMiningType
	if nMiningType == 4 then
		local nMaxGpuUsage = 35
		strExeName = "Share4PeerXN64.exe"
		strSleep = "108"
		if bFullSpeed then
			nMaxGpuUsage = 45
			strSleep = "80"
		end
		
		tabCfgJson = self:GetGpuNCfgTable(strSleep, nMaxGpuUsage,strHost, strAccount, strWorkID)
		strCfgName = self._strGpuNCfgName
	elseif nMiningType == 5 then
		if bFullSpeed then
			strExeName = "Share4PeerXA64.exe"
			tabCfgJson = self:GetGpuACfgTable(nPlatform, strHost, strAccount, strWorkID)
			strCfgName = self._strGpuACfgName
			IPCUtil:SetMinerType(5)
		else
			strExeName = "Share4PeerXC.exe"
			local nMaxGpuUsage = 60
			tabCfgJson = self:GetCpuCfgTable(nMaxGpuUsage, strHost, strAccount, strWorkID)
			strCfgName = self._strCpuCfgName
			nRealMiningType = 5
			IPCUtil:SetMinerType(7)
		end	
	elseif nMiningType == 6 then
		if bFullSpeed then
			strExeName = "Share4PeerXA.exe"
			tabCfgJson = self:GetGpuACfgTable(nPlatform, strHost, strAccount, strWorkID)
			strCfgName = self._strGpuACfgName
			IPCUtil:SetMinerType(6)
		else
			strExeName = "Share4PeerXC.exe"
			local nMaxGpuUsage = 60
			tabCfgJson = self:GetCpuCfgTable(nMaxGpuUsage, strHost, strAccount, strWorkID)
			strCfgName = self._strCpuCfgName
			nRealMiningType = 6
			IPCUtil:SetMinerType(7)
		end	
	elseif nMiningType == 7 then
		strExeName = "Share4PeerXC.exe"
		local nMaxGpuUsage = 60
		if bFullSpeed then
			nMaxGpuUsage = 90
		end
		tabCfgJson = self:GetCpuCfgTable(nMaxGpuUsage, strHost, strAccount, strWorkID)
		strCfgName = self._strCpuCfgName
	end
	self:WriteCfgByName(tabCfgJson, strCfgName)
	return strExeName, nRealMiningType
end


