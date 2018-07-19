local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local tClientProc = XLGetGlobal("ClientProc")

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
			if bRet then
				self:CalculateProfitPriority(bRet, tabGpuSpeed) 
			end	
		end)
	end
	self:GetServerJsonData(self._strCoinRateUrl, fnCallBack)
end

function ProfitMax:CalculateProfitPriority(bRet, tabGpuSpeed) 
	self._tabGpuSpeed = tabGpuSpeed
	local nEtcRate = tFunctionHelper.FetchValueByPath(self._tabCoinRate, {"data", "ca", "rate"}) or 0
	local nZCahsRate = tFunctionHelper.FetchValueByPath(self._tabCoinRate, {"data", "cb", "rate"}) or 0
	local nXmrRate = tFunctionHelper.FetchValueByPath(self._tabCoinRate, {"data", "cc", "rate"}) or 0
	
	local tabClientSpeed = {}
	for strKey, tabValue in pairs(tabGpuSpeed) do
		local nClient = tonumber(strKey)
		if SupportClientType:CheckIsGpuClient(nClient) then
			local nLen = #tabClientSpeed+1
			tabClientSpeed[nLen] = {}
			tabClientSpeed[nLen]["nClient"] = nClient or 0
			local nRate = 0
			if nClient == 1 then
				nRate = nEtcRate
			elseif nClient == 2 or nClient == 3 then
				nRate = nZCahsRate
			elseif nClient == 4 or nClient == 5 or nClient == 6 then
				nRate = nXmrRate
			end
			tabClientSpeed[nLen]["nSpeed"] = tabValue["MaxSpeed"] * nRate
		end	
	end
	if #tabClientSpeed <= 0 then
		TipLog("[CalculateProfitPriority] no speed info")
		return
	end
	table.sort(tabClientSpeed,function(first,second)
		return first.nSpeed > second.nSpeed
	end)
	tFunctionHelper.DumpObj(tabClientSpeed, "tabClientSpeed")
	
	local tNewProfitMax = {}
	for Idx=1, #tabClientSpeed do
		tNewProfitMax[Idx] = tabClientSpeed[Idx]["nClient"]
	end
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tProfitMax"]) ~= "table" then
		tUserConfig["tProfitMax"] = {}
	end
	tUserConfig["tProfitMax"]["nLastQueryServer"] = tipUtil:GetCurrentUTCTime()
	tUserConfig["tProfitMax"]["tRate"] = self._tabCoinRate
	tUserConfig["tProfitMax"]["tServerGpuSpeed"] = tabGpuSpeed
	if self:CheckIsPriorityChange(tNewProfitMax) then
		tUserConfig["tProfitMax"]["tPriority"] = tNewProfitMax
		tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
		SupportClientType:SortGpuClientTable()
		---[[
		if SupportClientType:CheckIsProfitMaxMode() then
			if MainWorkModule:CheckIsWorking() then
				MainWorkModule:UpdatePriority()
			end
		end
		--]]
	else
		tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
	end
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
	local nGpuHashRate, nCpuHashRate = tClientProc.GetModeWrokingHashSpeed()
	if nGpuHashRate == 0 then
		--return false
	end
	local nGPUClient, nCPUClient = tClientProc.GetModeWrokingClient()
	if nGPUClient == 0 then
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
	local tabClientSpeed = tabGpuSpeed[tostring(nGPUClient)]
	if type(tabClientSpeed) ~= "table" or not IsRealString(tabClientSpeed["VerRef"]) then
		return false, 7
	end
	local nMiniSpeed = tabClientSpeed["MinSpeed"]
	TipLog("[CheckShowRecommendCond] nGpuHashRate = " .. tostring(nGpuHashRate) .. ", nMiniSpeed = " .. tostring(nMiniSpeed))
	if nGpuHashRate > nMiniSpeed*0.9 then
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
	return true, nGpuHashRate
end

function ProfitMax:CheckRecommendDriver()
	self:ClearRecommendDriver()
	self:SendRecommendStat(0)
    if not SupportClientType:CheckIsProfitMaxMode() then
		TipLog("[CheckRecommendDriver] current is not profit max mode")
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
		local bCheck, nGpuHashRate = ProfitMax:CheckShowRecommendCond()
		if not bCheck then
			self:SendRecommendStat(nGpuHashRate)
		elseif not MainWorkModule:CheckIsWorking() then
			self:SendRecommendStat(13)
		else
			TipLog("[CheckRecommendDriver] try to show max speed window")
			UIInterface:ShowMaxSpeedWnd(nGpuHashRate)
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
    if not SupportClientType:CheckIsProfitMaxMode() then
		TipLog("[CanShowhowMaxSpeedWndNow] current is not profit max mode")
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
	local nGpuHashRate, nCpuHashRate = tClientProc.GetModeWrokingHashSpeed()
	if nGpuHashRate == 0 then
		--return false
	end
	local nGPUClient, nCPUClient = tClientProc.GetModeWrokingClient()
	if nGPUClient == 0 then
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
	local tabClientSpeed = tabGpuSpeed[tostring(nGPUClient)]
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




