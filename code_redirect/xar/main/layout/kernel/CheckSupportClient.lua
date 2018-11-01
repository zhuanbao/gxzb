--返回值说明
--64位系统
--1：N卡+A卡  显存>=3000000000 Share4Peer.exe  ETC
--2: N卡      显存>=2000000000 Share4PeerZN.exe  ZCASH
--3: A卡      显存>=2000000000 Share4PeerZA.exe  ZCASH  --已经舍弃


--4: N卡      显存>=1*1024*1024*1024 Share4PeerXN64.exe  XMR
--5: A卡      显存>=1*1024*1024*1024 Share4PeerXA64.exe  XMR
--32位系统
--6: A卡      显存>=1*1024*1024*1024 Share4PeerXA.exe  XMR
--32+64位系统
--7: CPU      Share4PeerXC.exe  XMR
--8: CPU      Share4PeerUC.exe  UT

local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("FunctionHelper")

ObjectBase = XLGetGlobal("ObjectBase")
SupportClientType = ObjectBase:New()
XLSetGlobal("SupportClientType", SupportClientType)

--常量定义
SupportClientType.ClientType = {}
SupportClientType.ClientType.ETC_NA64 = 1
SupportClientType.ClientType.ZCASH_N64 = 2
SupportClientType.ClientType.ZCASH_A64 = 3
SupportClientType.ClientType.XMR_N64 = 4
SupportClientType.ClientType.XMR_A64 = 5
SupportClientType.ClientType.XMR_A32 = 6
SupportClientType.ClientType.XMR_C32 = 7
SupportClientType.ClientType.UT_C64 = 8

SupportClientType._VENDOR = {}
SupportClientType._VENDOR.AMD = 1
SupportClientType._VENDOR.NVIDIA = 2

SupportClientType._tabGpuClient = {}
SupportClientType._nPlatformId = 0
SupportClientType._tabGpuInfo = nil

SupportClientType._tabCpuClient = {}

SupportClientType._tabDisplayCard = nil

SupportClientType._bProfitMaxMode = false

function TipLog(strLog)
	tipUtil:Log("CheckSupportClient: " .. tostring(strLog))
end

function SupportClientType:Init() 
	self._tabDisplayCard = tipUtil:GetAllDisplayCardInfo()
	self:CheckIsGpuEnvChange(self._tabDisplayCard)
	self:GetMachineSupportClient()
end

function SupportClientType:CheckIsGpuClient(nClient)
	if nClient == self.ClientType.ETC_NA64
		or nClient == self.ClientType.ZCASH_N64
		or nClient == self.ClientType.ZCASH_A64
		or nClient == self.ClientType.XMR_N64
		or nClient == self.ClientType.XMR_A64
		or nClient == self.ClientType.XMR_A32 then
	
		return true
	end
	return false
end

function SupportClientType:CheckIsProfitMaxMode()
	return self._bProfitMaxMode
end

function SupportClientType:GetCurrentGpuInfo()
	return self._tabGpuInfo
end

function SupportClientType:GetGpuClient()
	return self._tabGpuClient, self._nPlatformId
end

function SupportClientType:GetCpuClient()
	return self._tabCpuClient
end

function SupportClientType:IsWow64()
	if tFunctionHelper.GetSystemBits() ~= 64 then
		return false
	end
	return true
end

--主要是判断显卡名称，显存大小，显卡驱动版本是否变化过
function SupportClientType:CheckIsGpuEnvChange(tabNewGPUInfo)	
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tGPUInfo"]) ~= "table" or #tUserConfig["tGPUInfo"] < 1 then
		self:SaveNewGpuEnvInfo(tabNewGPUInfo)
		self:ClearCrash()
		TipLog("First ini gpu environment")
		return
	end
	local tabOldGPUInfo = tUserConfig["tGPUInfo"]

	for iOld = 1,#tabOldGPUInfo do
		local tabOldGPUItem = tabOldGPUInfo[iOld]
		if tabOldGPUItem["vendor"] == self._VENDOR.AMD or tabOldGPUItem["vendor"] == self._VENDOR.NVIDIA then
			local bComper = false
			for iNew = 1,#tabNewGPUInfo do
				local tabNewGPUItem = tabNewGPUInfo[iNew]
				if string.lower(tabOldGPUItem["name"]) == string.lower(tabNewGPUItem["name"])
					and string.lower(tabOldGPUItem["version"]) == string.lower(tabNewGPUItem["version"])
					and string.lower(tabOldGPUItem["memory_size"]) == string.lower(tabNewGPUItem["memory_size"]) then
					bComper = true
					break
				end
			end
			if not bComper then
				self:SaveNewGpuEnvInfo(tabNewGPUInfo)
				self:ClearCrash()
				TipLog("Gpu environment has changed")
				return
			end
		end	
	end
