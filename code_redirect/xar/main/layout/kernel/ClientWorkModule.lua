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
ClientWorkModule._SvrAverageMiningSpeed = 0
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
ClientWorkModule.CONNECT_MAX_COUNT = 10
ClientWorkModule.CONNECT_RETRY_COUNT = 0

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
	strParam = strParam .. "&md5=" .. strMd5
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
	if self:CheckIsBinded() then
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
	local nInterval = (self.CONNECT_RETRY_COUNT + 1 )*5*1000
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
	strInterfaceParam = strInterfaceParam .. "&workerID=" .. Helper:UrlEncode(tostring(tUserConfig["tUserInfo"]["strWorkID"]))
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

function ClientWorkModule:ReportClientInfoToServer()
	local strUrl = self:QuerySvrForReportClientInfo()
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	self:SendMinerInfoToServer(strUrl,3)
end

function ClientWorkModule:ReportMiningPoolInfoToServer()
	local strUrl = self:QuerySvrForReportPoolInfo()
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	self:SendMinerInfoToServer(strUrl,3)
end

function ClientWorkModule:SetMachineNameChangeInfo()
	self:ReportClientInfoToServer()
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
function ClientWorkModule:GetSvrAverageMiningSpeed()
	return self._SvrAverageMiningSpeed
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
	--if string.find(string.lower(tostring(strCmdline)), "/working") then
	--修改为启动就挖
	return true
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
	self:ReportClientInfoToServer()
	-----------------------UI相关
	UIInterface:ChangeClientTitle("共享赚宝")
	self:QueryWorkerInfo()
end

