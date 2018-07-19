local tFunctionHelper = XLGetGlobal("FunctionHelper")

local GXZBMenu = XLGetGlobal("GXZBMenu")
if not GXZBMenu then
	GXZBMenu = {}
	XLSetGlobal("GXZBMenu", GXZBMenu)
end

function InitIcon(self, resid)
	if resid ~= nil then
		local icon = self:GetControlObject("menu.item.icon")
		icon:SetObjPos2(24, "(father.height - 16)/2", 16, 16)
		icon:SetResID(resid)
	end	
	--顺便调整文字位置
	local text = self:GetControlObject("menu.item.text")
	text:SetObjPos2(47, 0, "father.width - 47", "father.height")
end

local menuFunTable = {}

function menuFunTable.OnSelect_setting(self)
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	objHostWnd:Show(1)
	Helper:CreateModalWnd("GXZB.SettingWnd", "GXZB.SettingWndTree", objHostWnd:GetWndHandle(), {["parentWnd"] = objHostWnd})
end

function menuFunTable.OnSelect_checkupdate(self)
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	objHostWnd:Show(1)
	Helper:CreateModalWnd("GXZB.CheckUpdateWnd", "GXZB.CheckUpdateWndTree", objHostWnd:GetWndHandle(), {["parentWnd"] = objHostWnd})
end

function menuFunTable.OnSelect_about(self)
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	objHostWnd:Show(1)
	Helper:CreateModalWnd("GXZB.AboutWnd", "GXZB.AboutWndTree", objHostWnd:GetWndHandle(), {["parentWnd"] = objHostWnd})
end

function menuFunTable.OnSelect_exit(self)
	local wndMain = UIInterface:GetMainHostWnd()
	local nRet, nCurBalance = 0, MainWorkModule:GetUserCurrentBalance()
	local bBind = WorkModuleHelper:CheckIsBinded()
	--未绑定微信且元宝余额不为0
	if nCurBalance > 0 and not bBind then
		wndMain:Show(1)
		Helper:CreateModalWnd("GXZB.ExitBindWnd", "GXZB.ExitBindWndTree", wndMain:GetWndHandle(), {["parentWnd"] = wndMain})
		return
	end
	if wndMain then
		wndMain:Show(0)
	end
	UIInterface:ReportAndExit()
end

function InitSelectIcon(self, id)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local nSelect = tFunctionHelper.FetchValueByPath(tUserConfig, {"tConfig", "WorkModel", "nState"})
	if ((not nSelect or nSelect == 1) and id == 1) or
		(nSelect == 0 and id == 0) then
		InitIcon(self, "bitmap.menu.select.normal")
	else
		local text = self:GetControlObject("menu.item.text")
		text:SetObjPos2(47, 0, "father.width - 47", "father.height")
	end
end

function SetWorkModelSetting(value)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["tConfig"] = tUserConfig["tConfig"] or {}
	tUserConfig["tConfig"]["WorkModel"] = tUserConfig["tConfig"]["WorkModel"] or {}
	tUserConfig["tConfig"]["WorkModel"]["nState"] = value
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
end

local menuTable = {
{id="setting", text = "设置", OnInitFun = function(self) InitIcon(self, "bitmap.menu.setting.normal") end},
--赚宝模式
{
	id="workmodel", 
	text = "赚宝模式", 
	OnSelectFun = function(self) end,
	SubMenuTable = {
		{id="allspeed", text = "全速赚宝", OnInitFun = function(self) InitSelectIcon(self, 0) end, OnSelectFun = function(self) SetWorkModelSetting(0)  end},
		{id="smartwork", text = "智能赚宝", OnInitFun = function(self) InitSelectIcon(self, 1) end, OnSelectFun = function(self) SetWorkModelSetting(1)  end},
	},
	OnInitFun = function(self) InitIcon(self, nil) end
},
{id="checkupdate", text = "检查更新", OnInitFun = function(self) InitIcon(self, "bitmap.menu.update.normal") end},
{id="about", text = "关于", OnInitFun = function(self) InitIcon(self, "bitmap.menu.about.normal") end},
{id="exit", text = "退出", OnInitFun = function(self) InitIcon(self, "bitmap.menu.exit.normal") end},
}

GXZBMenu.SettingMenu = {}
GXZBMenu.SettingMenu.menuTable = menuTable
GXZBMenu.SettingMenu.menuFunTable = menuFunTable
