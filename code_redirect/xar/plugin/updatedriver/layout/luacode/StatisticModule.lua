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

function StatisticClient:FormatRequestUrl(strParam)
	return self._strStatPrefix .. strParam
end

--[[
http://pgv.eastredm.com/pc/interface?fu1=1&fu2=1&fu3=1&fu4=1&fu5=1&fu6=1&fu7=1&fu8=1&fu9=1&md5=XXXX
interface:接口名称
fu1：类别
fu2: peerid
fu3: version
fu4: channel
fu5~fu9:额外信息
fu10:workid
--]]

function StatisticClient:SendServerStatistic(strApiInterface, tStat)
	local rdRandom = tipUtil:GetCurrentUTCTime()
	local tUserConfig = tFunctionHelper.ReadUserConfig()
	local strWorkID = tFunctionHelper.FetchValueByPath(tUserConfig, {"tUserInfo", "strWorkID"})
	local strVersion = tFunctionHelper.GetGXZBVersion() or ""
	local strChannel = tFunctionHelper.GetInstallSrc() or ""
	--local strApiInterface = tStat.ApiInterface or "clientError"
	local strInterfaceParam = "fu1=" .. ParamEncode(tostring("plugindriver"))
					 .. "&fu2=" .. ParamEncode(tostring(tFunctionHelper.GetPeerID()))
				     .. "&fu3=" .. ParamEncode(strVersion)
				     .. "&fu4=" .. ParamEncode(strChannel)
				     .. "&fu5=" .. (MakeMaxParamLen(tStat.fu5) or "")
				     .. "&fu6=" .. (MakeMaxParamLen(tStat.fu6) or "")
				     .. "&fu7=" .. (MakeMaxParamLen(tStat.fu7) or "")
				     .. "&fu8=" .. (MakeMaxParamLen(tStat.fu8) or "")
				     .. "&fu9=" .. (MakeMaxParamLen(tStat.fu9) or "")
					 .. "&fu10=" .. ParamEncode(strWorkID or "")
                     .. "&fu11=" .. (MakeMaxParamLen(tStat.fu11) or "")
	local strParam = tFunctionHelper.MakeInterfaceMd5(strApiInterface, strInterfaceParam)
	local strStatisticUrl = self:FormatRequestUrl(strParam)
	strStatisticUrl = strStatisticUrl.."&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("SendServerStatistic: " .. tostring(strStatisticUrl))
	
	self._nStatCount = self._nStatCount + 1
	if not self._bForceExit and tStat.Exit then
		self._bForceExit = true
	end
	--保证统计不卡进程，这样后面的新示例可以立马起来
	if self._bForceExit then
		tipUtil:CloseLuaMsgWnd()
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

function StatisticClient:FailExitProcess(iExitCode)
	local tStatInfo = {}
	tStatInfo.fu5 = "failexit"
	tStatInfo.fu6 = iExitCode
	tStatInfo.Exit = true
	self:SendEventReport(tStatInfo)
end

function StatisticClient:ExitClient(statInfo)
	tipUtil:Exit("Exit")
end

