local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local IPCUtil = XLGetObject("IPC.Util")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local hostwndManager = XLGetObject("Xunlei.UIEngine.HostWndManager")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local tClientProc = XLGetGlobal("ClientProc")

ObjectBase = XLGetGlobal("ObjectBase")
ShareBindWidth = ObjectBase:New()
XLSetGlobal("ShareBindWidth", ShareBindWidth)
ShareBindWidth._bStart = true
ShareBindWidth._nProcessID = 0
ShareBindWidth._CycleTimerId = nil
ShareBindWidth._strInterfacePrefix = "http://api.eastredm.com"
ShareBindWidth._strCoinType = "ce"

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
	tipUtil:Log("sharebindwidth: " .. tostring(strLog))
end

function ShareBindWidth:Init()

end

function ShareBindWidth:InitListener()
	--self:AddListener("OnRewardInfo", self.OnRewardInfo, self)
    --self:AddListener("OnShowQRCode", self.OnShowQRCode, self)
end

function ShareBindWidth:GetCacheInfo()
	local nCSIDL_WINDOWS = 0x0024
	local strWindows = tipUtil:GetSpecialFolderPathEx(nCSIDL_WINDOWS)
	local _,_, strSystem = string.find(strWindows, "([^\\]+).+$")
	local tDisk = tFunctionHelper.GetDiskList()
	local strMaxFreeSpaceDisk = ""
	local nMaxFreeSpace = 0
	if #tDisk == 1 then
		local nFreeBytesAvailable, nTotalNumberOfBytes, nTotalNumberOfFreeBytes = tipUtil:GetDiskFreeSpace(tDisk[1])
		TipLog("nFreeBytesAvailable = " .. tostring(nFreeBytesAvailable) .. ", nTotalNumberOfBytes = " .. tostring(nTotalNumberOfBytes) .. ", nTotalNumberOfFreeBytes = " .. tostring(nTotalNumberOfFreeBytes))
		if type(nFreeBytesAvailable) == "number" and nFreeBytesAvailable > nMaxFreeSpace then
			nMaxFreeSpace = nFreeBytesAvailable
			strMaxFreeSpaceDisk = strDisk
		end
	else
		for i = 1, #tDisk do
			local strDisk = tDisk[i]
			if string.lower(tostring(strDisk)) ~= string.lower(tostring(strSystem)) then
				local nFreeBytesAvailable, nTotalNumberOfBytes, nTotalNumberOfFreeBytes = tipUtil:GetDiskFreeSpace(strDisk)
				TipLog("nFreeBytesAvailable = " .. tostring(nFreeBytesAvailable) .. ", nTotalNumberOfBytes = " .. tostring(nTotalNumberOfBytes) .. ", nTotalNumberOfFreeBytes = " .. tostring(nTotalNumberOfFreeBytes))
				if type(nFreeBytesAvailable) == "number" and nFreeBytesAvailable > nMaxFreeSpace then
					nMaxFreeSpace = nFreeBytesAvailable
					strMaxFreeSpaceDisk = strDisk
				end
			end	
		end
	end	
	return strMaxFreeSpaceDisk, nMaxFreeSpace
end

function ShareBindWidth:GetCacheCfg()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tConfig"]["ShareBindWindth"]) ~= "table" then
		tUserConfig["tConfig"]["ShareBindWindth"] = {}
	end
	local strPluginDataDir = tUserConfig["tConfig"]["ShareBindWindth"]["strPluginDataDir"]
	if not IsRealString(strPluginDataDir) 
		or not tipUtil:QueryFileExists(strPluginDataDir) then
		local strMaxFreeSpaceDisk, nMaxFreeSpace = self:GetCacheInfo()
		local nMaxFreeSpaceInGB = nMaxFreeSpace/1024/1024/1024
		strPluginDataDir = tipUtil:PathCombine(strMaxFreeSpaceDisk, "gxzbplugin\\bindwidth\\data")
		if not tipUtil:QueryFileExists(strPluginDataDir) then
			tipUtil:CreateDir(strPluginDataDir)
		end
		
		local nDataSize = self:GetDataSize(strPluginDataDir)/1024/1024/1024
		local nTotalFreeGB = nMaxFreeSpaceInGB+nDataSize
		local nMaxDiskUsageGB = math.floor(nTotalFreeGB*0.9)
		local nMinDiskAvailGB = math.floor(nTotalFreeGB-nMaxDiskUsageGB)
		
		tUserConfig["tConfig"]["ShareBindWindth"]["strPluginDataDir"] = strPluginDataDir
		tUserConfig["tConfig"]["ShareBindWindth"]["nMaxDiskUsageGB"] = nMaxDiskUsageGB
		tUserConfig["tConfig"]["ShareBindWindth"]["nMinDiskAvailGB"] = nMinDiskAvailGB
		tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
	end
