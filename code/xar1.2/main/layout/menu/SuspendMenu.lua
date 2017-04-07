local GXZBMenu = XLGetGlobal("GXZBMenu")
if not GXZBMenu then
	GXZBMenu = {}
	XLSetGlobal("GXZBMenu", GXZBMenu)
end
local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")
local menuFunTable = {}

function InitIcon(self, resid)
	local icon = self:GetControlObject("menu.item.icon")
	icon:SetObjPos2(14, "(father.height - 16)/2", 16, 16)
	icon:SetResID(resid)
	--顺便调整文字位置
	local text = self:GetControlObject("menu.item.text")
	text:SetObjPos2(37, 0, "father.width - 37", "father.height")
end

function menuFunTable.OnSelect_mainui(self)
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	objHostWnd:BringWindowToTop(true)
end

function menuFunTable.OnSelect_hideball(self)
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.SuspendWnd.Instance")
	if objHostWnd then
		if objHostWnd:GetVisible() then
			objHostWnd:Show(0)
		else
			objHostWnd:Show(1)
		end
	end
end

function menuFunTable.OnSelect_exit(self)
	GXZBMenu.SettingMenu.menuFunTable.OnSelect_exit()
end

function SetBallSetting(value)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["tConfig"] = tUserConfig["tConfig"] or {}
	tUserConfig["tConfig"]["ShowBall"] = tUserConfig["tConfig"]["ShowBall"] or {}
	tUserConfig["tConfig"]["ShowBall"]["nState"] = value
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
	tFunctionHelper.UpdateSuspendWndVisible(value == 2 and 1 or 0)
end

function FetchValueByPath(obj, path)
	local cursor = obj
	for i = 1, #path do
		cursor = cursor[path[i]]
		if cursor == nil then
			return nil
		end
	end
	return cursor
end

function InitSelectIcon(self, id)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local nSelect = FetchValueByPath(tUserConfig, {"tConfig", "ShowBall", "nState"})
	if ((not nSelect or nSelect == 0) and id == 0) or
		(nSelect == 1 and id == 1) or
		(nSelect == 2 and id == 2) then
		InitIcon(self, "bitmap.menu.select.normal")
	else
		local text = self:GetControlObject("menu.item.text")
		text:SetObjPos2(37, 0, "father.width - 37", "father.height")
	end
end

local menuTable = {
--主界面
{id="mainui", text = "主界面", OnInitFun = function(self) InitIcon(self, "bitmap.menu.main.normal") end},
--设置
{
	id="setting", 
	text = "设置", 
	OnSelectFun = function(self) end,
	SubMenuTable = {
		{id="allwaysshow", text = "始终显示", OnInitFun = function(self) InitSelectIcon(self, 0) end, OnSelectFun = function(self) SetBallSetting(0)  end},
		{id="allwayshide", text = "始终隐藏", OnInitFun = function(self) InitSelectIcon(self, 1) end, OnSelectFun = function(self) SetBallSetting(1)  end},
		{id="onlymakemoney", text = "仅赚宝时显示", OnInitFun = function(self) InitSelectIcon(self, 2) end, OnSelectFun = function(self) SetBallSetting(2)  end},
	},
	OnInitFun = function(self) InitIcon(self, "bitmap.menu.setting.normal") end
},
--退出
{id="exit", text = "退出", OnInitFun = function(self) InitIcon(self, "bitmap.menu.exit.normal") end},
}

GXZBMenu.SuspendMenu = {}
GXZBMenu.SuspendMenu.menuTable = menuTable
GXZBMenu.SuspendMenu.menuFunTable = menuFunTable
