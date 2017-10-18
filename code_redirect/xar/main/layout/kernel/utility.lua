local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local IPCUtil = XLGetObject("IPC.Util")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")

local g_bLoadCfgSucc = false
local g_JsonFun = nil

local g_tConfigFileStruct = {
	["tUserConfig"] = {
		["strFileName"] = "UserConfig.dat",
		["bEncypt"] = true,
		["tContent"] = {}, 
		["fnMergeOldFile"] = function(infoTable, strFileName,bEncypt) return MergeOldUserCfg(infoTable, strFileName,bEncypt) end,
	},
	["tEarnings"] = {
		["strFileName"] = "Earnings.dat",
		["tContent"] = {}, 
	},
}
---[[ forlocal
function LoadLocalSvrHelper()
	local strLocalSvrHelper = __document.."\\..\\..\\localcfghelper.lua"
	local Module = XLLoadModule(strLocalSvrHelper)
end
LoadLocalSvrHelper()
--]]
function LoadJSONHelper()
	local strJSONHelperPath = __document.."\\..\\..\\JSON.lua"
	local Module = XLLoadModule(strJSONHelperPath)
	g_JsonFun = XLGetGlobal("Clent.Json")
end
LoadJSONHelper()

function IsNilString(AString)
	if AString == nil or AString == "" then
		return true
	end
	return false
end

function IsRealString(str)
	return type(str) == "string" and str ~= ""
end

function MessageBox(str)
	if not IsRealString(str) then
		return
	end
	
	tipUtil:MsgBox(str, "错误", 0x10)
end

function TipLog(strLog)
	tipUtil:Log("utility: " .. tostring(strLog))
end

function LoadTableFromFile(strDatFilePath)
	local tResult = nil

	if IsRealString(strDatFilePath) and tipUtil:QueryFileExists(strDatFilePath) then
		local tMod = XLLoadModule(strDatFilePath)
		if type(tMod) == "table" and type(tMod.GetSubTable) == "function" then
			local tDat = tMod.GetSubTable()
			if type(tDat) == "table" then
				tResult = tDat
			end
		end
	end
	
	return tResult
end

function FetchValueByPath(obj, path)
	local cursor = obj
	for i = 1, #path do
		cursor = cursor[path[i]]
		if cursor == nil then
			return nil
		end
	end
	return cursor
end

function DeCodeJson(strInfo,fnFail)
	local tabInfo = nil	
	local ret,errMessage=pcall(function()
								tabInfo = g_JsonFun:decode(strInfo)
							   end) 
	if not ret then
		TipLog("ret:" .. (ret and "true" or "false" )  .. " \nerrMessage:" .. (errMessage or "null")); 
		if type(funFail) == "function" then
			funFail()
		end
	end
	return tabInfo
end

function GetFileNameFromPath(strPath)
	local _,_,strFileName = string.find(tostring(strPath), ".+\\([^\\]+)$")
	return strFileName
end

function GetCommandStrValue(strKey)
	local bRet, strValue = false, nil
	local cmdString = tipUtil:GetCommandLine()
	
	if string.find(cmdString, strKey .. " ") then
		local cmdList = tipUtil:CommandLineToList(cmdString)
		if cmdList ~= nil then	
			for i = 1, #cmdList, 1 do
				local strTmp = tostring(cmdList[i])
				if strTmp == strKey 
					and not string.find(tostring(cmdList[i + 1]), "^/") then		
					bRet = true
					strValue = tostring(cmdList[i + 1])
					break
				end
			end
		end
	end
	return bRet, strValue
end

function GetTimeStamp()
	local strPeerId = GetPeerID()
	local iFlag = tonumber(string.sub(strPeerId, 12, 12), 16) or 0
	local iTime = tipUtil:GetCurrentUTCTime()
	local ss = math.floor((iTime + 8 * 3600  - (iFlag + 1) * 3600)/(24*3600))
	local strStamp = "?stamp=" .. tostring(ss)
	return strStamp 
end

function GetFileSaveNameFromUrl(url)
	local _, _, strFileName = string.find(tostring(url), ".*/(.*)$")
	local npos = string.find(strFileName, "?", 1, true)
	if npos ~= nil then
		strFileName = string.sub(strFileName, 1, npos-1)
	end
	return strFileName
end

function GetSystemBits()
	local iBits = 0
	if type(tipUtil.GetAllSystemInfo) == "function" then
		local tabSystemInfo =  tipUtil:GetAllSystemInfo()
		if type(tabSystemInfo) == "table" then
			iBits = tabSystemInfo["BitNumbers"]
			if type(iBits) ~= "number" then
				iBits = 0
			end
		end
	end
	return iBits
end

function IsUserFullScreen()
	local bRet = false
	if type(tipUtil.IsNowFullScreen) == "function" then
		bRet = tipUtil:IsNowFullScreen()
	end
	return bRet
end

function IsUACOS()
	local bRet = true
	local iMax, iMin = tipUtil:GetOSVersion()
	if type(iMax) == "number" and iMax <= 5 then
		bRet = false
	end
	return bRet
end

