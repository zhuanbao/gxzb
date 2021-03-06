local tFunctionHelper = XLGetGlobal("FunctionHelper")
local tipUtil = XLGetObject("API.Util")
local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")

--local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
--local strAutoRunRegPath = "HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\Share4Money"

local g_AutoRunState = false
--设置挖矿模式的默认值
--[[
0 全速，1智能
--]]
local g_tTaskMrgData = {}
local g_nWorkModel = 1
local g_SuspendedWndState = 0

local g_strBossKey = "Alt+Z"
local g_nBossKeyValue = 0x5A0001

local g_tKey2String = 
{
	[9] = "Tab", [13] = "回车", [20] = "Caps Lock", [32] = "空格", [33] = "PageUp",
	[34] = "PageDown", [35] = "End", [36] = "Home", [37] = "←", [38] = "↑",
	[39] = "→", [40] = "↓", [45] = "Insert", [96] = "小键盘0", [97] = "小键盘1",
	[98] = "小键盘2", [99] = "小键盘3", [100] = "小键盘4", [101] = "小键盘5", [102] = "小键盘6",
	[103] = "小键盘7", [104] = "小键盘8", [105] = "小键盘9", [106] = "小键盘*", [107] = "小键盘+",
	[109] = "小键盘-", [111] = "小键盘/", [112] = "F1", [113] = "F2", [114] = "F3", [115] = "F4",
	[116] = "F5", [117] = "F6", [118] = "F7", [119] = "F8", [120] = "F9", [121] = "F10",
	[122] = "F11", [123] = "F12", [144] = "Num Lock", [186] = ";", [187] = "+", [188] = ",",
	[189] = "-", [190] = ".", [191] = "/", [192] = "`", [219] = "[", [220] = "\\", [221] = "]",
	[222] = "\'", [16] = "Shift", [17] = "Ctrl", [18] = "Alt"
}

function IsRealString(str)
	return type(str) == "string" and str ~= ""
end

function OnMouseEnter(self)
	local objBtnHover = self:GetObject("BtnHover")
	if not objBtnHover then
		objBtnHover = objFactory:CreateUIObject("BtnHover", "ImageObject")
		self:AddChild(objBtnHover)
		objBtnHover:SetObjPos(-5, -9, 20, -6)
		objBtnHover:SetResID("GXZB.PopUpWnd.Btn.Hover")
	end
	objBtnHover:SetVisible(true)
end

function OnMouseLeave(self)
	local objBtnHover = self:GetObject("BtnHover")
	if objBtnHover then
		objBtnHover:SetVisible(false)
	end
end