end

function SupportClientType:ClearCrash()
	tipUtil:DeleteRegKey("HKEY_CURRENT_USER", "Software\\Share4Money\\Crash")
end

function SupportClientType:SetCrashDebugFlag(nClientType)
	local nValue = tFunctionHelper.RegQueryValue("HKEY_CURRENT_USER\\Software\\Share4Money\\Crash\\" .. tostring(nClientType))
	if type(nValue) ~= "number" then
		tFunctionHelper.RegSetValue("HKEY_CURRENT_USER\\Software\\Share4Money\\Crash\\" .. tostring(nClientType), 1)
	end	
end

function SupportClientType:ClearCrashDebugFlag(nClientType)
	local nValue = tFunctionHelper.RegQueryValue("HKEY_CURRENT_USER\\Software\\Share4Money\\Crash\\" .. tostring(nClientType))
	if nValue == 1 then
		tFunctionHelper.RegDeleteValue("HKEY_CURRENT_USER\\Software\\Share4Money\\Crash\\" .. tostring(nClientType))
	end	
end

function SupportClientType:SetNoCrashFlag(nClientType)
	local nValue = tFunctionHelper.RegQueryValue("HKEY_CURRENT_USER\\Software\\Share4Money\\Crash\\" .. tostring(nClientType))
	if nValue ~= 0 then
		tFunctionHelper.RegSetValue("HKEY_CURRENT_USER\\Software\\Share4Money\\Crash\\" .. tostring(nClientType), 0)
	end	
end

function SupportClientType:CheckHasCrashed(nClientType)
	local nValue = tFunctionHelper.RegQueryValue("HKEY_CURRENT_USER\\Software\\Share4Money\\Crash\\" .. tostring(nClientType))
	if nValue == nil or tonumber(nValue) ~= 1 then
		return false
	else
		return true
	end
end

function SupportClientType:SaveNewGpuEnvInfo(tabNewGPUInfo)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["tGPUInfo"] = nil
	tUserConfig["tGPUInfo"] = tabNewGPUInfo
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
end

function SupportClientType:CompareGpuPlatform(tabClient, nPlatformId, tabGpuInfo)
	if type(self._tabGpuClient) ~= "table"  or  #self._tabGpuClient < #tabClient then
		self._tabGpuClient = tabClient
		self._nPlatformId = nPlatformId
		self._tabGpuInfo = tabGpuInfo
	end
end

