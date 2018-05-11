local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local IPCUtil = XLGetObject("IPC.Util")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local hostwndManager = XLGetObject("Xunlei.UIEngine.HostWndManager")
local tFunctionHelper = XLGetGlobal("FunctionHelper")

ObjectBase = XLGetGlobal("ObjectBase")
Activity = ObjectBase:New()
XLSetGlobal("Activity", Activity)

Activity._tabLuaFile = {
"rewardbindweixin.lua",
"openbox\\openbox.lua",
}

Activity._tabCfg = {}

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
	tipUtil:Log("Activity: " .. tostring(strLog))
end

function Activity:LoadLuaModule(tFile, curDocPath)
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

function Activity:Init()
    self:LoadLuaModule(self._tabLuaFile, __document)
    --绑定微信活动
	RewardBindWX:Init()

end

--获取活动信息
function Activity:OnGetServerActivity(event, strPath)
	self:RemoveListener("OnGetServerActivity", self.OnGetServerActivity, self)
    if strPath == nil then
        return
    end
    local tActivityCfg = tFunctionHelper.LoadTableFromFile(strPath) or {}
    if type(tActivityCfg) ~= "table" then
        return
    end
    RewardBindWX:CheckCanShowRewardEnter(tActivityCfg)
	OpenBox:PrepareActivity(tActivityCfg["tOpenBoxCfg"])
end

function Activity:TryToGetServerActivity(tabActivity)
    if type(tabActivity) ~= "table" or #tabActivity < 0 then
        return
    end
    local tabActInfo = nil
    for Idx=1,#tabActivity do
        local tabItem = tabActivity[Idx]
        if type(tabItem) == "table" 
            and tFunctionHelper.CheckForceVersion(tabItem["tVersion"]) 
            and IsRealString(tabItem["strUrl"]) then
            tabActInfo = tabItem
            break
        end
    end
    if tabActInfo == nil then
        return
    end
    strActivityUrl = tabActInfo["strUrl"]
	local function fnDownLoadCallBack(strActivityPath)
		self:DispatchEvent("OnGetServerActivity", strActivityPath)
	end
    
	self:AddListener("OnGetServerActivity", self.OnGetServerActivity, self)
    
    local strFileName = tFunctionHelper.GetFileSaveNameFromUrl(strActivityUrl)
    local strSaveDir = tipUtil:GetSystemTempPath()
	local strSavePath = tipUtil:PathCombine(strSaveDir, strFileName)

	local strStamp = tFunctionHelper.GetTimeStamp()
    local strRequestUrl = strActivityUrl .. strStamp


	tFunctionHelper.NewAsynGetHttpFile(strRequestUrl, strSavePath, false
	, function(bRet, strRealPath)
		TipLog("[TryToGetServerActivity] bRet:"..tostring(bRet)
				..", strRealPath:"..tostring(strRealPath))
		if 0 == bRet then
			fnDownLoadCallBack(strRealPath)
		else
			fnDownLoadCallBack(nil)
		end
	end, 60*1000)
end