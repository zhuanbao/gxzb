local tFunctionHelper = XLGetGlobal("FunctionHelper")
local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")
local g_objTree = nil
local g_nShowIdx = nil

function OnMouseEnter(self)
	local objBtnHover = self:GetObject("BtnHover")
	if not objBtnHover then
		objBtnHover = objFactory:CreateUIObject("BtnHover", "ImageObject")
		self:AddChild(objBtnHover)
		objBtnHover:SetObjPos(-5, -9, 20, -6)
		objBtnHover:SetResID("GXZB.PopUpWnd.Btn.Hover")
	end
	objBtnHover:SetVisible(true)
end

function OnMouseLeave(self)
	local objBtnHover = self:GetObject("BtnHover")
	if objBtnHover then
		objBtnHover:SetVisible(false)
	end
end

function OnClickClose(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:EndDialog(0)
end

function ShowDescByIdx(nShowIdx)
	g_nShowIdx = nShowIdx
	for Idx=1, 5 do
		local strDescId = "InviteCodeBindWnd.Desc" .. tostring(Idx)
		local bShow = false
		if nShowIdx == Idx then
			bShow = true
		end
		local objDesc = g_objTree:GetUIObject(strDescId)	
		objDesc:SetVisible(bShow)
		objDesc:SetChildrenVisible(bShow)
	end
	local objBtn = g_objTree:GetUIObject("InviteCodeBindWnd.Btn")
	if nShowIdx == 2 then
		objBtn:Show(false)
	else
		objBtn:Show(true)
	end
	if nShowIdx == 3 or  nShowIdx == 4 then
		objBtn:SetText("去邀请")
	else
		objBtn:SetText("确定")
	end
	if nShowIdx == 1 or nShowIdx == 5 then
		objBtn:Enable(false)
	else
		objBtn:Enable(true)
	end
end

--编辑框
function OnEditFocusChange(self, bFocus)
	local objBtn = g_objTree:GetUIObject("InviteCodeBindWnd.Btn")
	local strText = self:GetText()
	local bBtnEnable = false
	local strID = self:GetID()
	local strTipText = "填写邀请码"
	if "InviteCodeBindWnd.Desc1.Edit.Input" == strID then
		strTipText = "在此填写邀请码"
	end
	if bFocus then
		if not Helper:IsRealString(strText) or strText == strTipText then
			self:SetText("")
		else
			 bBtnEnable = true
		end	
		self:SetTextColorID("555555")
	else
		local strText = self:GetText()
		if Helper:IsRealString(strText) and strText ~= strTipText then
			bBtnEnable = true
		else
			self:SetText(strTipText)
			self:SetTextColorID("BCB9B5")
		end	
	end
	objBtn:Enable(bBtnEnable)
end

function OnEditChange(self)
	local objBtn = g_objTree:GetUIObject("InviteCodeBindWnd.Btn")
	local bBtnEnable = false
	local strText = self:GetText()
	local strTipText = "填写邀请码"
	if "InviteCodeBindWnd.Desc1.Edit.Input" == strID then
		strTipText = "在此填写邀请码"
	end
	
	if Helper:IsRealString(strText) and strText ~= strTipText then
		bBtnEnable = true
	end	
	objBtn:Enable(bBtnEnable)
	return 0, true, false
end

function OnEditKeyDown(self, uChar, uRepeatCount, uFlags)
	return 0, true, false
end

function OnClickBtn(self)
	if g_nShowIdx == 3 or g_nShowIdx == 4 then
		local objHostWnd = g_objTree:GetBindHostWnd()
		objHostWnd:EndDialog(0)
		
		local tStatInfo = {}
		tStatInfo.fu1 = "invotecode"
		tStatInfo.fu5 = "showinvotereward"
		tStatInfo.fu6 = "bindwnd"
		tStatInfo.fu7 = g_nShowIdx
		StatisticClient:SendClickReport(tStatInfo)
	
		local objMainWnd = Helper.hostWndManager:GetHostWnd("GXZB.MainWnd")
		objMainWnd:Show(1)
		Helper:CreateModalWnd("GXZB.InviteRewardInfo", "GXZB.InviteRewardInfoTree", objMainWnd:GetWndHandle(), {["parentWnd"] = objMainWnd})
	else
		local strInputID = "InviteCodeBindWnd.Desc1.Edit.Input"
		if g_nShowIdx == 5 then
			strInputID = "InviteCodeBindWnd.Desc5.Edit.Input"
		end
		
		local objProgress = g_objTree:GetUIObject("InviteCodeBindWnd.Checking.Progress")
		local nProgressL, nProgressT, nProgressR, nProgressB = objProgress:GetObjPos()
		local nFullLen = nProgressR - nProgressL
		local objCompleting = g_objTree:GetUIObject("InviteCodeBindWnd.Checking.Progress.Completing")
		objCompleting:SetObjPos(0, 0, nFullLen*0.5, 10)
		ShowDescByIdx(2)
		local objInput = g_objTree:GetUIObject(strInputID)
		local strCode = objInput:GetText()
		--[[
			errCode	
				0            成功
				1            邀请码错误
				2            已经被绑定
				3            绑定失败(超过一个月老用户或者自己绑定自己)
		--]]
		CodeBind:QuerySvrForBindInviterCode(strCode, function(tabData)
			if type(tabData) ~="table" then
				ShowDescByIdx(5)
				return
			end
			if tabData["errCode"] == 0 then
				ShowDescByIdx(3)
			elseif tabData["errCode"] == 2 then
				local objText = g_objTree:GetUIObject("InviteCodeBindWnd.Desc4.Text1")
				objText:SetText("很抱歉，此设备已被其他用户绑定过,\r\n绑定更多新设备或邀请好友都可享受推广\r\n奖励哦~")
				ShowDescByIdx(4)
			else
				ShowDescByIdx(5)
			end
		end)
	end
end

function OnCreate(self)
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	local userData = self:GetUserData()
	if userData and userData.parentWnd then
		local objTree = self:GetBindUIObjectTree()
		g_objTree = objTree
		local objRootLayout = objTree:GetUIObject("InviteCodeBindWnd.Content")
		local nLayoutL, nLayoutT, nLayoutR, nLayoutB = objRootLayout:GetObjPos()
		local nLayoutWidth  = nLayoutR - nLayoutL
		local nLayoutHeight = nLayoutB - nLayoutT
	
		local parentLeft, parentTop, parentRight, parentBottom = userData.parentWnd:GetWindowRect()
		local parentWidth  = parentRight - parentLeft
		local parentHeight = parentBottom - parentTop
		self:Move( parentLeft + (parentWidth - nLayoutWidth)/2, parentTop + (parentHeight - nLayoutHeight)/2, nLayoutWidth, nLayoutHeight)
		local tabData = userData.inviter
		
		if tabData["can_be_invited"] == 0 and tabData["has_addition"] == 1 and tabData["is_new_device"] == 1 then
			ShowDescByIdx(3)
		elseif tabData["can_be_invited"] == 0 and tabData["has_addition"] == 1 and tabData["is_new_device"] == 0 then
			ShowDescByIdx(4)
		else
			ShowDescByIdx(1)
		end	
	end
end
