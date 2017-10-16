local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
ObjectBase = XLGetGlobal("ObjectBase")
StatisticClient = ObjectBase:New()
XLSetGlobal("StatisticClient", StatisticClient)

StatisticClient._strStatPrefix = "http://pgv.eastredm.com/pc"
StatisticClient._nStatCount = 0
StatisticClient._bForceExit = false

StatisticClient._StatTimeoutTimerId = nil
StatisticClient._RunTimeReportTimerId = nil
StatisticClient._nLastReportRunTimeUTC = tipUtil:GetCurrentUTCTime()
StatisticClient._strLastReportRunTimeState = "nomining"
StatisticClient._tabCpuTime = nil

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
	tipUtil:Log("StatisticModule: " .. tostring(strLog))
end

function MakeMaxParamLen(strParam)
	local strEncode = ParamEncode(strParam)
	while string.len(strEncode) > 256 do
		local nLen = string.len(strParam)-1
		if nLen > 256 then
			nLen = 256
		end
		strParam = string.sub(strParam, 1, nLen)
		strEncode = ParamEncode(strParam)
    end
	return strEncode
end

function ParamEncode(strParam)
	if type(strParam) == "number" then
		strParam = tostring(strParam)
	end
	if type(strParam) ~= "string" or "" == strParam then
		TipLog("The parameter is not a real string")
		return ""
	end
	
	strParam = string.gsub(strParam, "([%W])", function(c) 
			if c == "!" or c == "'" or c == "(" or c == ")" or c == "*" or c == "-" or c == "." or c == "_" or c == "~" then
				return
			end
			return string.format("%%%02X", string.byte(c)) 
	end)
    return strParam
end

function StatisticClient:CalculateCpuUsage()
	local nUsagePrecent,tabTime =  tipUtil:GetCPUUsage(self._tabCpuTime) 
	self._tabCpuTime = tabTime
	self._nCpuUsagePrecent = nUsagePrecent
end

function StatisticClient:Init()
	--ClientWorkModule = XLGetGlobal("ClientWorkModule")
	timeMgr:SetTimer(function(Itm, id)
			self:CalculateCpuUsage()
		end, 1*1000)
end

function StatisticClient:CheckReportCond(strReportPID)
	if not IsRealString(strReportPID) then
		return true
	end
	local strPeerId = tFunctionHelper.GetPeerID()
	local strPId12 = string.sub(strPeerId, 12, 12) or "0"
	if string.find(strReportPID,strPId12) ~= nil then 
		return true
	end
	return false
end

function StatisticClient:FormatRequestUrl(strParam)
	return self._strStatPrefix .. strParam
end

--[[
http://pgv.eastredm.com/pc/interface?fu1=1&fu2=1&fu3=1&fu4=1&fu5=1&fu6=1&fu7=1&fu8=1&fu9=1&md5=XXXX
interface:接口名称
fu1：类别
fu2: peerid
fu3: workid
fu4: version_channel
fu5~fu9:额外信息
--]]

function StatisticClient:SendServerStatistic(strApiInterface, tStat)
	local rdRandom = tipUtil:GetCurrentUTCTime()
	local tUserConfig = ClientWorkModule:GetUserConfig()
	local strWorkID = tUserConfig["tUserInfo"]["strWorkID"]
	local strVersionAndChannel = (tFunctionHelper.GetGXZBVersion() or "") .. "_" .. (tFunctionHelper.GetInstallSrc() or "")
	--local strApiInterface = tStat.ApiInterface or "clientError"
	local strInterfaceParam = "fu1=" .. ParamEncode(tostring(tStat.fu1))
					 .. "&fu2=" .. ParamEncode(tostring(tFunctionHelper.GetPeerID()))
				     .. "&fu3=" .. ParamEncode(strWorkID or "")
				     .. "&fu4=" .. ParamEncode(strVersionAndChannel)
				     .. "&fu5=" .. (MakeMaxParamLen(tStat.fu5) or "")
				     .. "&fu6=" .. (MakeMaxParamLen(tStat.fu6) or "")
				     .. "&fu7=" .. (MakeMaxParamLen(tStat.fu7) or "")
				     .. "&fu8=" .. (MakeMaxParamLen(tStat.fu8) or "")
				     .. "&fu9=" .. (MakeMaxParamLen(tStat.fu9) or "")
	
	local strParam = ClientWorkModule:MakeInterfaceMd5(strApiInterface, strInterfaceParam)
	local strStatisticUrl = self:FormatRequestUrl(strParam)
	strStatisticUrl = strStatisticUrl.."&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("SendServerStatistic: " .. tostring(strStatisticUrl))
	
	self._nStatCount = self._nStatCount + 1
	if not self._bForceExit and tStat.Exit then
		self._bForceExit = true
	end
	--保证统计不卡进程，这样后面的新示例可以立马起来
	if self._bForceExit then
		tipUtil:CloseSingletonMutex()
	end
	tipAsynUtil:AsynSendHttpStat(strStatisticUrl, function()
		self._nStatCount = self._nStatCount - 1
		if self._nStatCount == 0 and self._bForceExit then
			self:ExitClient()
		end
	end)
	
	local iStatCount = self._nStatCount
	if self._bForceExit and iStatCount > 0 and self._StatTimeoutTimerId == nil then	--开启定时退出定时器
		self._StatTimeoutTimerId = timeMgr:SetTimer(function(Itm, id)
			Itm:KillTimer(id)
			self:ExitClient()
		end, 15000 * iStatCount)
	end
