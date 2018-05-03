local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local IPCUtil = XLGetObject("IPC.Util")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local tFunctionHelper = XLGetGlobal("FunctionHelper")

ObjectBase = XLGetGlobal("ObjectBase")
ClientWorkModule = ObjectBase:New()
XLSetGlobal("ClientWorkModule", ClientWorkModule)

ClientWorkModule._strSeverInterfacePrefix = "http://api.eastredm.com/pc"
ClientWorkModule._strSeverConfigPrefix = "http://conf.eastredm.com"

ClientWorkModule._MiningType = 0
ClientWorkModule._WorkClient = nil

--心跳接口
ClientWorkModule._WorkingTimerId = nil
ClientWorkModule._Balance = 0
ClientWorkModule._LastQueryBalanceTime = 0

--UI界面工作状态
--
ClientWorkModule.UI_STATE = {}
ClientWorkModule.UI_STATE.STOPPED = 0
ClientWorkModule.UI_STATE.STARTING = 1
ClientWorkModule.UI_STATE.PREPARE_WORKID = 2
ClientWorkModule.UI_STATE.PREPARE_POOL = 3
ClientWorkModule.UI_STATE.CALCULATE = 4
ClientWorkModule._UIWorkState = ClientWorkModule.UI_STATE.STOPPED

--常量
--客户端状态
ClientWorkModule.CLIENT_STATE = {}
ClientWorkModule.CLIENT_STATE.CALCULATE = 0
ClientWorkModule.CLIENT_STATE.PREPARE = 1
ClientWorkModule.CLIENT_STATE.EEEOR = 2
ClientWorkModule.CLIENT_STATE.AUTO_EXIT = 3

--重试
ClientWorkModule.CONNECT_MAX_COUNT = 3
ClientWorkModule.CONNECT_RETRY_COUNT = 0

ClientWorkModule._ReConnectSvrTimerId = nil

--
ClientWorkModule._tabGetWorkerInfo = nil
ClientWorkModule._nLastGetWorkerTime = 0
ClientWorkModule._strLastPoolType = ""
	
ClientWorkModule._nLastPushCalcReportUTC = 0
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
	tipUtil:Log("ClientWorkModule: " .. tostring(strLog))
end

--[[
function ClientWorkModule:LoadGenOilClient()
	local strClientPath = __document.."\\..\\GenOilClient.lua"
	local Module = XLLoadModule(strClientPath)
end

function ClientWorkModule:LoadZcashNClient()
	local strClientPath = __document.."\\..\\ZcashNClient.lua"
	local Module = XLLoadModule(strClientPath)
end

function ClientWorkModule:LoadZcashAClient()
	local strClientPath = __document.."\\..\\ZcashAClient.lua"
	local Module = XLLoadModule(strClientPath)
end
--]]
function ClientWorkModule:Init()
	self:InitListener()
end

function ClientWorkModule:MakeInterfaceMd5(strInterface,strInterfaceParam)
	local strParam = "/" .. strInterface .. "?" .. tostring(strInterfaceParam)
	local strMd5 = tipUtil:GetStringMD5(strParam)
	if string.lower(tostring(strParam)) ~= string.lower(tostring(strMd5)) then
		strParam = strParam .. "&md5=" .. strMd5
	end	
	return strParam
end

function ClientWorkModule:GetUserConfig()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	return tUserConfig
end

function ClientWorkModule:GetHeartbeatInterval()
	local interval = 1
	--[[
	local nHeartbeatInterval = 60
	if type(g_ServerConfig) == "table" then
		local tServerInterfaceCfg = g_ServerConfig["tServerInterfaceCfg"]
		if type(tServerInterfaceCfg) == "table" then
			nHeartbeatInterval = tServerInterfaceCfg["nReportCalcInterval"] or 60
		end
	end	
	--]]
	local nHeartbeatInterval = tonumber(ServerCfg:GetServerCfgData({"tServerInterfaceCfg", "nReportCalcInterval"})) or 60
	nHeartbeatInterval = math.ceil(nHeartbeatInterval/interval)
	return nHeartbeatInterval
end

function ClientWorkModule:CheckMachineBindState()
    local tUserConfig = self:GetUserConfig()
	if type(tUserConfig["tUserInfo"]) == "table" and IsRealString(tUserConfig["tUserInfo"]["strWorkID"]) then
		self:QueryWorkerInfo()
	end
end


function ClientWorkModule:MakeSvrPoolCfgRequestUrl()
	local strStamp = tFunctionHelper.GetTimeStamp()
	local tUserConfig = self:GetUserConfig()
	
	local strPoolKey = self._WorkClient.GetPoolCfgName()
	if type(tUserConfig["tSvrPoolInfo"]) ~= "table" then
		tUserConfig["tSvrPoolInfo"] = {}
	end
	if type(tUserConfig["tSvrPoolInfo"][strPoolKey]) ~= "table" then
		tUserConfig["tSvrPoolInfo"][strPoolKey] = {}
	end
	
	local nLastUpdateCfgTime = tUserConfig["tSvrPoolInfo"][strPoolKey]["nLastUpdateCfgTime"]
	if nLastUpdateCfgTime ~= nil then
		strStamp = "?stamp=" .. tostring(nLastUpdateCfgTime)
	end
	local strPoolCfgName = self._WorkClient.GetPoolCfgName()
	local strReguestUrl = self._strSeverConfigPrefix .. "/static/" .. tostring(strPoolCfgName) .. strStamp
	TipLog("[QuerySvrForPoolCfg] strReguestUrl = " .. tostring(strReguestUrl))
	return strReguestUrl
end

function ClientWorkModule:FormatRequestUrl(strParam)
	return self._strSeverInterfacePrefix .. strParam
end

function ClientWorkModule:CheckCanReconnect()
	TipLog("[CheckCanReconnect] current retry cnt = " .. tostring(self.CONNECT_RETRY_COUNT))
	if self.CONNECT_RETRY_COUNT < self.CONNECT_MAX_COUNT then
		self.CONNECT_RETRY_COUNT = self.CONNECT_RETRY_COUNT + 1
		return true
	end
	return false
end

function ClientWorkModule:ResetReconnectCnt()
	self.CONNECT_RETRY_COUNT = 0
end

function ClientWorkModule:GetReconnectInterval()
	local nMaxInterval = self:GetHeartbeatInterval()
	if nMaxInterval < 3*60 then
		nMaxInterval = 3*60
	end
	self.CONNECT_RETRY_COUNT = self.CONNECT_RETRY_COUNT + 1
	local nInterval = (self.CONNECT_RETRY_COUNT)*30*1000
	if nInterval > nMaxInterval*1000 then
		nInterval = nMaxInterval*1000
	end
	return nInterval
end

function ClientWorkModule:QuerySvrForWorkID()
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

function ClientWorkModule:QuerySvrForChangeWorkID(strWorkID)
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

function ClientWorkModule:QuerySvrForLoginInfo()
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

function ClientWorkModule:QuerySvrForQrcodeInfo(strWorkID)
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

