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

SupportClientType._tabSupportClientInfo = nil
SupportClientType._nCoinCnt = 0
SupportClientType._nClientCnt = 0
SupportClientType._tabGpuInfo = nil

SupportClientType._tabCoinType = {"etc","zcash","xmr", "ut"}
SupportClientType._VENDOR = {}
SupportClientType._VENDOR.AMD = 1
SupportClientType._VENDOR.NVIDIA = 2

SupportClientType._tabDisplayCard = nil

SupportClientType._ClientIndex = 0
SupportClientType._nCurClientType = 0

SupportClientType._DebugType = nil

SupportClientType._nPriorityMode = 0

function TipLog(strLog)
	tipUtil:Log("CheckSupportClient: " .. tostring(strLog))
end

function SupportClientType:Init() 
	self._tabDisplayCard = tipUtil:GetAllDisplayCardInfo()
	self:CheckIsGpuEnvChange(self._tabDisplayCard)
	self:GetMachineSupportClient()
    
   
end

function SupportClientType:GetCurrentPriorityMode()
	return self._nPriorityMode
end

function SupportClientType:GetCurrentGpuInfo()
	return self._tabGpuInfo
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

--先按币种数来排，再按支持的客户端个数来排
function SupportClientType:GetCoinAndClientTypeCnt(tabInfo) 
	local nCoin = 0
	local nClient = #tabInfo
	for ctype=1,#self._tabCoinType do
		local strCoinType = self._tabCoinType[ctype]
		for index=1,#tabInfo do
			if tabInfo[index]["ctype"] == strCoinType then
				nCoin = nCoin+1
				break
			end
		end
	end
	return nCoin, nClient
end

function SupportClientType:ComparePlatform(tabInfo, nPlatformId, tabItem)
	local nCoin, nClient = self:GetCoinAndClientTypeCnt(tabInfo)
	if nCoin > self._nCoinCnt or (nCoin == self._nCoinCnt and nClient > self._nClientCnt)then
		self._tabSupportClientInfo = tabInfo
		self._nCoinCnt = nCoin
		self._nClientCnt = nClient
		self._nPlatformId = nPlatformId
		self._tabGpuInfo = tabItem
	end

end

