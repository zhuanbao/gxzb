local tFunctionHelper = XLGetGlobal("FunctionHelper")
local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")

function OnMouseEnter(self)
	local ObjHoverImage = self:GetObject("hoverimage")
	if not ObjHoverImage then
		ObjHoverImage = objFactory:CreateUIObject("hoverimage", "ImageObject")
		self:AddChild(ObjHoverImage)
		hoverimage:SetObjPos(-5, -9, 20, -6)
		hoverimage:SetResID("GXZB.Title.Hoverimage")
	end
	ObjHoverImage:SetVisible(true)
end

function OnMouseLeave(self)
	local ObjHoverImage = self:GetObject("hoverimage")
	if ObjHoverImage then
		ObjHoverImage:SetVisible(false)
	end
end

function ClosePopWnd(self)
	Helper:DestoryModelessWnd("GXZB.RemindOpenBoxWnd")
end

function OnClickClose(self)
	local tStatInfo = {}
	tStatInfo.fu1 = "openbox"
	tStatInfo.fu5 = "closepopupwnd"
	StatisticClient:SendClickReport(tStatInfo)
	ClosePopWnd(self)
end

function OnClickOpenBox(self)
	OpenBox:OpenWeb()
	local tStatInfo = {}
	tStatInfo.fu1 = "openbox"
	tStatInfo.fu5 = "openweb"
	tStatInfo.fu6 = "popupwnd"
	StatisticClient:SendClickReport(tStatInfo)
	ClosePopWnd(self)
end

function PopupInDeskRight(self)
	local objtree = self:GetBindUIObjectTree()
	local objRootLayout = objtree:GetUIObject("RemindOpenBoxWnd.Content")
    local templateMananger = XLGetObject("Xunlei.UIEngine.TemplateManager")
	
	local nLayoutL, nLayoutT, nLayoutR, nLayoutB = objRootLayout:GetObjPos()
	local nLayoutWidth = nLayoutR - nLayoutL
	local nLayoutHeight = nLayoutB - nLayoutT
	
	local workleft, worktop, workright, workbottom = Helper.tipUtil:GetWorkArea()
	self:Move( workright - nLayoutWidth, workbottom - nLayoutHeight, nLayoutWidth, nLayoutHeight)
	return true
end

function OnShowWindow(self, bShow)
	if bShow then
		PopupInDeskRight(self)
		local tStatInfo = {}
		tStatInfo.fu1 = "openbox"
		tStatInfo.fu5 = "showpopupwnd"
		StatisticClient:SendEventReport(tStatInfo)
	end
end

function OnCreate(self)
	local userData = self:GetUserData()
	local objTree = self:GetBindUIObjectTree()
	local ObjText = objTree:GetUIObject("RemindOpenBoxWnd.Text")
	ObjText:SetText(userData["tOpenBoxCfg"]["strText"])
end