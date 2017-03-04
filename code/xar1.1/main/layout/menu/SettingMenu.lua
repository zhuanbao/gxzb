local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")

local GXZBMenu = XLGetGlobal("GXZBMenu")
if not GXZBMenu then
	GXZBMenu = {}
	XLSetGlobal("GXZBMenu", GXZBMenu)
end

local menuFunTable = {}

function menuFunTable.OnSelect_setting(self)
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	objHostWnd:Show(1)
	local maskWnd = Helper:CreateTransparentMask(objHostWnd)
	Helper:CreateModalWnd("GXZB.SettingWnd", "GXZB.SettingWndTree", maskWnd:GetWndHandle(), {["parentWnd"] = maskWnd})
	Helper:DestoryTransparentMask(objHostWnd)
end

function menuFunTable.OnSelect_checkupdate(self)
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	objHostWnd:Show(1)
	local maskWnd = Helper:CreateTransparentMask(objHostWnd)
	Helper:CreateModalWnd("GXZB.UpdateWnd", "GXZB.UpdateWndTree", maskWnd:GetWndHandle(), {["parentWnd"] = maskWnd})
	Helper:DestoryTransparentMask(objHostWnd)
end

function menuFunTable.OnSelect_about(self)
	local objHostWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	objHostWnd:Show(1)
	local maskWnd = Helper:CreateTransparentMask(objHostWnd)
	Helper:CreateModalWnd("GXZB.AboutWnd", "GXZB.AboutWndTree", maskWnd:GetWndHandle(), {["parentWnd"] = maskWnd})
	Helper:DestoryTransparentMask(objHostWnd)
end

function menuFunTable.OnSelect_exit(self)
	local wnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
	local nLocalState, nRet, nCurBalance = tFunctionHelper.GetClientCurrentState(), 0, tFunctionHelper.GetUserCurrentBalance()
	local MING_CALCULATE_DAG = 2
	local bBind = tFunctionHelper.CheckIsBinded()
	--正在生成本地数据块
	if nLocalState == MING_CALCULATE_DAG then
		nRet = Helper:CreateModalWnd("MessageBoxWnd", "MessageBoxWndTree", nil, 
			{
				["parentWnd"] = wnd, 
				["Text"] = "正在生成本地数据，是否退出？",
				["ChangeUI"] = function(objWnd)
					local objtree = objWnd:GetBindUIObjectTree()
					local btnyes = objtree:GetUIObject("yes")
					local btnno = objtree:GetUIObject("no")
					btnyes:SetText("退出")
					btnno:SetText("取消")
				end,
			}
		)
		if nRet ~= 0 then
			return
		end
	--非生成本地数据块状态，未绑定微信且元宝余额不为0
	elseif nLocalState ~= 2 and nCurBalance > 0 and not bBind then
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
{id="setting", text = "设置"},
{id="checkupdate", text = "检查更新"},
{id="about", text = "关于"},
{id="exit", text = "退出"},
}

GXZBMenu.SettingMenu = {}
GXZBMenu.SettingMenu.menuTable = menuTable
GXZBMenu.SettingMenu.menuFunTable = menuFunTable
