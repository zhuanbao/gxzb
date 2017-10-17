local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")


function LoadLuaModule(tFile, curDocPath)
--tFile可以传lua文件绝对路径、相对路径
	if "table" == type(tFile) then
		for index, value in ipairs(tFile) do
			if "string" == type(value) and value ~= "" then
				local dstPath = curDocPath.."\\..\\"..value
				if XLModuleExists(dstPath) then
					XLUnloadModule(dstPath)
					XLLoadModule(dstPath)
				else
					XLLoadModule(dstPath)
				end
				
			end
		end
	elseif "string" == type(tFile) and tFile ~= ""then
		if curDocPath then
			tFile = curDocPath.."\\..\\"..tFile
		end
		if XLModuleExists(tFile) then
			XLUnloadModule(tFile)
			XLLoadModule(tFile)
		else
			XLLoadModule(tFile)
		end
	end
end

local tabLuaFile = {
"luacode\\objectbase.lua",
"luacode\\helper.lua",
"luacode\\helper_token.lua",
"kernel\\utility.lua",

"menu\\SuspendMenu.lua",
"menu\\SettingMenu.lua",
"kernel\\ServerCfgModule.lua",
"kernel\\StatisticClientModule.lua",
"kernel\\UIInterfaceModule.lua",
"kernel\\ClientWorkModule.lua",
"kernel\\GenOilClient.lua",
"kernel\\ZcashNClient.lua",
"kernel\\ZcashAClient.lua",
}
LoadLuaModule(tabLuaFile, __document)

local Helper = XLGetGlobal("Helper")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local ServerCfg = XLGetGlobal("ServerCfg")
local StatisticClient = XLGetGlobal("StatisticClient")
local UIInterface = XLGetGlobal("UIInterface")
local ClientWorkModule = XLGetGlobal("ClientWorkModule")
local GenOilClient = XLGetGlobal("GenOilClient")
local ZcashNClient = XLGetGlobal("ZcashNClient")
local ZcashAClient = XLGetGlobal("ZcashAClient")
function InitGlobalObj()
	StatisticClient:Init()
	--UIInterface:Init()
	ClientWorkModule:Init()
end
InitGlobalObj()

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
	tipUtil:Log("onload: " .. tostring(strLog))
end

function CheckIsDebug()
	local nValue = tipUtil:QueryRegValue("HKEY_CURRENT_USER", "SOFTWARE\\Share4Money", "Debug")
	if type(nValue) == "number" and nValue > 0 then
		ClientWorkModule:SetMiningType(nValue)
		return true
	end
	return false
end

function SendStartUpReport()
	local tStatInfo = {}
	tStatInfo.fu1 = "startup"
	local tabMemoryInfo = tipUtil:GetMemoryStatus()
	if type(tabMemoryInfo) ~= "table" then
		tabMemoryInfo = {}
	end
	tStatInfo.fu5 = math.floor((tabMemoryInfo["TotalPhys"] or 0)/1024)
	local tabDisplayCard = tipUtil:GetAllDisplayCardInfo()
	if type(tabDisplayCard) == "table" then
		for index=1,#tabDisplayCard do
			local tabItem = tabDisplayCard[index]
			if type(tabItem) == "table" then
				nMemSize = 0
				if type(tabItem["memory_size"]) == "number" then
					nMemSize = math.floor(tabItem["memory_size"]/(1024*1024))
				end
				if IsRealString(tStatInfo.fu6) then
					tStatInfo.fu6 = tStatInfo.fu6 .. "_"
				else
					tStatInfo.fu6 = ""
				end
				tStatInfo.fu6 = tStatInfo.fu6 .. (tabItem["vendor"] or "") .. "|"
								.. (tabItem["name"] or "") .. "|"
								.. (nMemSize)
			end					
		end
	end
	local strCpuName =  tFunctionHelper.RegQueryValue("HKEY_LOCAL_MACHINE\\HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0\\ProcessorNameString") or ""
	local strCpuMz = tFunctionHelper.RegQueryValue("HKEY_LOCAL_MACHINE\\HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0\\~MHz") or 0
	tStatInfo.fu7 = strCpuName.."_"..tostring(strCpuMz)
	local bRet, strSource = tFunctionHelper.GetCommandStrValue("/sstartfrom")
	tStatInfo.fu8 = strSource or ""
	StatisticClient:SendEventReport(tStatInfo)
end

function SendInitSuccessReport()
	local tStatInfo = {}
	tStatInfo.fu1 = "initsuccess"
	StatisticClient:SendEventReport(tStatInfo)
end

--返回值说明 -1: 需要安装额外的版本 0：不适合挖矿；1：适合挖ETH和ETC 2：挖ZcashN卡 3:挖ZcashA卡
function CheckMachineSuitable()
	if tFunctionHelper.GetSystemBits() ~= 64 then
		LOG("CheckMachineSuitable GetSystemBits ~= 64")
		return 0
	end
	
	local bEthereum = tipUtil:CheckEthereumCond()
	if bEthereum then
		return 1
	end
	local bZcashN = tipUtil:CheckZcashNCond()
	if bZcashN then
		return 2
	end
	---[[
	local bZcashA = tipUtil:CheckZcashACond()
	if bZcashA then
		return 3
		--UIInterface:ShowPopupWndByName("GXZB.ZcashAPromptWnd.Instance", true)
		--return -1
	end
	--]]
	return 0
