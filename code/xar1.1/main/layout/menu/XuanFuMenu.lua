local GXZBMenu = XLGetGlobal("GXZBMenu")
if not GXZBMenu then
	GXZBMenu = {}
	XLSetGlobal("GXZBMenu", GXZBMenu)
end
local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
local menuFunTable = {}

function InitIcon(self, resid)
	local icon = self:GetControlObject("menu.item.icon")
	icon:SetObjPos2(9, "(father.height - 13)/2", 13, 13)
	icon:SetResID(resid)
end

function menuFunTable.OnSelect_mainui(self)
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	objHostWnd:BringWindowToTop(true)
end

function menuFunTable.OnSelect_hideball(self)
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.XuanFuWnd.Instance")
	if objHostWnd then
		if objHostWnd:GetVisible() then
			objHostWnd:Show(0)
		else
			objHostWnd:Show(1)
		end
	end
end

function menuFunTable.OnSelect_exit(self)
	local wnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	if wnd then
		wnd:Show(0)
	end
	tFunctionHelper.ReportAndExit()
end

function SetBallSetting(value)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["tConfig"] = tUserConfig["tConfig"] or {}
	tUserConfig["tConfig"]["showball"] = value
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
end

local menuTable = {
--主界面
{id="mainui", text = "主界面", OnInitFun = function(self) InitIcon(self, "bitmap.menu.setting_check.normal") end},
--设置
{
	id="setting", 
	text = "设置", 
	OnSelectFun = function(self) end,
	SubMenuTable = {
		{id="allwaysshow", text = "始终显示", OnSelectFun = function(self) SetBallSetting(0)  end},
		{id="allwayshide", text = "始终隐藏", OnSelectFun = function(self) SetBallSetting(1)  end},
		{id="onlymakemoney", text = "仅赚宝时显示", OnSelectFun = function(self) SetBallSetting(2)  end},
	},
	OnInitFun = function(self) InitIcon(self, "bitmap.menu.setting_check.normal") end
},
--退出
{id="exit", text = "退出", OnInitFun = function(self) InitIcon(self, "bitmap.menu.setting_check.normal") end},
}

GXZBMenu.XuanFuMenu = {}
GXZBMenu.XuanFuMenu.menuTable = menuTable
GXZBMenu.XuanFuMenu.menuFunTable = menuFunTable
