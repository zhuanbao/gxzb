local tipUtil = XLGetObject("API.Util")
local tipAsynUtil = XLGetObject("API.AsynUtil")
local IPCUtil = XLGetObject("IPC.Util")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")
local hostwndManager = XLGetObject("Xunlei.UIEngine.HostWndManager")
local tFunctionHelper = XLGetGlobal("FunctionHelper")

ObjectBase = XLGetGlobal("ObjectBase")
NoticeTip = ObjectBase:New()
XLSetGlobal("NoticeTip", NoticeTip)

NoticeTip._bInitOnce = false
NoticeTip._QueryTimerId = nil

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
	tipUtil:Log("NoticeTip: " .. tostring(strLog))
end

function NoticeTip:ReLoadLuaModule(strLuaPath)
	if XLModuleExists(strLuaPath) then
		XLUnloadModule(strLuaPath)
	end
	local tResult = nil
	local tMod = XLLoadModule(strLuaPath)
	if type(tMod) == "table" and type(tMod.GetSubTable) == "function" then
		local tDat = tMod.GetSubTable()
		if type(tDat) == "table" then
			tResult = tDat
		end
	end
	return tResult
end

function NoticeTip:Init()
	if not self._bInitOnce then
		self:AddListener("OnGetNoticeCfg", self.OnGetNoticeCfg, self)
		self._bInitOnce = true
		
	end	
end

--获取活动信息
function NoticeTip:OnGetNoticeCfg(event, strLuaPath)
	--strLuaPath = "E:\\github_etherun\\gxzbsvn\\trunk\\code_redirect\\cfg\\noticetip_v1.1.dat"
    if strLuaPath == nil then
        return
    end
    local tabCfg = self:ReLoadLuaModule(strLuaPath)
	UIInterface:ShowNoticeTip(tabCfg)
end

function NoticeTip:QueryServerForNewCfg(strUrl)
	local function fnDownLoadCallBack(strLuaPath)
		self:DispatchEvent("OnGetNoticeCfg", strLuaPath)
	end
	
    local strFileName = tFunctionHelper.GetFileSaveNameFromUrl(strUrl)
    local strSaveDir = tipUtil:GetSystemTempPath()
	local strSavePath = tipUtil:PathCombine(strSaveDir, strFileName)

	local strStamp = tFunctionHelper.GetTimeStamp()
    local strRequestUrl = strUrl .. strStamp


	tFunctionHelper.NewAsynGetHttpFile(strRequestUrl, strSavePath, false
	, function(bRet, strRealPath)
		TipLog("[QueryServerForNewCfg] bRet:"..tostring(bRet)
				..", strRealPath:"..tostring(strRealPath))
		if 0 == bRet then
			fnDownLoadCallBack(strRealPath)
		else
			fnDownLoadCallBack(nil)
		end
	end, 60*1000)
end

function NoticeTip:TryToGetNoticeCfg(tNotice)
    if type(tNotice) ~= "table" or not IsRealString(tNotice["strUrl"]) then
        return
    end
	local strUrl = tNotice["strUrl"]
	local nQueryInterval = tonumber(tNotice["nQueryInterval"]) or 60*30
	self:Init()
	self:QueryServerForNewCfg(strUrl)
	self._QueryTimerId = timeMgr:SetTimer(function(Itm, id)
		self:QueryServerForNewCfg(strUrl)
	end, nQueryInterval*1000)
	
end