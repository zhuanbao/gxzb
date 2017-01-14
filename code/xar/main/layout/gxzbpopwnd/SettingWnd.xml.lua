local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}

function OnClickClose(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:EndDialog(0)
end

function OnSelectSysBoot(self, event, bSelect)
	if bSelect then
		local strExePath = Helper.tipUtil:QueryRegValue("HKEY_LOCAL_MACHINE", "Software\\gxzb", "Path")
		if not Helper:IsRealString(strExePath) or not Helper.tipUtil:QueryFileExists(strExePath) then
			return
		end
		Helper.tipUtil:SetRegValue("HKEY_CURRENT_USER", "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run", "gxzb", "\""..strExePath.."\" /sstartfrom sysboot /embedding")
	else
		Helper.tipUtil:DeleteRegValue("HKEY_CURRENT_USER", "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\gxzb")
	end
end

function OnClickSureBtn(self)
	OnClickClose(self)
	local editCache = self:GetObject("tree:SettingWnd.EditCache")
	local strPath = editCache:GetText()
	if Helper:IsRealString(strPath) and Helper.tipUtil:QueryFileExists(strPath) then
		Helper.tipUtil:SetRegValue("HKEY_CURRENT_USER", "Software\\gxzb", "DAGDir", strPath)
	end
	OnClickMachineBtn(self)
end

function OnClickCacheBtn(self)
	local editCache = self:GetObject("tree:SettingWnd.EditCache")
	local strPath = editCache:GetText()
	if not Helper:IsRealString(strPath) or not Helper.tipUtil:QueryFileExists(strPath) then
		strPath = "C:\\"
	end
	local strNewPath = Helper.tipUtil:FolderDialog("目录选择", strPath)
	if Helper:IsRealString(strNewPath) and Helper.tipUtil:QueryFileExists(strNewPath) then
		editCache:SetText(strNewPath)
	end
end

function OnClickMachineBtn(self)
	local editMachine = self:GetObject("tree:SettingWnd.EditMachine")
	local strmachine = editMachine:GetText()
	if Helper:IsRealString(strmachine) then
		local strMachine = string.len(strmachine)
		if strMachine <= 20 and strMachine >= 3 then
			tUserConfig["tUserInfo"] = tUserConfig["tUserInfo"] or {}
			tUserConfig["tUserInfo"]["strMachineName"] = strmachine
			tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
			tFunctionHelper.SetMachineNameChangeInfo()
		end
	end
end

function OnSelectSuDu(self, event, bcheck)
	local r1 = self:GetObject("tree:SettingWnd.Radio.AllSpeed")
	local r2 = self:GetObject("tree:SettingWnd.Radio.Zhineng")
	local id = self:GetID()
	if id == "SettingWnd.Radio.AllSpeed" then
		r2:SetCheck(false, true)
		tUserConfig["workmodel"] = 0
	else
		r1:SetCheck(false, true)
		tUserConfig["workmodel"] = 1
	end
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
end

function OnFocusChangeEdit(self, isFocus)
	if isFocus then
		self:SetSelAll(true)
		self:SetNoCaret(false)
	else
		self:SetSelAll(false)
		self:SetNoCaret(true)
	end
end

function OnChangeEditCache(self)
	local textDAGDir = self:GetText()
	local freeSpace = self:GetObject("tree:SettingWnd.ShowFreeSpace")
	--XLMessageBox(tostring(textDAGDir))
	if Helper:IsRealString(textDAGDir) and Helper.tipUtil:QueryFileExists(textDAGDir) then
		local FreeBiyes = Helper.tipUtil:GetDiskFreeSpace(textDAGDir)
		--XLMessageBox(tostring(p1/1073741824))
		if type(FreeBiyes) == "number" then
			local n1, n2 = math.modf(FreeBiyes/1073741824)
			freeSpace:SetTextColorResID("DDDDDD")
			freeSpace:SetText(tostring(n1).."."..math.floor(n2*100).."GB")
		end
	else
		freeSpace:SetText("无效路径")
		freeSpace:SetTextColorResID("system.red")
	end
end

local function SetEditFocus(edit, x, y)
	local editL, editT, editR, editB = edit:GetAbsPos()
	if x > editL and x < editR and y > editT and y < editB then
		edit:SetFocus(true)
	else
		edit:SetFocus(false)
	end
end

function OnLButtonDownCaption(self, x, y)
	local editMachine = self:GetObject("tree:SettingWnd.EditMachine")
	local editCache = self:GetObject("tree:SettingWnd.EditCache")
	SetEditFocus(editMachine, x, y)
	SetEditFocus(editCache, x, y)
end

function OnCreate(self)
	local userData = self:GetUserData()
	if userData and userData.parentWnd then
		local objtree = self:GetBindUIObjectTree()
		local objRootLayout = objtree:GetUIObject("root")
		local nLayoutL, nLayoutT, nLayoutR, nLayoutB = objRootLayout:GetObjPos()
		local nLayoutWidth  = nLayoutR - nLayoutL
		local nLayoutHeight = nLayoutB - nLayoutT
	
		local parentLeft, parentTop, parentRight, parentBottom = userData.parentWnd:GetWindowRect()
		local parentWidth  = parentRight - parentLeft
		local parentHeight = parentBottom - parentTop
		self:Move( parentLeft + (parentWidth - nLayoutWidth)/2, parentTop + (parentHeight - nLayoutHeight)/2, nLayoutWidth, nLayoutHeight)
		local chkboxKaiji = objtree:GetUIObject("SettingWnd.CheckBox.Sysboot")
		local editMachine = objtree:GetUIObject("SettingWnd.EditMachine")
		local editCache = objtree:GetUIObject("SettingWnd.EditCache")
		local freeSpace = objtree:GetUIObject("SettingWnd.ShowFreeSpace")
		local radio1 = objtree:GetUIObject("SettingWnd.Radio.AllSpeed")
		local radio2 = objtree:GetUIObject("SettingWnd.Radio.Zhineng")
		
		if Helper:QueryRegValue("HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\gxzb") then
			chkboxKaiji:SetCheck(true, false)
		else
			chkboxKaiji:SetCheck(false, false)
		end
	
		local cacheDir = Helper:QueryRegValue("HKEY_CURRENT_USER\\SOFTWARE\\gxzb\\DAGDir")
		if not Helper:IsRealString(cacheDir) then
			cacheDir = "C:"
		end
		editCache:SetText(cacheDir)
		--OnChangeEditCache(editMachine)
		
		local machineName
		if tUserConfig["tUserInfo"] and tUserConfig["tUserInfo"]["strMachineName"] then
			machineName = tUserConfig["tUserInfo"]["strMachineName"]
		else
			machineName = Helper:QueryRegValue("HKEY_LOCAL_MACHINE\\SOFTWARE\\gxzb\\PeerId")
		end
		if machineName then
			editMachine:SetText(machineName)
		end
		
		local model = tUserConfig["workmodel"]
		--model=0全速， model=1智能，默认全速
		if tonumber(model) == 1 then
			radio2:SetCheck(true)
		else
			radio1:SetCheck(true)
		end
	end
end