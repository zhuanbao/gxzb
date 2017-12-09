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
"kernel\\CheckSupportClient.lua",

"menu\\SuspendMenu.lua",
"menu\\SettingMenu.lua",
"kernel\\ServerCfgModule.lua",
"kernel\\StatisticClientModule.lua",
"kernel\\UIInterfaceModule.lua",
"kernel\\ClientWorkModule.lua",
"kernel\\GenOilClient.lua",
"kernel\\ZcashNClient.lua",
"kernel\\ZcashAClient.lua",
"kernel\\XmrClient.lua",
"kernel\\XmrClientHelper.lua",
}
LoadLuaModule(tabLuaFile, __document)

local Helper = XLGetGlobal("Helper")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local SupportClientType = XLGetGlobal("SupportClientType")

local ServerCfg = XLGetGlobal("ServerCfg")
local StatisticClient = XLGetGlobal("StatisticClient")
local UIInterface = XLGetGlobal("UIInterface")
local ClientWorkModule = XLGetGlobal("ClientWorkModule")
local GenOilClient = XLGetGlobal("GenOilClient")
local ZcashNClient = XLGetGlobal("ZcashNClient")
local ZcashAClient = XLGetGlobal("ZcashAClient")
local XmrClient = XLGetGlobal("XmrClient")
local XmrHelper = XLGetGlobal("XmrHelper")

function InitGlobalObj()
	local bSuccess = tFunctionHelper.ReadAllConfigInfo()
	StatisticClient:Init()
	--UIInterface:Init()
	ClientWorkModule:Init()
	SupportClientType:Init()
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
	UIInterface:CreatePopupTipWnd()
	
	TipMain()
end

PreTipMain()