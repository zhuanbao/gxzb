local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local IPCUtil = XLGetObject("IPC.Util")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local tClientProc = XLGetGlobal("ClientProc")

ObjectBase = XLGetGlobal("ObjectBase")
WorkModuleHelper = ObjectBase:New()
XLSetGlobal("WorkModuleHelper", WorkModuleHelper)

WorkModuleHelper._strSeverInterfacePrefix = "http://api.eastredm.com/pc"
WorkModuleHelper._strSeverConfigPrefix = "http://conf.eastredm.com"

--重试
WorkModuleHelper.CONNECT_MAX_COUNT = 3
WorkModuleHelper.CONNECT_RETRY_COUNT = 0
WorkModuleHelper._ReConnectSvrTimerId = nil

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
	tipUtil:Log("WorkModuleHelper: " .. tostring(strLog))
end

function WorkModuleHelper:GetUserConfig()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	return tUserConfig
end

function WorkModuleHelper:UpdateSpeedRate(tabRate)
	local tUserConfig = self:GetUserConfig()
	tUserConfig["tSpeedRate"] = tabRate
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")	
end

function WorkModuleHelper:GetCoinRate(strCoinType)
	local tUserConfig = self:GetUserConfig()
	if type(tUserConfig["tSpeedRate"]) ~= "table" then
		tUserConfig["tSpeedRate"] = {}
	end
	return tUserConfig["tSpeedRate"][strCoinType] or 0
end

function WorkModuleHelper:CheckIsBinded()
	local tUserConfig = self:GetUserConfig()
	if type(tUserConfig["tUserInfo"]) == "table"
		and IsRealString(tUserConfig["tUserInfo"]["strWorkID"]) 
		and tUserConfig["tUserInfo"]["bBind"] then
		return true
	end
	return false
end
--[[
0 全速，1智能
--]]

function WorkModuleHelper:IsSpeedWorkChanged(bOld)
	local bNew = self:IsMaxSpeedWork()
	TipLog("[IsSpeedWorkChanged] bOld = " .. tostring(bOld) .. ", bNew = " ..  tostring(bNew))
	if bOld == bNew then
		return false
	end
	return true
end

function WorkModuleHelper:IsMaxSpeedWork()
	local bMax = true
	if UIInterface:GetCurrentWorkModel() == 1
		and self:IsNeedLimitSpeed() then
		bMax = false
	end
	TipLog("[IsMaxSpeedWork] bMax = " .. tostring(bMax))
	return bMax
end

function WorkModuleHelper:IsNeedLimitSpeed()
	if tipUtil:IsNowFullScreen() then
		TipLog("[IsNeedLimitSpeed] full screen")
		return true
	end
	local hr, dwTime = tipUtil:GetLastInputInfo()
	local dwTickCount = tipUtil:GetTickCount()
	if hr == 0 and type(dwTime) == "number" and type(dwTickCount) == "number" and dwTickCount - dwTime < 3*60*1000 then
		TipLog("[IsNeedLimitSpeed] Last input in 3*60 second")
		return true
	end
	TipLog("[IsNeedLimitSpeed] not need speed limit")
	return false
end

function WorkModuleHelper:CheckCanReconnect()
	TipLog("[CheckCanReconnect] current retry cnt = " .. tostring(self.CONNECT_RETRY_COUNT))
	if self.CONNECT_RETRY_COUNT < self.CONNECT_MAX_COUNT then
		self.CONNECT_RETRY_COUNT = self.CONNECT_RETRY_COUNT + 1
		return true
	end
	return false
end

function WorkModuleHelper:ResetReconnectCnt()
	self.CONNECT_RETRY_COUNT = 0
end

function WorkModuleHelper:GetReconnectInterval()
	local nMaxInterval = ApiInterfaceModule:GetHeartbeatInterval()
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

function WorkModuleHelper:CheckCanStartNow()
	if tFunctionHelper.CheckIsUpdatingDriver() then
		UIInterface:ShowRemindRebootWarning()
		TipLog("[CheckCanStartNow] updating driver, can not start")
		return false
	end
	return true
end