end

function StatisticClient:SendClickReport(tStatInfo)
	local strApiInterface = "click"
	self:SendServerStatistic(strApiInterface, tStatInfo)
end

function StatisticClient:SendEventReport(tStatInfo)
	
	local strApiInterface = "event"
	self:SendServerStatistic(strApiInterface, tStatInfo)
end

function StatisticClient:SendInstallReport(tStatInfo)
	local strApiInterface = "install"
	self:SendServerStatistic(strApiInterface, tStatInfo)
end

function StatisticClient:SendClientErrorReport(tStatInfo)
	local strApiInterface = "clientError"
	self:SendServerStatistic(strApiInterface, tStatInfo)
end

function StatisticClient:SendOnlineReport(tStatInfo)
	local strApiInterface = "online"
	self:SendServerStatistic(strApiInterface, tStatInfo)
end

--心跳包
function StatisticClient:SendRunTimeReport(strState)
	local nSpanTime = math.abs(tipUtil:GetCurrentUTCTime() - self._nLastReportRunTimeUTC)
	if nSpanTime == 0 then
		return
	end
	local tStatInfo = {}
	tStatInfo.fu1 = "runtime"
	tStatInfo.fu5 = self._strLastReportRunTimeState
	if tStatInfo.fu5 == "mining" then
		tStatInfo.fu6 = ClientWorkModule:GetClientMiningSpeed()
		tStatInfo.fu7 = ClientWorkModule:GetMiningType()
		local tabMemoryInfo = tipUtil:GetMemoryStatus()
		if type(tabMemoryInfo) ~= "table" then
			tabMemoryInfo = {}
		end
		local nCpuUsagePrecent = self._nCpuUsagePrecent or 0
		local nMemoryLoadPrecent = tabMemoryInfo["MemoryLoad"] or 0
		local nGpuUsagePrecent = tipUtil:GetGPUUsage(2) or 0
		tStatInfo.fu8 = nCpuUsagePrecent .. "_" .. nMemoryLoadPrecent .. "_" .. nGpuUsagePrecent
	end
	tStatInfo.fu9 = nSpanTime
	self:SendOnlineReport(tStatInfo)
	self._strLastReportRunTimeState = strState
end

function StatisticClient:StartRunTimeReport(strState)
	--XLMessageBox(tostring(strState))
	--下次启动才生效
	local strReportPID  = ServerCfg:GetLocalServerCfgData({"tReportInfo", "strOnlinePID"})
	if not self:CheckReportCond(strReportPID) then return end
	local nTimeSpanInSec = ServerCfg:GetLocalServerCfgData({"tReportInfo", "nOnlineInterval"})
	nTimeSpanInSec = tonumber(nTimeSpanInSec) or 10 * 60 
	--XLMessageBox(nTimeSpanInSec)
	local nTimeSpanInMs = nTimeSpanInSec * 1000
	if self._RunTimeReportTimerId ~= nil then
		timeMgr:KillTimer(self._RunTimeReportTimerId)
		self._RunTimeReportTimerId = nil
		self:SendRunTimeReport(strState)
	end
	self._nLastReportRunTimeUTC = tipUtil:GetCurrentUTCTime()
	self._RunTimeReportTimerId = timeMgr:SetTimer(function(item, id)
		self:SendRunTimeReport(strState)
	end, nTimeSpanInMs)
end

function StatisticClient:FailExitProcess(iExitCode)
	local tStatInfo = {}
	--[[	
	tStatInfo.strEC = "failexit"
	tStatInfo.strEA = GetInstallSrc() or ""
	tStatInfo.strEL = tostring(iExitCode)
	tStatInfo.Exit = true
		
	Statistic:SendServerStatistic(tStatInfo)
	--]]
	local tStatInfo = {}
	tStatInfo.fu1 = "failexit"
	tStatInfo.fu5 = iExitCode
	tStatInfo.Exit = true
	self:SendEventReport(tStatInfo)
end

function StatisticClient:ExitClient(statInfo)
	tFunctionHelper.SaveAllConfig()		
	ClientWorkModule:NotifyQuit()
	TipLog("************ Exit ************")
	--tipUtil:CloseSingletonMutex()
	tipUtil:Exit("Exit")
end