local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
ObjectBase = XLGetGlobal("ObjectBase")
Statistic = ObjectBase:New()
XLSetGlobal("Statistic", Statistic)


Statistic._nStatCount = 0
Statistic._bForceExit = false

Statistic._StatTimeoutTimerId = nil
Statistic._MiningReportTimerId = nil

Statistic._nLastReportRunTmUTC = tipUtil:GetCurrentUTCTime()
Statistic._nLastReportMiningTmUTC = tipUtil:GetCurrentUTCTime()

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

function Statistic:Init()
	ClientWorkModule = XLGetGlobal("ClientWorkModule")
end

function Statistic:CheckReportCond(strReportPID)
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

function Statistic:SendServerStatistic(tStat)
	local rdRandom = tipUtil:GetCurrentUTCTime()
	local tStatInfo = tStat or {}
	local strDefaultNil = "zb_null"
	
	local strCID = tFunctionHelper.GetPeerID()
	local strEC = tStatInfo.strEC 
	local strEA = tStatInfo.strEA 
	local strEL = tStatInfo.strEL
	local strEV = tStatInfo.strEV
	local strTID = tStatInfo.strTID or "UA-96195625-1"
	if IsNilString(strEC) then
		strEC = strDefaultNil
	end
	
	if IsNilString(strEA) then
		strEA = strDefaultNil
	end
	
	if IsNilString(strEL) then
		strEL = strDefaultNil
	end
	
	if tonumber(strEV) == nil then
		strEV = 1
	end

	local strUrl = "http://www.google-analytics.com/collect?v=1&tid=" .. tostring(strTID).. "="..tostring(strCID)
					.."&t=event&ec="..tostring(strEC).."&ea="..tostring(strEA)
					.."&el="..tostring(strEL).."&ev="..tostring(strEV)
	TipLog("SendServerStatistic: " .. tostring(strUrl))
	
	self._nStatCount = self._nStatCount + 1
	if not self._bForceExit and tStat.Exit then
		self._bForceExit = true
	end
	tipAsynUtil:AsynSendHttpStat(strUrl, function()
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

function Statistic:SendUIReport(strEC,strEA,strEL)
	local tStatInfo = {}
	tStatInfo.strEC = strEC
	if strEA == nil then
		tStatInfo.strEA = tFunctionHelper.GetInstallSrc() or ""
	else
		tStatInfo.strEA = strEA
	end
	if strEL == nil then
		tStatInfo.strEL = tFunctionHelper.GetGXZBMinorVer() or ""
	else
		tStatInfo.strEL = strEL
	end
	
	tStatInfo.strEV = 1
	self:SendServerStatistic(tStatInfo)
end

function Statistic:SendErrorReport(strEA,strEL)
	local tStatInfo = {}
	tStatInfo.strTID = "UA-106737106-1"
	tStatInfo.strEC = tFunctionHelper.GetGXZBMinorVer() or ""
	tStatInfo.strEA = strEA or 0
	tStatInfo.strEL = strEL or ""
	
	tStatInfo.strEV = 1
	self:SendServerStatistic(tStatInfo)
end


function Statistic:SendStartupReport(bShowWnd)
	local tStatInfo = {}
	local bRet, strSource = tFunctionHelper.GetCommandStrValue("/sstartfrom")
	tStatInfo.strEL = strSource or ""
	
	if not bShowWnd then
		tStatInfo.strEC = "startup"  --进入上报
		tStatInfo.strEA = tFunctionHelper.GetInstallSrc() or ""
	else
		tStatInfo.strEC = "showui" 	 --展示上报
		tStatInfo.strEA = tFunctionHelper.GetInstallSrc() or ""
	end
	
	tStatInfo.strEV = 1
	self:SendServerStatistic(tStatInfo)
end

--启动客户端后的心跳包
function Statistic:StartRunCountTimer()
	local strReportPID  = ServerCfg:GetServerCfgData({"tReportPID", "strRunTime"})
	if not self:CheckReportCond(strReportPID) then return end
	
	local nTimeSpanInSec = 10 * 60 
	local nTimeSpanInMs = nTimeSpanInSec * 1000
	timeMgr:SetTimer(function(item, id)
		self._nLastReportRunTmUTC = tipUtil:GetCurrentUTCTime()
		self:SendRunTimeReport(nTimeSpanInSec, false)
	end, nTimeSpanInMs)
	--[[
	local nTimeSpanInMs = 2*60*1000
	timerManager:SetTimer(function(item, id)
		--SendClientReport(10)
	end, nTimeSpanInMs)
	--]]
end

function Statistic:SendRunTimeReport(nTimeSpanInSec, bExit)
	local strReportPID  = ServerCfg:GetServerCfgData({"tReportPID", "strRunTime"})
	if not self:CheckReportCond(strReportPID) then return end
	local tStatInfo = {}
	tStatInfo.strEC = "runtime"
	tStatInfo.strEA = tFunctionHelper.GetInstallSrc() or ""
	
	local nRunTime = 0
	if bExit and self._nLastReportRunTmUTC ~= 0 then
		nRunTime = math.abs(tipUtil:GetCurrentUTCTime() - self._nLastReportRunTmUTC)
	else
		nRunTime = nTimeSpanInSec
	end
	tStatInfo.strEV = nRunTime
	self:SendServerStatistic(tStatInfo)
end

--启动挖矿程序后的心跳包
function Statistic:StartMiningCountTimer()
	local strReportPID  = ServerCfg:GetServerCfgData({"tReportPID", "strMining"})
	if not self:CheckReportCond(strReportPID) then return end

	local nTimeSpanInSec = 10 * 60 
	local nTimeSpanInMs = nTimeSpanInSec * 1000
	if self._MiningReportTimerId ~= nil then
		timeMgr:KillTimer(self._MiningReportTimerId)
		self._MiningReportTimerId = nil
	end
	self._nLastReportMiningTmUTC = tipUtil:GetCurrentUTCTime()
	self._MiningReportTimerId = timeMgr:SetTimer(function(item, id)
		self._nLastReportMiningTmUTC = tipUtil:GetCurrentUTCTime()
		self:SendMiningReport(nTimeSpanInSec, false)
	end, nTimeSpanInMs)
end

function Statistic:StopMiningCountTimer()
	if self._MiningReportTimerId ~= nil then
		timeMgr:KillTimer(self._MiningReportTimerId)
		self._MiningReportTimerId = nil
	end
	self._nLastReportMiningTmUTC = 0
end

function Statistic:SendMiningReport(nTimeSpanInSec, bExit)
	local strReportPID  =  ServerCfg:GetServerCfgData({"tReportPID", "strMining"})
	if not self:CheckReportCond(strReportPID) then return end
	if self._MiningReportTimerId == nil then return end
	local tStatInfo = {}
	tStatInfo.strEC = "mining"
	tStatInfo.strEA = tFunctionHelper.GetInstallSrc() or ""
	
	local nMiningTime = 0
	if bExit and self._nLastReportMiningTmUTC ~= 0 then
		nMiningTime = math.abs(tipUtil:GetCurrentUTCTime() - self._nLastReportMiningTmUTC)
		self._nLastReportMiningTmUTC = 0
	else
		nMiningTime = nTimeSpanInSec
	end
	tStatInfo.strEV = nMiningTime
	if nMiningTime == 0 then
		return
	end
	self:SendServerStatistic(tStatInfo)
end

function Statistic:ExitClient(statInfo)
	tFunctionHelper.SaveAllConfig()		
	ClientWorkModule:NotifyQuit()
	TipLog("************ Exit ************")
	tipUtil:CloseSingletonMutex()
	tipUtil:Exit("Exit")
end