function WorkModuleHelper:CheckShoudAutoMining()
	local strCmdline = tipUtil:GetCommandLine()
	--修改为按参数判断是否自动挖
	if string.find(string.lower(tostring(strCmdline)), "/working") then
		return true
	else
		return false
	end
end

function WorkModuleHelper:DoAutoMining()
	if not MainWorkModule:CheckIsWorking() then
		MainWorkModule:NotifyStart()
	end
end

function WorkModuleHelper:InitMiningClient()
	tClientProc.InitWorkMode()
end

function WorkModuleHelper:CheckMachineBindState()
    local tUserConfig = self:GetUserConfig()
	if type(tUserConfig["tUserInfo"]) == "table" and IsRealString(tUserConfig["tUserInfo"]["strWorkID"]) then
		self:GetWorkerInfo()
	end
end

function WorkModuleHelper:SetUserBindInfo(tabBindInfo)
	local tUserConfig = self:GetUserConfig()
	tUserConfig["tUserInfo"]["strHeadImgUrl"] = tabBindInfo["data"]["wxHeadImgUrl"]
	tUserConfig["tUserInfo"]["strNickName"] = tabBindInfo["data"]["wxName"]
	tUserConfig["tUserInfo"]["strOpenID"] = tabBindInfo["data"]["wxOpenID"]
	tUserConfig["tUserInfo"]["bBind"] = true
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
	--self:ReportClientInfoToServer()
	-----------------------UI相关
	UIInterface:ChangeClientTitle("共享赚宝")
	self:GetWorkerInfo()
end

function WorkModuleHelper:UnBindingClientFromClient()
	ApiInterfaceModule:SendUnBindInfoToServer(function(bSuccess, tabInfo)
		if not bSuccess then
			UIInterface:UnBindFail()
		else
			if MainWorkModule:CheckIsWorking() then
				MainWorkModule:NotifyQuit()
			end
			UIInterface:UnBindSuccess()
		end
	end)
end

function WorkModuleHelper:UnBindingClientFromServer()
	if MainWorkModule:CheckIsWorking() then
		MainWorkModule:NotifyQuit()
	end
	UIInterface:UnBindSuccess()
end

--下载二维码
function WorkModuleHelper:DownLoadTempQrcode(funResult)	
	ApiInterfaceModule:GetUserWorkID(function(bGet,strWorkID)
		if bGet then
			ApiInterfaceModule:GetQrcodeInfo(strWorkID, function(bSuccess, tabInfo)
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
							funResult(false,"下载二维码图片失败")
							return 
						end
						tabInfo["data"]["qrcodePath"] = strDownLoadPath
						funResult(true,tabInfo)
					end, expire)
				else
					funResult(false,"获取绑定二维码信息失败，请检测网络")
				end
			end)
		else
			funResult(false)
		end
	end)
end

function WorkModuleHelper:WorkingPrepareWorkID(funResult)
	ApiInterfaceModule:GetUserWorkID(function(bSuccess,strWorkID)
		if not bSuccess then
			if not MainWorkModule:CheckIsWorking() then
				return
			end
			if not self:CheckCanReconnect() then
				UIInterface:SetStateInfoToUser("连接赚宝服务器失败")
				funResult(false)
				return
			end	
			UIInterface:SetStateInfoToUser("连接服务器失败，重试中...")
			SetOnceTimer(function()
							self:WorkingPrepareWorkID(funResult)
						end, 10*1000)
			return
		end
		self:ResetReconnectCnt()
		UIInterface:SetStateInfoToUser(nil)
		funResult(true)
	end)	
end

