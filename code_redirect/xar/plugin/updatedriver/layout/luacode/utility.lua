local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")

local tUserConfig = nil

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
	tipUtil:Log("utility: " .. tostring(strLog))
end

function GTV(obj)
	return "[" .. type(obj) .. "`" .. tostring(obj) .. "]"
end

function _DumpObj(obj, strIndent)
	if type(strIndent) ~= "string" then return end
	
	if type(obj) ~= "table" then
		TipLog(strIndent .. " obj = " .. GTV(obj));
		return;
	end
	
	local strIndentUnit = "   ";
	for key, value in pairs(obj) do
		TipLog(strIndent .. " obj(" .. tostring(obj) .. ")[" .. GTV(key) .. "] = " .. GTV(value));
		_DumpObj(value, strIndent .. strIndentUnit);
	end
end

function DumpObj(obj, strObjName) --打印Table表信息
	local strIndent = "";
	if type(strObjName) == "string" then
		strIndent = strObjName;
	end
	_DumpObj(obj, strIndent);
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

function RegQueryValue(sPath)
	if IsRealString(sPath) then
		local sRegRoot, sRegPath, sRegKey = string.match(sPath, "^(.-)[\\/](.*)[\\/](.-)$")
		if IsRealString(sRegRoot) and IsRealString(sRegPath) then
			return tipUtil:QueryRegValue(sRegRoot, sRegPath, sRegKey or "") or ""
		end
	end
	return ""
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
    local strDebugPeerID = RegQueryValue("HKEY_CURRENT_USER\\Software\\Share4Money\\PeerId")
    if IsRealString(strDebugPeerID) then
        return strDebugPeerID
    end
	local strPeerID = RegQueryValue("HKEY_LOCAL_MACHINE\\Software\\Share4Money\\PeerId")
	local strDecryptPeerID = tipUtil:DecryptString(strPeerID,"RpXVQTFlU7NaeMcV")
	if IsRealString(strDecryptPeerID) then
		return string.upper(strDecryptPeerID)
	end

	local strRandPeerID = tipUtil:GetPeerId()
	if not IsRealString(strRandPeerID) then
		return ""
	end
	return string.upper(strRandPeerID)
end

function GetExePath()
	local strExePath = RegQueryValue("HKEY_LOCAL_MACHINE\\Software\\Share4Money\\Path")
	if IsRealString(strExePath) and tipUtil:QueryFileExists(strExePath) then
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

function GetGXZBVersion()
	local strGXZBPath = GetExePath()
	if not IsRealString(strGXZBPath) or not tipUtil:QueryFileExists(strGXZBPath) then
		return ""
	end

	return tipUtil:GetFileVersionString(strGXZBPath)
end

function GetInstallSrc()
	local strInstallSrc = RegQueryValue("HKEY_LOCAL_MACHINE\\Software\\Share4Money\\InstallSource")
	if not IsNilString(strInstallSrc) then
		return tostring(strInstallSrc)
	end
	
	return ""
end

function MakeInterfaceMd5(strInterface,strInterfaceParam)
	local strParam = "/" .. strInterface .. "?" .. tostring(strInterfaceParam)
	local strMd5 = tipUtil:GetStringMD5(strParam)
	strParam = strParam .. "&md5=" .. strMd5
	return strParam
end

function GetCfgPathWithName(strCfgName)
	local bOk, strBaseDir = QueryAllUsersDir()
	if not bOk then
		return ""
	end
	
	local strCfgFilePath = tipUtil:PathCombine(strBaseDir, "Share4Money\\"..tostring(strCfgName))
	return strCfgFilePath or ""
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

function ReadUserConfig()
	if tUserConfig == nil then
		local strCfgPath = GetCfgPathWithName("UserConfig.dat")
		if not tipUtil:IsFilePlaintext(strCfgPath) then
			local strDecryptPath = GenDecFilePath(strCfgPath)
			TipLog("[ReadUserConfigInfo] strDecryptPath = "..tostring(strDecryptPath))
			if IsRealString(strDecryptPath) then
				tUserConfig = LoadTableFromFile(strDecryptPath)
				tipUtil:DeletePathFile(strDecryptPath)
			end	
		else
			tUserConfig = LoadTableFromFile(strCfgPath)
		end
		if type(tUserConfig) ~= "table" then
			TipLog("[ReadUserConfigInfo] GetConfigFile failed! ")
			tUserConfig = {}
		end
	end
	return tUserConfig
end

function RegisterFunctionObject(self)
	local obj = {}
	--通用功能函数
	obj.TipLog = TipLog
	obj.DumpObj = DumpObj
	obj.IsNilString = IsNilString
	obj.IsRealString = IsRealString
	obj.LoadTableFromFile = LoadTableFromFile
	obj.FetchValueByPath = FetchValueByPath
	
	obj.GetFileNameFromPath = GetFileNameFromPath
	obj.GetCommandStrValue = GetCommandStrValue
	obj.GetTimeStamp = GetTimeStamp
	obj.GetFileSaveNameFromUrl = GetFileSaveNameFromUrl
	obj.GetSystemBits = GetSystemBits
	obj.IsUserFullScreen = IsUserFullScreen
	obj.IsUACOS = IsUACOS
	
	obj.RegQueryValue = RegQueryValue
	obj.RegSetValue = RegSetValue
	
	obj.QueryAllUsersDir = QueryAllUsersDir
	obj.GetPeerID = GetPeerID
	obj.GetExePath = GetExePath
	obj.GetModuleDir = GetModuleDir
	obj.GetGXZBVersion = GetGXZBVersion
	obj.GetInstallSrc = GetInstallSrc
	obj.MakeInterfaceMd5 = MakeInterfaceMd5
	obj.ReadUserConfig = ReadUserConfig
	XLSetGlobal("FunctionHelper", obj)
end	
RegisterFunctionObject()

