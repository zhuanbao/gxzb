local tFunctionHelper = XLGetGlobal("FunctionHelper")
local tipUtil = XLGetObject("API.Util")
--local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
--local strAutoRunRegPath = "HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\Share4Money"

local g_AutoRunState = false
--设置挖矿模式的默认值
--[[
0 全速，1智能
--]]
local g_nWorkModel = 1
local g_SuspendedWndState = 0

local g_strBossKey = "Alt+Z"
local g_nBossKeyValue = 0x5A0001
--[[
function CheckIsSysAutoRun()
	local strValue = Helper:QueryRegValue(strAutoRunRegPath)
	if Helper:IsRealString(strValue) then
		return true
	end
	return false
end

function CheckIsCfgAutoRun()
	return tFunctionHelper.CheckLastSetBoot()
end

function SetAutoRun()
	if not CheckIsCfgAutoRun() then
		tFunctionHelper.WriteLastSetBootTime()
	end
	if not CheckIsSysAutoRun() then
		local strExePath = tFunctionHelper.GetExePath()
		local strValue = "\""..strExePath.."\" /sstartfrom sysboot /embedding /mining"
		Helper:SetRegValue(strAutoRunRegPath, strValue)
	end
end
--]]

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

function SaveSettingConfig(objTree)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if g_AutoRunState then
		tFunctionHelper.WriteCfgSetBoot()
		tFunctionHelper.WriteSysSetBoot()
	else
		tFunctionHelper.DeleteCfgSetBoot()
		tFunctionHelper.DeleteSysSetBoot()
	end
	
	local ObjEditMachineID = objTree:GetUIObject("SettingWnd.Content.MachineIDArea.Edit")
	local strMachineName = ObjEditMachineID:GetText()
	if not Helper:IsRealString(strMachineName) then
		strMachineName = tFunctionHelper.GetMachineName()
	end
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	if not Helper:IsRealString(tUserConfig["tUserInfo"]["strMachineName"]) or tUserConfig["tUserInfo"]["strMachineName"] ~= strMachineName then
		tUserConfig["tUserInfo"]["strMachineName"] = strMachineName
		ClientWorkModule:SetMachineNameChangeInfo()
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
	local isWorking = ClientWorkModule:CheckIsWorking()
	UIInterface:UpdateSuspendWndVisible()
	
	--老板键
	local ObjCheckBoxBossKey = objTree:GetUIObject("SettingWnd.Content.BossKeyArea.Check")
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
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
end