end

function ShareBindWidth:GetDataSize(strDataDir)
	--[[
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tConfig"]["ShareBindWindth"]) ~= "table" then
		tUserConfig["tConfig"]["ShareBindWindth"] = {}
	end
	local strPluginDataDir = tUserConfig["tConfig"]["ShareBindWindth"]["strPluginDataDir"]
	--]]
	if IsRealString(strDataDir) and tipUtil:QueryFileExists(strDataDir) then
		local tabFiles = tipUtil:FindFileList(strDataDir,'*')
		local nDataSize = 0
		if type(tabFiles) == "table" then
			for i=1, #tabFiles do
				if tipUtil:QueryFileExists(tabFiles[i]) then
					local nSize = tipUtil:GetFileSize(tabFiles[i])
					nDataSize = nDataSize+nSize
				end
			end
		end
		return nDataSize
	end
	return 0
end

function ShareBindWidth:CheckCanStart()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local bCheck = tUserConfig["tConfig"]["ShareBindWindth"]["bCheck"]
	if bCheck == nil then
		bCheck = true
	end
	return bCheck
end

function ShareBindWidth:GetPluginDir()
	local bOk, strBaseDir = tFunctionHelper.QueryAllUsersDir()
	local strPluginDir = tipUtil:PathCombine(strBaseDir, "Share4Money\\plugin\\scdn_app")
	--strPluginDir = "G:\\third_app\\scdn_app"
	return strPluginDir
end

function ShareBindWidth:SendStartReport()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tConfig"]["ShareBindWindth"]) ~= "table" then
		return false
	end
	local nMaxDiskUsageGB = tUserConfig["tConfig"]["ShareBindWindth"]["nMaxDiskUsageGB"] or 0
	local tStatInfo = {}
	tStatInfo.fu1 = "bandwidth"
	tStatInfo.fu5 = "run"
	tStatInfo.fu6 = nMaxDiskUsageGB
	StatisticClient:SendEventReport(tStatInfo)
end

function ShareBindWidth:UpdatePluginSpeed(nSpeed)
	tClientProc.SetPluginData("nShareBWSpeed", nSpeed)
end

function ShareBindWidth:StopPlugin()
	self:UpdatePluginSpeed(0)
	if self._nProcessID > 0 then
		self._bStart = false
		tipAsynUtil:AsynKillProcess(self._nProcessID, 1000, function(nErrCode)
			TipLog("[StopPlugin] nProcessID: " .. tostring(self._nProcessID) .. ", nErrCode: " .. tostring(nErrCode))
			self._nProcessID = 0
		end)
	end	
	if self._CycleTimerId then
		timeMgr:KillTimer(self._CycleTimerId)
		self._CycleTimerId = nil
	end
end

