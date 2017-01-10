local GXZBMenu = XLGetGlobal("GXZBMenu")
if not GXZBMenu then
	GXZBMenu = {}
	XLSetGlobal("GXZBMenu", GXZBMenu)
end

local bReverse = true
local menuFunTable = {}

function menuFunTable.OnInit_FileName(self)
	
end

function menuFunTable.OnSelect_FileName(self)
	
end

function menuFunTable.OnInit_Size(self)
	
end

function menuFunTable.OnSelect_Size(self)
	
end

function menuFunTable.OnInit_OperateTime(self)
	
end

function menuFunTable.OnSelect_OperateTime(self)
	
end

function menuFunTable.OnInit_Ext(self)
	
end

function menuFunTable.OnSelect_Ext(self)
	
end

local menuTable = {
{id="FileName", text = "文件名"},
{id="Size", text = "大小"},
{id="OperateTime", text = "修改日期"},
{id="Ext", text = "类型"},
}

GXZBMenu.SettingMenu = {}
GXZBMenu.SettingMenu.menuTable = menuTable
GXZBMenu.SettingMenu.menuFunTable = menuFunTable