function NumberToFormatMoney(Num)
	local strNum = tostring(Num)
	if string.len(strNum) <= 4 then
		return Num
	end
	local strLeft = string.sub(strNum, 1, string.len(strNum)-4);
	local strRight = string.sub(strNum, -4); 
	local strFormat = strLeft .. "," .. strRight
	TipLog("[NumberToFormatMoney] strFormat = "..tostring(strFormat))
	return strFormat
end

function FormatMoneyToNumber(strMoney)
	if not IsRealString(strMoney) then
		return strMoney
	end
	local strNum = string.gsub(strMoney, ",","")
	return tonumber(strNum)
end

function CheckTimeIsAnotherDay(LastTime)
	local bRet = false
	local LYear, LMonth, LDay, LHour, LMinute, LSecond = tipUtil:FormatCrtTime(LastTime)
	local curTime = tipUtil:GetCurrentUTCTime()
	local CYear, CMonth, CDay, CHour, CMinute, CSecond = tipUtil:FormatCrtTime(curTime)
	if LYear ~= CYear or LMonth ~= CMonth or LDay ~= CDay then
		bRet = true
	end
	return bRet
end

function CheckIsAnotherDay(nLastTime, nCurrentTime)
	local bRet = false
	local nLYear, nLMonth, nLDay, nLHour, nLMinute, nLSecond = tipUtil:FormatCrtTime(nLastTime)
	local nCYear, nCMonth, nCDay, nCHour, nCMinute, nCSecond = tipUtil:FormatCrtTime(nCurrentTime)
	if nLYear ~= nCYear or nLMonth ~= nCMonth or nLDay ~= nCDay then
		bRet = true
	end
	return bRet
end

function RegQueryValue(sPath)
	if IsRealString(sPath) then
		local sRegRoot, sRegPath, sRegKey = string.match(sPath, "^(.-)[\\/](.*)[\\/](.-)$")
		if IsRealString(sRegRoot) and IsRealString(sRegPath) then
			return tipUtil:QueryRegValue(sRegRoot, sRegPath, sRegKey or "") or ""
		end
	end
	return ""
end

function RegDeleteValue(sPath)
	if IsRealString(sPath) then
		local sRegRoot, sRegPath = string.match(sPath, "^(.-)[\\/](.*)")
				
		if IsRealString(sRegRoot) and IsRealString(sRegPath) then
			return tipUtil:DeleteRegValue(sRegRoot, sRegPath)
		end
	end
	return false
end

function RegSetValue(sPath, value)
	if IsRealString(sPath) then
		local sRegRoot, sRegPath, sRegKey = string.match(sPath, "^(.-)[\\/](.*)[\\/](.-)$")
		if IsRealString(sRegRoot) and IsRealString(sRegPath) then
			if not tipUtil:QueryRegKeyExists(sRegRoot, sRegPath) then
				tipUtil:CreateRegKey(sRegRoot, sRegPath)
			end
			return tipUtil:SetRegValue(sRegRoot, sRegPath, sRegKey or "", value or "")
		end
	end
	return false
end

function QueryAllUsersDir()	--获取AllUser路径
	local bRet = false
	local strPublicEnv = "%PUBLIC%"
	local strRet = tipUtil:ExpandEnvironmentStrings(strPublicEnv)
	if strRet == nil or strRet == "" or strRet == strPublicEnv then
		local nCSIDL_COMMON_APPDATA = 35 --CSIDL_COMMON_APPDATA(0x0023)
		strRet = tipUtil:GetSpecialFolderPathEx(nCSIDL_COMMON_APPDATA)
	end
	if not IsNilString(strRet) and tipUtil:QueryFileExists(strRet) then
		bRet = true
	end
	return bRet, strRet
end

function GetPeerID()
	local strPeerID = RegQueryValue("HKEY_LOCAL_MACHINE\\Software\\Share4Money\\PeerId")
	local strDecryptPeerID = tipUtil:DecryptString(strPeerID,"RpXVQTFlU7NaeMcV")
	if IsRealString(strDecryptPeerID) then
		return string.upper(strDecryptPeerID)
	end

	local strRandPeerID = tipUtil:GetPeerId()
	if not IsRealString(strRandPeerID) then
		return ""
	end
	local strEncryptPeerID = tipUtil:EncryptString(strRandPeerID,"RpXVQTFlU7NaeMcV")
	RegSetValue("HKEY_LOCAL_MACHINE\\Software\\Share4Money\\PeerId", strEncryptPeerID)
	return string.upper(strRandPeerID)
end

function CheckPeerIDList(tPIDlist)
	if type(tPIDlist) == "table" and #tPIDlist > 0 then
		local bCheckPid = false
		local strPeerId = GetPeerID()
		local strPeerId12 = string.sub(tostring(strPeerId), 1, 12)
		for i = 1, #tPIDlist do
			if string.find(string.lower(tostring(strPeerId12)), ".*" .. string.lower(tostring(tPIDlist[i])) .. "$", 1) then
				bCheckPid = true
				break
			end
		end
		return bCheckPid
	else
		return true
	end	
