local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
--local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
local strAutoRunRegPath = "HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\gxzb"
local strDAGRegPath = "HKEY_CURRENT_USER\\SOFTWARE\\gxzb\\DAGDir"
local g_nDagCacheMinSize = 4*1024*1024*1024

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
	local strValue = "\""..strExePath.."\" /sstartfrom sysboot /embedding"
	Helper:SetRegValue(strAutoRunRegPath, strValue)
end

function GetDagCache()
	local strValue = Helper:QueryRegValue(strDAGRegPath) or ""
	return strValue
end

function SaveSettingConfig(objTree)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	if g_AutoRunState and not CheckIsAutoRun() then
		SetAutoRun()
	elseif not g_AutoRunState and CheckIsAutoRun() then
		tFunctionHelper.RegDeleteValue(strAutoRunRegPath)
	end
	
	local ObjEditMachineID = objTree:GetUIObject("SettingWnd.Content.MachineIDArea.Edit")
	local strMachineName = ObjEditMachineID:GetText(strMachineName)
	if type(tUserConfig["tUserInfo"]) ~= "table" then
		tUserConfig["tUserInfo"] = {}
	end
	tUserConfig["tUserInfo"]["strMachineName"] = strMachineName
	
	local ObjEditDagCache = objTree:GetUIObject("SettingWnd.Content.DagCacheArea.Edit")
	local strNewDagCachePath = ObjEditDagCache:GetText(strMachineName)
	local strCurrentDagCachePath = GetDagCache()
	if string.lower(strCurrentDagCachePath) ~= string.lower(strNewDagCachePath) then
		Helper:SetRegValue(strDAGRegPath, strNewDagCachePath)
	end
	
	if type(tUserConfig["tConfig"]["WorkModel"]) ~= "table" then
		tUserConfig["tConfig"]["WorkModel"] = {}
	end
	tUserConfig["tConfig"]["WorkModel"]["nState"] = g_nWorkModel

	if type(tUserConfig["tConfig"]["SuspendedWnd"]) ~= "table" then
		tUserConfig["tConfig"]["SuspendedWnd"] = {}
	end
	tUserConfig["tConfig"]["SuspendedWnd"]["nState"] = g_SuspendedWndState
	
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

function OnDagCacheEditFocusChange(self, bFocus)
	SetEditTextState(self, bFocus)
end

function OnDagCacheEditTextChange(self)
	local bRet = false
	local strInfo = "无效路径"
	local strText = self:GetText()
	local ObjDagCacheInfo = self:GetObject("tree:SettingWnd.Content.DagCacheArea.Info")
	local ObjBtnConfirm = self:GetObject("tree:SettingWnd.Buttom.Confirm")
	if Helper:IsRealString(strText) and Helper.tipUtil:QueryFileExists(strText) then
		local nBytes = Helper.tipUtil:GetDiskFreeSpace(strText)
		if type(nBytes) == "number" then
			local strSize = tFunctionHelper.FormatByteUnit(nBytes)
			if nBytes >= g_nDagCacheMinSize then
				bRet = true
				strInfo = "剩余空间".. strSize .. ",更改后需重启生效"
			else
				strInfo = "剩余空间" .. strSize ..",该磁盘剩余空间小于4G，请重新选择！"
			end	
		end
	end
	if not bRet then
		ObjBtnConfirm:Enable(false)
		ObjDagCacheInfo:SetTextColorResID("system.red")
	else	
		ObjBtnConfirm:Enable(true)
		ObjDagCacheInfo:SetTextColorResID("DDDDDD")
	end
	ObjDagCacheInfo:SetText(strInfo)
end

function OnClickChangeDir(self)
	local editDagCache = self:GetObject("tree:SettingWnd.Content.DagCacheArea.Edit")
	local strPath = editDagCache:GetText()
	if not Helper:IsRealString(strPath) or not Helper.tipUtil:QueryFileExists(strPath) then
		strPath = "C:\\"
	end
	local strNewPath = Helper.tipUtil:FolderDialog("目录选择", strPath)
	if Helper:IsRealString(strNewPath) and Helper.tipUtil:QueryFileExists(strNewPath) then
		editDagCache:SetText(strNewPath)
	end
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
	local editDagCache = self:GetObject("tree:SettingWnd.Content.DagCacheArea.Edit")
	SetSettingWndEditFocus(editMachineID, x, y)
	SetSettingWndEditFocus(editDagCache, x, y)
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
		
		local ObjEditDagCache = objTree:GetUIObject("SettingWnd.Content.DagCacheArea.Edit")
		
		local ObjTextCacheInfo = objTree:GetUIObject("SettingWnd.Content.DagCacheArea.Info")
		
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
		if Helper:IsRealString(strMachineName) then 
			ObjEditMachineID:SetText(strMachineName)
		end 
		
		local strDagCachePath = GetDagCache()
		if Helper:IsRealString(strDagCachePath)then
			ObjEditDagCache:SetText(strDagCachePath)
			local strInfo = "无效路径"
			if Helper.tipUtil:QueryFileExists(strDagCachePath) then
				local nBytes = Helper.tipUtil:GetDiskFreeSpace(strDagCachePath)
				if type(nBytes) == "number" then
					local strSize = tFunctionHelper.FormatByteUnit(nBytes)
					strInfo = "剩余空间".. strSize .. ",更改后需重启生效"
				end
			end
			ObjTextCacheInfo:SetText(strInfo)
		end
		
		if type(tUserConfig["tConfig"]["WorkModel"]) ~= "table" then
			tUserConfig["tConfig"]["WorkModel"] = {}
		end
		g_SuspendedWndState = tUserConfig["tConfig"]["WorkModel"]["nState"] or 0
		if g_SuspendedWndState == 0 then
			ObjRadioShow:SetCheck(true, false)
		elseif g_SuspendedWndState == 1 then
			ObjRadioHide:SetCheck(true, false)
		else
			ObjRadioShowAtMining:SetCheck(true, false)
		end
		
		if type(tUserConfig["tConfig"]["SuspendedWnd"]) ~= "table" then
			tUserConfig["tConfig"]["SuspendedWnd"] = {}
		end
		g_SuspendedWndState = tUserConfig["tConfig"]["SuspendedWnd"]["nState"] or 0
		if g_SuspendedWndState == 0 then
			ObjRadioFull:SetCheck(true, false)
		else
			ObjRadioIntelligent:SetCheck(true, false)
		end
	end
end