--查询客户信息
function WorkModuleHelper:GetWorkerInfo(bRetry ,funResult)
	ApiInterfaceModule:QueryWorkerInfo(function(bSuccess, tabInfo)
		if not bSuccess then
			if bRetry and MainWorkModule:CheckIsWorking() then
				if not self:CheckCanReconnect() then
					MainWorkModule:CheckAndReTryConnectServer()
				else
					UIInterface:SetStateInfoToUser("连接服务器失败，重试中...")
					SetOnceTimer(function()
						self:GetWorkerInfo(true, funResult)
					end, 10*1000)
				end
			end	
			return
		end
		self:ResetReconnectCnt()
		UIInterface:SetStateInfoToUser(nil)
		if tonumber(tabInfo["data"]["balance"]) ~= nil then
			if MainWorkModule:GetUserCurrentBalance() ~= tonumber(tabInfo["data"]["balance"]) then
				MainWorkModule:SetUserCurrentBalance(tabInfo["data"]["balance"])
				UIInterface:UpdateUserBalance()
			end	
		end
		if type(tabInfo["data"]["status"]) == "number" and tabInfo["data"]["status"] ~= 1 then
			if self:CheckIsBinded() then
				self:UnBindingClientFromServer()
				ApiInterfaceModule:UpdateWorkerInfo(nil, 0)
				return
			end
		end
		if type(tabInfo["data"]["rate"]) == "table" then
			self:UpdateSpeedRate(tabInfo["data"]["rate"])
		end
		--ApiInterfaceModule:UpdateWorkerInfo(tabInfo, tFunctionHelper.GetCurrentServerTime())
		if type(funResult) == "function" then
			funResult(tabInfo)
		end
	end)
end

--上报算力
function WorkModuleHelper:PushCalcInfo(nMiningSpeed)
	ApiInterfaceModule:PushCalcInfo(nMiningSpeed, function(bSuccess, tabInfo)
		if not bSuccess then
			if MainWorkModule:CheckIsWorking() then
				if not self:CheckCanReconnect() then
					MainWorkModule:CheckAndReTryConnectServer()
				else
					UIInterface:SetStateInfoToUser("连接服务器失败，重试中...")
					SetOnceTimer(function()
						self:PushCalcInfo(nMiningSpeed)
					end, 10*1000)
				end
			end	
			return
		end
		self:ResetReconnectCnt()
		UIInterface:SetStateInfoToUser(nil)
		if tonumber(tabInfo["data"]["balance"]) ~= nil then
			if MainWorkModule:GetUserCurrentBalance() ~= tonumber(tabInfo["data"]["balance"]) then
				MainWorkModule:SetUserCurrentBalance(tabInfo["data"]["balance"])
				UIInterface:UpdateUserBalance()
			end	
		end
		if tabInfo["data"]["status"] ~= 1 then
			if self:CheckIsBinded() then
				self:UnBindingClientFromServer()
				ApiInterfaceModule:UpdateWorkerInfo(nil, 0)
				return
			end
		end
		if type(tabInfo["data"]["rate"]) == "table" then
			self:UpdateSpeedRate(tabInfo["data"]["rate"])
		end
		MainWorkModule:UpdatePriority(tabInfo["data"]["efficiency"], tabInfo["data"]["forceplist"])
		if type(tabInfo["data"]["efficiency"]) == "table" then
			local tabPriorityNew = tFunctionHelper.ConvertTableStrToNum(tabInfo["data"]["efficiency"])
			local tUserConfig = self:GetUserConfig()
			tUserConfig["tPriority"] = tabPriorityNew
			tUserConfig["tForcePlist"] = tabInfo["data"]["forceplist"] or {}
			tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
			MainWorkModule:UpdatePriority()
		end
		MainWorkModule:UpdateSvrPoolCfg(tabInfo["data"]["lastCfg"])
		local tabUpdateGetWorkerInfo = {}
		tabUpdateGetWorkerInfo["rtn"] = tabInfo["rtn"] 
		tabUpdateGetWorkerInfo["data"] = {}
		tabUpdateGetWorkerInfo["data"]["balance"] = tabInfo["data"]["balance"]
		tabUpdateGetWorkerInfo["data"]["lastCfg"] = tabInfo["data"]["lastCfg"]
		tabUpdateGetWorkerInfo["data"]["rate"] = tabInfo["data"]["rate"]
		ApiInterfaceModule:UpdateWorkerInfo(tabUpdateGetWorkerInfo, tFunctionHelper.GetCurrentServerTime())
		
		--[[
		tClientProc.UpdateSpeedRate(tabInfo["data"]["rate"])
		tClientProc.UpdateSvrPoolCfg(tabInfo["data"]["lastCfg"])
		tClientProc.UpdatePriority(tabInfo["data"]["efficiency"])
		--]]
	end)
end