end

function GetExePath()
	local strExePath = RegQueryValue("HKEY_LOCAL_MACHINE\\Software\\Share4Money\\Path")
	if IsRealString(strExePath) then
		return tostring(strExePath)
	else
		return tipUtil:GetModuleExeName()
	end
end

function GetModuleDir()
	local strExePath = tipUtil:GetModuleExeName()
	local _,_,strDir = string.find(tostring(strExePath), "(.+)\\[^\\]+$")
	return strDir
end

function GetMachineID()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	local strMachineID = tUserConfig["strMachineID"]
	if not IsRealString(strMachineID) then
		local strRegOldPath = "HKEY_CURRENT_USER\\Software\\Share4Money\\machineid"
		strMachineID = RegQueryValue(strRegOldPath)
		if not IsRealString(strMachineID) then
			strMachineID = tipUtil:CreateGuid()
			--strMachineID = tipUtil:EncryptString(strGUID,"RpXVQTFlU7NaeMcV")
			--RegSetValue("HKEY_CURRENT_USER\\Software\\Share4Money\\machineid", strMachineID)
		else
			RegDeleteValue(strRegOldPath)
		end
		tUserConfig["strMachineID"] = strMachineID
		SaveConfigToFileByKey("tUserConfig")
	end
	if IsRealString(strMachineID) then
		return string.upper(strMachineID)
	end
end

function GetGXZBVersion()
	local strGXZBPath = GetExePath()
	if not IsRealString(strGXZBPath) or not tipUtil:QueryFileExists(strGXZBPath) then
		return ""
	end

	return tipUtil:GetFileVersionString(strGXZBPath)
end

function GetGXZBMinorVer()
	local strVersion = GetGXZBVersion()
	if not IsRealString(strVersion) then
		return ""
	end
	
	local _, _, strMinorVer = string.find(strVersion, "%d+%.%d+%.%d+%.(%d+)")
	return strMinorVer
end

function GetInstallSrc()
	local strInstallSrc = RegQueryValue("HKEY_LOCAL_MACHINE\\Software\\Share4Money\\InstallSource")
	if not IsNilString(strInstallSrc) then
		return tostring(strInstallSrc)
	end
	
	return ""
end

function GetResSavePath(strName)
	local bOk, strBaseDir = QueryAllUsersDir()
	if not bOk then
		return ""
	end
	
	local strPath = tipUtil:PathCombine(strBaseDir, "Share4Money\\res\\"..tostring(strName))
	return strPath or ""
end

function InitMachineName()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	if not IsRealString(tUserConfig["tUserInfo"]["strMachineName"]) then 
		local strDeviceName = tipUtil:GetDeviceName()
		if IsRealString(strDeviceName) then
			local iMajor,iMinor = tipUtil:NewGetOSVersion()
			local strWinVer = "Windows " .. tostring(iMajor) .. "." .. tostring(iMinor)
			strDeviceName = tostring(strDeviceName) .. "(" .. strWinVer .. ")"
			TipLog("[InitMachineName] strDeviceName = " .. tostring(strDeviceName))
			tUserConfig["tUserInfo"]["strMachineName"] = strDeviceName
		else
			tUserConfig["tUserInfo"]["strMachineName"] = GetPeerID()
		end
		SaveConfigToFileByKey("tUserConfig")
	end
	return tUserConfig["tUserInfo"]["strMachineName"]
end

function GetMachineName()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	if IsRealString(tUserConfig["tUserInfo"]["strMachineName"]) then 
		return tUserConfig["tUserInfo"]["strMachineName"]
	else	
		return InitMachineName()
	end
end

function WriteLastLaunchTime()
	local nCurrnetTime = tipUtil:GetCurrentUTCTime()
	local strRegPath = "HKEY_CURRENT_USER\\SOFTWARE\\Share4Money\\LastLaunchTime"
	RegSetValue(strRegPath, nCurrnetTime)
end


