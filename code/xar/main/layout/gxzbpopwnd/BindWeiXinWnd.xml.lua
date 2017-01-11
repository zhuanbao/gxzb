local tipUtil = XLGetObject("API.Util")
local FunctionObj = XLGetGlobal("Global.FunctionHelper")

function OnCreate( self )
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
	end
end


function OnClickBindWeiXin(self)
	--弹出绑定微信二维码
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:EndDialog(0)
	local Helper =  XLGetGlobal("Helper")
	local wnd = Helper.hostWndManager:GetHostWnd("GXZBTipWnd.MainFrame")
	local maskWnd = Helper:CreateTransparentMask(wnd)
	Helper:CreateModalWnd("GXZB.BindWeiXin2WeiMaWnd", "GXZB.BindWeiXin2WeiMaWndTree", maskWnd:GetWndHandle(), {["parentWnd"] = maskWnd})
	Helper:DestoryTransparentMask(wnd)
end