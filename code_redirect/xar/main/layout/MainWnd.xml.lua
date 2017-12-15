local tipUtil = XLGetObject("API.Util")
local gRootCtrl = nil
local tFunctionHelper = XLGetGlobal("FunctionHelper")

function OnClose( self )
	self:Show(0)
	return 0, true
end


function OnMouseLeave(self, x, y)

end

local gShowOnce = false
function TryPopAutoRunTip()
	if gShowOnce then
		return
	end
	
	if not tFunctionHelper.CheckCfgSetBoot() or tFunctionHelper.CheckSysSetBoot() then
		return
	end
	local hostWndManager = XLGetObject("Xunlei.UIEngine.HostWndManager")
	local wndUpdate = hostWndManager:GetHostWnd("GXZB.UpdateFrameWnd.Instance")
	if wndUpdate == nil then
		return
	end
	if wndUpdate:GetVisible() then
		return
	end
	gShowOnce = true
	UIInterface:ShowPopupWndByName("GXZB.AutoRunTipWnd.Instance", true)
end

function OnShowWindow(self, bShow)
	if bShow then
		if not UIInterface:ShowUpdateDriveWnd() then
			TryPopAutoRunTip()
		end	
		gTipStartTime = tipUtil:GetCurrentUTCTime()
	end
end


function PopupInDeskMiddle(self)
	local objtree = self:GetBindUIObjectTree()
	local objRootLayout = objtree:GetUIObject("root.layout")
    local templateMananger = XLGetObject("Xunlei.UIEngine.TemplateManager")
	--local aniT = templateMananger:GetTemplate("tip.pos.animation","AnimationTemplate")
	--local ani = aniT:CreateInstance()
	--ani:BindObj(objRootLayout)
	
	local nLayoutL, nLayoutT, nLayoutR, nLayoutB = objRootLayout:GetObjPos()
	local nLayoutWidth = nLayoutR - nLayoutL
	local nLayoutHeight = nLayoutB - nLayoutT
	
	local workleft, worktop, workright, workbottom = tipUtil:GetWorkArea()
	self:Move( (workright - nLayoutWidth)/2, (workbottom - nLayoutHeight)/2, nLayoutWidth, nLayoutHeight)
	--ani:SetKeyFramePos(0, nLayoutHeight, 0, 0) 
	--objtree:AddAnimation(ani)
	--ani:Resume()

	return true
end

function OnCreate( self )
	 local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local tMain = tFunctionHelper.FetchValueByPath(tUserConfig, {"tWindow", "tMain"})
	if type(tMain) == "table" and type(tMain.nLeft) == "number" and type(tMain.nTop) == "number" and type(tMain.nWidth) == "number" and type(tMain.nHeight) == "number" then
		--写死高和宽
		self:Move(tMain.nLeft, tMain.nTop, 420, 652)
	else	
		PopupInDeskMiddle(self)
	end
end


function OnDestroy( self )
	local objtree = self:GetBindUIObjectTree()
	if objtree ~= nil then
		self:UnbindUIObjectTree()
		local objtreeManager = XLGetObject("Xunlei.UIEngine.TreeManager")
		objtreeManager:DestroyTree(objtree)
	end
	local wndId = self:GetID()
	if wndId ~= nil then
		local hostwndManager = XLGetObject("Xunlei.UIEngine.HostWndManager")
		local tempWnd = hostwndManager:GetHostWnd(wndId)
		if tempWnd then
			hostwndManager:RemoveHostWnd(wndId)
		end
	end
end


