local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
--local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
local strAutoRunRegPath = "HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\Share4Money"

local g_AutoRunState = false
local g_nWorkModel = 0
local g_SuspendedWndState = 0


function CheckIsAutoRun()
	local strValue = Helper:QueryRegValue(strAutoRunRegPath)
	if Helper:IsRealString(strValue) then
		return true
	end
	return false
end

function SetAutoRun()
	local strExePath = tFunctionHelper.GetExePath()
	local strValue = "\""..strExePath.."\" /sstartfrom sysboot /embedding /mining"
	Helper:SetRegValue(strAutoRunRegPath, strValue)
end

function SaveSettingConfig(objTree)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if g_AutoRunState and not CheckIsAutoRun() then
		SetAutoRun()
	elseif not g_AutoRunState and CheckIsAutoRun() then
		tFunctionHelper.RegDeleteValue(strAutoRunRegPath)
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
		tFunctionHelper.SetMachineNameChangeInfo()
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
	
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
	--更新球的状态
	local isWorking = tFunctionHelper.CheckIsWorking()
	tFunctionHelper.UpdateSuspendWndVisible(isWorking and 1 or 0)
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
	if bSelect then
		g_AutoRunState = true
	else
		g_AutoRunState = false
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

		g_AutoRunState = CheckIsAutoRun()
		if CheckIsAutoRun() then
			ObjCheckBoxAutoRun:SetCheck(true, false)
		else
			ObjCheckBoxAutoRun:SetCheck(false, false)
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
			ObjRadioShow:SetCheck(true, false)
		elseif g_SuspendedWndState == 1 then
			ObjRadioHide:SetCheck(true, false)
		else
			ObjRadioShowAtMining:SetCheck(true, false)
		end
		
		
		if type(tUserConfig["tConfig"]["WorkModel"]) ~= "table" then
			tUserConfig["tConfig"]["WorkModel"] = {}
		end
		g_nWorkModel = tUserConfig["tConfig"]["WorkModel"]["nState"] or 0
		if g_nWorkModel == 0 then
			ObjRadioFull:SetCheck(true, false)
		else
			ObjRadioIntelligent:SetCheck(true, false)
		end
	end
end