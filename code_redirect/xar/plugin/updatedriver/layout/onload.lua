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
"luacode\\utility.lua",
"luacode\\StatisticModule.lua",
}
LoadLuaModule(tabLuaFile, __document)

local tFunctionHelper = XLGetGlobal("FunctionHelper")
local StatisticClient = XLGetGlobal("StatisticClient")

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

function SetWndForeGround(objHostWnd)
	if not objHostWnd then
		return
	end

	if not tFunctionHelper.IsUserFullScreen() then
		-- objHostWnd:SetTopMost(true)
		if type(tipUtil.SetWndPos) == "function" then
			local hWnd = objHostWnd:GetWndHandle()
			if hWnd ~= nil then
				TipLog("[SetWndForeGround] success")
				tipUtil:SetWndPos(hWnd, 0, 0, 0, 0, 0, 0x0043)
			end
		end
	elseif type(tipUtil.GetForegroundProcessInfo) == "function" then
		local hFrontHandle, strPath = tipUtil:GetForegroundProcessInfo()
		if hFrontHandle ~= nil then
			objHostWnd:BringWindowToBack(hFrontHandle)
		end
	end
end

function SendShowMainWndReport()
	local tStatInfo = {}
	tStatInfo.fu5 = "showmainwnd"
	StatisticClient:SendEventReport(tStatInfo)
end

function StartDownload(objMainWnd)
	local objtree = objMainWnd:GetBindUIObjectTree()
	local objRootLayout = objtree:GetUIObject("MainWndCtrl")
	objRootLayout:Start()
end

function ShowMainTipWnd(objMainWnd)	
	objMainWnd:Show(5)
	SetWndForeGround(objMainWnd)
	objMainWnd:SetTitle("共享赚宝")
	SendShowMainWndReport()
	StartDownload(objMainWnd)
end

function PopTipWnd(OnCreateFunc)
	local bSuccess = false
	local templateMananger = XLGetObject("Xunlei.UIEngine.TemplateManager")
	local frameHostWndTemplate = templateMananger:GetTemplate("UpdateDriverMainWnd", "HostWndTemplate" )
	local frameHostWnd = nil
	if frameHostWndTemplate then
		frameHostWnd = frameHostWndTemplate:CreateInstance("SharePlugin.UpdateDriverMainWnd")
		if frameHostWnd then
			local objectTreeTemplate = nil
			objectTreeTemplate = templateMananger:GetTemplate("MainWndTree", "ObjectTreeTemplate")
			if objectTreeTemplate then
				local uiObjectTree = objectTreeTemplate:CreateInstance("SharePlugin.MainWndTree")
				if uiObjectTree then
					frameHostWnd:BindUIObjectTree(uiObjectTree)
					
					local bFunc = OnCreateFunc(uiObjectTree)
					if bFunc then
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
end

function CreateMainTipWnd()
	local function OnCreateFuncF(treectrl)
		local ObjRootCtrl = treectrl:GetUIObject("MainWndCtrl")
		local bRet = ObjRootCtrl:InitCtrl()			
		if not bRet then
			return false
		end
	
		return true
	end
	PopTipWnd(OnCreateFuncF)	
end

function PluginMain()
	CreateMainTipWnd()
end

PluginMain()