function ClientWorkModule:QuerySvrForReportClientInfo()
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

function ClientWorkModule:QuerySvrForReportPoolInfo()
	local tUserConfig = self:GetUserConfig()
	local strInterfaceName = "registeCalc"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetPeerID()))
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strWorkID"]))
	if IsRealString(tUserConfig["tUserInfo"]["strOpenID"]) then
		strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strOpenID"])))
	end
	strInterfaceParam = strInterfaceParam .. "&pool=" .. Helper:UrlEncode((tostring(self._WorkClient.GetCurrentPool())))
	strInterfaceParam = strInterfaceParam .. "&account=" .. Helper:UrlEncode((tostring(self._WorkClient.GetCurrentAccount())))
	local strParam = self:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  self:FormatRequestUrl(strParam)
	TipLog("[QuerySvrForReportPoolInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function ClientWorkModule:QuerySvrForPushCalcInfo(nSpeed)
	local tUserConfig = self:GetUserConfig()
	local strInterfaceName = "pushCalc"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetPeerID()))
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strWorkID"]))
	if IsRealString(tUserConfig["tUserInfo"]["strOpenID"]) then
		strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strOpenID"])))
	end
	local strSpeedFormat = self._WorkClient.GetSpeedFormat(nSpeed)
	strInterfaceParam = strInterfaceParam .. "&speed=" .. Helper:UrlEncode(strSpeedFormat)
	local strPoolInfo = self._WorkClient.GetCurrentPool()
	if not IsRealString(strPoolInfo) then
		strPoolInfo = self._WorkClient.GetDefaultPoolType()
	end
	strInterfaceParam = strInterfaceParam .. "&p=" .. Helper:UrlEncode((tostring(strPoolInfo)))
	--strInterfaceParam = strInterfaceParam .. "&account=" .. Helper:UrlEncode((tostring(self._WorkClient.GetCurrentAccount())))
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

function ClientWorkModule:QuerySvrForTakeCashInfo(nMoney)
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