--历史收益
--查询收益接口,strtype = h24 最近24小时，d30 最近1个月
--不同整点才会去请求，否则使用本地
--请求失败显示上次， 颜色用灰色
function WorkModuleHelper:CreateIncomeTimeTab(strTabKey,tabValue)
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

function WorkModuleHelper:GetLocalHistoryIncome(strType)
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

function WorkModuleHelper:CheckLastGetIncomeTime(nLastUtc)
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

function WorkModuleHelper:GetServerHistoryIncome(strType, funResult)
	local strTabKey = "hour24"
    if strType == "d30" then
        strTabKey = "day30"
    end
	local tabLocal = self:GetLocalHistoryIncome(strType)
	
	local tUserConfig = self:GetUserConfig()
	if type(tUserConfig["tUserInfo"]) ~= "table"
		or not IsRealString(tUserConfig["tUserInfo"]["strWorkID"]) then
		 funResult(false, tabLocal)
		 return
	end	
    
    local tEarnings = tFunctionHelper.ReadConfigFromMemByKey("tEarnings") or {}
	if type(tEarnings[strType]) == "table" and not self:CheckLastGetIncomeTime(tEarnings[strType]["lastutc"]) then
		funResult(true, tabLocal)
		return
	end
	ApiInterfaceModule:QueryHistoryIncome(strType, function(bSuccess, tabInfo)
		if not bSuccess then
			funResult(false, tabLocal)
			return
		end
		tEarnings[strTabKey] = self:CreateIncomeTimeTab(strTabKey,tabInfo["data"])
        if type(tEarnings[strType]) ~= "table" then
            tEarnings[strType] = {}
        end
        tEarnings[strType]["lastutc"] = tFunctionHelper.GetCurrentServerTime()
        tFunctionHelper.SaveConfigToFileByKey("tEarnings")
        funResult(true, tEarnings[strTabKey])
	end)
end


function WorkModuleHelper:IsPoolCfgChanged(strCfgName, strPoolVerKey, nCoinNewCfgTime)
	local tUserConfig = self:GetUserConfig()
	if type(tUserConfig["tSvrPoolInfo"]) ~= "table" then
		tUserConfig["tSvrPoolInfo"] = {}
	end
	if type(tUserConfig["tSvrPoolInfo"][strCfgName]) ~= "table" then
		tUserConfig["tSvrPoolInfo"][strCfgName] = {}
	end
	local tPoolList = tUserConfig["tSvrPoolInfo"][strCfgName]
	if type(tPoolList) ~= "table" or #tPoolList < 1 then
		return true
	end
	local strOldPoolVerKey = tUserConfig["tSvrPoolInfo"][strCfgName]["strPoolVerKey"]
	if strPoolVerKey ~= strOldPoolVerKey then
		return true
	end
	local nLastUpdateCfgTime = tUserConfig["tSvrPoolInfo"][strCfgName]["nLastUpdateCfgTime"]
	nLastUpdateCfgTime = tonumber(nLastUpdateCfgTime) or 0
	if nCoinNewCfgTime > nLastUpdateCfgTime then
		return true
	end
	return false
end

function WorkModuleHelper:GetSvrPoolCfg(strCfgName, funResult)
	local strUrl = ApiInterfaceModule:MakePoolCfgRequestUrl(strCfgName)
	tFunctionHelper.NewAsynGetHttpContent(strUrl, false
	, function(nRet, strContent, respHeaders)
		TipLog("[GetSvrPoolCfg] nRet:"..tostring(nRet)
				.." strContent:"..tostring(strContent))
		if 0 == nRet then
			local tabInfo = tFunctionHelper.DeCodeJson(strContent)
			if type(tabInfo) == "table" 
				and type(tabInfo["data"]) == "table" then
				self:ResetReconnectCnt()
				funResult(tabInfo)
				return
			end	
		end
		if not self:CheckCanReconnect() then
			funResult(nil)
			return
		end	
		SetOnceTimer(function()
			self:GetSvrPoolCfg(strCfgName, funResult)
		end, 10*1000)
	 end
	)
end

function WorkModuleHelper:ReConnectTest(funResult)
	ApiInterfaceModule:QueryRateInfo(funResult)
end