function DestoryDialog(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:EndDialog(0)
end

function OnClickClose(self)
	DestoryDialog(self)
end

function OnClickBaseSetting(self)
	local objTree = self:GetOwner()
	local objBase = objTree:GetUIObject("SettingWnd.Content.Base")
	objBase:SetVisible(true)
	objBase:SetChildrenVisible(true)
	self:SetTextColorID("DEAF37")
	
	local objAdvance = objTree:GetUIObject("SettingWnd.Content.Advance")
	objAdvance:SetVisible(false)
	objAdvance:SetChildrenVisible(false)
	
	local objItemAdvance = objTree:GetUIObject("SettingWnd.Content.Item.Advance")
	objItemAdvance:SetTextColorID("6D5539")
	
	local objTaskMgr = objTree:GetUIObject("SettingWnd.Content.TaskMgr")
	objTaskMgr:SetVisible(false)
	objTaskMgr:SetChildrenVisible(false)
	
	local objItemTaskMgr = objTree:GetUIObject("SettingWnd.Content.Item.TaskMgr")
	objItemTaskMgr:SetTextColorID("6D5539")
end

function OnClickAdvanceSetting(self)
	local objTree = self:GetOwner()
	local objAdvance = objTree:GetUIObject("SettingWnd.Content.Advance")
	objAdvance:SetVisible(true)
	objAdvance:SetChildrenVisible(true)
	self:SetTextColorID("DEAF37")
	
	local objBase = objTree:GetUIObject("SettingWnd.Content.Base")
	objBase:SetVisible(false)
	objBase:SetChildrenVisible(false)
	
	local objItemBase = objTree:GetUIObject("SettingWnd.Content.Item.Base")
	objItemBase:SetTextColorID("6D5539")
	
	local objTaskMgr = objTree:GetUIObject("SettingWnd.Content.TaskMgr")
	objTaskMgr:SetVisible(false)
	objTaskMgr:SetChildrenVisible(false)
	
	local objItemTaskMgr = objTree:GetUIObject("SettingWnd.Content.Item.TaskMgr")
	objItemTaskMgr:SetTextColorID("6D5539")
end

function OnClickTaskMgrSetting(self)
	local objTree = self:GetOwner()
	local objTaskMgr = objTree:GetUIObject("SettingWnd.Content.TaskMgr")
	objTaskMgr:SetVisible(true)
	objTaskMgr:SetChildrenVisible(true)
	self:SetTextColorID("DEAF37")
	
	local objBase = objTree:GetUIObject("SettingWnd.Content.Base")
	objBase:SetVisible(false)
	objBase:SetChildrenVisible(false)
	
	local objItemBase = objTree:GetUIObject("SettingWnd.Content.Item.Base")
	objItemBase:SetTextColorID("6D5539")
	
	local objAdvance = objTree:GetUIObject("SettingWnd.Content.Advance")
	objAdvance:SetVisible(false)
	objAdvance:SetChildrenVisible(false)
	
	local objItemAdvance = objTree:GetUIObject("SettingWnd.Content.Item.Advance")
	objItemAdvance:SetTextColorID("6D5539")
end

function SaveSettingConfig(objTree)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if g_AutoRunState then
		tFunctionHelper.WriteCfgSetBoot()
		tFunctionHelper.WriteSysSetBoot()
	else
		tFunctionHelper.DeleteCfgSetBoot()
		tFunctionHelper.DeleteSysSetBoot()
	end
	
	local ObjEditMachineID = objTree:GetUIObject("SettingWnd.Content.Base.MachineIDEdit.Input")
	local strMachineName = ObjEditMachineID:GetText()
	if not Helper:IsRealString(strMachineName) then
		strMachineName = tFunctionHelper.GetMachineName()
	end
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	if not Helper:IsRealString(tUserConfig["tUserInfo"]["strMachineName"]) or tUserConfig["tUserInfo"]["strMachineName"] ~= strMachineName then
		tUserConfig["tUserInfo"]["strMachineName"] = strMachineName
		ApiInterfaceModule:ReportClientInfoToServer(true)
	end
	
	if type(tUserConfig["tConfig"]) ~= "table" then
		tUserConfig["tConfig"] = {}
	end
	if type(tUserConfig["tConfig"]["WorkModel"]) ~= "table" then
		tUserConfig["tConfig"]["WorkModel"] = {}
	end
	tUserConfig["tConfig"]["WorkModel"]["nState"] = g_nWorkModel

	if type(tUserConfig["tConfig"]["ShowBall"]) ~= "table" then
		tUserConfig["tConfig"]["ShowBall"] = {}
	end
	tUserConfig["tConfig"]["ShowBall"]["nState"] = g_SuspendedWndState
	
	
	--更新球的状态
	local isWorking = MainWorkModule:CheckIsWorking()
	UIInterface:UpdateSuspendWndVisible()
	
	--老板键
	local ObjCheckBoxBossKey = objTree:GetUIObject("SettingWnd.Content.Advance.CheckBossKeyArea")
	if type(tUserConfig["tConfig"]["BossKey"]) ~= "table" then
		tUserConfig["tConfig"]["BossKey"] = {}
	end
	tUserConfig["tConfig"]["BossKey"]["strDesc"] = g_strBossKey
	tUserConfig["tConfig"]["BossKey"]["nValue"] = g_nBossKeyValue
	local ObjAttr = ObjCheckBoxBossKey:GetAttribute()
    tUserConfig["tConfig"]["BossKey"]["bCheck"] = ObjAttr.Select
	if ObjAttr.Select then
		tFunctionHelper.RegisterHotKey()
	else
		tipUtil:UnRegisterBosskey()
	end
	
	--掉线监控
	local ObjCheckMonitor = objTree:GetUIObject("SettingWnd.Content.Advance.CheckOffLineMonitor")
	local ObjMonitorAttr = ObjCheckMonitor:GetAttribute()
	local strSvcCfg = tFunctionHelper.GetCfgPathWithName("svccfg.ini")
	if ObjMonitorAttr.Select then
		tFunctionHelper.WriteOffLineMonitorNoLaunchCfg(0)
	else
		tFunctionHelper.WriteOffLineMonitorNoLaunchCfg(1)
	end
	
	--收益提醒
	local ObjCheckRemind = objTree:GetUIObject("SettingWnd.Content.Advance.CheckEarningRemind")
	local ObjRemindAttr = ObjCheckRemind:GetAttribute()
	if type(tUserConfig["tConfig"]["EarningRemind"]) ~= "table" then
		tUserConfig["tConfig"]["EarningRemind"] = {}
	end
	tUserConfig["tConfig"]["EarningRemind"]["bCheck"] = ObjRemindAttr.Select
	
	--任务管理
	if type(tUserConfig["tConfig"]["ShareBindWindth"]) ~= "table" then
		tUserConfig["tConfig"]["ShareBindWindth"] = {}
	end
	local objCheckBandWidth = objTree:GetUIObject("SettingWnd.Content.TaskMgr.CheckBandWidth")
	local objBandWidthAttr = objCheckBandWidth:GetAttribute()
	tUserConfig["tConfig"]["ShareBindWindth"]["bCheck"] = objBandWidthAttr.Select

	tUserConfig["tConfig"]["ShareBindWindth"]["strPluginDataDir"] = g_tTaskMrgData["strPluginDataDir"]
	tUserConfig["tConfig"]["ShareBindWindth"]["nMaxDiskUsageGB"] = g_tTaskMrgData["nMaxDiskUsageGB"]
	tUserConfig["tConfig"]["ShareBindWindth"]["nMinDiskAvailGB"] = g_tTaskMrgData["nMinDiskAvailGB"]
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
end


function GetOffLineMonitorNoLaunchCfg()
	local strSvcCfg = tFunctionHelper.GetCfgPathWithName("svccfg.ini")
	if not tipUtil:QueryFileExists(strSvcCfg) then
		return 1
	end
	local nNoLaunch, bRet = tipUtil:ReadINI(strSvcCfg, "offline", "nolaunch")
	if tonumber(nNoLaunch) == nil then
		nNoLaunch = 1
	else
		nNoLaunch =  tonumber(nNoLaunch)
	end
	return nNoLaunch
end



function OnSelectAutoRun(self, event, bSelect)
	local tStatInfo = {}
	if bSelect then
		g_AutoRunState = true
		tStatInfo.fu5 = 1
	else
		g_AutoRunState = false
		tStatInfo.fu5 = 0
	end	
	tStatInfo.fu1 = "autorun"
	tStatInfo.fu6 = "settingwnd"
	StatisticClient:SendClickReport(tStatInfo)
end

function OnSelectBossKey(self, event, bSelect)
	local objTree = self:GetOwner()
	local objBossKeyInput = objTree:GetUIObject("SettingWnd.Content.BossKeyEdit.Input")
	
	if bSelect then
		objBossKeyInput:SetEnable(true)
		objBossKeyInput:SetTextColorID("555555")
	else
		objBossKeyInput:SetEnable(false)
		objBossKeyInput:SetTextColorID("BCB9B5")
	end
end

function OnSelectOffLineMonitor(self, event, bSelect)
	
end

function OnSelectEarningRemind(self, event, bSelect)
	
end

function SetEditTextState(self, bFocus)
	if bFocus then
		--self:SetSelAll(true)
		--self:SetNoCaret(false)
	else
		--self:SetSelAll(false)
		--self:SetNoCaret(true)
	end
end

function OnMachineEditFocusChange(self, bFocus)
	SetEditTextState(self, bFocus)
end

function OnClickConfirm(self)
	local objTree = self:GetOwner()
	SaveSettingConfig(objTree)
	DestoryDialog(self)
end

function OnClickCancel(self)
	DestoryDialog(self)
end

function OnSelectSWndRadio(self, event, bCheck)
	local ObjRadioShow = self:GetObject("tree:SettingWnd.Content.Base.SuspendedWnd.Show")
	local ObjRadioHide = self:GetObject("tree:SettingWnd.Content.Base.SuspendedWnd.Hide")
	local ObjRadioShowAtMining = self:GetObject("tree:SettingWnd.Content.Base.SuspendedWnd.ShowAtMining")
	local strCurrentID = self:GetID()
	if strCurrentID == "SettingWnd.Content.Base.SuspendedWnd.Show" then
		ObjRadioHide:SetCheck(false, true)
		ObjRadioShowAtMining:SetCheck(false, true)
		g_SuspendedWndState = 0
	elseif strCurrentID == "SettingWnd.Content.Base.SuspendedWnd.Hide" then
		ObjRadioShow:SetCheck(false, true)
		ObjRadioShowAtMining:SetCheck(false, true)
		g_SuspendedWndState = 1
	else
		ObjRadioShow:SetCheck(false, true)
		ObjRadioHide:SetCheck(false, true)
		g_SuspendedWndState = 2
	end
end

function OnSelectWorkModelRadio(self, event, bCheck)
	local ObjRadioFull = self:GetObject("tree:SettingWnd.Content.Base.WorkModel.Full")
	local ObjRadioIntelligent = self:GetObject("tree:SettingWnd.Content.Base.WorkModel.Intelligent")
	local strCurrentID = self:GetID()
	if strCurrentID == "SettingWnd.Content.Base.WorkModel.Full" then
		ObjRadioIntelligent:SetCheck(false, true)
		g_nWorkModel = 0
	else
		ObjRadioFull:SetCheck(false, true)
		g_nWorkModel = 1
	end
end

function SetSettingWndEditFocus(ObjEdit, x, y)
	local editL, editT, editR, editB = ObjEdit:GetAbsPos()
	if x > editL and x < editR and y > editT and y < editB then
		ObjEdit:SetFocus(true)
	else
		ObjEdit:SetFocus(false)
	end
end



function OnLButtonDownCaption(self, x, y)
	--local editMachineID = self:GetObject("tree:SettingWnd.Content.MachineIDArea.Edit")
	--SetSettingWndEditFocus(editMachineID, x, y)
end

function OnBossKeyFocusChange(self, bFocus)
	if bFocus then
		self:SetSelAll()
	else
		self:SetSelNone()
	end
end


function OnBossKeyChange(self)
	--local xmpEdit = self:GetOwnerControl()
	--local owerAttr = xmpEdit:GetAttribute()
	--self:SetText(owerAttr.Text)
	-- 最后个参数表示执行完此函数后不再调用下个事件处理函数
	self:SetText(g_strBossKey)
	return 0, true, false
end

function ShowRegHotKeyErrorInfo(ObjTree, bShow)
	local ObjTip = ObjTree:GetUIObject("SettingWnd.Content.Advance.BossKeyError")
	local ObjTipText = ObjTree:GetUIObject("SettingWnd.Content.Advance.BossKeyError.TipText")
	ObjTip:SetVisible(bShow)
    ObjTipText:SetVisible(bShow)
end

function OnBossKeyDown(self, uChar, uRepeatCount, uFlags)
	if BitAnd(uFlags, 0x4000) == 0 and uChar ~= 16 and uChar ~= 17 and uChar ~= 18 then -- 第一次
		local ObjTree = self:GetOwner()
		local text = ""
		local iValue = uChar * 0x10000
		local iFnKey = 0
		local wKeyText = ""
		if tipUtil:GetKeyState(0x11) < 0 then -- VK_CONTROL
			wKeyText = "Ctrl+"
			iFnKey  = iFnKey+0x2
		end	
		if tipUtil:GetKeyState(0x12) < 0 then -- VK_ALT
			wKeyText = wKeyText .. "Alt+"
			iFnKey  = iFnKey+0x1
		end
		if tipUtil:GetKeyState(0x10) < 0 then -- VK_SHIFT
			wKeyText = wKeyText .. "Shift+"
			iFnKey = iFnKey + 0x4
		end
		if iFnKey > 0 and ((uChar >= 48 and uChar <= 57) or (uChar >= 65 and uChar <= 90) or (uChar >= 96 and uChar <= 105)) then
			if g_tKey2String[uChar] ~= nil then
				text = g_tKey2String[uChar]
			else
				text = string.upper(string.char(uChar))
			end	
			ShowRegHotKeyErrorInfo(ObjTree, false)
		--[[
		elseif uChar == 8 or uChar == 46 then -- BackSpace
			g_strBossKey = "无"
			self:SetText("无")
			g_nBossKeyValue = 0
			return 0, true, false
		--]]
		else
			
			g_strBossKey = "无"
			self:SetText("无")
			g_nBossKeyValue = 0
			ShowRegHotKeyErrorInfo(ObjTree, true)
			return 0, true, false
		end
		
		text = wKeyText .. text
		g_strBossKey = text
		self:SetText(text)
		g_nBossKeyValue = iValue+iFnKey
	end	
	return 0, true, false
end

function OnMouseEnterAbout(self)
	Helper.Tip:SetTips("如果老板来了，按老板键，赚宝会自动隐藏")
end

function OnMouseLeaveAbout(self)
	Helper.Tip:DestoryTipWnd()
end

--任务管理
function OnSelectBandWidth(self, event, bSelect)
	local tStatInfo = {}
	if bSelect then
		tStatInfo.fu5 = 1
	else
		tStatInfo.fu5 = 0
	end	
	tStatInfo.fu1 = "bandwidth"
	tStatInfo.fu6 = "settingwnd"
	StatisticClient:SendClickReport(tStatInfo)
end

function OnClickChangeDir(self)
	local objTree = self:GetOwner()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local strPluginDataDir = g_tTaskMrgData["strPluginDataDir"]
	local strTitle = "请选择保存数据文件的路径"
	local strNewDataDir = tipUtil:FolderDialog(strTitle, strPluginDataDir)
	if not IsRealString(strNewDataDir) 
		or not tipUtil:QueryFileExists(strNewDataDir) 
		or string.lower(strNewDataDir) == string.lower(strPluginDataDir) then
		return
	end	
	local _,_, strDisk = string.find(strNewDataDir, "([^\\]+).+$")
	local nFreeBytesAvailable, nTotalNumberOfBytes, nTotalNumberOfFreeBytes = tipUtil:GetDiskFreeSpace(strDisk)
	local nMaxFreeSpaceInGB = nFreeBytesAvailable/1024/1024/1024
	
	if not tipUtil:QueryFileExists(strNewDataDir) then
		tipUtil:CreateDir(strNewDataDir)
	end
	local nDataSize = ShareBindWidth:GetDataSize(strNewDataDir)/1024/1024/1024
	local nTotalFreeGB = nMaxFreeSpaceInGB+nDataSize
	local nMaxDiskUsageGB = math.floor(nTotalFreeGB*0.9)
	local nMinDiskAvailGB = math.floor(nTotalFreeGB-nMaxDiskUsageGB)
	
	local objCacheDirEdit = objTree:GetUIObject("SettingWnd.Content.TaskMgr.CacheDirEdit.Input")
	objCacheDirEdit:SetText(strNewDataDir)

	local objDefaultMaxUsage = objTree:GetUIObject("SettingWnd.Content.TaskMgr.SetCache.DefaultMaxUsage")
	local nDefaultL, nDefaultT, nDefaultR, nDefaultB = objDefaultMaxUsage:GetObjPos()
	local objRealMaxUsage = objTree:GetUIObject("SettingWnd.Content.TaskMgr.SetCache.RealMaxUsage")
	local objChangeUsage = objTree:GetUIObject("SettingWnd.Content.TaskMgr.SetCache.ChangeUsage")
	local nBtnL, nBtnT, nBtnR, nBtnB = objChangeUsage:GetObjPos()
	local nBtnWidth = nBtnR-nBtnL
	local nBtnMid = math.floor(nBtnWidth/2)
	objRealMaxUsage:SetObjPos(nDefaultL,nDefaultT, nDefaultR, nDefaultB)
	objChangeUsage:SetObjPos(nDefaultR-nBtnMid,nBtnT, nDefaultR-nBtnMid+nBtnWidth, nBtnB)
	
	
	local objUsageGB = objTree:GetUIObject("SettingWnd.Content.TaskMgr.SetCache.UsageGB")
	objUsageGB:SetText(tostring(nMaxDiskUsageGB) .. "GB")
	
	local objRemainingSpace = objTree:GetUIObject("SettingWnd.Content.TaskMgr.RemainingSpace")
	objRemainingSpace:SetText("剩余空间：" .. tostring(nMaxFreeSpaceInGB-nMaxFreeSpaceInGB%0.01) .. "GB")
	g_tTaskMrgData["strPluginDataDir"] = strNewDataDir
	g_tTaskMrgData["nMaxDiskUsageGB"] = nMaxDiskUsageGB
	g_tTaskMrgData["nMinDiskAvailGB"] = nMinDiskAvailGB
end

local g_tabUsage = {}
g_tabUsage.bHit = false
function OnLButtonDownChangeUsage(self, x, y)
	self:SetCaptureMouse(true)
	g_tabUsage.bHit = true
	g_tabUsage.nHitX = x
	g_tabUsage.nHitY = y
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local strPluginDataDir = g_tTaskMrgData["strPluginDataDir"]
	local _,_, strDisk = string.find(strPluginDataDir, "([^\\]+).+$")
	local nDataSize = ShareBindWidth:GetDataSize(strPluginDataDir)/1024/1024/1024
	local nFreeBytesAvailable, nTotalNumberOfBytes, nTotalNumberOfFreeBytes = tipUtil:GetDiskFreeSpace(strDisk)
	nFreeBytesAvailable = nFreeBytesAvailable/1024/1024/1024
	local nTotalFreeGB = nFreeBytesAvailable+nDataSize
	local nMaxTotalFreeGB = math.floor(nTotalFreeGB*0.9)
	local nMinTotalFreeGB = math.floor(math.min(nTotalFreeGB/2, 30))
	g_tabUsage.nMaxTotalFreeGB = nMaxTotalFreeGB
	g_tabUsage.nMinTotalFreeGB = nMinTotalFreeGB
	self:SetTextureID("GXZB.Setting.ChangeUsage.down")
end

function OnLButtonUpChangeUsage(self, x, y)
	self:SetCaptureMouse(false)
	g_tabUsage = {}
	self:SetTextureID("GXZB.Setting.ChangeUsage.normal")
end

function OnMouseEnterChangeUsage(self, x, y)
end

function OnMouseLeaveChangeUsage(self, x, y)
	--g_tabUsage.bHit = false
	--g_tabUsage.nHitX = 0
	--g_tabUsage.nHitY = 0
	--self:SetTextureID("GXZB.Setting.ChangeUsage.normal")
end

function OnMouseMoveChangeUsage(self, x, y)
	if g_tabUsage.bHit then
		local objTree = self:GetOwner()
		local objDefaultMaxUsage = objTree:GetUIObject("SettingWnd.Content.TaskMgr.SetCache.DefaultMaxUsage")
		local nDefaultL, nDefaultT, nDefaultR, nDefaultB = objDefaultMaxUsage:GetObjPos()
		local objRealMaxUsage = objTree:GetUIObject("SettingWnd.Content.TaskMgr.SetCache.RealMaxUsage")
		local nBtnL, nBtnT, nBtnR, nBtnB = self:GetObjPos()
		local nBtnWidth = nBtnR-nBtnL
		local nBtnMid = math.floor((nBtnWidth)/2)
		if x > g_tabUsage.nHitX then
			local dx = x-g_tabUsage.nHitX
			nBtnL = math.min(nDefaultR-nBtnMid, nBtnL+dx)
			nBtnR = nBtnL + nBtnWidth
		elseif x < g_tabUsage.nHitX then
			local dx = g_tabUsage.nHitX-x
			nBtnL = math.max(nDefaultL-nBtnMid,nBtnL-dx)
			nBtnR = nBtnL + nBtnWidth
		end
		self:SetObjPos(nBtnL, nBtnT, nBtnR, nBtnB) 
		local nBtnMid = math.floor((nBtnL+nBtnR)/2)
		objRealMaxUsage:SetObjPos(nDefaultL,nDefaultT, nBtnMid, nDefaultB)
		
		local nMaxDiskUsageGB = math.floor(g_tabUsage.nMinTotalFreeGB+(g_tabUsage.nMaxTotalFreeGB-g_tabUsage.nMinTotalFreeGB)*nBtnMid/(nDefaultR-nDefaultL))
		local objUsageGB = objTree:GetUIObject("SettingWnd.Content.TaskMgr.SetCache.UsageGB")
		objUsageGB:SetText(tostring(nMaxDiskUsageGB) .. "GB")
		g_tTaskMrgData["nMaxDiskUsageGB"] = nMaxDiskUsageGB
	end
end

function OnMouseEnterUsageAbout(self)
	Helper.Tip:SetTips("缓存越大，有效资源越多，收益越高")
end

function OnMouseLeaveUsageAbout(self)
	Helper.Tip:DestoryTipWnd()
end

function InitTaskMgr(objTree)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local strPluginDataDir = tUserConfig["tConfig"]["ShareBindWindth"]["strPluginDataDir"]
	local nMaxDiskUsageGB = tUserConfig["tConfig"]["ShareBindWindth"]["nMaxDiskUsageGB"]
	local nMinDiskAvailGB = tUserConfig["tConfig"]["ShareBindWindth"]["nMinDiskAvailGB"]
	g_tTaskMrgData["strPluginDataDir"] = strPluginDataDir
	g_tTaskMrgData["nMaxDiskUsageGB"] = nMaxDiskUsageGB
	g_tTaskMrgData["nMinDiskAvailGB"] = nMinDiskAvailGB
	local _,_, strDisk = string.find(strPluginDataDir, "([^\\]+).+$")
	local objCacheDirEdit = objTree:GetUIObject("SettingWnd.Content.TaskMgr.CacheDirEdit.Input")
	objCacheDirEdit:SetText(strPluginDataDir)
	local nDataSize = ShareBindWidth:GetDataSize(strPluginDataDir)/1024/1024/1024
	local nFreeBytesAvailable, nTotalNumberOfBytes, nTotalNumberOfFreeBytes = tipUtil:GetDiskFreeSpace(strDisk)
	nFreeBytesAvailable = nFreeBytesAvailable/1024/1024/1024
	local nTotalFreeGB = nFreeBytesAvailable+nDataSize
	local nMaxTotalFreeGB = math.floor(nTotalFreeGB*0.9)
	local nMinTotalFreeGB = math.floor(math.min(nTotalFreeGB/2, 30))

	local objDefaultMaxUsage = objTree:GetUIObject("SettingWnd.Content.TaskMgr.SetCache.DefaultMaxUsage")
	local nDefaultL, nDefaultT, nDefaultR, nDefaultB = objDefaultMaxUsage:GetObjPos()
	local objRealMaxUsage = objTree:GetUIObject("SettingWnd.Content.TaskMgr.SetCache.RealMaxUsage")
	local objChangeUsage = objTree:GetUIObject("SettingWnd.Content.TaskMgr.SetCache.ChangeUsage")
	local nBtnL, nBtnT, nBtnR, nBtnB = objChangeUsage:GetObjPos()
	local nBtnWidth = nBtnR-nBtnL
	local nBtnMid = math.floor(nBtnWidth/2)
	local nRealMaxUsageWidth = (nMaxDiskUsageGB-nMinTotalFreeGB)/(nMaxTotalFreeGB-nMinTotalFreeGB)*(nDefaultR-nDefaultL)
	objRealMaxUsage:SetObjPos(nDefaultL,nDefaultT, nRealMaxUsageWidth, nDefaultB)
	
	nBtnL = nRealMaxUsageWidth-nBtnMid
	nBtnR = nBtnL+nBtnWidth
	if nBtnL < nDefaultL-nBtnMid then
		nBtnL = nDefaultL-nBtnMid
		nBtnR = nBtnL + nBtnWidth
	elseif nBtnL + nBtnMid > nDefaultR then
		nBtnL = nDefaultR - nBtnMid
		nBtnR = nBtnL+nBtnMid
	end
	objChangeUsage:SetObjPos(nBtnL,nBtnT, nBtnR, nBtnB)
	
	
	local objUsageGB = objTree:GetUIObject("SettingWnd.Content.TaskMgr.SetCache.UsageGB")
	objUsageGB:SetText(tostring(nMaxDiskUsageGB) .. "GB")
	
	local objRemainingSpace = objTree:GetUIObject("SettingWnd.Content.TaskMgr.RemainingSpace")
	objRemainingSpace:SetText("剩余空间：" .. tostring(nFreeBytesAvailable-nFreeBytesAvailable%0.01) .. "GB")
	
	
end

function OnCreate(self)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local userData = self:GetUserData()
	if userData and userData.parentWnd then
		local objTree = self:GetBindUIObjectTree()
		local objRootLayout = objTree:GetUIObject("SettingWnd.Root")
		local nLayoutL, nLayoutT, nLayoutR, nLayoutB = objRootLayout:GetObjPos()
		local nLayoutWidth  = nLayoutR - nLayoutL
		local nLayoutHeight = nLayoutB - nLayoutT
	
		local parentLeft, parentTop, parentRight, parentBottom = userData.parentWnd:GetWindowRect()
		local parentWidth  = parentRight - parentLeft
		local parentHeight = parentBottom - parentTop
		self:Move( parentLeft + (parentWidth - nLayoutWidth)/2, parentTop + (parentHeight - nLayoutHeight)/2, nLayoutWidth, nLayoutHeight)
		
		--[[
		local objAdvance = objTree:GetUIObject("SettingWnd.Content.Advance")
		objAdvance:SetVisible(false)
		objAdvance:SetChildrenVisible(false)
		--]]
		
		local objItemBase = objTree:GetUIObject("SettingWnd.Content.Item.Base")
		objItemBase:FireExtEvent("OnClick")
		
		local objCheckBoxAutoRun = objTree:GetUIObject("SettingWnd.Content.Base.CheckAutoRun")
		
		local objMachineIDInput = objTree:GetUIObject("SettingWnd.Content.Base.MachineIDEdit.Input")
		
		local objRadioShow = objTree:GetUIObject("SettingWnd.Content.Base.SuspendedWnd.Show")
		local objRadioHide = objTree:GetUIObject("SettingWnd.Content.Base.SuspendedWnd.Hide")
		local objRadioShowAtMining = objTree:GetUIObject("SettingWnd.Content.Base.SuspendedWnd.ShowAtMining")
		
		local objRadioFull = objTree:GetUIObject("SettingWnd.Content.Base.WorkModel.Full")
		local objRadioIntelligent = objTree:GetUIObject("SettingWnd.Content.Base.WorkModel.Intelligent")

		g_AutoRunState = tFunctionHelper.CheckCfgSetBoot()
		if g_AutoRunState then
			objCheckBoxAutoRun:SetCheck(true, true)
		else
			objCheckBoxAutoRun:SetCheck(false, true)
		end
		if type(tUserConfig["tUserInfo"]) ~= "table" then
			tUserConfig["tUserInfo"] = {}
		end
		local strMachineName = tUserConfig["tUserInfo"]["strMachineName"]
		if not Helper:IsRealString(strMachineName) then 
			strMachineName = tFunctionHelper.GetMachineName()
		end 
		objMachineIDInput:SetText(strMachineName)
		if type(tUserConfig["tConfig"]) ~= "table" then
			tUserConfig["tConfig"] = {}
		end
		if type(tUserConfig["tConfig"]["ShowBall"]) ~= "table" then
			tUserConfig["tConfig"]["ShowBall"] = {}
		end
		g_SuspendedWndState = tUserConfig["tConfig"]["ShowBall"]["nState"] or 0
		if g_SuspendedWndState == 0 then
			objRadioShow:SetCheck(true, true)
		elseif g_SuspendedWndState == 1 then
			objRadioHide:SetCheck(true, true)
		else
			objRadioShowAtMining:SetCheck(true, true)
		end
		
		
		if type(tUserConfig["tConfig"]["WorkModel"]) ~= "table" then
			tUserConfig["tConfig"]["WorkModel"] = {}
		end
		g_nWorkModel = tUserConfig["tConfig"]["WorkModel"]["nState"] or UIInterface:GetDefaultWorkModel()
		if g_nWorkModel == 0 then
			objRadioFull:SetCheck(true, true)
		else
			objRadioIntelligent:SetCheck(true, true)
		end
		
		--老板键
		local objCheckBoxBossKey = objTree:GetUIObject("SettingWnd.Content.Advance.CheckBossKeyArea")
		if type(tUserConfig["tConfig"]["BossKey"]) ~= "table" then
			tUserConfig["tConfig"]["BossKey"] = {}
		end
		local strBossKey = tUserConfig["tConfig"]["BossKey"]["strDesc"]
		local nBossKeyValue = tUserConfig["tConfig"]["BossKey"]["nValue"]
		if Helper:IsRealString(strBossKey) and nBossKeyValue ~= nil then
			g_strBossKey = strBossKey
			g_nBossKeyValue = nBossKeyValue
		end
		local ObjBossKeyInput = objTree:GetUIObject("SettingWnd.Content.BossKeyEdit.Input")
		ObjBossKeyInput:SetText(g_strBossKey)
		local bBossKeyCheck = tUserConfig["tConfig"]["BossKey"]["bCheck"]
		
		if bBossKeyCheck then
			objCheckBoxBossKey:SetCheck(true, true)
			ObjBossKeyInput:SetEnable(true)
			ObjBossKeyInput:SetTextColorID("555555")
		else
			objCheckBoxBossKey:SetCheck(false, true)
			ObjBossKeyInput:SetEnable(false)
			ObjBossKeyInput:SetTextColorID("BCB9B5")
		end
		
		--收益提醒
		local objCheckRemind = objTree:GetUIObject("SettingWnd.Content.Advance.CheckEarningRemind")
		if type(tUserConfig["tConfig"]["EarningRemind"]) ~= "table" then
			tUserConfig["tConfig"]["EarningRemind"] = {}
		end
		local bRemind = tUserConfig["tConfig"]["EarningRemind"]["bCheck"]
		if bRemind == nil then
			bRemind = true
		end
		if bRemind then
			objCheckRemind:SetCheck(true, true)
		else
			objCheckRemind:SetCheck(false, true)
		end
		
		--掉线监控
		local objCheckMonitor = objTree:GetUIObject("SettingWnd.Content.Advance.CheckOffLineMonitor")
		local nNoLaunch = GetOffLineMonitorNoLaunchCfg()
		if nNoLaunch == 0 then
			objCheckMonitor:SetCheck(true, true)
		else
			objCheckMonitor:SetCheck(false, true)
		end
		
		
		--任务管理
		local objCheckBandWidth = objTree:GetUIObject("SettingWnd.Content.TaskMgr.CheckBandWidth")
		if type(tUserConfig["tConfig"]["ShareBindWindth"]) ~= "table" then
			tUserConfig["tConfig"]["ShareBindWindth"] = {}
		end
		local bCheck = tUserConfig["tConfig"]["ShareBindWindth"]["bCheck"]
		if bCheck == nil then
			bCheck = true
		end
		if bCheck then
			objCheckBandWidth:SetCheck(true, true)
		else
			objCheckBandWidth:SetCheck(false, true)
		end
		ShareBindWidth:GetCacheCfg()
		InitTaskMgr(objTree)
		
	end
end