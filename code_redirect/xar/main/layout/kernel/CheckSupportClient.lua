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

local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("FunctionHelper")

ObjectBase = XLGetGlobal("ObjectBase")
SupportClientType = ObjectBase:New()
XLSetGlobal("SupportClientType", SupportClientType)

SupportClientType._tabSupportClientInfo = nil
SupportClientType._nCoinCnt = 0
SupportClientType._nClientCnt = 0

SupportClientType._tabCoinType = {"ETC","ZCASH","XMR"}
SupportClientType._VENDOR = {}
SupportClientType._VENDOR.AMD = 1
SupportClientType._VENDOR.NVIDIA = 2

SupportClientType._ClientIndex = 0

function SupportClientType:Init() 
	self:GetMachineSupportClient()
end

function SupportClientType:IsWow64()
	if tFunctionHelper.GetSystemBits() ~= 64 then
		return false
	end
	return true
end

--先按币种数来排，再按支持的客户端个数来排
function SupportClientType:GetSupportCoinAndClientInfo(tabInfo) 
	local nCoin = 0
	local nClient = 0
	for index=1,#self._tabCoinType do
		if type(tabInfo[self._tabCoinType[index]]) == "table" then
			nCoin = nCoin+1
		end
	end
	nClient = #tabInfo["ClientType"]
	return nCoin, nClient
end

function SupportClientType:ComparePlatform(tabInfo)
	local nCoin, nClient = self:GetSupportCoinAndClientInfo(tabInfo)
	if nCoin > self._nCoinCnt or (nCoin == self._nCoinCnt and nClient > self._nClientCnt)then
		self._tabSupportClientInfo = tabInfo
		self._nCoinCnt = nCoin
		self._nClientCnt = nClient
	end

end

function SupportClientType:InsertCoinInfoToTab(strCoinType,nClientType)
	if type(self._tabSupportClientInfo) ~= "table" then
		self._tabSupportClientInfo = {}
		self._tabSupportClientInfo["ClientType"] = {}
	end
	if type(self._tabSupportClientInfo[strCoinType]) ~= "table" then
		self._tabSupportClientInfo[strCoinType] = {}
		self._nCoinCnt = self._nCoinCnt + 1
	end
	self._tabSupportClientInfo[strCoinType][#self._tabSupportClientInfo[strCoinType]+1] = nClientType
	self._tabSupportClientInfo["ClientType"][#self._tabSupportClientInfo["ClientType"]+1] = nClientType
	self._nClientCnt = #self._tabSupportClientInfo["ClientType"]
end


function SupportClientType:GetMachineSupportClient()
	local tabDisplayCard = tipUtil:GetAllDisplayCardInfo()
	if type(tabDisplayCard) == "table" then
		for index=1,#tabDisplayCard do
			local tabItem = tabDisplayCard[index]
			if type(tabItem) == "table" 
				and type(tabItem["memory_size"]) == "number"
				and type(tabItem["vendor"]) == "number" then
				local tabClientType = {}
				tabClientType["ClientType"] = {}
				if self:IsWow64() then
					if tabItem["memory_size"] >= 3000000000 and (tabItem["vendor"] == self._VENDOR.AMD or tabItem["vendor"] == self._VENDOR.NVIDIA) then
						tabClientType["ETC"] = {}
						tabClientType["ETC"][#tabClientType["ETC"]+1] = 1
						tabClientType["ClientType"][#tabClientType["ClientType"]+1] = 1
					end
					if tabItem["memory_size"] >= 2000000000 and tabItem["vendor"] == self._VENDOR.NVIDIA then
						tabClientType["ZCASH"] = {}
						tabClientType["ZCASH"][#tabClientType["ZCASH"]+1] = 2
						tabClientType["ClientType"][#tabClientType["ClientType"]+1] = 2
					end
					if tabItem["memory_size"] >= 2000000000 and tabItem["vendor"] == self._VENDOR.AMD then
						--tabClientType["ZCASH"] = {}
						--tabClientType["ZCASH"][#tabClientType["ZCASH"]+1] = 3
						--tabClientType["ClientType"][#tabClientType["ClientType"]+1] = 3
					end
					if tabItem["memory_size"] >= 1*1024*1024*1024 and tabItem["vendor"] == self._VENDOR.NVIDIA then
						tabClientType["XMR"] = {}
						tabClientType["XMR"][#tabClientType["XMR"]+1] = 4
						tabClientType["ClientType"][#tabClientType["ClientType"]+1] = 4
					end
					if tabItem["memory_size"] >= 1*1024*1024*1024 and tabItem["vendor"] == self._VENDOR.AMD then
						tabClientType["XMR"] = {}
						tabClientType["XMR"][#tabClientType["XMR"]+1] = 5
						tabClientType["ClientType"][#tabClientType["ClientType"]+1] = 5
					end
				else
					if tabItem["memory_size"] >= 1*1024*1024*1024 and tabItem["vendor"] == self._VENDOR.AMD then
						tabClientType["XMR"] = {}
						tabClientType["XMR"][#tabClientType["XMR"]+1] = 6
						tabClientType["ClientType"][#tabClientType["ClientType"]+1] = 6
					end
				end	
				tabClientType["PlatformId"] = tabItem["platformid"]
				self:ComparePlatform(tabClientType)
			end					
		end
	end
	--全部加入CPU的客户端
	--7: CPU      Share4PeerXC.exe  XMR
	self:InsertCoinInfoToTab("XMR", 7)
	tFunctionHelper.DumpObj(self._tabSupportClientInfo, "DisplayCardInfo")
end

function SupportClientType:CheckIsDebug()
	local nValue = tipUtil:QueryRegValue("HKEY_CURRENT_USER", "SOFTWARE\\Share4Money", "Debug")
	if type(nValue) == "number" and nValue > 0 then
		--ClientWorkModule:SetMiningType(nValue)
		return true, nValue
	end
	return false
end

function SupportClientType:GetNextClientInfo() 
	local nPlatformId = self._tabSupportClientInfo["PlatformId"]
	local bDeBug,nMiningType = self:CheckIsDebug()
	if not bDeBug then
		local tabInfo = self._tabSupportClientInfo["ClientType"]
		self._ClientIndex = self._ClientIndex + 1
		if self._ClientIndex > #tabInfo then
			self._ClientIndex = #tabInfo
		end
		nMiningType = tabInfo[self._ClientIndex]
	end	
	return nPlatformId, nMiningType
end


