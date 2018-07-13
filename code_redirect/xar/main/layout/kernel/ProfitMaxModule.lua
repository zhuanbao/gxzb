local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")

ObjectBase = XLGetGlobal("ObjectBase")
ProfitMax = ObjectBase:New()
XLSetGlobal("ProfitMax", ProfitMax)

ProfitMax._strCoinRateUrl = "http://api.eastredm.com/pc/getClassInfo"
ProfitMax._strGpuInfoPrefix = "http://conf.eastredm.com/static/gpuInfo/"

ProfitMax._tabCoinRate = nil
ProfitMax._tabGpuSpeed = nil


function TipLog(strLog)
	tipUtil:Log("ProfitMax: " .. tostring(strLog))
end

function IsRealString(str)
	return type(str) == "string" and str ~= ""
end

function ProfitMax:Init() 
	if self:CheckSpanTime() then
		self:GetServerGpuMiningInfo()
	end
	timeMgr:SetTimer(function(Itm, id)
		self:GetServerGpuMiningInfo()
	end, 4*3600*1000)
end

function ProfitMax:CheckSpanTime()
	local nLastQueryUtc = 0
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tProfitMax"]) == "table" and type(tUserConfig["tProfitMax"]["nLastQueryServer"]) == "number" then
		nLastQueryUtc =tUserConfig["tProfitMax"]["nLastQueryServer"]
	end
	
	local nCurTimeUTC = tipUtil:GetCurrentUTCTime()
	if math.abs(nCurTimeUTC - nLastQueryUtc) > 2*3600 then
		return true
	end
	return false
end

