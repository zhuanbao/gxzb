local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")

local GXZBMenu = XLGetGlobal("GXZBMenu")
if not GXZBMenu then
	GXZBMenu = {}
	XLSetGlobal("GXZBMenu", GXZBMenu)
end

function InitIcon(self, resid)
	local icon = self:GetControlObject("menu.item.icon")
	icon:SetObjPos2(9, "(father.height - 16)/2", 16, 16)
	icon:SetResID(resid)
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
	Helper:CreateModalWnd("GXZB.UpdateWnd", "GXZB.UpdateWndTree", objHostWnd:GetWndHandle(), {["parentWnd"] = objHostWnd})
end

function menuFunTable.OnSelect_about(self)
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	objHostWnd:Show(1)
	Helper:CreateModalWnd("GXZB.AboutWnd", "GXZB.AboutWndTree", objHostWnd:GetWndHandle(), {["parentWnd"] = objHostWnd})
end

function menuFunTable.OnSelect_exit(self)
	local wnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	local nLocalState, nRet, nCurBalance = tFunctionHelper.GetClientCurrentState(), 0, tFunctionHelper.GetUserCurrentBalance()
	local bBind = tFunctionHelper.CheckIsBinded()
	--未绑定微信且元宝余额不为0
	if nLocalState ~= 2 and nCurBalance > 0 and not bBind then
		nRet = Helper:CreateModalWnd("MessageBoxWnd", "MessageBoxWndTree", nil, 
			{
				["parentWnd"] = wnd, 
				["Text"] = "您已赚取了"..tostring(nCurBalance).."个元宝，请及时绑定微信将元宝入账。",
				["ChangeUI"] = function(objWnd)
					local objtree = objWnd:GetBindUIObjectTree()
					local btnyes = objtree:GetUIObject("yes")
					local btnno = objtree:GetUIObject("no")
					btnyes:SetText("立即绑定")
					btnno:SetText("下次再说")
				end,
			}
		)
		if nRet == 0 then
			tFunctionHelper.ChangeMainBodyPanel("QRCodePanel")
			return
		end
	end
	if wnd then
		wnd:Show(0)
	end
	tFunctionHelper.ReportAndExit()
end

local menuTable = {
{id="setting", text = "设置", OnInitFun = function(self) InitIcon(self, "bitmap.menu.setting.normal") end},
{id="checkupdate", text = "检查更新", OnInitFun = function(self) InitIcon(self, "bitmap.menu.update.normal") end},
{id="about", text = "关于", OnInitFun = function(self) InitIcon(self, "bitmap.menu.about.normal") end},
{id="exit", text = "退出", OnInitFun = function(self) InitIcon(self, "bitmap.menu.exit.normal") end},
}

GXZBMenu.SettingMenu = {}
GXZBMenu.SettingMenu.menuTable = menuTable
GXZBMenu.SettingMenu.menuFunTable = menuFunTable
