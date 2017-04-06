local tipUtil = XLGetObject("API.Util")
local strFakeUrl = "http://ip.dnsexit.com/index.php"
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

function GetLocalSvrCfgWithName(strCfgFileName,bGetPath)
	local bOk, strBaseDir = QueryAllUsersDir()
	if not bOk then
		return ""
	end
	
	local strCfgFilePath = tipUtil:PathCombine(strBaseDir, "Share2Gain\\localsvrcfg\\"..tostring(strCfgFileName))
	if not tipUtil:QueryFileExists(strCfgFilePath) then
		MessageBox("获取本地服务器配置文件路径失败\r\n文件名：" .. tostring(strCfgFileName))
		return nil
	end
	if bGetPath then
		return strCfgFilePath
	end
	local strContent = tipUtil:ReadFileToString(strCfgFilePath)
	if not IsRealString(strContent) then
		MessageBox("获取本地服务器配置内容失败\r\n文件名：" .. tostring(strCfgFileName))
		return nil
	end
	return strContent
end

XLSetGlobal("GetLocalSvrCfgWithName", GetLocalSvrCfgWithName)