--
function ClientWorkModule:ReportInterfaceErrorInfo(strUrl, strFu6, strFu8)
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
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	if not IsRealString(strUrl) then
		self:DispatchEvent("OnUnBindCallBack", false)
		return
	end
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
	if bUpdate and tabInfo then
		local tUserConfig = self:GetUserConfig()
		
		local strPoolKey = self._WorkClient.GetPoolCfgName()
		if type(tUserConfig["tSvrPoolInfo"]) ~= "table" then
			tUserConfig["tSvrPoolInfo"] = {}
		end
		if type(tUserConfig["tSvrPoolInfo"][strPoolKey]) ~= "table" then
			tUserConfig["tSvrPoolInfo"][strPoolKey] = {}
		end
		
		local tabPool = tabInfo["data"]["p"]
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
		end, 5*1000)
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
		if bUpdated then
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
	--self:GetServerJsonData(strUrl, fnGetPoolCallback)
	--[[
	NewAsynGetHttpContent(strUrl, false
	, function(nRet, strContent, respHeaders)
		TipLog("[GetWorkPoolCfg] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
				
		if 0 ~= nRet then
			TipLog("[GetSvrPoolCfg] query sever failed")	
			OnSvrPoolCfgUpdate(false, false, nLastCfg)
			return
		end
		----forlocal
		strContent = GetLocalSvrCfgWithName("zcash_poolcfg.json")
		----
		local tabInfo = DeCodeJson(strContent)
		if type(tabInfo) ~= "table" 
			or type(tabInfo["data"]) ~= "table" 
			or type(tabInfo["data"]["pool"]) ~= "table" 
			or #tabInfo["data"]["pool"] == 0 then
			TipLog("[GetSvrPoolCfg] parse Json failed.")
			OnSvrPoolCfgUpdate(false, false, nLastCfg)
			return 
		end
		local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
		if type(tUserConfig["tSvrPoolInfo"]) ~= "table" then
			tUserConfig["tSvrPoolInfo"] = {}
		end
		local strPoolKey = g_WorkClient.GetPoolCfgName()
		if type(tUserConfig["tSvrPoolInfo"][strPoolKey]) ~= "table" then
			tUserConfig["tSvrPoolInfo"][strPoolKey] = {}
		end
		
		local tabPool = tabInfo["data"]["pool"]
		local tabUserPool = {}
		for index = 1, #tabPool do
			if type(tabPool[index]) == "table" and CheckPeerIDList(tabPool[index]["pidlist"]) then
				tabUserPool[#tabUserPool+1] = tabPool[index]
			end
		end
		tUserConfig["tSvrPoolInfo"][strPoolKey] = tabUserPool
		
		if nLastCfg ~= nil then
			tUserConfig["tSvrPoolInfo"][strPoolKey]["nLastUpdateCfgTime"] = nLastCfg
		end	
		SaveConfigToFileByKey("tUserConfig")
		OnSvrPoolCfgUpdate(true, true, nLastCfg)
	end)
	--]]
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
		self:UpdateSvrPoolCfg(tabInfo)
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
		self:ResetReconnectCnt()
	else
		if bRetry and self:CheckIsWorking() then
			if not self:CheckCanReconnect() then
				self:NotifyPause()
				UIInterface:SetStateInfoToUser("连接赚宝服务器失败")
			else
				local nInterval = self:GetReconnectInterval()
				UIInterface:SetStateInfoToUser("连接服务器失败，重试中...")
				SetOnceTimer(function()
					self:QueryWorkerInfo(true)
				end, nInterval)
			end	
		end	
	end
end

function ClientWorkModule:QueryWorkerInfo(bRetry)
	local strUrl = self:QuerySvrForWorkerInfo()
	strUrl = strUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[QueryWorkerInfo] strUrl = " .. strUrl)
	
	local function fnWorkerInfoCallBack(bSuccess, tabInfo)
		self:DispatchEvent("OnQueryWorkerInfo", bSuccess, tabInfo, bRetry)
	end
	
	self:GetServerJsonData(strUrl, fnWorkerInfoCallBack)
	
	--[[
	NewAsynGetHttpContent(strReguestUrl, false
	, function(nRet, strContent, respHeaders)
		TipLog("[QueryWorkerInfo] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
				
		if 0 == nRet then
			-- forlocal
			strContent = GetLocalSvrCfgWithName("getWorkerInfo.json")
			--
			local tabInfo = DeCodeJson(strContent)
			if type(tabInfo) ~= "table" 
				or tabInfo["rtn"] ~= 0 
				or type(tabInfo["data"]) ~= "table" then
				TipLog("[QueryWorkerInfo] parse info error.")
				if fnCallBack ~= nil then
					fnCallBack(false)
				end
				return 
			end
			UpdateSvrPoolCfg(tabInfo)
			if fnCallBack ~= nil then
				fnCallBack(true)
			end
			-- 绑定 未绑定 解绑 是否 status 不一样
			if tabInfo["data"]["status"] ~= 1 then
				if CheckIsBinded() then
					UnBindingClientFromServer()
					--return
				end	
			end
			if tonumber(tabInfo["data"]["balance"]) ~= nil then
				--g_Balance = tabInfo["data"]["balance"]
				if g_Balance ~= tonumber(tabInfo["data"]["balance"]) then
					SetUserCurrentBalance(tabInfo["data"]["balance"])
					UpdateUserBalance()
				end	
			end
		else
			if fnCallBack ~= nil then
				fnCallBack(false)
			end
			TipLog("[QueryWorkerInfo] query sever failed.")
		end
	end)
	--]]
end

--查询客户端信息
function ClientWorkModule:OnQueryClientInfo(event, bSuccess, tabInfo)
	if bSuccess then
		self:UpdateSvrPoolCfg(tabInfo)
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
			self._SvrAverageMiningSpeed = tabInfo["data"]["rate"]
		end
		self:ResetReconnectCnt()
	else
		--[[
		if not self:CheckCanReconnect() then
			if self:CheckIsWorking() then
				self:NotifyPause()
				UIInterface:SetStateInfoToUser("连接赚宝服务器失败")
			end	
		end	
		--]]
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
	--[[
	NewAsynGetHttpContent(strReguestUrl, false
	, function(nRet, strContent, respHeaders)
		TipLog("[QueryClientInfo] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
				
		if 0 == nRet then
			-- forlocal
			strContent = GetLocalSvrCfgWithName("pushCalc.json")
			--
			local tabInfo = DeCodeJson(strContent)
			if type(tabInfo) ~= "table" 
				or tabInfo["rtn"] ~= 0 
				or type(tabInfo["data"]) ~= "table" then
				TipLog("[QueryClientInfo] parse info error.")
				if fnCallBack ~= nil then
					fnCallBack(false)
				end
				return 
			end
			UpdateSvrPoolCfg(tabInfo)
			if fnCallBack ~= nil then
				fnCallBack(true)
			end
			-- 绑定 未绑定 解绑 是否 status 不一样
			if tabInfo["data"]["status"] ~= 1 then
				if CheckIsBinded() then
					UnBindingClientFromServer()
					--return
				end	
			end
			if tonumber(tabInfo["data"]["balance"]) ~= nil then
				--g_Balance = tabInfo["data"]["balance"]
				if g_Balance ~= tonumber(tabInfo["data"]["balance"]) then
					SetUserCurrentBalance(tabInfo["data"]["balance"])
					UpdateUserBalance()
				end	
			end
			if tonumber(tabInfo["data"]["rate"]) ~= nil then
				--g_PerSpeed = tabInfo["data"]["rate"]
				g_SvrAverageMiningSpeed = tabInfo["data"]["rate"]
			end
		else
			if fnCallBack ~= nil then
				fnCallBack(false)
			end
			TipLog("[QueryClientInfo] query sever failed.")
		end
	end)
	--]]
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
function ClientWorkModule:GetHistoryToServer(strtype, fnCallBack)
	local function CheckLastUTC(utc)
		if type(utc) ~= "number" then
			return true
		end
		local nCurrentUtc = tipUtil:GetCurrentUTCTime() or 0
		local nLYear, nLMonth, nLDay, nLHour, nLMin = tipUtil:FormatCrtTime(utc)
		local nCYear, nCMonth, nCDay, nCHour, nCMin = tipUtil:FormatCrtTime(nCurrentUtc)
		if nLYear ~= nCYear or nLMonth ~= nCMonth or nLDay ~= nCDay or nLHour ~= nCHour or nLMin ~= nCMin then
			return true
		end
		return false
	end
	local function UINeedTable(t)
		local tmp = {}
		local nCurrent = tipUtil:GetCurrentUTCTime() or 0
		--[[
		if strtype == "h24" then
			nCurrent = nCurrent - 3600
		else
			nCurrent = nCurrent - 86400
		end
		--]]
		for i=#t, 1, -1 do
			local _, LMonth, LDay, LHour = tipUtil:FormatCrtTime(nCurrent)
			tmp[i] = {}
			if strtype == "h24" then
				tmp[i][1] = string.format("%02d", LHour)..":00"
				nCurrent = nCurrent - 3600
			else
				tmp[i][1] = string.format("%02d", LMonth).."/".. string.format("%02d", LDay)
				nCurrent = nCurrent - 86400
			end
			tmp[i][2] = t[i]
		end
		return tmp
	end
	local function GetLocal(tLocal)
		local t = {}
		local count = 0
		tLocal = tLocal or {}
		if strtype == "h24" then
			if type(tLocal["hour24"]) == "table" and #tLocal["hour24"] == 24 then
				return tLocal["hour24"]
			end
			count = 24
		else
			if type(tLocal["day30"]) == "table" and #tLocal["day30"] == 30 then
				return tLocal["day30"]
			end
			count = 30
		end
		for i = 1, count do
			t[i] = 0
		end
		return UINeedTable(t)
	end
	local function Save2Local(tServer)
		local tEarnings = tFunctionHelper.ReadConfigFromMemByKey("tEarnings") or {}
		tEarnings[strtype] = tEarnings[strtype] or {}
		tEarnings[strtype]["lastutc"] = tipUtil:GetCurrentUTCTime() or 0
		tEarnings[strtype == "h24" and "hour24" or "day30"] = UINeedTable(tServer)
		tFunctionHelper.SaveConfigToFileByKey("tEarnings")
	end
	local tEarnings = tFunctionHelper.ReadConfigFromMemByKey("tEarnings") or {}
	tEarnings[strtype] = tEarnings[strtype] or {}
	if not CheckLastUTC(tEarnings[strtype]["lastutc"]) then
		fnCallBack(true, GetLocal(tEarnings))
		return
	end
	local strReguestUrl = self:QuerySvrForGetHistoryInfo(strtype)
	if not strReguestUrl then
		local tDefault = GetLocal()
		fnCallBack(false, tDefault)
		return
	end
	strReguestUrl = strReguestUrl .. "&rd="..tostring(tipUtil:GetCurrentUTCTime())
	TipLog("[GetHistoryToServer] strReguestUrl = " .. strReguestUrl)
	tFunctionHelper.NewAsynGetHttpContent(strReguestUrl, false
	, function(nRet, strContent, respHeaders)
		TipLog("[GetHistoryToServer] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
		--[[forlocal
		strContent = GetLocalSvrCfgWithName("getHistory"..strtype..".json")
		local tabInfo = DeCodeJson(strContent)
		if type(tabInfo) == "table" and type(tabInfo["data"]) == "table" then
			fnCallBack(true, UINeedTable(tabInfo["data"]))
			Save2Local(tabInfo["data"])
		else
			fnCallBack(false, GetLocal())
		end
		if true then return end
		--]]
		if 0 == nRet then
			local tabInfo = tFunctionHelper.DeCodeJson(strContent)	
			if type(tabInfo) ~= "table" or type(tabInfo["data"]) ~= "table" then
				TipLog("[GetHistoryToServer] parse info error.")
				fnCallBack(false, GetLocal(tEarnings))
				return
			end
			fnCallBack(true, UINeedTable(tabInfo["data"]))
			Save2Local(tabInfo["data"])
		else
			TipLog("[GetHistoryToServer] get content failed.")
			fnCallBack(false, GetLocal(tEarnings))
		end	
	end)
end
--与服务端通信逻辑--End

--挖矿逻辑
function ClientWorkModule:ResetGlobalParam()
	if self._WorkingTimerId then
		timeMgr:KillTimer(self._WorkingTimerId)
		self._WorkingTimerId = nil
	end
	self:ResetReconnectCnt()
end

function ClientWorkModule:WorkingTimerHandle()
	local nReportCalcInterval = self:GetHeartbeatInterval()
	self._WorkingTimerId = timeMgr:SetTimer(function(Itm, id)
		local nAverageHashRate = self._WorkClient.GetAverageHashRate()
		self:QueryClientInfo(nAverageHashRate)
		self._LastQueryBalanceTime = tipUtil:GetCurrentUTCTime()
	end, nReportCalcInterval*1000)
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
end

function ClientWorkModule:QuitMinerSuccess()
	--UpdateUserBalance()
	self._UIWorkState = self.UI_STATE.STOPPED
	self:ResetGlobalParam()
	UIInterface:OnQuit()
end

function ClientWorkModule:TryToExecuteMiner()
	UIInterface:SetStateInfoToUser(nil)
	self._WorkClient.InitCmdLine()
	local nRet = self._WorkClient.Start()
	if nRet ~= 0 then
		if nRet == 1 then
			self:NotifyPause()
			UIInterface:SetStateInfoToUser("连接赚宝服务器失败,请重试")
		end	
		return
	end
	self:StartMinerSuccess()
end

function ClientWorkModule:OnUpdateCfgFinish(event, bUpdate)
	if self._UIWorkState == self.UI_STATE.PREPARE_POOL then
		self:TryToExecuteMiner()
	elseif self._UIWorkState == self.UI_STATE.CALCULATE
		or self._UIWorkState == self.UI_STATE.STARTING then
		if bUpdated then
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

function ClientWorkModule:NotifyStart()
	self._UIWorkState = self.UI_STATE.STARTING
	UIInterface:OnStart()
	--[[
	local function OnQueryWorkerInfo(bRet)
		if GetUIWorkState() ~= UI_STATE_PREPARE_POOL then
			return 
		end
		if not bRet then
			SetStateInfoToUser("连接服务器失败，重试中...")
			SetOnceTimer(function()
				QueryWorkerInfo(OnQueryWorkerInfo)
			end, 5*1000)
			return
		end	
		SetStateInfoToUser(nil)
	end
	
	local function OnGetUserWorkID(bWorkID, strInfo)
		if GetUIWorkState() ~= UI_STATE_PREPARE_WORKID then
			return 
		end
		if not bWorkID then
			SetStateInfoToUser("连接服务器失败，重试中...")
			SetOnceTimer(function()
				GetUserWorkID(OnGetUserWorkID)
			end, 5*1000)
			
			return
		end
		--获取矿池信息
		g_UIWorkState = UI_STATE_PREPARE_POOL
		QueryWorkerInfo(OnQueryWorkerInfo)
		SetStateInfoToUser(nil)
	end
	--]]
	self._UIWorkState = self.UI_STATE.PREPARE_WORKID
	local function fnCallBack(bSuccess)
		self:DispatchEvent("OnFinishPrepareWorkID", bSuccess)
	end
	self:GetUserWorkID(fnCallBack)
end

function ClientWorkModule:NotifyPause()
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

function ClientWorkModule:NotifyQuit()
	if self._WorkClient then
		self._WorkClient.Quit()
		self:QuitMinerSuccess()
	end	
end


function ClientWorkModule:SetMiningType(nMiningType)
	self._MiningType = nMiningType
end

function ClientWorkModule:GetMiningType()
	return self._MiningType
end
--初始化客户端,根据需要 1:ETH 2:ZcashN
function ClientWorkModule:InitMiningClient()
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
	end
	self._WorkClient.InitClient()
end




