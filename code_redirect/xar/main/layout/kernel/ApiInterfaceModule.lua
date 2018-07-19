local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local IPCUtil = XLGetObject("IPC.Util")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local tFunctionHelper = XLGetGlobal("FunctionHelper")

ObjectBase = XLGetGlobal("ObjectBase")
ApiInterfaceModule = ObjectBase:New()
XLSetGlobal("ApiInterfaceModule", ApiInterfaceModule)

ApiInterfaceModule._strSeverInterfacePrefix = "http://api.eastredm.com/pc"
ApiInterfaceModule._strSeverConfigPrefix = "http://conf.eastredm.com"


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
	tipUtil:Log("ApiInterfaceModule: " .. tostring(strLog))
end

function ApiInterfaceModule:MakeInterfaceMd5(strInterface,strInterfaceParam)
	local strParam = "/" .. strInterface .. "?" .. tostring(strInterfaceParam)
	local strMd5 = tipUtil:GetStringMD5(strParam)
	if string.lower(tostring(strParam)) ~= string.lower(tostring(strMd5)) then
		strParam = strParam .. "&md5=" .. strMd5
	end	
	return strParam
end

function ApiInterfaceModule:FormatRequestUrl(strParam)
	return self._strSeverInterfacePrefix .. strParam
end

function ApiInterfaceModule:GetUserConfig()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	return tUserConfig
end

function ApiInterfaceModule:GetHeartbeatInterval()
	local interval = 1
	local nHeartbeatInterval = tonumber(ServerCfg:GetServerCfgData({"tServerInterfaceCfg", "nReportCalcInterval"})) or 60
	nHeartbeatInterval = math.ceil(nHeartbeatInterval/interval)
	return nHeartbeatInterval
end

function ApiInterfaceModule:UpdateLastPushCalcTime(nUtc)
	self._nLastPushCalcReportUTC = nUtc
end