function ShareBindWidth:StartPlugin()
	if self._CycleTimerId then
		timeMgr:KillTimer(self._CycleTimerId)
		self._CycleTimerId = nil
	end
	
	if not self:CheckCanStart() then
		return false
	end
	if tipUtil:QueryProcessExists("platinumd.exe") then
		return false
	end
	ShareBindWidth:GetCacheCfg()
	local strModuleDir = self:GetPluginDir()
	local strWorkDir = tipUtil:PathCombine(strModuleDir, "bin")
	local strExePath = tipUtil:PathCombine(strModuleDir, "bin\\platinumd.exe")
	if not tipUtil:QueryFileExists(strExePath) then
		return false
	end
	local strCfgPath = tipUtil:PathCombine(strModuleDir, "conf\\server.ini")
	if not tipUtil:QueryFileExists(strCfgPath) then
		return false
	end
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tConfig"]["ShareBindWindth"]) ~= "table" then
		return false
	end
	if not IsRealString(tUserConfig["tUserInfo"]["strWorkID"]) then
		return false
	end
	local strHostname = "GXZB" .. tUserConfig["tUserInfo"]["strWorkID"]
	tipUtil:WriteINI("user", "Repository", tUserConfig["tConfig"]["ShareBindWindth"]["strPluginDataDir"], strCfgPath)
	tipUtil:WriteINI("user", "Hostname", strHostname, strCfgPath)
	tipUtil:WriteINI("disk", "MaxDiskUsageGB", tUserConfig["tConfig"]["ShareBindWindth"]["nMaxDiskUsageGB"], strCfgPath)
	tipUtil:WriteINI("disk", "MinDiskAvailGB", tUserConfig["tConfig"]["ShareBindWindth"]["nMinDiskAvailGB"], strCfgPath)
	self._bStart = true
	tipAsynUtil:AsynCreateProcess("", strExePath, strWorkDir, 32, 0, 
		function (nRet, tProcDetail)
			TipLog("StartPlugin AsynCreateProcess callback:nRet="..tostring(nRet))
			if nRet == 0 and tProcDetail and tProcDetail.hProcess then
				self:CycleQuerySvrForBWPluginData()
				self:SendStartReport()
				self._nProcessID = tProcDetail.dwProcessId
				tipAsynUtil:AsynWaitForSingleObject(tProcDetail.hProcess, nil, function(nRet)
						self:UpdatePluginSpeed(0)
						if self._bStart then
							self:StartPlugin()
						end
					end)
			else
				TipLog("StartPlugin AsynCreateProcess callback failed")
			end
		end)

end

function ShareBindWidth:GetBWPluginRequestUrl()
	local tUserConfig = WorkModuleHelper:GetUserConfig()
	local strWorkID = tFunctionHelper.FetchValueByPath(tUserConfig, {"tUserInfo", "strWorkID"})
	if not IsRealString(strWorkID) then
		return
	end
	local strInterfaceName = "getXlSpeed"
	local strInterfaceParam = "workerID=" .. Helper:UrlEncode(strWorkID)
	local strParam = ApiInterfaceModule:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  self._strInterfacePrefix .. strParam
	TipLog("[GetBWPluginRequestUrl] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function ShareBindWidth:CycleQuerySvrForBWPluginData()
	local strUrl = self:GetBWPluginRequestUrl()
	if not IsRealString(strUrl) then
		return 
	end
	local nCycleTime = 10*60
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[CycleQuerySvrForBWPluginData] strUrl = " .. strUrl)
	
	local function fnCallBack(bRet, tabInfo)
		---[[
		if not bRet or type(tabInfo["data"]) ~= "table" then
			return
		end
		local nSpeed = tonumber(tabInfo["data"]["speed"])
		if type(nSpeed) ~= "number" then
			return
		end
		--]]
		local nRate = WorkModuleHelper:GetCoinRate(self._strCoinType) or 0
		TipLog("[CycleQuerySvrForBWPluginData] nSpeed = " .. nSpeed .. ", nRate = " .. nRate)
		--nRate = 10
		--nSpeed = 30
		self:UpdatePluginSpeed(nRate*nSpeed)
		if MainWorkModule:CheckIsCalculate() then
			MainWorkModule:UpdateMiningSpeed()
		end	
	end
	
	self._CycleTimerId = timeMgr:SetTimer(function(Itm, id)
		ApiInterfaceModule:GetServerJsonData(strUrl, fnCallBack)
	end, nCycleTime*1000)
	
end