--与服务端通信逻辑--
function ProfitMax:GetServerJsonData(strUrl,fnCallBack)
	tFunctionHelper.NewAsynGetHttpContent(strUrl, false
	, function(nRet, strContent, respHeaders)
		TipLog("[GetServerJsonData] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
				
		if 0 ~= nRet then
			TipLog("[GetServerJsonData] download failed.")
			fnCallBack(false)
			return
		end
		
		local tabInfo = tFunctionHelper.DeCodeJson(strContent)		
		if type(tabInfo) ~= "table" then
			fnCallBack(false)
			return
		end
		fnCallBack(true,tabInfo)
		return
	end)	
end

function ProfitMax:GetServerGpuMiningInfo() 
	local function fnCallBack(bRet, tabRate)
		if not bRet then
			return
		end
		if tabRate["rtn"] ~= 0 then
			return
		end
		self._tabCoinRate = tabRate
		local tabGpuInfo = SupportClientType:GetCurrentGpuInfo()
		if type(tabGpuInfo) ~= "table"
			or tabGpuInfo["vendor"] ~= SupportClientType._VENDOR.NVIDIA 
			or not IsRealString(tabGpuInfo["name"]) then
			return
		end
		
		local strServerGpuInfo = self._strGpuInfoPrefix .. Helper:UrlEncode((tostring(tabGpuInfo["name"]))) .. ".json"
		self:GetServerJsonData(strServerGpuInfo, function(bRet, tabGpuSpeed)
			self:CalculateProfitPriority(bRet, tabGpuSpeed) 
		end)
	end
	self:GetServerJsonData(self._strCoinRateUrl, fnCallBack)
end

function ProfitMax:CalculateProfitPriority(bRet, tabGpuSpeed) 
	self._tabGpuSpeed = tabGpuSpeed
	local nEtcRate = tFunctionHelper.FetchValueByPath(self._tabCoinRate, {"data", "ca", "rate"}) or 0
	local nZCahsRate = tFunctionHelper.FetchValueByPath(self._tabCoinRate, {"data", "cb", "rate"}) or 0
	local nXmrRate = tFunctionHelper.FetchValueByPath(self._tabCoinRate, {"data", "cc", "rate"}) or 0
	
	local tabMaxSpeed = {}
	for strKey, tabValue in pairs(tabGpuSpeed) do
		if strKey ~= "7" then
			local nLen = #tabMaxSpeed+1
			tabMaxSpeed[nLen] = {}
			tabMaxSpeed[nLen]["ClientType"] = tonumber(strKey) or 0
			local nRate = 0
			if strKey == "1" then
				nRate = nEtcRate
			elseif strKey == "2" or strKey == "3" then
				nRate = nZCahsRate
			elseif strKey == "4" or strKey == "5" or strKey == "6" then
				nRate = nXmrRate
			end
			tabMaxSpeed[nLen]["Speed"] = tabValue["MaxSpeed"] * nRate
		end	
	end
	tFunctionHelper.DumpObj(tabMaxSpeed, "before tabMaxSpeed")
	table.sort(tabMaxSpeed,function(first,second)
		return first.Speed > second.Speed
	end)
	
	tFunctionHelper.DumpObj(tabMaxSpeed, "tabMaxSpeed")
	
	local tabSort = {}
	for Idx=1, #tabMaxSpeed do
		tabSort[Idx] = tabMaxSpeed[Idx]["ClientType"]
	end
	tabSort[#tabSort+1] = 7
	tabSort[#tabSort+1] = 8
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tProfitMax"]) ~= "table" then
		tUserConfig["tProfitMax"] = {}
	end
	tUserConfig["tProfitMax"]["nLastQueryServer"] = tipUtil:GetCurrentUTCTime()
	tUserConfig["tProfitMax"]["tRate"] = self._tabCoinRate
	tUserConfig["tProfitMax"]["tServerGpuSpeed"] = tabGpuSpeed
	--tUserConfig["tProfitMax"]["tUserGpuInfo"] = SupportClientType:GetCurrentGpuInfo()
	if self:CheckIsPriorityChange(tabSort) then
		tUserConfig["tProfitMax"]["tPriority"] = tabSort
		if SupportClientType:GetCurrentPriorityMode() == 1 then
			if ClientWorkModule:CheckIsWorking() then
				ClientWorkModule:DispatchEvent("OnPriorityChange")
			else
				SupportClientType:SortClientTable()
				ClientWorkModule:InitMiningClient()
			end
		end
	end
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
end

function ProfitMax:CheckIsPriorityChange(tabNew)
    local tabOld = SupportClientType:GetLocalProfitMaxTable()
    if type(tabNew) ~= "table" then 
        TipLog("[CheckIsPriorityChange] tabNew is not table")
        return false
    end
    if type(tabOld) ~= "table" and type(tabNew) == "table" then 
        TipLog("[CheckIsPriorityChange] tabOld is not table, but tabNew is a table")
        return true
    end
    for idx=1,#tabNew do
        if tabNew[idx] ~= tabOld[idx] then
            TipLog("[CheckIsPriorityChange] Priority has change")
            return true
        end
    end
    TipLog("[CheckIsPriorityChange] Priority has not change")
    return false
end

function ProfitMax:IsExistIgnoreMark()
	local nValue = tFunctionHelper.RegQueryValue("HKEY_CURRENT_USER\\Software\\Share4Money\\RecommendDriver\\Ignore")
	if nValue ~= 1 then
		return false
	end
	return true
end

function ProfitMax:SetIgnoreMark()
	tFunctionHelper.RegSetValue("HKEY_CURRENT_USER\\Software\\Share4Money\\RecommendDriver\\Ignore", 1)
end

function ProfitMax:CheckLastRecommendTime()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tProfitMax"]) ~= "table" then
		tUserConfig["tProfitMax"] = {}
	end
	local tabRecommendDriver = tUserConfig["tProfitMax"]["tRecommendDriver"]
	if type(tabRecommendDriver) ~= "table" then
		tabRecommendDriver = {}
	end
	local nRecommendCnt = tabRecommendDriver["nCnt"] or 0
	local nLastTime = tabRecommendDriver["nLastTime"] or 0
	local nCurTimeUTC = tFunctionHelper.GetCurrentServerTime()
	nCurTimeUTC = tipUtil:GetCurrentUTCTime()
	if nRecommendCnt >= 3 then
		self:SetIgnoreMark()
		return false
	elseif nRecommendCnt == 2 then
		if nCurTimeUTC - nLastTime < 86400*4 then
			return false
		end
	elseif nRecommendCnt == 1 then
		if nCurTimeUTC - nLastTime < 86400*2 then
			return false
		end
	end
	return true
end

function ProfitMax:RecommendDriver()
	
end

function ProfitMax:CheckShowRecommendCond()
	local nHashRate = ClientWorkModule:GetClientLastAverageHashRate()
	if nHashRate == 0 then
		--return false
	end
	local nClient = ClientWorkModule:GetRealMiningType()
	if nClient == 7 or nClient == 8 then
		return false, 4
	end
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tProfitMax"]) ~= "table" then
		return false, 5
	end
	local tabRate = tUserConfig["tProfitMax"]["tRate"]
	local tabGpuSpeed = tUserConfig["tProfitMax"]["tServerGpuSpeed"]
	if type(tabRate) ~= "table" or type(tabGpuSpeed) ~= "table" then
		return false, 6
	end
	--[[
	local nRate = 0
	if nClient == 1 then
		nRate = tFunctionHelper.FetchValueByPath(tabRate, {"data", "ca", "rate"}) or 0
	elseif nClient == 2 or nClient == 3 then
		nRate = tFunctionHelper.FetchValueByPath(tabRate, {"data", "cb", "rate"}) or 0
	elseif nClient == 4 or nClient == 5 or nClient == 6 then
		nRate = tFunctionHelper.FetchValueByPath(tabRate, {"data", "cc", "rate"}) or 0
	end
	--]]
	local tabClientSpeed = tabGpuSpeed[tostring(nClient)]
	if type(tabClientSpeed) ~= "table" or not IsRealString(tabClientSpeed["VerRef"]) then
		return false, 7
	end
	local nMiniSpeed = tabClientSpeed["MinSpeed"]
	TipLog("[CheckShowRecommendCond] nHashRate = " .. tostring(nHashRate) .. ", nMiniSpeed = " .. tostring(nMiniSpeed))
	if nHashRate > nMiniSpeed*0.9 then
		TipLog("[CheckShowRecommendCond] hash rate is enough")
		self:SetIgnoreMark()
		return false, 8
	end
	local tabUserGpuInfo = SupportClientType:GetCurrentGpuInfo()
	if type(tabUserGpuInfo) ~= "table" then
		return false, 9
	end
	local strVer = tabUserGpuInfo["version"]
	if not IsRealString(strVer) then
		return false, 10
	end
	if strVer == tabClientSpeed["VerRef"] then
		TipLog("[CheckShowRecommendCond] current ver is equal ref ver")
		self:SetIgnoreMark()
		return false, 11
	end
	local tabExcludeVer = tabClientSpeed["VerList"] or {}
	for Idx=1, #tabExcludeVer do
		if strVer == tabExcludeVer[Idx] then
			TipLog("[CheckShowRecommendCond] current ver is in ver list")
			self:SetIgnoreMark()
		    return false, 12
		end
	end
	return true, nHashRate
end

function ProfitMax:CheckRecommendDriver()
	self:ClearRecommendDriver()
	self:SendRecommendStat(0)
    if SupportClientType:GetCurrentPriorityMode() ~= 1 then
		TipLog("[CheckRecommendDriver] GetCurrentPriorityMode is not 1")
		self:SendRecommendStat(1)
		return
	end
	if self:IsExistIgnoreMark() then
		TipLog("[CheckRecommendDriver] exist ignore mark")
		self:SendRecommendStat(2)
		return
	end
	if not self:CheckLastRecommendTime() then
		TipLog("[CheckRecommendDriver] last recommend time return false")
		self:SendRecommendStat(3)
		return
	end
	self._RecommendTimerID = timeMgr:SetOnceTimer(function () 
		self._RecommendTimerID = nil
		--if true then
		local bCheck, nHashRate = ProfitMax:CheckShowRecommendCond()
		if not bCheck then
			self:SendRecommendStat(nHashRate)
		elseif not ClientWorkModule:CheckIsWorking() then
			self:SendRecommendStat(13)
		else
			TipLog("[CheckRecommendDriver] try to show max speed window")
			UIInterface:ShowMaxSpeedWnd(nHashRate)
			self:SendRecommendStat(99)
		end
	end, 600*1000)
end

function ProfitMax:ClearRecommendDriver()
    if self._RecommendTimerID ~= nil then
		timeMgr:KillTimer(self._RecommendTimerID)
		self._RecommendTimerID = nil
	end
end


function ProfitMax:CanShowMaxSpeedWndNow()
    self:ClearRecommendDriver()
    if SupportClientType:GetCurrentPriorityMode() ~= 1 then
		TipLog("[CanShowhowMaxSpeedWndNow] GetCurrentPriorityMode is not 1")
		return false
	end
	if self:IsExistIgnoreMark() then
		TipLog("[CanShowhowMaxSpeedWndNow] exist ignore mark")
		return false
	end
	if not self:CheckLastRecommendTime() then
		TipLog("[CanShowhowMaxSpeedWndNow] last recommend time return false")
		return false
	end
		local nHashRate = ClientWorkModule:GetClientLastAverageHashRate()
	if nHashRate == 0 then
		--return false
	end
	local nClient = ClientWorkModule:GetRealMiningType()
	if nClient == 7 or nClient == 8 then
		return false
	end
	
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tProfitMax"]) ~= "table" then
		return false
	end
	local tabGpuSpeed = tUserConfig["tProfitMax"]["tServerGpuSpeed"]
	if type(tabGpuSpeed) ~= "table" then
		return false
	end
	local tabClientSpeed = tabGpuSpeed[tostring(nClient)]
	if type(tabClientSpeed) ~= "table" or not IsRealString(tabClientSpeed["VerRef"]) then
		return false
	end
	
	local tabUserGpuInfo = SupportClientType:GetCurrentGpuInfo()
	if type(tabUserGpuInfo) ~= "table" then
		return false
	end
	local strVer = tabUserGpuInfo["version"]
	if not IsRealString(strVer) then
		return false
	end
	if strVer == tabClientSpeed["VerRef"] then
		TipLog("[CheckShowRecommendCond] current ver is equal ref ver")
		self:SetIgnoreMark()
		return false
	end
	local tabExcludeVer = tabClientSpeed["VerList"] or {}
	for Idx=1, #tabExcludeVer do
		if strVer == tabExcludeVer[Idx] then
			TipLog("[CheckShowRecommendCond] current ver is in ver list")
			self:SetIgnoreMark()
		    return false
		end
	end
	return true
end

function ProfitMax:SendRecommendStat(nFlag)
    local tStatInfo = {}
	tStatInfo.fu1 = "recommenddriver"
	tStatInfo.fu5 = nFlag
	StatisticClient:SendEventReport(tStatInfo)
end