--服务器时间
function SplitStringBySeperator(strToSplit, strSeperator)
	local tResult = {}
	
	if type(strToSplit) == "string" and type(strSeperator) == "string" then
		local nSepStartPos = 0
		local nSepEndPos = 0
		local nLastSepStartPos = 0
		local nLastSepEndPos = 0
		while true do
			nLastSepStartPos = nSepStartPos
			nLastSepEndPos = nSepEndPos
			nSepStartPos, nSepEndPos = string.find(strToSplit, strSeperator, nLastSepEndPos + 1)
			if type(nSepStartPos) ~= "number" or type(nSepEndPos) ~= "number" then
				tResult[#tResult + 1] = string.sub(strToSplit, nLastSepEndPos + 1, -1)
				break
			end
			tResult[#tResult + 1] = string.sub(strToSplit, nLastSepEndPos + 1, nSepStartPos - 1)
		end
	end

	return tResult
end

function ExtractHttpHeaders(strHttpHeaders)
	local tResult = {}
	
	local tHeaderSet = SplitStringBySeperator(strHttpHeaders, "\r\n")
	for i = 1, #tHeaderSet do
		local tHeader = SplitStringBySeperator(tHeaderSet[i], ": ")
		if #tHeader == 2 
			and type(tHeader[1]) == "string" and tHeader[1] ~= "" 
			and type(tHeader[2]) == "string" and tHeader[2] ~= "" 
			then
			tResult[tHeader[1]] = tHeader[2]
		end
	end
	
	return tResult
end

function UpdateTimeCalibration(nLocalUTCInSec, nSvrUTCInSec)
	local nDefaultUTCInSec = tipUtil:GetCurrentUTCTime() or 0
	local nNewLocalUTCInSec = nDefaultUTCInSec
	local nNewSvrUTCInSec = nDefaultUTCInSec
	if type(nLocalUTCInSec) == "number" and type(nSvrUTCInSec) == "number" then
		nNewLocalUTCInSec = nLocalUTCInSec
		nNewSvrUTCInSec = nSvrUTCInSec
	end
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["tStandardTime"] = {}
	tUserConfig["tStandardTime"]["nLocalTime"] = nNewLocalUTCInSec
	tUserConfig["tStandardTime"]["nServerTime"] = nNewSvrUTCInSec
	SaveConfigToFileByKey("tUserConfig")
end

function GetTimeCalibration()
	local nDefaultUTCInSec = tipUtil:GetCurrentUTCTime() or 0
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	local tTime = tUserConfig["tStandardTime"] or {}
	local nLocalTimeUTCInSec = tTime["nLocalTime"] or nDefaultUTCInSec
	local nSvrTimeUTCInSec = tTime["nServerTime"] or nDefaultUTCInSec
	if tTime["ignore"] == 1 then
		nLocalTimeUTCInSec = 0
		nSvrTimeUTCInSec = 0
	end
	
	return nLocalTimeUTCInSec, nSvrTimeUTCInSec
end

function GetCurrentServerTime()
	local nCurLocalUTCInSec = tipUtil:GetCurrentUTCTime() or 0
	local nLocalUTCInSec, nSvrUTCInSec = GetTimeCalibration()
	local nCurSvrUTCInSec = nCurLocalUTCInSec + (nSvrUTCInSec - nLocalUTCInSec)
	return nCurSvrUTCInSec
end

--开机启动 配置逻辑
function WriteCfgSetBoot()
	if CheckCfgSetBoot() then
		return
	end
	local nCurrnetTime = tipUtil:GetCurrentUTCTime()
	local strRegPath = "HKEY_CURRENT_USER\\SOFTWARE\\Share4Money\\LastSetBootTime"
	RegSetValue(strRegPath, nCurrnetTime)
end

function DeleteCfgSetBoot()
	local strRegPath = "HKEY_CURRENT_USER\\SOFTWARE\\Share4Money\\LastSetBootTime"
	RegDeleteValue(strRegPath)
end

function CheckCfgSetBoot()
	local bRet = false
	if CheckSysSetBoot() then
		bRet = true
	end
	local nValue = tipUtil:QueryRegValue("HKEY_CURRENT_USER", "SOFTWARE\\Share4Money", "LastSetBootTime")
	if nValue ~= nil then
		bRet = true
	end
	if bRet and nValue == nil then
		local nCurrnetTime = tipUtil:GetCurrentUTCTime()
		local strRegPath = "HKEY_CURRENT_USER\\SOFTWARE\\Share4Money\\LastSetBootTime"
		RegSetValue(strRegPath, nCurrnetTime)
	end
	return bRet
end

function WriteSysSetBoot()
	if CheckSysSetBoot() then
		return
	end
	local strRegPath = "HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\Share4Money"
	local strExePath = GetExePath()
	local strValue = "\""..strExePath.."\" /sstartfrom sysboot /embedding /working"
	RegSetValue(strRegPath, strValue)
end

function DeleteSysSetBoot()
	local strRegPath = "HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\Share4Money"
	RegDeleteValue(strRegPath)
end

function CheckSysSetBoot()
	local strRegPath = "HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\Share4Money"
	local strValue = RegQueryValue(strRegPath)
	return IsRealString(strValue) 
end

--配置相关
function SaveAllConfig()
	if g_bLoadCfgSucc then
		for strKey, tContent in pairs(g_tConfigFileStruct) do
			SaveConfigToFileByKey(strKey)
		end
	end
end

function SaveConfigInTimer()
	local nTimeSpanInMs = 10 * 60 * 1000
	timeMgr:SetTimer(function(item, id)
		SaveAllConfig()
	end, nTimeSpanInMs)
end

function ReadAllConfigInfo()
	for strKey, tConfig in pairs(g_tConfigFileStruct) do
		local strFileName = tConfig["strFileName"]
		local strCfgPath = GetCfgPathWithName(strFileName)
		local infoTable = nil
		if tConfig["bEncypt"] and not tipUtil:IsFilePlaintext(strCfgPath) then
			local strDecryptPath = GenDecFilePath(strCfgPath)
			TipLog("[ReadAllConfigInfo] strDecryptPath = "..tostring(strDecryptPath))
			if IsRealString(strDecryptPath) then
				infoTable = LoadTableFromFile(strDecryptPath)
				tipUtil:DeletePathFile(strDecryptPath)
			end	
		else
			infoTable = LoadTableFromFile(strCfgPath)
		end
		if type(infoTable) ~= "table" then
			TipLog("[ReadAllConfigInfo] GetConfigFile failed! "..tostring(strFileName))
			--读失败了不用返回
			--return false
		end
		infoTable = infoTable or {}
		
		local tContent = infoTable
		local bMerge = false
		local fnMergeOldFile = tConfig["fnMergeOldFile"]
		if type(fnMergeOldFile) == "function" then
			bMerge, tContent = fnMergeOldFile(infoTable, strFileName,tConfig["bEncypt"])
		end
		
		tConfig["tContent"] = tContent
		if bMerge then
			SaveConfigToFileByKey(strKey)
		end
	end

	g_bLoadCfgSucc = true	
	TipLog("[ReadAllConfigInfo] success!")
	return true
end

function EncryptFilePath(strTmpPath,strSavePath)
	local strKey = "RpXVQTFlU7NaeMcV"
	local strData = tipUtil:ReadFileToString(strTmpPath)
	tipUtil:EncryptAESToFile(strSavePath,strData,strKey)
	tipUtil:DeletePathFile(strTmpPath)
end

function GenDecFilePath(strEncFilePath)
	local strKey = "RpXVQTFlU7NaeMcV"
	local strDecString = tipUtil:DecryptFileAES(strEncFilePath, strKey)
	if type(strDecString) ~= "string" then
		TipLog("[GenDecFilePath] DecryptFileAES failed : "..tostring(strEncFilePath))
		return ""
	end
	
	local strTmpDir = tipUtil:GetSystemTempPath()
	if not tipUtil:QueryFileExists(strTmpDir) then
		TipLog("[GenDecFilePath] GetSystemTempPath failed strTmpDir: "..tostring(strTmpDir))
		return ""
	end
	
	local strCfgName = tipUtil:GetTmpFileName() or "s4mcfg.dat"
	local strCfgPath = tipUtil:PathCombine(strTmpDir, strCfgName)
	tipUtil:WriteStringToFile(strCfgPath, strDecString)
	return strCfgPath
end

function ReadConfigFromMemByKey(strKey)
	if not IsRealString(strKey) or type(g_tConfigFileStruct[strKey])~="table" then
		return nil
	end

	local tContent = g_tConfigFileStruct[strKey]["tContent"]
	return tContent
end

function GetCfgPathWithName(strCfgName)
	local bOk, strBaseDir = QueryAllUsersDir()
	if not bOk then
		return ""
	end
	
	local strCfgFilePath = tipUtil:PathCombine(strBaseDir, "Share4Money\\"..tostring(strCfgName))
	return strCfgFilePath or ""
end

function SaveConfigToFileByKey(strKey)
	if not IsRealString(strKey) or type(g_tConfigFileStruct[strKey])~="table" then
		return
	end

	local strFileName = g_tConfigFileStruct[strKey]["strFileName"]
	local tContent = g_tConfigFileStruct[strKey]["tContent"]
	local strConfigPath = GetCfgPathWithName(strFileName)
	if IsRealString(strConfigPath) and type(tContent) == "table" then
		if not g_tConfigFileStruct[strKey]["bEncypt"] then
			tipUtil:SaveLuaTableToLuaFile(tContent, strConfigPath)
		else
			local strTmpPath = strConfigPath .. ".tmp"
			tipUtil:SaveLuaTableToLuaFile(tContent, strTmpPath)
			EncryptFilePath(strTmpPath,strConfigPath)
		end
	end	
end

function MergeOldUserCfg(tCurrentCfg, strFileName, bEncypt)
	local tOldCfg, strOldCfgPath = GetOldCfgContent(strFileName,bEncypt)
	if type(tOldCfg) ~= "table" then
		return false, tCurrentCfg
	end
	
	for k, v in pairs(tOldCfg) do
		--除了strServerConfigURL，其他都用老的
		if k ~= "strServerConfigURL" then
			tCurrentCfg[k] = v
		end
	end
	
	tipUtil:DeletePathFile(strOldCfgPath)
	return true, tCurrentCfg
end

function GetOldCfgContent(strCurFileName,bEncypt)
	local strOldFileName = strCurFileName..".bak"
	local strOldCfgPath = GetCfgPathWithName(strOldFileName)
	if not IsRealString(strOldCfgPath) or not tipUtil:QueryFileExists(strOldCfgPath) then
		return nil
	end
	local tOldCfg = nil
	if bEncypt and not tipUtil:IsFilePlaintext(strOldCfgPath) then
		local strDecryptPath = GenDecFilePath(strOldCfgPath)
		TipLog("[GetOldCfgContent] strDecryptPath = "..tostring(strDecryptPath))
		if IsRealString(strDecryptPath) then
			tOldCfg = LoadTableFromFile(strDecryptPath)
			tipUtil:DeletePathFile(strDecryptPath)
		end	
	else
		tOldCfg = LoadTableFromFile(strOldCfgPath)
	end
	return tOldCfg, strOldCfgPath
end

--下载相关
function CheckMD5(strFilePath, strExpectedMD5) 
	local bPassCheck = false
	
	if not IsNilString(strFilePath) then
		local strMD5 = tipUtil:GetMD5Value(strFilePath)
		TipLog("[CheckMD5] strFilePath = " .. tostring(strFilePath) .. ", strMD5 = " .. tostring(strMD5))
		if not IsRealString(strExpectedMD5) 
			or (not IsNilString(strMD5) and not IsNilString(strExpectedMD5) and string.lower(strMD5) == string.lower(strExpectedMD5))
			then
			bPassCheck = true
		end
	end
	
	TipLog("[CheckMD5] strFilePath = " .. tostring(strFilePath) .. ", strExpectedMD5 = " .. tostring(strExpectedMD5) .. ". bPassCheck = " .. tostring(bPassCheck))
	return bPassCheck
end

function NewAsynGetHttpFile(strUrl, strSavePath, bDelete, funCallback, nTimeoutInMS)
	local bHasAlreadyCallback = false
	local timerID = nil
	if false then
	--if string.find(strUrl, "^https://") == nil then
		tipAsynUtil:AsynGetHttpFile(strUrl, strSavePath, bDelete, 
			function (nRet, strTargetFilePath, strHeaders)
				if timerID ~= nil then
					tipAsynUtil:KillTimer(timerID)
				end
				if not bHasAlreadyCallback then
					bHasAlreadyCallback = true
					funCallback(nRet, strTargetFilePath, strHeaders)
				end
			end)
	else
		tipAsynUtil:AjaxGetHttpFile(strUrl, strSavePath, function(nRet, strTargetFilePath, strHeaders)
			if timerID ~= nil then
				tipAsynUtil:KillTimer(timerID)
			end
			if not bHasAlreadyCallback then
				bHasAlreadyCallback = true
				funCallback(nRet, strTargetFilePath, strHeaders)
			end
		end)
	end
	
	timerID = tipAsynUtil:SetTimer(nTimeoutInMS or 2 * 60 * 1000,
		function (nTimerId)
			tipAsynUtil:KillTimer(nTimerId)
			timerID = nil
			if not bHasAlreadyCallback then
				bHasAlreadyCallback = true
				funCallback(-2)
			end
		end)
end

function NewAsynGetHttpContent(strUrl, bDelete,funCallback, nTimeoutInMS)
	local bHasAlreadyCallback = false
	local timerID = nil 
	
	tipAsynUtil:AsynGetHttpContent(strUrl, bDelete,
		function(nRet, strContent, respHeaders)
			if timerID ~= nil then
				tipAsynUtil:KillTimer(timerID)
			end
			if not bHasAlreadyCallback then
				bHasAlreadyCallback = true
				funCallback(nRet, strContent, respHeaders)
			end
		end)	
	timerID = tipAsynUtil:SetTimer(nTimeoutInMS or 2 * 60 * 1000,
		function (nTimerId)
			tipAsynUtil:KillTimer(nTimerId)
			timerID = nil
			if not bHasAlreadyCallback then
				bHasAlreadyCallback = true
				funCallback(-2)
			end
		end)
end


--升级相关
function CheckForceVersion(tForceVersion)
	if type(tForceVersion) ~= "table" then
		return false
	end

	local bRightVer = false
	
	local strCurVersion = GetGXZBVersion()
	local _, _, _, _, _, strCurVersion_4 = string.find(strCurVersion, "(%d+)%.(%d+)%.(%d+)%.(%d+)")
	local nCurVersion_4 = tonumber(strCurVersion_4)
	if type(nCurVersion_4) ~= "number" then
		return bRightVer
	end
	for iIndex = 1, #tForceVersion do
		local strRange = tForceVersion[iIndex]
		local iPos = string.find(strRange, "-")
		if iPos ~= nil then
			local lVer = tonumber(string.sub(strRange, 1, iPos - 1))
			local hVer = tonumber(string.sub(strRange, iPos + 1))
			if lVer ~= nil and hVer ~= nil and nCurVersion_4 >= lVer and nCurVersion_4 <= hVer then
				bRightVer = true
				break
			end
		else
			local verFlag = tonumber(strRange)
			if verFlag ~= nil and nCurVersion_4 == verFlag then
				bRightVer = true
				break
			end
		end
	end
	
	return bRightVer
end

function CheckCommonUpdateTime(nTimeInDay)
	return CheckUpdateTimeSpan(nTimeInDay, "nLastCommonUpdateUTC")
end

function SaveCommonUpdateUTC()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["nLastCommonUpdateUTC"] = tipUtil:GetCurrentUTCTime()
	SaveConfigToFileByKey("tUserConfig")
end

function CheckAutoUpdateTime(nTimeInDay)
	return CheckUpdateTimeSpan(nTimeInDay, "nLastAutoUpdateUTC")
end

function CheckUpdateTimeSpan(nTimeInDay, strUpdateType)
	if type(nTimeInDay) ~= "number" then
		return false
	end
	
	local nTimeInSec = nTimeInDay*24*3600
	local nCurTimeUTC = tipUtil:GetCurrentUTCTime()
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	local nLastUpdateUTC = tUserConfig[strUpdateType] or 0
	local nTimeSpan = math.abs(nCurTimeUTC - nLastUpdateUTC)
	
	if nTimeSpan > nTimeInSec then
		return true
	end	
	
	return false
end

function CheckIsNewVersion(strNewVer, strCurVer)
	if not IsRealString(strNewVer) or not IsRealString(strCurVer) then
		return false
	end

	local a,b,c,d = string.match(strNewVer, "(%d+)%.(%d+)%.(%d+)%.(%d+)")
	local A,B,C,D = string.match(strCurVer, "(%d+)%.(%d+)%.(%d+)%.(%d+)")
	
	a = tonumber(a)
	b = tonumber(b)
	c = tonumber(c)
	d = tonumber(d)
	
	A = tonumber(A)
	B = tonumber(B)
	C = tonumber(C)
	D = tonumber(D)
	
	return a>A or (a==A and (b>B or (b==B and (c>C or (c==C and d>D)))))
end

function DownLoadFileWithCheck(strURL, strSavePath, strCheckMD5, fnCallBack)
	if type(fnCallBack) ~= "function"  then
		return
	end

	if IsRealString(strCheckMD5) and CheckMD5(strSavePath, strCheckMD5) then
		TipLog("[DownLoadFileWithCheck]File Already existed")
		fnCallBack(1, strSavePath)
		return
	end
	
	NewAsynGetHttpFile(strURL, strSavePath, false, function(bRet, strDownLoadPath)
		TipLog("[DownLoadFileWithCheck] NewAsynGetHttpFile:bret = " .. tostring(bRet) 
				.. ", strURL = " .. tostring(strURL) .. ", strDownLoadPath = " .. tostring(strDownLoadPath))
		if 0 == bRet then
			strSavePath = strDownLoadPath
            if CheckMD5(strSavePath, strCheckMD5) then
				fnCallBack(bRet, strSavePath)
			else
				TipLog("[DownLoadFileWithCheck]Did Not Pass MD5 Check")
				fnCallBack(-2)
			end	
		else
			TipLog("[DownLoadFileWithCheck] DownLoad failed")
			fnCallBack(-3)
		end
	end)
end

function DownLoadNewVersion(tNewVersionInfo, fnCallBack)
	local strPacketURL = tNewVersionInfo.strPacketURL
	local strMD5 = tNewVersionInfo.strMD5
	if not IsRealString(strPacketURL) then
		return
	end
	
	local strFileName = GetFileSaveNameFromUrl(strPacketURL)
	if not string.find(strFileName, "%.exe$") then
		strFileName = strFileName..".exe"
	end
	local strSaveDir = tipUtil:GetSystemTempPath()
	local strSavePath = tipUtil:PathCombine(strSaveDir, strFileName)
	
	local strStamp = GetTimeStamp()
	local strURLFix = strPacketURL..strStamp
	
	DownLoadFileWithCheck(strURLFix, strSavePath, strMD5
	, function(bRet, strRealPath)
		TipLog("[DownLoadNewVersion] strOpenLink:"..tostring(strPacketURL)
		        .."  bRet:"..tostring(bRet).."  strRealPath:"..tostring(strRealPath))
				
		if 0 == bRet then
			fnCallBack(strRealPath, tNewVersionInfo)
			return
		end
		
		if 1 == bRet then	--安装包已经存在
			fnCallBack(strSavePath, tNewVersionInfo)
			return
		end
		fnCallBack(nil)
	end)	
end

function DownLoadServerConfig(fnCallBack, nTimeInMs)
	local tUserConfig = ReadConfigFromMemByKey("tUserConfig") or {}
	local strConfigURL = tUserConfig["strServerConfigURL"] or ClientWorkModule._strSeverConfigPrefix .. "/static/ServerConfig.dat"
	local strSavePath = GetCfgPathWithName("ServerConfig.dat")
	local strStamp = GetTimeStamp()
	local strURLFix = strConfigURL..strStamp
	local nTime = tonumber(nTimeInMs) or 5*1000
	local nBeginLocalUTCInSec = tipUtil:GetCurrentUTCTime() or 0	
	NewAsynGetHttpFile(strURLFix, strSavePath, false
	, function(bRet, strRealPath, strHttpHeaders)
		TipLog("[DownLoadServerConfig] bRet:"..tostring(bRet)
				..", strRealPath:"..tostring(strRealPath)
				.. ", strHttpHeaders = " .. tostring(strHttpHeaders))
		local nEndLocalUTCInSec = tipUtil:GetCurrentUTCTime() or 0
		local nAvgLocalUTCInSec = math.floor((nBeginLocalUTCInSec + nEndLocalUTCInSec) / 2)
		local tHttpHeaders = ExtractHttpHeaders(strHttpHeaders)	
		if type(tHttpHeaders["Date"]) == "string" then
			local nSvrUTCInSec = tipUtil:InternetTimeToUTCTime(tHttpHeaders["Date"])
			if nAvgLocalUTCInSec ~= 0 
				and type(nSvrUTCInSec) == "number" and nSvrUTCInSec ~= 0 
				then
				UpdateTimeCalibration(nAvgLocalUTCInSec, nSvrUTCInSec)
			end
		end
		if 0 == bRet then
			--[[ forlocal
			strSavePath = GetLocalSvrCfgWithName("ServerConfig.dat", true)
			--]]
			fnCallBack(0, strSavePath)
		else
			fnCallBack(bRet)
		end		
	end, nTime)
end



function RegisterFunctionObject(self)
	local obj = {}
	--通用功能函数
	obj.TipLog = TipLog
	obj.IsNilString = IsNilString
	obj.IsRealString = IsRealString
	obj.MessageBox = MessageBox
	obj.LoadTableFromFile = LoadTableFromFile
	obj.FetchValueByPath = FetchValueByPath
	
	obj.DeCodeJson = DeCodeJson
	obj.GetFileNameFromPath = GetFileNameFromPath
	obj.GetCommandStrValue = GetCommandStrValue
	obj.GetTimeStamp = GetTimeStamp
	obj.GetFileSaveNameFromUrl = GetFileSaveNameFromUrl
	obj.GetSystemBits = GetSystemBits
	obj.IsUserFullScreen = IsUserFullScreen
	obj.IsUACOS = IsUACOS
	obj.NumberToFormatMoney = NumberToFormatMoney
	obj.FormatMoneyToNumber = FormatMoneyToNumber
	obj.CheckTimeIsAnotherDay = CheckTimeIsAnotherDay
	obj.CheckIsAnotherDay = CheckIsAnotherDay
	obj.RegQueryValue = RegQueryValue
	obj.RegDeleteValue = RegDeleteValue
	obj.RegSetValue = RegSetValue
	
	
	obj.QueryAllUsersDir = QueryAllUsersDir
	obj.GetPeerID = GetPeerID
	obj.CheckPeerIDList = CheckPeerIDList
	obj.GetExePath = GetExePath
	obj.GetModuleDir = GetModuleDir
	obj.GetMachineID = GetMachineID
	obj.GetGXZBVersion = GetGXZBVersion
	obj.GetGXZBMinorVer = GetGXZBMinorVer
	obj.GetInstallSrc = GetInstallSrc
	obj.GetResSavePath = GetResSavePath
	obj.InitMachineName = InitMachineName
	obj.GetMachineName = GetMachineName
	obj.WriteLastLaunchTime = WriteLastLaunchTime
	
	--服务器时间的获取
	obj.SplitStringBySeperator = SplitStringBySeperator
	obj.ExtractHttpHeaders = ExtractHttpHeaders
	obj.UpdateTimeCalibration = UpdateTimeCalibration
	obj.GetTimeCalibration = GetTimeCalibration
	obj.GetCurrentServerTime = GetCurrentServerTime
	
	--开机启动配置
	obj.WriteCfgSetBoot = WriteCfgSetBoot
	obj.DeleteCfgSetBoot = DeleteCfgSetBoot
	obj.CheckCfgSetBoot = CheckCfgSetBoot
	obj.WriteSysSetBoot = WriteSysSetBoot
	obj.DeleteSysSetBoot = DeleteSysSetBoot
	obj.CheckSysSetBoot = CheckSysSetBoot
	
	--配置相关
	obj.SaveAllConfig = SaveAllConfig
	obj.SaveConfigInTimer = SaveConfigInTimer
	obj.ReadAllConfigInfo = ReadAllConfigInfo
	obj.EncryptFilePath = EncryptFilePath
	obj.GenDecFilePath = GenDecFilePath
	obj.ReadConfigFromMemByKey = ReadConfigFromMemByKey
	obj.GetCfgPathWithName = GetCfgPathWithName
	obj.SaveConfigToFileByKey = SaveConfigToFileByKey
	obj.MergeOldUserCfg = MergeOldUserCfg
	obj.GetOldCfgContent = GetOldCfgContent
	
	--下载
	obj.CheckMD5 = CheckMD5
	obj.NewAsynGetHttpFile = NewAsynGetHttpFile
	obj.NewAsynGetHttpContent = NewAsynGetHttpContent
	
	--升级相关
	obj.CheckForceVersion = CheckForceVersion
	obj.CheckCommonUpdateTime = CheckCommonUpdateTime
	obj.SaveCommonUpdateUTC = SaveCommonUpdateUTC
	obj.CheckAutoUpdateTime = CheckAutoUpdateTime
	obj.CheckUpdateTimeSpan = CheckUpdateTimeSpan
	obj.CheckIsNewVersion = CheckIsNewVersion
	obj.DownLoadFileWithCheck = DownLoadFileWithCheck
	obj.DownLoadNewVersion = DownLoadNewVersion
	
	obj.DownLoadServerConfig = DownLoadServerConfig
	XLSetGlobal("FunctionHelper", obj)
end	
RegisterFunctionObject()