end

function LoadDynamicFont()
	local strFontPath = __document.."\\..\\dynamicfont.lua"
	local Module = XLLoadModule(strFontPath)
end

function ShowMainTipWnd(objMainWnd)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local bHideMainPage = tFunctionHelper.FetchValueByPath(tUserConfig, {"tConfig", "HideMainPage", "bState"})
	
	local cmdString = tipUtil:GetCommandLine()
	
	local bRet = string.find(tostring(cmdString), "/forceshow")
	if bRet then
		bHideMainPage = false
	else
		local bRet = string.find(tostring(cmdString), "/embedding")
		if bRet then
			bHideMainPage = true
		end
	end
	
	if bHideMainPage then
		objMainWnd:Show(0)
	else
		objMainWnd:Show(5)
		UIInterface:SetWndForeGround(objMainWnd)
	end
	
	objMainWnd:SetTitle("共享赚宝")
	SendInitSuccessReport()
	tFunctionHelper.WriteLastLaunchTime()
end

function PopTipWnd(OnCreateFunc)
	local bSuccess = false
	local templateMananger = XLGetObject("Xunlei.UIEngine.TemplateManager")
	local frameHostWndTemplate = templateMananger:GetTemplate("MainWnd", "HostWndTemplate" )
	local frameHostWnd = nil
	if frameHostWndTemplate then
		frameHostWnd = frameHostWndTemplate:CreateInstance("GXZB.MainWnd")
		if frameHostWnd then
			local objectTreeTemplate = nil
			objectTreeTemplate = templateMananger:GetTemplate("WndPanelTree", "ObjectTreeTemplate")
			if objectTreeTemplate then
				local uiObjectTree = objectTreeTemplate:CreateInstance("GXZB.WndPanelTree")
				if uiObjectTree then
					frameHostWnd:BindUIObjectTree(uiObjectTree)
					
					local ret = OnCreateFunc(uiObjectTree)
					if ret then
						local iRet = frameHostWnd:Create()
						if iRet ~= nil and iRet ~= 0 then
							bSuccess = true
							ShowMainTipWnd(frameHostWnd)
						end
					end
				end
			end
		end
	end
	if not bSuccess then
		StatisticClient:FailExitProcess(4)
	end
	---初始化托盘
    if frameHostWnd then
		TipLog("[PopTipWnd] try to init tray tip wnd")
	    UIInterface:InitTrayTipWnd(frameHostWnd)
	end
end

function CreateMainTipWnd()
	local function OnCreateFuncF(treectrl)
		local rootctrl = treectrl:GetUIObject("root.layout:root.ctrl")
		local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
		local bRet = rootctrl:SetTipData(tUserConfig)			
		if not bRet then
			return false
		end
	
		return true
	end
	PopTipWnd(OnCreateFuncF)	
end

--[[
function IsZcashAClientExist()
	local strDir = FunctionObj.GetModuleDir()
	local CLIENT_PATH = "Share4Peer\\Share4PeerZA\\Share4PeerZA.exe"
	local strWorkExe = tipUtil:PathCombine(strDir, CLIENT_PATH)
	if not tipUtil:QueryFileExists(strWorkExe) then
		return false
	end
	return true
end
--]]

function TipMain()	
	CreateMainTipWnd()
	tFunctionHelper.InitMachineName()
	tFunctionHelper.SaveConfigInTimer()
	if not ClientWorkModule:CheckIsBinded() then
		UIInterface:ChangeClientTitle("共享赚宝(未绑定)")
	end
	--显示悬浮框
	UIInterface:UpdateSuspendWndVisible()
	ClientWorkModule:InitMiningClient()
	ServerCfg:TryToConnectServer()
	ClientWorkModule:CheckMachineBindState()
	if ClientWorkModule:CheckShoudAutoMining() then
		TipLog("[TipMain] try to auto mining")
		ClientWorkModule:DoAutoMining()
	end
end

function PreTipMain()
	--安装的时候快捷方式和这里都不设置APPID就能使得图标重合
	--tipUtil:SetApplicationId("{FEE8E80D-0A47-44DD-AD58-9E7F6F08C4E8}")
	LoadDynamicFont()
	SendStartUpReport()
	StatisticClient:StartRunTimeReport("noworking")
	local bSuccess = tFunctionHelper.ReadAllConfigInfo()
	UIInterface:CreatePopupTipWnd()
	local nMiningType = CheckMachineSuitable()
	ClientWorkModule:SetMiningType(nMiningType)
	local bDebug = CheckIsDebug()
	if nMiningType == 0 and not bDebug then
		UIInterface:ShowPopupWndByName("GXZB.MachineCheckWnd.Instance", true)
	elseif nMiningType ~= -1 then
		TipMain()
	end
end

PreTipMain()