function ClientWorkModule:QuerySvrForWorkerInfo()
	local tUserConfig = self:GetUserConfig()
	local strInterfaceName = "getWorkerInfo"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetPeerID()))
	local strWorkID = tUserConfig["tUserInfo"]["strWorkID"]
	if not IsRealString(strWorkID) then
		return nil
	end
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(tostring(strWorkID))
	if IsRealString(tUserConfig["tUserInfo"]["strOpenID"]) then
		strInterfaceParam = strInterfaceParam .. "&openID=" .. Helper:UrlEncode((tostring(tUserConfig["tUserInfo"]["strOpenID"])))
	end
	local strPoolInfo = self._WorkClient.GetCurrentPool()
	if not IsRealString(strPoolInfo) then
		strPoolInfo = self._WorkClient.GetDefaultPoolType()
	end
	strInterfaceParam = strInterfaceParam .. "&p=" .. Helper:UrlEncode((tostring(strPoolInfo)))
	local strParam = self:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  self:FormatRequestUrl(strParam)
	TipLog("[QuerySvrForWorkInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function ClientWorkModule:QuerySvrForReportStopMiningInfo(strStatus)
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
function ClientWorkModule:GetUnBindUrl()
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

function ClientWorkModule:QuerySvrForGetHistoryInfo(strtype)
	local tUserConfig = self:GetUserConfig()
	if not tUserConfig["tUserInfo"]["strWorkID"] then
		TipLog("[QuerySvrForGetHistoryInfo] strWorkID = nil")
		return
	end
	local strInterfaceName = "getHistory"
	local strInterfaceParam = "peerid=" .. Helper:UrlEncode(tostring(tFunctionHelper.GetPeerID()))
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strWorkID"]))
	strInterfaceParam = strInterfaceParam .. "&type=" .. Helper:UrlEncode((tostring(strtype)))
	local strParam = self:MakeInterfaceMd5(strInterfaceName, strInterfaceParam)
	local strReguestUrl =  self:FormatRequestUrl(strParam)
	TipLog("[QuerySvrForGetHistoryInfo] strReguestUrl = " .. strReguestUrl)
	return strReguestUrl
end

function ClientWorkModule:ReportClientInfoToServer(bForce)
	if bForce or not self._bHasReportClientConf then
		local strUrl = self:QuerySvrForReportClientInfo()
		strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
		self:SendMinerInfoToServer(strUrl,3)
		self._bHasReportClientConf = true
	end	
end

function ClientWorkModule:ReportMiningPoolInfoToServer()
	local strUrl = self:QuerySvrForReportPoolInfo()
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	self:SendMinerInfoToServer(strUrl,3)
end

function ClientWorkModule:SetMachineNameChangeInfo()
	self:ReportClientInfoToServer(true)
end

--获取当前余额
function ClientWorkModule:GetUserCurrentBalance()
	return self._Balance
end

function ClientWorkModule:SetUserCurrentBalance(nBalance)
	self._Balance = nBalance
end

function ClientWorkModule:GetLastQueryBalanceTime()
	return self._LastQueryBalanceTime
end

--获取客户端状态
function ClientWorkModule:GetClientCurrentState()
	if self._WorkClient == nil then
		return nil
	end
	return self._WorkClient.GetCurrentClientWorkState()
end

--获取当前客户端挖矿速度
function ClientWorkModule:GetClientMiningSpeed()
	if self._WorkClient == nil then
		return 0
	end
	return self._WorkClient.GetCurrentMiningSpeed()
end

function ClientWorkModule:GetClientLastAverageHashRate()
	if self._WorkClient == nil then
		return 0
	end
	return self._WorkClient.GetLastAverageHashRate()
end

function ClientWorkModule:GetUIWorkState()
	return self._UIWorkState
end
--是否在工作
function ClientWorkModule:CheckIsWorking()
	if self:GetUIWorkState() == self.UI_STATE.STOPPED then
		return false
	else
		return true
	end
end

--是否在准备
function ClientWorkModule:CheckIsPrepare()
	local nUIWorkState = self:GetUIWorkState()
	if nUIWorkState == self.UI_STATE.STARTING
		or nUIWorkState == self.UI_STATE.PREPARE_WORKID 
		or nUIWorkState == self.UI_STATE.PREPARE_POOL 
		or (nUIWorkState == self.UI_STATE.CALCULATE and self:GetClientCurrentState() ~= self.CLIENT_STATE.CALCULATE) then
		return true
	end
	return false
end

--是否在计算
function ClientWorkModule:CheckIsCalculate()
	if self:GetUIWorkState() == self.UI_STATE.CALCULATE and self:GetClientCurrentState() == self.CLIENT_STATE.CALCULATE then
		return true
	else
		return false
	end
end

--获取工作客户端对象
function ClientWorkModule:GetWorkClient()
	return self._WorkClient
end

--返回当前挖矿速度的比例系数
function ClientWorkModule:GetSvrAverageMiningSpeed(strCoinType)
	local tUserConfig = self:GetUserConfig()
	if type(tUserConfig["tSpeedRate"]) ~= "table" then
		tUserConfig["tSpeedRate"] = {}
	end
	return tUserConfig["tSpeedRate"][strCoinType] or 0
end

function ClientWorkModule:UpdateAverageMiningSpeed(strCoinType, nSpeedRate)
	local tUserConfig = self:GetUserConfig()
	if type(tUserConfig["tSpeedRate"]) ~= "table" then
		tUserConfig["tSpeedRate"] = {}
	end
	if type(nSpeedRate) == "number" then
		tUserConfig["tSpeedRate"][strCoinType] = nSpeedRate
	end
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
end

function ClientWorkModule:CheckIsGettedWorkID()
	local tUserConfig = self:GetUserConfig()
	if IsRealString(tUserConfig["tUserInfo"]["strWorkID"]) then
		return true
	end
	return false
end

function ClientWorkModule:CheckIsBinded()
	local tUserConfig = self:GetUserConfig()
	if type(tUserConfig["tUserInfo"]) == "table"
		and IsRealString(tUserConfig["tUserInfo"]["strWorkID"]) 
		and tUserConfig["tUserInfo"]["bBind"] then
		return true
	end
	return false
end

function ClientWorkModule:CheckShoudAutoMining()
	local strCmdline = tipUtil:GetCommandLine()
	--修改为按参数判断是否自动挖
	if string.find(string.lower(tostring(strCmdline)), "/working") then
		return true
	else
		return false
	end
end

function ClientWorkModule:DoAutoMining()
	if not self:CheckIsWorking() then
		self:NotifyStart()
	end
end

--UI交互
function ClientWorkModule:SetUserBindInfo(tabBindInfo)
	local tUserConfig = self:GetUserConfig()
	tUserConfig["tUserInfo"]["strHeadImgUrl"] = tabBindInfo["data"]["wxHeadImgUrl"]
	tUserConfig["tUserInfo"]["strNickName"] = tabBindInfo["data"]["wxName"]
	tUserConfig["tUserInfo"]["strOpenID"] = tabBindInfo["data"]["wxOpenID"]
	tUserConfig["tUserInfo"]["bBind"] = true
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
	--self:ReportClientInfoToServer()
	-----------------------UI相关
	UIInterface:ChangeClientTitle("共享赚宝")
	self:QueryWorkerInfo()
end

--
function ClientWorkModule:ReportInterfaceErrorInfo(strUrl, strFu6, strFu8)
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
--与服务端通信逻辑--
function ClientWorkModule:GetServerJsonData(strUrl,fnCallBack)
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
--事件处理
function ClientWorkModule:InitListener()
	--self:AddListener("OnEventCallBack", OnEventCallBack)
	self:AddListener("OnUnBindCallBack", self.OnUnBindCallBack, self)
	self:AddListener("OnGetUserWorkID", self.OnGetUserWorkID, self)
	self:AddListener("OnUpdateCfgFinish", self.OnUpdateCfgFinish, self)
	self:AddListener("OnSvrPoolCfgUpdate", self.OnSvrPoolCfgUpdate, self)
	self:AddListener("OnBindResultCallback", self.OnBindResultCallback, self)
	self:AddListener("OnQrcodeInfoCallBack", self.OnQrcodeInfoCallBack, self)
	self:AddListener("OnQueryWorkerInfo", self.OnQueryWorkerInfo, self)
	self:AddListener("OnQueryClientInfo", self.OnQueryClientInfo, self)
	self:AddListener("OnFinishPrepareWorkID", self.OnFinishPrepareWorkID, self)
    self:AddListener("OnPriorityChange", self.OnPriorityChange, self)
end

function ClientWorkModule:SendMinerInfoToServer(strUrl,nRetryTimes,fnSuccess)
	local function fnCallback(bRet, tabInfo)	
		if not bRet then
			nRetryTimes = nRetryTimes -1
			if nRetryTimes > 0 then
				self:SendMinerInfoToServer(strUrl,nRetryTimes,fnSuccess)
			end	
		else
			if fnSuccess ~= nil then
				fnSuccess(tabInfo)
			end	
		end
	end
	self:GetServerJsonData(strUrl, fnCallback)
end

function ClientWorkModule:SendStopMiningInfoToServer(strStatus, func)
	local strUrl = self:QuerySvrForReportStopMiningInfo(strStatus)
	if not IsRealString(strUrl) then
		func(false, nil)
		return
	end
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	local function fnCallback(bRet, tabInfo)
		if type(func) == "function" then
			func(bRet, tabInfo)
		end
	end
	self:GetServerJsonData(strUrl, fnCallback)
end

function ClientWorkModule:OnUnBindCallBack(event, bSuccess)
	if not bSuccess then
		UIInterface:UnBindFail()
	else
		if self:CheckIsWorking() then
			self:NotifyQuit()
		end
		UIInterface:UnBindSuccess()
	end
end

--解绑三步
--[[
1.清空绑定数据
2.退出挖矿
3.更新UI
--]]
function ClientWorkModule:SendUnBindInfoToServer()
	--self:AddListener("OnUnBindCallBack", OnUnBindCallBack)
	local strUrl = self:GetUnBindUrl()
    if not IsRealString(strUrl) then
		self:DispatchEvent("OnUnBindCallBack", false)
		return
	end 
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	local function fnCallback(bRet, tabInfo)	
		self:DispatchEvent("OnUnBindCallBack", bRet, tabInfo)
	end
	self:GetServerJsonData(strUrl, fnCallback)
end
--[[
function OnUnBindSuccess()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["tUserInfo"] = nil
	SaveConfigToFileByKey("tUserConfig")
	ChangeClientTitle("共享赚宝 (未绑定)")
	if CheckIsWorking() then
		NotifyQuit()
	end
	ChangeMainBodyPanel("MiningPanel")
	UpdateClientUnBindState()
end	

function OnUnBindFail()
	SendUIReport("unbindclient","fail")
	local wnd = GetMainHostWnd()
	if not wnd then
		return
	end
	local objtree = wnd:GetBindUIObjectTree()
	local objRootCtrl = objtree:GetUIObject("root.layout:root.ctrl")
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	objMainBodyCtrl:UpdateClientUnBindFailState()
	ChangeMainBodyPanel("MiningPanel")
end	
--]]
function ClientWorkModule:UnBindingClientFromClient()
	--Statistic:SendUIReport("unbindclient","start")
	self:SendUnBindInfoToServer()
end

function ClientWorkModule:UnBindingClientFromServer()
	--不用再发统计了
	--OnUnBindSuccess()
	self:DispatchEvent("OnUnBindCallBack", true)
end

function ClientWorkModule:OnGetUserWorkID(event, bSuccess, tabInfo, fnCallBack)
	if bSuccess then
		local tUserConfig = self:GetUserConfig()
		local strWorkID = tabInfo["data"]["workerID"]
		tUserConfig["tUserInfo"]["strWorkID"] = strWorkID
		tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
		fnCallBack(true,strWorkID)
	else	
		fnCallBack(false)
	end
end

function ClientWorkModule:GetUserWorkID(fnCallBack)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	local strWorkID = tUserConfig["tUserInfo"]["strWorkID"]
	
	local function fnGetWorkIDCallback(bRet, tabInfo)	
		self:DispatchEvent("OnGetUserWorkID", bRet, tabInfo, fnCallBack)
	end
	
	if not IsRealString(strWorkID) then
		local strUrl = self:QuerySvrForWorkID()
		strUrl = strUrl.."&rd="..tostring(tipUtil:GetCurrentUTCTime())
		self:GetServerJsonData(strUrl, fnGetWorkIDCallback)
		return
	end
	if strWorkID ~= string.lower(strWorkID) 
		or string.find(strWorkID, "_") ~= nil  
		or string.find(strWorkID, "-") ~= nil then
		local strUrl = self:QuerySvrForChangeWorkID(strWorkID)
		strUrl = strUrl.."&rd="..tostring(tipUtil:GetCurrentUTCTime())
		self:GetServerJsonData(strUrl, fnGetWorkIDCallback)
		return
	end	
	fnCallBack(true,strWorkID)
end

--矿池配置更新
function ClientWorkModule:CheckSvrPoolCfg(nLastCfg)
	local tUserConfig = self:GetUserConfig()
	
	local strPoolKey = self._WorkClient.GetPoolCfgName()
	if type(tUserConfig["tSvrPoolInfo"]) ~= "table" then
		tUserConfig["tSvrPoolInfo"] = {}
	end
	if type(tUserConfig["tSvrPoolInfo"][strPoolKey]) ~= "table" then
		tUserConfig["tSvrPoolInfo"][strPoolKey] = {}
	end
	local tPoolList = tUserConfig["tSvrPoolInfo"][strPoolKey]
	if type(tPoolList) ~= "table" or #tPoolList < 1 then
		return false
	end
	local nLastUpdateCfgTime = tUserConfig["tSvrPoolInfo"][strPoolKey]["nLastUpdateCfgTime"]
	nLastUpdateCfgTime = tonumber(nLastUpdateCfgTime) or 0
	if nLastCfg > nLastUpdateCfgTime then
		return false
	end
	return true
end

function ClientWorkModule:OnSvrPoolCfgUpdate(event, bUpdate, tabInfo)
	--更新配置先
	--然后转发消息
	TipLog("[OnSvrPoolCfgUpdate] bUpdate = " .. tostring(bUpdate))
	if bUpdate and tabInfo then
		local tUserConfig = self:GetUserConfig()
		
		local strPoolKey = self._WorkClient.GetPoolCfgName()
		if type(tUserConfig["tSvrPoolInfo"]) ~= "table" then
			tUserConfig["tSvrPoolInfo"] = {}
		end
		if type(tUserConfig["tSvrPoolInfo"][strPoolKey]) ~= "table" then
			tUserConfig["tSvrPoolInfo"][strPoolKey] = {}
		end
		
		local strPoolVerKey = self._WorkClient.GetPoolVerKey() or "p"
		local tabPool = tabInfo["data"][tostring(strPoolVerKey)] or {}
		local tabUserPool = {}
		for index = 1, #tabPool do
			if type(tabPool[index]) == "table" and tFunctionHelper.CheckPeerIDList(tabPool[index]["pidlist"]) then
				tabUserPool[#tabUserPool+1] = tabPool[index]
			end
		end
		tUserConfig["tSvrPoolInfo"][strPoolKey] = tabUserPool
		
		if self._LastCfg ~= nil then
			tUserConfig["tSvrPoolInfo"][strPoolKey]["nLastUpdateCfgTime"] = self._LastCfg
		end	
		tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
		self:DispatchEvent("OnUpdateCfgFinish", bUpdate)
	elseif bUpdate and not tabInfo then
		UIInterface:SetStateInfoToUser("连接服务器失败，重试中...")
		SetOnceTimer(function()
			self:GetSvrPoolCfg()
		end, 10*1000)
	elseif not bUpdate then
		self:DispatchEvent("OnUpdateCfgFinish", bUpdate)
	end
	
	--[[
	if self:GetUIWorkState() == self.UI_STATE.PREPARE_POOL then
		if not bGet then
			SetStateInfoToUser("连接服务器失败，重试中...")
			SetOnceTimer(function()
				GetSvrPoolCfg(nLastCfg)
			end, 5*1000)
			return
		end
		self:StartClient()
	elseif GetUIWorkState() == UI_STATE_CALCULATE or GetUIWorkState() == UI_STATE_STARTING then
		if bUpdate then
			g_WorkClient.ReStartClientByNewPoolList()
		end
	end
	--]]
end

function ClientWorkModule:UpdateSvrPoolCfg(tabInfo)
	local nLastCfg = tonumber(tabInfo["data"]["lastCfg"]) or 0
	self._LastCfg = nLastCfg
	if not self:CheckSvrPoolCfg(nLastCfg) then
		self:GetSvrPoolCfg()
	else
		self:DispatchEvent("OnSvrPoolCfgUpdate", false, nil)
		--fnCallBack(true)
	end
	--[[
	if bRet then
		self:OnSvrPoolCfgUpdate(true,false,nLastCfg)
	else
		self:GetSvrPoolCfg(nLastCfg)
	end
	--]]
end

function ClientWorkModule:GetSvrPoolCfg()
	local strUrl = self:MakeSvrPoolCfgRequestUrl()
	local function fnGetNewPoolCallback(tabInfo)
		self:DispatchEvent("OnSvrPoolCfgUpdate", true, tabInfo)
	end
	tFunctionHelper.NewAsynGetHttpContent(strUrl, false
	, function(nRet, strContent, respHeaders)
		TipLog("[GetSvrPoolCfg] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
		if 0 == nRet then
			local tabInfo = tFunctionHelper.DeCodeJson(strContent)
			if type(tabInfo) == "table" 
				and type(tabInfo["data"]) == "table" 
				and type(tabInfo["data"]["p"]) == "table" 
				and #tabInfo["data"]["p"] > 0 then
				fnGetNewPoolCallback(tabInfo)
				return
			end	
		end
		fnGetNewPoolCallback(nil)
	 end
	)
end

function ClientWorkModule:CheckIsPriorityChange(tabNew)
    local tabOld = SupportClientType:GetLocalPriorityTable()
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

function ClientWorkModule:IsProfitMaxFirst(tabForcePlist)
	if #tabForcePlist > 0 and tFunctionHelper.CheckPeerIDList(tabForcePlist) then
		return false
	end
	local tabProfitMax = SupportClientType:GetLocalProfitMaxTable()
	if type(tabProfitMax) ~= "table" or #tabProfitMax == 0 then
		return false
	end
	return true
end

function ClientWorkModule:UpdatePriority(tabInfo)
    if type(tabInfo["data"]["efficiency"]) ~= "table" then
        TipLog("[UpdatePriority] no efficiency info")
        return
    end
    local tabPriorityNew = tFunctionHelper.ConvertTableStrToNum(tabInfo["data"]["efficiency"])
	local tabForcePlist = tabInfo["data"]["forceplist"] or {}
	
	if (not self:IsProfitMaxFirst(tabForcePlist) and (self:CheckIsPriorityChange(tabPriorityNew) or SupportClientType:GetCurrentPriorityMode() ~= 0) )
		or (self:IsProfitMaxFirst(tabForcePlist) and SupportClientType:GetCurrentPriorityMode() == 0) then
        local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
        tUserConfig["tPriority"] = tabPriorityNew
		tUserConfig["tForcePlist"] = tabForcePlist
        tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
        self:DispatchEvent("OnPriorityChange")
    end
end

--二维码绑定
function ClientWorkModule:OnBindResultCallback(event, bSuccess, tabInfo, fnCallBack)
	fnCallBack(bSuccess, tabInfo)
end

function ClientWorkModule:CycleQuerySeverForBindResult(fnCallBack)
	local strUrl = self:QuerySvrForLoginInfo()
	strUrl = strUrl.."&rd="..tostring(tipUtil:GetCurrentUTCTime())
	local function fnBindResultCallback(bRet, tabInfo)
		self:DispatchEvent("OnBindResultCallback", bRet, tabInfo, fnCallBack)
	end
	self:GetServerJsonData(strUrl, fnBindResultCallback)
	
	--[[
	local strBindResult = QuerySvrForLoginInfo()
	strBindResult = strBindResult.."&rd="..tostring(tipUtil:GetCurrentUTCTime())
	NewAsynGetHttpContent(strBindResult, false
	, function(nRet, strContent, respHeaders)
		TipLog("[CycleQuerySeverForBindResult] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
				
		if 0 == nRet then
			local tabInfo = DeCodeJson(strContent)
			if type(tabInfo) ~= "table" 
				or tabInfo["rtn"] ~= 0 then
				TipLog("[CycleQuerySeverForBindResult] Parse Json failed.")
				fnCallBack(false,"解析登陆信息失败")
				return 
			end
			fnCallBack(true,tabInfo)
		else
			fnCallBack(false,"获取绑定二维码信息失败，请检测网络")
		end		
	end,nTimeoutInMS)
	--]]
end

function ClientWorkModule:OnQrcodeInfoCallBack(event, bSuccess, tabInfo, fnCallBack)
	if bSuccess then
		local strQrcodeUrl = tabInfo["data"]["qrcodeUrl"]
		local expire = tonumber(tabInfo["data"]["expire"])
		if type(expire) ~= "number" then
			expire = 60*1000
		end
		TipLog("[OnQrcodeInfoCallBack] strQrcodeUrl = "..tostring(strQrcodeUrl)..", expire = "..tostring(expire))
		local strQrcodePath = tFunctionHelper.GetResSavePath("tmpqrcode.jpg")
		tFunctionHelper.NewAsynGetHttpFile(strQrcodeUrl, strQrcodePath, false, function(bRet, strDownLoadPath)
			TipLog("[OnQrcodeInfoCallBack] NewAsynGetHttpFile:bRet = " .. tostring(bRet) 
					.. ", strURL = " .. tostring(strQrcodeUrl) .. ", strDownLoadPath = " .. tostring(strDownLoadPath))
			if 0 ~= bRet then
				TipLog("[OnQrcodeInfoCallBack] DownLoad failed")
				fnCallBack(false,"下载二维码图片失败")
				return 
			end
			tabInfo["data"]["qrcodePath"] = strDownLoadPath
			fnCallBack(true,tabInfo)
		end, expire)
	else
		fnCallBack(false,"获取绑定二维码信息失败，请检测网络")
	end
end

function ClientWorkModule:DownLoadTempQrcode(fnCallBack)	
	local function fnQrcodeInfoCallBack(bRet, tabInfo)
		self:DispatchEvent("OnQrcodeInfoCallBack", bRet, tabInfo, fnCallBack)
	end
	
	local function fnGetWorkIDResult(bGet,strWorkID)
		if bGet then
			local strUrl = self:QuerySvrForQrcodeInfo(strWorkID)
			strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
			self:GetServerJsonData(strUrl, fnQrcodeInfoCallBack)
		else
			fnCallBack(false)
		end
	end
	self:GetUserWorkID(fnGetWorkIDResult)
	--[[
	GetUserWorkID(function(bWorkID,strWorkID)
		if bWorkID then
			local strQrcodeUrl = QuerySvrForQrcodeInfo(strWorkID)
			strQrcodeUrl = strQrcodeUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
			TipLog("[DownLoadTempQrcode] strQrcodeUrl = " .. strQrcodeUrl)
			NewAsynGetHttpContent(strQrcodeUrl, false
			, function(nRet, strContent, respHeaders)
				TipLog("[DownLoadTempQrcode] nRet:"..tostring(nRet)
						.." strContent:"..tostring(strContent))
						
				if 0 == nRet then
					local tabInfo = DeCodeJson(strContent)
					if type(tabInfo) ~= "table" 
						or tabInfo["rtn"] ~= 0 
						or type(tabInfo["data"]) ~= "table" 
						or not IsRealString(tabInfo["data"]["qrcodeUrl"])
						or tonumber(tabInfo["data"]["sceneID"]) == nil then
						TipLog("[DownLoadTempQrcode] Parse Json failed.")
						fnCallBack(false,"解析二维码信息失败")
						return 
					end
					local strQrcodeUrl = tabInfo["data"]["qrcodeUrl"]
					local expire = tonumber(tabInfo["data"]["expire"])
					if type(expire) ~= "number" then
						expire = 60*1000
					end
					TipLog("[DownLoadTempQrcode] strQrcodeUrl = "..tostring(strQrcodeUrl)..", expire = "..tostring(expire))
					local strQrcodePath = GetResSavePath("tmpqrcode.jpg")
					NewAsynGetHttpFile(strQrcodeUrl, strQrcodePath, false, function(bRet, strDownLoadPath)
						TipLog("[DownLoadTempQrcode] NewAsynGetHttpFile:bRet = " .. tostring(bRet) 
								.. ", strURL = " .. tostring(strQrcodeUrl) .. ", strDownLoadPath = " .. tostring(strDownLoadPath))
						if 0 ~= bRet then
							TipLog("[DownLoadTempQrcode] DownLoad failed")
							fnCallBack(false,"下载二维码图片失败")
							return 
						end
						tabInfo["data"]["qrcodePath"] = strDownLoadPath
						--tabInfo["data"]["workerID"] = strWorkID
						fnCallBack(true,tabInfo)
					end, expire)
				else
					fnCallBack(false,"获取绑定二维码信息失败，请检测网络")
				end		
			end)
		else
			fnCallBack(false, strWorkID)
		end
	end)
	--]]
end

--查询客户端信息
function ClientWorkModule:OnQueryWorkerInfo(event, bSuccess, tabInfo, bRetry)
	if bSuccess then 
		self._tabGetWorkerInfo = tabInfo
		self._nLastGetWorkerTime = tFunctionHelper.GetCurrentServerTime()
		self._strLastPoolType = self._WorkClient.GetDefaultPoolType()
		self:UpdateSvrPoolCfg(tabInfo)
		if tabInfo["data"]["status"] ~= 1 then
			if self:CheckIsBinded() then
				self:UnBindingClientFromServer()
				self._tabGetWorkerInfo = nil
				self._nLastGetWorkerTime = 0
				self._strLastPoolType = ""
			end	
		end
		if tonumber(tabInfo["data"]["balance"]) ~= nil then
			--g_Balance = tabInfo["data"]["balance"]
			if self._Balance ~= tonumber(tabInfo["data"]["balance"]) then
				self:SetUserCurrentBalance(tabInfo["data"]["balance"])
				UIInterface:UpdateUserBalance()
			end	
		end
		if type(tabInfo["data"]["rate"]) == "table" then
			for strCoinType, nSpeedRate in pairs(tabInfo["data"]["rate"]) do
				self:UpdateAverageMiningSpeed(strCoinType, nSpeedRate)
			end
		end
		self:ResetReconnectCnt()
	else
		if bRetry and self:CheckIsWorking() then
			if not self:CheckCanReconnect() then
				if self:CheckIsWorking() then
					--self:NotifyPause()
					--UIInterface:SetStateInfoToUser("连接赚宝服务器失败")
					self:CheckAndReTryConnectServer()
				end	
			else
				local nInterval = self:GetReconnectInterval()
				UIInterface:SetStateInfoToUser("连接服务器失败，重试中...")
				SetOnceTimer(function()
					self:QueryWorkerInfo(true)
				end, 10*1000)
			end
		end	
	end
end

--该接口间隔一定时间调一次 默认5分钟
function ClientWorkModule:QueryWorkerInfo(bRetry)
	local nInterval = tonumber(ServerCfg:GetServerCfgData({"tServerInterfaceCfg", "nGetWorkInfoInterval"})) or 5*60
	local nCurrentTime = tFunctionHelper.GetCurrentServerTime()
	if math.abs(nCurrentTime - self._nLastGetWorkerTime) < nInterval and type(self._tabGetWorkerInfo) == "table" 
		and self._strLastPoolType == self._WorkClient.GetDefaultPoolType() then
		self:UpdateSvrPoolCfg(self._tabGetWorkerInfo)
		return
	end
	local strUrl = self:QuerySvrForWorkerInfo()
	if not IsRealString(strUrl) then
		return
	end
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[QueryWorkerInfo] strUrl = " .. strUrl)
	
	local function fnWorkerInfoCallBack(bSuccess, tabInfo)
		self:DispatchEvent("OnQueryWorkerInfo", bSuccess, tabInfo, bRetry)
	end
	
	self:GetServerJsonData(strUrl, fnWorkerInfoCallBack)
end

--查询客户端信息
function ClientWorkModule:OnQueryClientInfo(event, bSuccess, tabInfo)
	if bSuccess then
		self:ResetReconnectCnt()
		self:UpdateSvrPoolCfg(tabInfo)
        self:UpdatePriority(tabInfo)
		if tabInfo["data"]["status"] ~= 1 then
			if self:CheckIsBinded() then
				self:UnBindingClientFromServer()
				--return
			end	
		end
		if tonumber(tabInfo["data"]["balance"]) ~= nil then
			--g_Balance = tabInfo["data"]["balance"]
			if self._Balance ~= tonumber(tabInfo["data"]["balance"]) then
				self:SetUserCurrentBalance(tabInfo["data"]["balance"])
				UIInterface:UpdateUserBalance()
			end	
		end
		if tonumber(tabInfo["data"]["rate"]) ~= nil then
			strCoinType = self._WorkClient.GetCoinType()
			self:UpdateAverageMiningSpeed(strCoinType, tabInfo["data"]["rate"])
		end
	else
		self:CheckAndReTryConnectServer()
	end
end

function ClientWorkModule:QueryClientInfo(nMiningSpeed)
	local strUrl = self:QuerySvrForPushCalcInfo(nMiningSpeed)
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[QueryClientInfo] strUrl = " .. strUrl)
	
	local function fnClientInfoCallBack(bRet, tabInfo)
		self:DispatchEvent("OnQueryClientInfo", bRet, tabInfo)
	end
	
	self:GetServerJsonData(strUrl, fnClientInfoCallBack)
end

--提现接口
--[[
function ClientWorkModule:OnTakeCashToServer(event, bSuccess, tabInfo)
	在调用处实现
end
--]]
function ClientWorkModule:TakeCashToServer(nMoney)
	local strUrl = self:QuerySvrForTakeCashInfo(nMoney)
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[TakeCashToServer] strUrl = " .. strUrl)
	
	local function fnTakeCashCallBack(bRet, tabInfo)
		self:DispatchEvent("OnTakeCashToServer", bRet, tabInfo)
	end
	self:GetServerJsonData(strUrl, fnTakeCashCallBack)
	--[[
	NewAsynGetHttpContent(strReguestUrl, false
	, function(nRet, strContent, respHeaders)
		TipLog("[TakeCashToServer] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
				
		if 0 == nRet then
			-- forlocal
			strContent = GetLocalSvrCfgWithName("takeCash.json")
			--
			local tabInfo = DeCodeJson(strContent)
			if type(tabInfo) ~= "table" then
				TipLog("[TakeCashToServer] parse info error.")
				fnCallBack(false)
				return
			end
			fnCallBack(true, tabInfo)
		else
			TipLog("[TakeCashToServer] get content failed.")
			fnCallBack(false)
		end	
	end)
	--]]
end

--查询收益接口,strtype = h24 最近24小时，d30 最近1个月
--不同整点才会去请求，否则使用本地
--请求失败显示上次， 颜色用灰色
function ClientWorkModule:CreateIncomeTimeTab(strTabKey,tabValue)
    if type(tabValue) ~= "table" then
        tabValue = {}
    end
    local tabTypeData = {}
    local nCurrentUtc = tFunctionHelper.GetCurrentServerTime() or 0
    local nCYear, nCMonth, nCDay, nCHour = tipUtil:FormatCrtTime(nCurrentUtc)
    if strTabKey == "hour24" then
        for IdxHour=1, 24 do
            tabTypeData[IdxHour] = {}
            local nUtc = tipUtil:DateTime2Seconds(nCYear,nCMonth,nCDay,nCHour,0,0)
            local nIdxUtc = nUtc-(24-IdxHour)*3600
            local nIdxYear, nIdxMonth, nIdxDay, nIdxHour = tipUtil:FormatCrtTime(nIdxUtc) 
            tabTypeData[IdxHour][1] = string.format("%02d", nIdxHour)..":00"
            tabTypeData[IdxHour][2] = tonumber(tabValue[IdxHour]) or 0
        end
    else
        for IdxMonth=1,30 do
            tabTypeData[IdxMonth] = {}
            local nUtc = tipUtil:DateTime2Seconds(nCYear,nCMonth,nCDay,nCHour,0,0)
            local nIdxUtc = nUtc-(30-IdxMonth)*86400
            local nIdxYear, nIdxMonth, nIdxDay, nIdxHour = tipUtil:FormatCrtTime(nIdxUtc) 
            tabTypeData[IdxMonth][1] = string.format("%02d", nIdxMonth)..".".. string.format("%02d", nIdxDay)
            tabTypeData[IdxMonth][2] = tonumber(tabValue[IdxMonth]) or 0
        end
    end
    return tabTypeData
end

function ClientWorkModule:GetLocalHistoryIncome(strType)
	local strTabKey = "hour24"
    if strType == "d30" then
        strTabKey = "day30"
    end
	
    local tEarnings = tFunctionHelper.ReadConfigFromMemByKey("tEarnings") or {}
	if type(tEarnings[strTabKey]) == "table" and #tEarnings[strTabKey] > 0 then
        return tEarnings[strTabKey]
    end
    tEarnings[strTabKey] = self:CreateIncomeTimeTab(strTabKey, nil)
    tFunctionHelper.SaveConfigToFileByKey("tEarnings")
    return tEarnings[strTabKey]
end

function ClientWorkModule:GetServerHistoryIncome(strType, fnCallBack)
    local strTabKey = "hour24"
    if strType == "d30" then
        strTabKey = "day30"
    end
	local tabLocal = ClientWorkModule:GetLocalHistoryIncome(strType) 
	
    local strReguestUrl = self:QuerySvrForGetHistoryInfo(strType)
    if not IsRealString(strReguestUrl) then
        fnCallBack(false, tabLocal)
        return
    end
	local function CheckLastUTC(nLastUtc)
		if type(nLastUtc) ~= "number" then
			return true
		end
		local nCurrentUtc = tFunctionHelper.GetCurrentServerTime() or 0
		local nLYear, nLMonth, nLDay, nLHour, nLMin = tipUtil:FormatCrtTime(nLastUtc)
		local nCYear, nCMonth, nCDay, nCHour, nCMin = tipUtil:FormatCrtTime(nCurrentUtc)
		if nLYear ~= nCYear or nLMonth ~= nCMonth or nLDay ~= nCDay or nLHour ~= nCHour or nLMin ~= nCMin then
			return true
		end
		return false
	end
    local tEarnings = tFunctionHelper.ReadConfigFromMemByKey("tEarnings") or {}
	if type(tEarnings[strType]) == "table" and not CheckLastUTC(tEarnings[strType]["lastutc"]) then
		fnCallBack(true, tabLocal)
		return
	end
	strReguestUrl = strReguestUrl .. "&rd="..tostring(tFunctionHelper.GetMinuteStamp())
	TipLog("[GetHistoryToServer] strReguestUrl = " .. strReguestUrl)
	tFunctionHelper.NewAsynGetHttpContent(strReguestUrl, false
	, function(nRet, strContent, respHeaders)
		TipLog("[GetHistoryToServer] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
		if 0 ~= nRet then
            TipLog("[GetHistoryToServer] get content failed.")
			fnCallBack(false, tabLocal)
            return
        end
        local tabInfo = tFunctionHelper.DeCodeJson(strContent)	
        if type(tabInfo) ~= "table" or type(tabInfo["data"]) ~= "table" then
            TipLog("[GetHistoryToServer] parse info error.")
            fnCallBack(false, tabLocal)
            return
        end
        tEarnings[strTabKey] = self:CreateIncomeTimeTab(strTabKey,tabInfo["data"])
        if type(tEarnings[strType]) ~= "table" then
            tEarnings[strType] = {}
        end
        tEarnings[strType]["lastutc"] = tFunctionHelper.GetCurrentServerTime()
        tFunctionHelper.SaveConfigToFileByKey("tEarnings")
        fnCallBack(true, tEarnings[strTabKey])
	end)
end
--与服务端通信逻辑--End

--挖矿逻辑
function ClientWorkModule:ResetGlobalParam()
	if self._WorkingTimerId then
		timeMgr:KillTimer(self._WorkingTimerId)
		self._WorkingTimerId = nil
	end
	--self:ResetReconnectCnt()
	if self._ReConnectSvrTimerId then
		timeMgr:KillTimer(self._ReConnectSvrTimerId)
		self._ReConnectSvrTimerId = nil
	end
end

function ClientWorkModule:WorkingTimerHandle()
	if self._WorkingTimerId then
		timeMgr:KillTimer(self._WorkingTimerId)
		self._WorkingTimerId = nil
	end
	local nReportCalcInterval = self:GetHeartbeatInterval()
	
	self._WorkingTimerId = timeMgr:SetTimer(function(Itm, id)
		local nAverageHashRate = self._WorkClient.GetAverageHashRate()
		if nAverageHashRate > 0 then
			timeMgr:KillTimer(self._WorkingTimerId)
			self._WorkingTimerId = nil
			self:QueryClientInfo(nAverageHashRate)
			self._WorkingTimerId = timeMgr:SetTimer(function(Itm, id)
				local nAverageHashRate = self._WorkClient.GetAverageHashRate()
				self:QueryClientInfo(nAverageHashRate)
				self._LastQueryBalanceTime = tipUtil:GetCurrentUTCTime()
			end, nReportCalcInterval*1000)
		end	
	end, 60*1000)	
end

function ClientWorkModule:StartMinerSuccess()
	self._UIWorkState = self.UI_STATE.CALCULATE
	self:WorkingTimerHandle()
	self:ReportClientInfoToServer()
	--UIInterface:OnStart()
	--[[
	UIInterface:UpdateSuspendWndVisible()
	self:WorkingTimerHandle()
	UIInterface:OnWorkStateChange()
	StartMiningCountTimer()
	tipUtil:StopComputerSleep(true)
	--]]
	ProfitMax:CheckRecommendDriver()
end

function ClientWorkModule:QuitMinerSuccess()
	--UpdateUserBalance()
	self._UIWorkState = self.UI_STATE.STOPPED
	self:ResetGlobalParam()
	UIInterface:OnQuit()
	ProfitMax:ClearRecommendDriver()
end

function ClientWorkModule:TryToExecuteMiner()
	UIInterface:SetStateInfoToUser(nil)
	self._WorkClient.InitCmdLine()
	local nRet = self._WorkClient.Start()
	if nRet ~= 0 then
		if nRet == 1 then
			self:NotifyPause()
			UIInterface:SetStateInfoToUser("连接赚宝服务器失败,请重试")
        elseif nRet == 2 then
            self:NotifyPause()
			UIInterface:SetStateInfoToUser("可执行文件不存在，可能被杀毒软件误杀，请添加信任")
		end	
		return
	end
	self:StartMinerSuccess()
end

function ClientWorkModule:OnUpdateCfgFinish(event, bUpdate)
	TipLog("[OnUpdateCfgFinish] self._UIWorkState =" .. tostring(self._UIWorkState))
	if self._UIWorkState == self.UI_STATE.PREPARE_POOL then
		self:TryToExecuteMiner()
	elseif self._UIWorkState == self.UI_STATE.CALCULATE
		or self._UIWorkState == self.UI_STATE.STARTING then
		if bUpdate then
			self._WorkClient.ReStartClientByNewPoolList()
		end
	end
end

function ClientWorkModule:OnFinishPrepareWorkID(event, bSuccess)
	if self._UIWorkState ~= self.UI_STATE.PREPARE_WORKID then
		return 
	end
	if not bSuccess then
		--[[
		UIInterface:SetStateInfoToUser("连接服务器失败，重试中...")
		SetOnceTimer(function()
			self:GetUserWorkID(
								function(bSuccess)
									self:DispatchEvent("OnFinishPrepareWorkID", bSuccess)
								end
							  )
		end, 5*1000)
		return
		--]]
		if not self:CheckCanReconnect() then
			if self:CheckIsWorking() then
				self:NotifyPause()
				UIInterface:SetStateInfoToUser("连接赚宝服务器失败")
			end	
		else
			local nInterval = self:GetReconnectInterval()
			UIInterface:SetStateInfoToUser("连接服务器失败，重试中...")
			SetOnceTimer(function()
				self:GetUserWorkID(
					function(bSuccess)
						self:DispatchEvent("OnFinishPrepareWorkID", bSuccess)
					end
				  )
			end, nInterval)
		end
		return
	end
	--获取矿池信息
	self._UIWorkState = self.UI_STATE.PREPARE_POOL
	self:QueryWorkerInfo(true)
	UIInterface:SetStateInfoToUser(nil)
	self:ResetReconnectCnt()
end


function ClientWorkModule:OnPriorityChange(event)  
    if SupportClientType:CheckIsNeedChangeNow() then
        self._WorkClient.Quit()
        self:StartNextClient()
    end
end

function ClientWorkModule:NotifyStart()
	if not self:CheckCanStartNow() then
		return
	end
	self._nLastPushCalcReportUTC = tFunctionHelper.GetCurrentServerTime()
	self._UIWorkState = self.UI_STATE.STARTING
	UIInterface:OnStart()
	self._UIWorkState = self.UI_STATE.PREPARE_WORKID
	local function fnCallBack(bSuccess)
		self:DispatchEvent("OnFinishPrepareWorkID", bSuccess)
	end
	self:GetUserWorkID(fnCallBack)
end

function ClientWorkModule:NotifyPause()
	self._nLastPushCalcReportUTC = 0
	if self._WorkClient then
		self._WorkClient.Pause()
		self:QuitMinerSuccess()
	end	
end

function ClientWorkModule:NotifyResume()
	if self._WorkClient then
		self._WorkClient.Resume()
		self:StartMinerSuccess()
	end	
end

function ClientWorkModule:NotifyQuit(bNotReport)
	if self._WorkClient then
		self._WorkClient.Quit()
		self:QuitMinerSuccess()
	end	
	if not bNotReport then
		self:SendStopMiningInfoToServer("stop")	
	end
end


function ClientWorkModule:SetMiningType(nMiningType)
	self._MiningType = nMiningType
end

function ClientWorkModule:GetMiningType()
	return self._MiningType
end

function ClientWorkModule:GetRealMiningType()
	if self._WorkClient ~= nil and type(self._WorkClient.GetRealMiningType) == "table" then
		return self._WorkClient.GetRealMiningType()
	else
		return self._MiningType
	end
end

function ClientWorkModule:StartNextClient()
	if self:InitMiningClient() then
		self:ResetGlobalParam()
		--self:NotifyStart()
        self._UIWorkState = self.UI_STATE.PREPARE_WORKID
        local function fnCallBack(bSuccess)
            self:DispatchEvent("OnFinishPrepareWorkID", bSuccess)
        end
        self:GetUserWorkID(fnCallBack)
	else
		if not self:CheckAndReTryConnectServer() then
			self:NotifyQuit()
			UIInterface:SetStateInfoToUser("赚宝进程运行失败")
		end	
	end
end
--
function ClientWorkModule:InitMiningClient()
	local nPlatformId, nMiningType = SupportClientType:GetNextClientInfo()
	if nMiningType == nil then
		return false
	end
	self:SetMiningType(nMiningType)
	if self._MiningType == 1 then
		--LoadGenOilClient()
		--self._WorkClient = XLGetGlobal("Global.GenOilClient")
		self._WorkClient = GenOilClient
	elseif self._MiningType == 2 then
		--LoadZcashNClient()
		--self._WorkClient = XLGetGlobal("Global.ZcashNClient")
		self._WorkClient = ZcashNClient
	elseif self._MiningType == 3 then
		--LoadZcashAClient()
		--self._WorkClient = XLGetGlobal("Global.ZcashAClient")
		self._WorkClient = ZcashAClient
	elseif self._MiningType == 4 
			or  self._MiningType == 5 
			or  self._MiningType == 6 
			or  self._MiningType == 7 
			then
		self._WorkClient = XmrClient
	end
	self._WorkClient.InitClient(nPlatformId, self._MiningType)
	return true
end

function ClientWorkModule:CheckCanStartNow()
	if tFunctionHelper.CheckIsUpdatingDriver() then
		UIInterface:ShowRemindRebootWarning()
		TipLog("[CheckCanStartNow] updating driver, can not start")
		return false
	end
	return true
end

function ClientWorkModule:QuerySvrForReTryConnect()
	local function fnCallBack(bRet, tabRate)
		if not bRet then
			self:CheckAndReTryConnectServer()
			return
		end
		self:ResetReconnectCnt()
		self:QueryWorkerInfo(true)
	end
	local strReguestUrl = "http://api.eastredm.com/pc/getClassInfo"
	self:GetServerJsonData(strReguestUrl, fnCallBack)
end

function ClientWorkModule:CheckAndReTryConnectServer()
	if self._ReConnectSvrTimerId then
		timeMgr:KillTimer(self._ReConnectSvrTimerId)
		self._ReConnectSvrTimerId = nil
	end
	if self:GetClientCurrentState() == self.CLIENT_STATE.CALCULATE or self:GetClientCurrentState() == self.CLIENT_STATE.PREPARE then
		return false
	end
	--无条件暂停一下，因为可能当前客户端状态为nil
	if self:CheckIsWorking() then
		self:NotifyQuit(true)
	end	
	SupportClientType:ResetClientIndex() 
	self:InitMiningClient()
	self._UIWorkState = self.UI_STATE.PREPARE_POOL
	UIInterface:OnStart()
	local nInterval = self:GetReconnectInterval()
	UIInterface:SetStateInfoToUser("连接服务器失败，重试中...")
	self._ReConnectSvrTimerId = SetOnceTimer(function()
		self._ReConnectSvrTimerId = nil
		self:QuerySvrForReTryConnect()
	end, nInterval)	
	return true	
end