function SupportClientType:InsertClientInfoToTab(strCoinType,nClientType)
	if type(self._tabSupportClientInfo) ~= "table" then
		self._tabSupportClientInfo = {}
	end
	self._tabSupportClientInfo[#self._tabSupportClientInfo+1] = {}
	self._tabSupportClientInfo[#self._tabSupportClientInfo]["mtype"] = nClientType
	self._tabSupportClientInfo[#self._tabSupportClientInfo]["ctype"] = strCoinType
	
	local nCoin, nClient = self:GetCoinAndClientTypeCnt(self._tabSupportClientInfo)
	self._nCoinCnt = nCoin
	self._nClientCnt = nClient
end


function SupportClientType:GetMachineSupportClient()
	local tabDisplayCard = self._tabDisplayCard
	if type(tabDisplayCard) == "table" then
		for index=1,#tabDisplayCard do
			local tabItem = tabDisplayCard[index]
			if type(tabItem) == "table" 
				and type(tabItem["memory_size"]) == "number"
				and type(tabItem["vendor"]) == "number" then
				local tabClient = {}
				if self:IsWow64() then
					if tabItem["memory_size"] >= 3000000000 
						and (tabItem["vendor"] == self._VENDOR.AMD or tabItem["vendor"] == self._VENDOR.NVIDIA) 
						and not self:CheckHasCrashed(self.ClientType.ETC_NA64) then
						tabClient[#tabClient+1] = {}
						tabClient[#tabClient]["mtype"] = self.ClientType.ETC_NA64
						tabClient[#tabClient]["ctype"] = "etc"
					end
					if tabItem["memory_size"] >= 2000000000 
						and tabItem["vendor"] == self._VENDOR.NVIDIA 
						and not self:CheckHasCrashed(self.ClientType.ZCASH_N64) then
						tabClient[#tabClient+1] = {}
						tabClient[#tabClient]["mtype"] = self.ClientType.ZCASH_N64
						tabClient[#tabClient]["ctype"] = "zcash"
					end
					if tabItem["memory_size"] >= 2000000000 
						and tabItem["vendor"] == self._VENDOR.AMD
						and not self:CheckHasCrashed(self.ClientType.ZCASH_A64) then
						--tabClient[#tabClient+1] = {}
						--tabClient[#tabClient]["mtype"] = self.ClientType.ZCASH_A64
						--tabClient[#tabClient]["ctype"] = "zcash"
					end
					if tabItem["memory_size"] >= 1*1024*1024*1024 
						and tabItem["vendor"] == self._VENDOR.NVIDIA
						and not self:CheckHasCrashed(self.ClientType.XMR_N64) then
						tabClient[#tabClient+1] = {}
						tabClient[#tabClient]["mtype"] = self.ClientType.XMR_N64
						tabClient[#tabClient]["ctype"] = "xmr"
					end
					if tabItem["memory_size"] >= 1*1024*1024*1024 
						and tabItem["vendor"] == self._VENDOR.AMD
						and not self:CheckHasCrashed(self.ClientType.XMR_A64) then
						tabClient[#tabClient+1] = {}
						tabClient[#tabClient]["mtype"] = self.ClientType.XMR_A64
						tabClient[#tabClient]["ctype"] = "xmr"
					end
				else
					if tabItem["memory_size"] >= 1*1024*1024*1024 
						and tabItem["vendor"] == self._VENDOR.AMD
						and not self:CheckHasCrashed(self.ClientType.XMR_A32) then						
						tabClient[#tabClient+1] = {}
						tabClient[#tabClient]["mtype"] = self.ClientType.XMR_A32
						tabClient[#tabClient]["ctype"] = "xmr"
					end
				end	
				local nPlatformId = tabItem["platformid"]
				self:ComparePlatform(tabClient, nPlatformId, tabItem)
			end					
		end
	end
	--全部加入CPU的客户端
	--8: CPU      Share4PeerUC.exe  UT
	self:InsertClientInfoToTab("ut", self.ClientType.UT_C64)
	--7: CPU      Share4PeerXC.exe  XMR
	self:InsertClientInfoToTab("xmr", self.ClientType.XMR_C32)
	self:SortClientTable()
	tFunctionHelper.DumpObj(self._tabSupportClientInfo, "DisplayCardInfo")
end

function SupportClientType:GetLocalPriorityTable()
	local tForcePlist = nil
    local tPriority = {2,1,3,4,5,6,8,7}
    local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tPriority"]) == "table" then
		tPriority = tUserConfig["tPriority"]
	end
	if type(tUserConfig["tForcePlist"]) == "table" then
		tForcePlist = tUserConfig["tForcePlist"]
	end 
	return tPriority, tForcePlist
end

function SupportClientType:InsertNewPriority(tabProfitMax, nNewItem, nBeforeItem)
	local nFind = 0
	for Idx=1, #tabProfitMax do
		if tabProfitMax[Idx] == nBeforeItem then
			nFind = Idx
		elseif tabProfitMax[Idx] == nNewItem then
			return
		end
	end
	if nFind == 0 then
		tabProfitMax[#tabProfitMax+1] = nNewItem
	else
		tabProfitMax[nFind] = nNewItem
		tabProfitMax[#tabProfitMax+1] = nBeforeItem
	end
	
end

function SupportClientType:GetLocalProfitMaxTable()
	local tabProfitMax = nil
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tProfitMax"]) == "table" and type(tUserConfig["tProfitMax"]["tPriority"]) == "table" then
		tabProfitMax = tUserConfig["tProfitMax"]["tPriority"]
		self:InsertNewPriority(tabProfitMax, 8, 7)
	end
	return tabProfitMax
end

function SupportClientType:SortClientTable()
	local tabSort = nil
	local tPriority, tForcePlist = self:GetLocalPriorityTable()
	tForcePlist = tForcePlist or {}
	local tabProfitMax = self:GetLocalProfitMaxTable()
	if (#tForcePlist <= 0 or not tFunctionHelper.CheckPeerIDList(tForcePlist)) and type(tabProfitMax) == "table" then
		tabSort = tabProfitMax
		self._nPriorityMode = 1
	else
		tabSort = tPriority
		self._nPriorityMode = 0
	end
	if type(tabSort) ~= "table" or #tabSort < 1 then
		return
	end
	local tabClientInfo = {}
	for nPIndex=1,#tabSort do
		local nClientType = tabSort[nPIndex]
		for nCIndex=1,#self._tabSupportClientInfo do
			if self._tabSupportClientInfo[nCIndex]["mtype"] == nClientType then
				table.insert(tabClientInfo,self._tabSupportClientInfo[nCIndex])
				break
			end
		end
	end
	self._tabSupportClientInfo = tabClientInfo
	local nCoin, nClient = self:GetCoinAndClientTypeCnt(self._tabSupportClientInfo)
	self._nCoinCnt = nCoin
	self._nClientCnt = nClient
end

function SupportClientType:CheckIsNeedChangeNow()
    self:SortClientTable()
    self._ClientIndex = 0
    local bDeBug,nClientType = self:CheckIsDebug()
    if bDeBug then
        return false
    end
    if type(self._tabSupportClientInfo) == "table" and ClientWorkModule:CheckIsWorking() then
        if self._nCurClientType ~= self._tabSupportClientInfo[1]["mtype"] then
            return true
        end
    end 
    return false
end

function SupportClientType:CheckIsDebug()
	local nValue = tipUtil:QueryRegValue("HKEY_CURRENT_USER", "SOFTWARE\\Share4Money", "Debug")
	if type(nValue) == "number" and nValue > 0 then
		--ClientWorkModule:SetMiningType(nValue)
		return true, nValue
	end
	return false
end

function SupportClientType:ResetClientIndex() 
	self._ClientIndex = 0
end

function SupportClientType:GetNextClientInfo() 
	local bDeBug,nClientType = self:CheckIsDebug()
	if not bDeBug then
		local tabInfo = self._tabSupportClientInfo
		self._ClientIndex = self._ClientIndex + 1
		if self._ClientIndex > #tabInfo then
			return
		end
		nClientType = tabInfo[self._ClientIndex]["mtype"]
	else
		if self._DebugType ~= nClientType then
			self._DebugType = nClientType
		else
			return
		end
	end	
    self._nCurClientType = nClientType
	return self._nPlatformId, nClientType
end