function SupportClientType:GetMachineSupportClient()
	local tabDisplayCard = self._tabDisplayCard
	if type(tabDisplayCard) == "table" then
		for index=1,#tabDisplayCard do
			local tabItem = tabDisplayCard[index]
			if type(tabItem) == "table" 
				and type(tabItem["memory_size"]) == "number"
				and type(tabItem["vendor"]) == "number" then
				TipLog("[GetMachineSupportClient] memory_size = " .. tostring(tabItem["memory_size"]))
				TipLog("[GetMachineSupportClient] vendor = " .. tostring(tabItem["vendor"]))
				local tabClient = {}
				if self:IsWow64() then
					if tabItem["memory_size"] >= 3000000000 
						and (tabItem["vendor"] == self._VENDOR.AMD or tabItem["vendor"] == self._VENDOR.NVIDIA) 
						and not self:CheckHasCrashed(self.ClientType.ETC_NA64) then
						tabClient[#tabClient+1] = self.ClientType.ETC_NA64
					end
					if tabItem["memory_size"] >= 2000000000 
						and tabItem["vendor"] == self._VENDOR.NVIDIA 
						and not self:CheckHasCrashed(self.ClientType.ZCASH_N64) then
						tabClient[#tabClient+1] = self.ClientType.ZCASH_N64
					end
					if tabItem["memory_size"] >= 2000000000 
						and tabItem["vendor"] == self._VENDOR.AMD
						and not self:CheckHasCrashed(self.ClientType.ZCASH_A64) then
						--exe过白被报毒，所以暂时不用
					end
					if tabItem["memory_size"] >= 1*1024*1024*1024 
						and tabItem["vendor"] == self._VENDOR.NVIDIA
						and not self:CheckHasCrashed(self.ClientType.XMR_N64) then
						tabClient[#tabClient+1] = self.ClientType.XMR_N64
					end
					if tabItem["memory_size"] >= 1*1024*1024*1024 
						and tabItem["vendor"] == self._VENDOR.AMD
						and not self:CheckHasCrashed(self.ClientType.XMR_A64) then
						tabClient[#tabClient+1] = self.ClientType.XMR_A64
					end
				else
					if tabItem["memory_size"] >= 1*1024*1024*1024 
						and tabItem["vendor"] == self._VENDOR.AMD
						and not self:CheckHasCrashed(self.ClientType.XMR_A32) then						
						tabClient[#tabClient+1] = self.ClientType.XMR_A32
					end
				end	
				--TipLog("[GetMachineSupportClient] tabClient num = " .. tostring(#tabClient))
				local nPlatformId = tabItem["platformid"]
				self:CompareGpuPlatform(tabClient, nPlatformId, tabItem)
			end					
		end
	end
	--加入CPU的客户端
	self._tabCpuClient = {}
	if self:IsWow64() then
		--8: CPU      Share4PeerUC.exe  UT
		self._tabCpuClient[#self._tabCpuClient+1] = self.ClientType.UT_C64
	end	
	--7: CPU      Share4PeerXC.exe  XMR
	self._tabCpuClient[#self._tabCpuClient+1] = self.ClientType.XMR_C32
	
	self:SortClientTable()
	tFunctionHelper.DumpObj(self._tabGpuClient, "tabGpuClient")
	tFunctionHelper.DumpObj(self._tabCpuClient, "tabCpuClient")
end

function SupportClientType:GetLocalPriorityTable()
	local tForcePlist = nil
    local tPriority = {2,1,3,4,5,6,7,8}
    local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tPriority"]) == "table" then
		tPriority = tUserConfig["tPriority"]
	end
	if type(tUserConfig["tForcePlist"]) == "table" then
		tForcePlist = tUserConfig["tForcePlist"]
	end 
	return tPriority, tForcePlist
end

function SupportClientType:GetLocalProfitMaxTable()
	local tabProfitMax = nil
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tProfitMax"]) == "table" and type(tUserConfig["tProfitMax"]["tPriority"]) == "table" then
		tabProfitMax = tUserConfig["tProfitMax"]["tPriority"]
	end
	return tabProfitMax
end

function SupportClientType:SortGpuClientTable()
	local nValue = tipUtil:QueryRegValue("HKEY_CURRENT_USER", "SOFTWARE\\Share4Money", "DebugG")
	if type(nValue) == "number" and nValue > 0 then
		self._tabGpuClient = {nValue}
		return
	end
	local tabSort = nil
	local tPriority, tForcePlist = self:GetLocalPriorityTable()
	local tabProfitMax = self:GetLocalProfitMaxTable()
	tForcePlist = tForcePlist or {}
	if #tForcePlist > 0 and tFunctionHelper.CheckPeerIDList(tForcePlist) then
		self._bProfitMaxMode = false
		tabSort = tPriority
	elseif type(tabProfitMax) == "table" then
		self._bProfitMaxMode = true
		tabSort = tabProfitMax
	else
		self._bProfitMaxMode = false
		tabSort = tPriority
	end
	local tabClientInfo = {}
	for nPIndex=1,#tabSort do
		local nClientType = tabSort[nPIndex]
		for nCIndex=1,#self._tabGpuClient do
			if self._tabGpuClient[nCIndex] == nClientType then
				table.insert(tabClientInfo,self._tabGpuClient[nCIndex])
				break
			end
		end
	end
	--没在优先级表里的再添加进去
	for	nCIdx=1, #self._tabGpuClient do 
		local nItem = self._tabGpuClient[nCIdx]
		local bAdd = true
		for nPIdx=1, #tabClientInfo do
			if nItem == tabClientInfo[nPIdx] then
				bAdd = false
				break
			end
		end
		if bAdd then
			table.insert(tabClientInfo, nItem)
		end
	end
	self._tabGpuClient = tabClientInfo
end

function SupportClientType:SortCpuClientTable()
	local nValue = tipUtil:QueryRegValue("HKEY_CURRENT_USER", "SOFTWARE\\Share4Money", "DebugC")
	if type(nValue) == "number" and nValue > 0 then
		self._tabCpuClient = {nValue}
		return
	end
	local tabSort = nil
	local tPriority, tForcePlist = self:GetLocalPriorityTable()
	tForcePlist = tForcePlist or {}
	if #tForcePlist > 0 and tFunctionHelper.CheckPeerIDList(tForcePlist) then
		tabSort = tPriority
	else
		tabSort = tPriority
	end
	local tabClientInfo = {}
	for nPIndex=1,#tabSort do
		local nClientType = tabSort[nPIndex]
		for nCIndex=1,#self._tabCpuClient do
			if self._tabCpuClient[nCIndex] == nClientType then
				table.insert(tabClientInfo,self._tabCpuClient[nCIndex])
				break
			end
		end
	end
	self._tabCpuClient = tabClientInfo
end

function SupportClientType:SortClientTable()
	self:SortGpuClientTable()
	self:SortCpuClientTable()
end