--接口定义
function ApiInterfaceModule:QuerySvrForWorkID()
	local strInterfaceName = "getWorkerID"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetPeerID()))
	local strGUID = tFunctionHelper.GetMachineID()
	if IsRealString(strGUID) then
		strInterfaceParam = strInterfaceParam .. "&param1=" .. Helper:UrlEncode(strGUID)
	end	
	local strParam = self:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  self:FormatRequestUrl(strParam)
	TipLog("[QuerySvrForWorkID] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function ApiInterfaceModule:QuerySvrForChangeWorkID(strWorkID)
	local strInterfaceName = "changeWorkerID"
	local strInterfaceParam="workerID=" .. Helper:UrlEncode(tostring(strWorkID))
	strInterfaceParam = strInterfaceParam .. "&peerid=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetPeerID()))
	local strGUID = tFunctionHelper.GetMachineID()
	if IsRealString(strGUID) then
		strInterfaceParam = strInterfaceParam .. "&param1=" .. Helper:UrlEncode(strGUID)
	end	
	local strParam = self:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl = self:FormatRequestUrl(strParam)
	TipLog("[QuerySvrForChangeWorkID] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function ApiInterfaceModule:QuerySvrForLoginInfo()
	--这里保证workID不为空
	local tUserConfig = self:GetUserConfig()
	local strWorkID = tUserConfig["tUserInfo"]["strWorkID"]
	local strInterfaceName = "bind"
	local strInterfaceParam = "workerID=" .. Helper:UrlEncode(tostring(strWorkID))
	local strParam = self:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  self:FormatRequestUrl(strParam)
	TipLog("[QuerySvrForLoginInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function ApiInterfaceModule:QuerySvrForQrcodeInfo(strWorkID)
	local strInterfaceName = "getQrcode"
	local strInterfaceParam = "workerID="..Helper:UrlEncode(tostring(strWorkID)) .. "&peerid=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetPeerID()))
	local strGUID = tFunctionHelper.GetMachineID()
	if IsRealString(strGUID) then
		strInterfaceParam = strInterfaceParam .. "&param1=" .. Helper:UrlEncode(strGUID)
	end	
	local strParam = self:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl = self:FormatRequestUrl(strParam)
	TipLog("[QuerySvrForQrcodeInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function ApiInterfaceModule:QuerySvrForReportClientInfo()
	local tUserConfig = self:GetUserConfig()
	if not IsRealString(tUserConfig["tUserInfo"]["strWorkID"]) then
		TipLog("[QuerySvrForReportClientInfo] no work id")
		return
	end
	local strInterfaceName = "reportClientConf"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetPeerID()))
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strWorkID"]))
	if IsRealString(tUserConfig["tUserInfo"]["strOpenID"]) then
		strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strOpenID"]))
	end	
	strInterfaceParam = strInterfaceParam .. "&workerName=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetMachineName()))
    
    local strChannel = tFunctionHelper.GetInstallSrc() or ""
    if IsRealString(strChannel) then
        strInterfaceParam = strInterfaceParam .. "&channel=" .. Helper:UrlEncode(tostring(strChannel))
    end    
    
    local strVersion = tFunctionHelper.GetGXZBVersion() or ""
    if IsRealString(strVersion) then
        strInterfaceParam = strInterfaceParam .. "&version=" .. Helper:UrlEncode(tostring(strVersion))
    end
    
	local strParam = self:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  self:FormatRequestUrl(strParam)
	TipLog("[QuerySvrForReportClientInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end



function ApiInterfaceModule:QuerySvrForPushCalcInfo(nSpeed)
	local tUserConfig = self:GetUserConfig()
	local strInterfaceName = "pushCalcMultiP"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetPeerID()))
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strWorkID"]))
	if IsRealString(tUserConfig["tUserInfo"]["strOpenID"]) then
		strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strOpenID"])))
	end
	strInterfaceParam = strInterfaceParam .. "&speed=" .. Helper:UrlEncode(tostring(nSpeed))
	--运行时长
	local nWorkingTime =  tFunctionHelper.GetCurrentServerTime() - self._nLastPushCalcReportUTC
	local nInterval = self:GetHeartbeatInterval()
	if nWorkingTime < 0 or nWorkingTime > nInterval then
		nWorkingTime = nInterval
	end
	self._nLastPushCalcReportUTC = tFunctionHelper.GetCurrentServerTime()
	strInterfaceParam = strInterfaceParam .. "&workTime=" .. Helper:UrlEncode((tostring(nWorkingTime)))
	
	local strParam = self:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  self:FormatRequestUrl(strParam)
	TipLog("[QuerySvrForPushCalcInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function ApiInterfaceModule:QuerySvrForTakeCashInfo(nMoney)
	local tUserConfig = self:GetUserConfig()
	local strInterfaceName = "drawout"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetPeerID()))
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strWorkID"]))
	if IsRealString(tUserConfig["tUserInfo"]["strOpenID"]) then
		strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strOpenID"])))
	end
	strInterfaceParam = strInterfaceParam .. "&amount=" .. Helper:UrlEncode((tostring(nMoney)))
	local strParam = self:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  self:FormatRequestUrl(strParam)
	TipLog("[QuerySvrForTakeCashInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function ApiInterfaceModule:QuerySvrForWorkerInfo()
	local tUserConfig = self:GetUserConfig()
	local strInterfaceName = "getWorkerInfoMultiP"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetPeerID()))
	local strWorkID = tUserConfig["tUserInfo"]["strWorkID"]
	if not IsRealString(strWorkID) then
		return nil
	end
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(tostring(strWorkID))
	if IsRealString(tUserConfig["tUserInfo"]["strOpenID"]) then
		strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strOpenID"])))
	end
	local strParam = self:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  self:FormatRequestUrl(strParam)
	TipLog("[QuerySvrForWorkInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function ApiInterfaceModule:QuerySvrForReportStopMiningInfo(strStatus)
	local tUserConfig = self:GetUserConfig()
	if not IsRealString(tUserConfig["tUserInfo"]["strWorkID"]) then
		TipLog("[QuerySvrForReportStopMiningInfo] no work id")
		return
	end
	local strInterfaceName = "eventWork"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetPeerID()))
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strWorkID"]))
	if IsRealString(tUserConfig["tUserInfo"]["strOpenID"]) then
		strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strOpenID"]))
	end	
	strInterfaceParam = strInterfaceParam .. "&status=" .. Helper:UrlEncode(tostring(strStatus))
	local strParam = self:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  self:FormatRequestUrl(strParam)
	TipLog("[QuerySvrForReportStopMiningInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

--客户端解绑Url
function ApiInterfaceModule:GetUnBindUrl()
	local tUserConfig = self:GetUserConfig()
	local strOpenID = tFunctionHelper.FetchValueByPath(tUserConfig, {"tUserInfo", "strOpenID"})
	local strWorkID = tFunctionHelper.FetchValueByPath(tUserConfig, {"tUserInfo", "strWorkID"})
	if not IsRealString(strWorkID) or not IsRealString(strOpenID) then
		return
	end
	local strInterfaceName = "unbind"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetPeerID()))
				.."&workerID=" .. Helper:UrlEncode(tostring(strWorkID))
				.. "&openID=" .. Helper:UrlEncode(tostring(strOpenID))
	local strGUID = tFunctionHelper.GetMachineID()
	if IsRealString(strGUID) then
		strInterfaceParam = strInterfaceParam .. "&param1=" .. Helper:UrlEncode(strGUID)
	end	
	local strParam = self:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  self:FormatRequestUrl(strParam)
	TipLog("[GetUnBindUrl] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function ApiInterfaceModule:QuerySvrForGetHistoryInfo(strType)
	local tUserConfig = self:GetUserConfig()
	if not tUserConfig["tUserInfo"]["strWorkID"] then
		TipLog("[QuerySvrForGetHistoryInfo] strWorkID = nil")
		return
	end
	local strInterfaceName = "getHistory"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetPeerID()))
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strWorkID"]))
	strInterfaceParam = strInterfaceParam .. "&type=" .. Helper:UrlEncode((tostring(strType)))
	local strParam = self:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  self:FormatRequestUrl(strParam)
	TipLog("[QuerySvrForGetHistoryInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

--接口定义 end

--与服务端通信逻辑--
function ApiInterfaceModule:GetServerJsonData(strUrl,fnCallBack)
	tFunctionHelper.NewAsynGetHttpContent(strUrl, false
	, function(nRet, strContent, respHeaders)
		TipLog("[GetServerJsonData] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
				
		if 0 ~= nRet then
			TipLog("[GetServerJsonData] download failed.")
			self:ReportInterfaceErrorInfo(strUrl, "downfail")
			fnCallBack(false)
			return
		end
		
		local tabInfo = tFunctionHelper.DeCodeJson(strContent)		
		if type(tabInfo) ~= "table" 
			or tabInfo["rtn"] ~= 0 then
			TipLog("[GetServerJsonData] parse json failed, strUrl = " .. tostring(strUrl))
			if type(tabInfo) ~= "table" then
				self:ReportInterfaceErrorInfo(strUrl, "decodefail")
			else
				local nRtn = tabInfo["rtn"] or -1
				self:ReportInterfaceErrorInfo(strUrl, "rtnfail", tostring(nRtn))
			end
			fnCallBack(false,tabInfo)
			return
		end
		fnCallBack(true,tabInfo)
		return
	end)	
end

function ApiInterfaceModule:ReportInterfaceErrorInfo(strUrl, strFu6, strFu8)
	local bReport = ServerCfg:GetServerCfgData({"tReportCfg", "bInterfaceError"})
	if not bReport then
		return
	end
	local _,_,strInterfaceName = string.find(tostring(strUrl), ".+/([%w]+)?")
	local tStatInfo = {}
	tStatInfo.fu1 = "interfaceerror"
	tStatInfo.fu5 = strInterfaceName
	tStatInfo.fu6 = strFu6
	tStatInfo.fu7 = strUrl
	if IsRealString(strFu8) then
		tStatInfo.fu8 = strFu8
	end	
	StatisticClient:SendClientErrorReport(tStatInfo)
end

function ApiInterfaceModule:ReportClientInfoToServer(bForce)
	if bForce or not self._bHasReportClientConf then
		local strUrl = self:QuerySvrForReportClientInfo()
		strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
		self:SendMinerInfoToServer(strUrl,3)
		self._bHasReportClientConf = true
	end	
end

function ApiInterfaceModule:SendMinerInfoToServer(strUrl,nRetryTimes)
	local function fnCallback(bRet, tabInfo)	
		if not bRet then
			nRetryTimes = nRetryTimes -1
			if nRetryTimes > 0 then
				self:SendMinerInfoToServer(strUrl,nRetryTimes)
			end	
		end
	end
	self:GetServerJsonData(strUrl, fnCallback)
end

function ApiInterfaceModule:ReportClientInfoToServer(bForce)
	if bForce or not self._bHasReportClientConf then
		local strUrl = self:QuerySvrForReportClientInfo()
		strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
		self:SendMinerInfoToServer(strUrl,3)
		self._bHasReportClientConf = true
	end	
end

function ApiInterfaceModule:SendStopMiningInfoToServer(strStatus, funResult)
	local strUrl = self:QuerySvrForReportStopMiningInfo(strStatus)
	if not IsRealString(strUrl) then
		if type(funResult) == "function" then
			funResult(false, nil)
		end
		return
	end
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	local function fnCallback(bRet, tabInfo)
		if type(funResult) == "function" then
			funResult(bRet, tabInfo)
		end
	end
	self:GetServerJsonData(strUrl, fnCallback)
end

function ApiInterfaceModule:SendUnBindInfoToServer(funResult)
	local strUrl = self:GetUnBindUrl()
    if not IsRealString(strUrl) then
		funResult(false)
		return
	end 
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	self:GetServerJsonData(strUrl, funResult)
end

--获取workID
function ApiInterfaceModule:GetUserWorkID(funResult)
	local function funCallBack(bSuccess, tabInfo)
		if bSuccess then
			local tUserConfig = self:GetUserConfig()
			local strWorkID = tabInfo["data"]["workerID"]
			tUserConfig["tUserInfo"]["strWorkID"] = strWorkID
			tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
			funResult(true,strWorkID)
		else	
			funResult(false)
		end
	end
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	local strWorkID = tUserConfig["tUserInfo"]["strWorkID"]
	
	if not IsRealString(strWorkID) then
		local strUrl = self:QuerySvrForWorkID()
		strUrl = strUrl.."&rd="..tostring(tipUtil:GetCurrentUTCTime())
		self:GetServerJsonData(strUrl, funCallBack)
		return
	end
	if strWorkID ~= string.lower(strWorkID) 
		or string.find(strWorkID, "_") ~= nil  
		or string.find(strWorkID, "-") ~= nil then
		local strUrl = self:QuerySvrForChangeWorkID(strWorkID)
		strUrl = strUrl.."&rd="..tostring(tipUtil:GetCurrentUTCTime())
		self:GetServerJsonData(strUrl, funCallBack)
		return
	end	
	funResult(true,strWorkID)
end

--获取微信消息
function ApiInterfaceModule:GetQrcodeInfo(strWorkID, funResult)
	local strUrl = self:QuerySvrForQrcodeInfo(strWorkID)
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	self:GetServerJsonData(strUrl, funResult)
end

--轮训二维码绑定
function ApiInterfaceModule:CycleQuerySeverForBindResult(funResult)
	local strUrl = self:QuerySvrForLoginInfo()
	strUrl = strUrl.."&rd="..tostring(tipUtil:GetCurrentUTCTime())
	self:GetServerJsonData(strUrl, funResult)
end

--查询客户端信息
--该接口间隔一定时间调一次 默认5分钟
function ApiInterfaceModule:UpdateWorkerBalance(nBalance)
	if type(self._tabGetWorkerInfo) ~= "table" 
		or type(self._tabGetWorkerInfo["data"]) ~= "table" then
		return
	end
	self._tabGetWorkerInfo["data"]["balance"] = nBalance
end

function ApiInterfaceModule:UpdateWorkerInfo(tabGetWorkerInfo, nLastGetWorkerTime)
	self._tabGetWorkerInfo = tabGetWorkerInfo
	self._nLastGetWorkerTime = nLastGetWorkerTime
end

function ApiInterfaceModule:QueryWorkerInfo(funResult)
	local nInterval = tonumber(ServerCfg:GetServerCfgData({"tServerInterfaceCfg", "nGetWorkInfoInterval"})) or 5*60
	local nCurrentTime = tFunctionHelper.GetCurrentServerTime()
	self._nLastGetWorkerTime = self._nLastGetWorkerTime or 0
	if math.abs(nCurrentTime - self._nLastGetWorkerTime) < nInterval 
		and type(self._tabGetWorkerInfo) == "table" then
		funResult(true, self._tabGetWorkerInfo)
		return
	end
	local strUrl = self:QuerySvrForWorkerInfo()
	if not IsRealString(strUrl) then
		funResult(false)
		return
	end
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[QueryWorkerInfo] strUrl = " .. strUrl)
	
	self:GetServerJsonData(strUrl, funResult)
end

--上报算力
function ApiInterfaceModule:PushCalcInfo(nMiningSpeed, funResult)
	local strUrl = self:QuerySvrForPushCalcInfo(nMiningSpeed)
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[PushCalcInfo] strUrl = " .. strUrl)
	self:GetServerJsonData(strUrl, funResult)
end

--提现接口
function ApiInterfaceModule:TakeCashToServer(nMoney)
	local strUrl = self:QuerySvrForTakeCashInfo(nMoney)
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[TakeCashToServer] strUrl = " .. strUrl)
	local function fnTakeCashCallBack(bRet, tabInfo)
		self:DispatchEvent("OnTakeCashToServer", bRet, tabInfo)
	end
	self:GetServerJsonData(strUrl, fnTakeCashCallBack)
end

--查询收益
function ApiInterfaceModule:QueryHistoryIncome(strType, funResult)
	local strUrl = self:QuerySvrForGetHistoryInfo(strType)
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[QueryHistoryIncome] strUrl = " .. strUrl)
	self:GetServerJsonData(strUrl, funResult)
end

--矿池配置
function ApiInterfaceModule:MakePoolCfgRequestUrl(strCfgName)
	local strStamp = tFunctionHelper.GetTimeStamp()
	
	local tUserConfig = self:GetUserConfig()
	local nLastUpdateCfgTime = tFunctionHelper.FetchValueByPath(tUserConfig, {"tSvrPoolInfo", strCfgName, "nLastUpdateCfgTime"})
	if nLastUpdateCfgTime ~= nil then
		strStamp = "?stamp=" .. tostring(nLastUpdateCfgTime)
	end
	local strReguestUrl = self._strSeverConfigPrefix .. "/static/" .. tostring(strCfgName) .. strStamp
	TipLog("[QuerySvrForPoolCfg] strReguestUrl = " .. tostring(strReguestUrl))
	return strReguestUrl
end

--矿池配置
function ApiInterfaceModule:QueryRateInfo(funResult)
	local strInterfaceName = "/getClassInfo"
	local strUrl =  self:FormatRequestUrl(strInterfaceName)
	strUrl = strUrl .. "?rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[QueryRateInfo] strUrl = " .. strUrl)
	self:GetServerJsonData(strUrl, funResult)
end