function DestoryDialog(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:EndDialog(0)
end

function OnClickCloseDialog(self)
	DestoryDialog(self)
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
	local ObjEditBossKey = objTree:GetUIObject("SettingWnd.Content.BossKeyArea.Edit")
	
	if bSelect then
		ObjEditBossKey:SetEnable(true)
		ObjEditBossKey:SetTextColorID("555555")
	else
		ObjEditBossKey:SetEnable(false)
		ObjEditBossKey:SetTextColorID("BCB9B5")
	end
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
	local ObjRadioShow = self:GetObject("tree:SettingWnd.Content.SuspendedWnd.Show")
	local ObjRadioHide = self:GetObject("tree:SettingWnd.Content.SuspendedWnd.Hide")
	local ObjRadioShowAtMining = self:GetObject("tree:SettingWnd.Content.SuspendedWnd.ShowAtMining")
	local strCurrentID = self:GetID()
	if strCurrentID == "SettingWnd.Content.SuspendedWnd.Show" then
		ObjRadioHide:SetCheck(false, true)
		ObjRadioShowAtMining:SetCheck(false, true)
		g_SuspendedWndState = 0
	elseif strCurrentID == "SettingWnd.Content.SuspendedWnd.Hide" then
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
	local ObjRadioFull = self:GetObject("tree:SettingWnd.Content.WorkModel.Full")
	local ObjRadioIntelligent = self:GetObject("tree:SettingWnd.Content.SuspendedWnd.Intelligent")
	local strCurrentID = self:GetID()
	if strCurrentID == "SettingWnd.Content.WorkModel.Full" then
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
	local editMachineID = self:GetObject("tree:SettingWnd.Content.MachineIDArea.Edit")
	SetSettingWndEditFocus(editMachineID, x, y)
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
	local ObjTip = ObjTree:GetUIObject("SettingWnd.Content.BossKeyArea.Tip")
	local ObjTipText = ObjTree:GetUIObject("SettingWnd.Content.BossKeyArea.TipText")
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
			iFnKey  = iFnKey+0x2
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
		g_nBossKeyValue = iValue
	end	
	return 0, true, false
end

function OnMouseEnterAbout(self)
	Helper.Tip:SetTips("如果老板来了，按老板键，赚宝会自动隐藏")
end

function OnMouseLeaveAbout(self)
	Helper.Tip:DestoryTipWnd()
end

function OnCreate(self)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local userData = self:GetUserData()
	if userData and userData.parentWnd then
		local objTree = self:GetBindUIObjectTree()
		local objRootLayout = objTree:GetUIObject("root")
		local nLayoutL, nLayoutT, nLayoutR, nLayoutB = objRootLayout:GetObjPos()
		local nLayoutWidth  = nLayoutR - nLayoutL
		local nLayoutHeight = nLayoutB - nLayoutT
	
		local parentLeft, parentTop, parentRight, parentBottom = userData.parentWnd:GetWindowRect()
		local parentWidth  = parentRight - parentLeft
		local parentHeight = parentBottom - parentTop
		self:Move( parentLeft + (parentWidth - nLayoutWidth)/2, parentTop + (parentHeight - nLayoutHeight)/2, nLayoutWidth, nLayoutHeight)
		
		local ObjCheckBoxAutoRun = objTree:GetUIObject("SettingWnd.Content.AutoRunArea.CheckAutoRun")
		
		local ObjEditMachineID = objTree:GetUIObject("SettingWnd.Content.MachineIDArea.Edit")
		
		local ObjRadioShow = objTree:GetUIObject("SettingWnd.Content.SuspendedWnd.Show")
		local ObjRadioHide = objTree:GetUIObject("SettingWnd.Content.SuspendedWnd.Hide")
		local ObjRadioShowAtMining = objTree:GetUIObject("SettingWnd.Content.SuspendedWnd.ShowAtMining")
		
		local ObjRadioFull = objTree:GetUIObject("SettingWnd.Content.WorkModel.Full")
		local ObjRadioIntelligent = objTree:GetUIObject("SettingWnd.Content.SuspendedWnd.Intelligent")

		g_AutoRunState = tFunctionHelper.CheckCfgSetBoot()
		if g_AutoRunState then
			ObjCheckBoxAutoRun:SetCheck(true, true)
		else
			ObjCheckBoxAutoRun:SetCheck(false, true)
		end
		if type(tUserConfig["tUserInfo"]) ~= "table" then
			tUserConfig["tUserInfo"] = {}
		end
		local strMachineName = tUserConfig["tUserInfo"]["strMachineName"]
		if not Helper:IsRealString(strMachineName) then 
			strMachineName = tFunctionHelper.GetMachineName()
		end 
		ObjEditMachineID:SetText(strMachineName)
		if type(tUserConfig["tConfig"]) ~= "table" then
			tUserConfig["tConfig"] = {}
		end
		if type(tUserConfig["tConfig"]["ShowBall"]) ~= "table" then
			tUserConfig["tConfig"]["ShowBall"] = {}
		end
		g_SuspendedWndState = tUserConfig["tConfig"]["ShowBall"]["nState"] or 0
		if g_SuspendedWndState == 0 then
			ObjRadioShow:SetCheck(true, true)
		elseif g_SuspendedWndState == 1 then
			ObjRadioHide:SetCheck(true, true)
		else
			ObjRadioShowAtMining:SetCheck(true, true)
		end
		
		
		if type(tUserConfig["tConfig"]["WorkModel"]) ~= "table" then
			tUserConfig["tConfig"]["WorkModel"] = {}
		end
		g_nWorkModel = tUserConfig["tConfig"]["WorkModel"]["nState"] or UIInterface:GetDefaultWorkModel()
		if g_nWorkModel == 0 then
			ObjRadioFull:SetCheck(true, true)
		else
			ObjRadioIntelligent:SetCheck(true, true)
		end
		
		--老板键
		local ObjCheckBoxBossKey = objTree:GetUIObject("SettingWnd.Content.BossKeyArea.Check")
		if type(tUserConfig["tConfig"]["BossKey"]) ~= "table" then
			tUserConfig["tConfig"]["BossKey"] = {}
		end
		local strBossKey = tUserConfig["tConfig"]["BossKey"]["strDesc"]
		local nBossKeyValue = tUserConfig["tConfig"]["BossKey"]["nValue"]
		if Helper:IsRealString(strBossKey) and nBossKeyValue ~= nil then
			g_strBossKey = strBossKey
			g_nBossKeyValue = nBossKeyValue
		end
		local ObjEditBossKey = objTree:GetUIObject("SettingWnd.Content.BossKeyArea.Edit")
		ObjEditBossKey:SetText(g_strBossKey)
		local bBossKeyCheck = tUserConfig["tConfig"]["BossKey"]["bCheck"]
		
		if bBossKeyCheck then
			ObjCheckBoxBossKey:SetCheck(true, true)
			ObjEditBossKey:SetEnable(true)
			ObjEditBossKey:SetTextColorID("555555")
		else
			ObjCheckBoxBossKey:SetCheck(false, true)
			ObjEditBossKey:SetEnable(false)
			ObjEditBossKey:SetTextColorID("BCB9B5")
		end
	end
end