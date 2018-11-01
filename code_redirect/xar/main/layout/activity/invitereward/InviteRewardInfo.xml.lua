local tFunctionHelper = XLGetGlobal("FunctionHelper")
local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")
local tipUtil = XLGetObject("API.Util")
local timeMgr = XLGetObject("Xunlei.UIEngine.TimerManager")

local g_objTree = nil
local g_posChangeAni = nil
local g_NoticeTimerId = nil
--Control
local g_tabDefaultData = {
	{["nickname"] = "*c", ["invite_total"] = 236, ["money"] = 11552568}, 
	{["nickname"] = "*意", ["invite_total"] = 13, ["money"] = 517499}, 
	{["nickname"] = "*8", ["invite_total"] = 25, ["money"] = 6998105}, 
	{["nickname"] = "*は", ["invite_total"] = 121, ["money"] = 9566323}, 
	{["nickname"] = "*走", ["invite_total"] = 6, ["money"] = 725632}, 
	{["nickname"] = "*秀", ["invite_total"] = 307, ["money"] = 32843651}, 
	{["nickname"] = "*甲", ["invite_total"] = 19, ["money"] = 943687}, 
	{["nickname"] = "*使", ["invite_total"] = 156, ["money"] = 8877368}, 
	{["nickname"] = "*檬", ["invite_total"] = 268, ["money"] = 19354366}, 
	{["nickname"] = "*发", ["invite_total"] = 35, ["money"] = 2335787}, 
	{["nickname"] = "*子", ["invite_total"] = 11, ["money"] = 554365}, 
	{["nickname"] = "*！", ["invite_total"] = 5, ["money"] = 217785}, 
	{["nickname"] = "*m", ["invite_total"] = 68, ["money"] = 3857698}, 
	{["nickname"] = "*中", ["invite_total"] = 97, ["money"] = 4473151}, 
	{["nickname"] = "*一", ["invite_total"] = 319, ["money"] = 23943653}, 
	{["nickname"] = "*远", ["invite_total"] = 44, ["money"] = 1843817}, 
	{["nickname"] = "*醉", ["invite_total"] = 67, ["money"] = 2243359}, 
	{["nickname"] = "*s", ["invite_total"] = 173, ["money"] = 7552769}, 
	{["nickname"] = "*杰", ["invite_total"] = 66, ["money"] = 1546227}, 
	{["nickname"] = "*岗", ["invite_total"] = 88, ["money"] = 3773147}, 
}

function IsRealString(str)
	return type(str) == "string" and str ~= ""
end

function NumberToFormatMoney(Num)
	local strFormat = ""
	local strLeft = tostring(Num)
	local nLen = string.len(strLeft)
	while string.len(strLeft) > 3 do
		local strRight = string.sub(strLeft, -3)
		strFormat = strFormat .. "," .. tostring(strRight)
		strLeft = string.sub(strLeft, 0, -4)
	end
	strFormat = strLeft .. tostring(strFormat)
	return strFormat
end


function SetText(self, tabText)
	local tabTextLen = {}
	local nFLeft, nFTop, nFRight, nFBottom = self:GetObjPos()
	local nFWidth = nFRight - nFLeft
	local nFHeight = nFBottom - nFTop
	local nTotalLen = 0
	for Idx=1, #tabText do
		local strText = tabText[Idx]
		local objText = self:GetControlObject("TextJoin.Text" .. tostring(Idx))
		objText:SetObjPos2(0, 0, nFWidth, nFHeight)
		objText:SetText(strText)
		local nLen = objText:GetTextExtent()
		objText:SetObjPos(0, 0, nLen, nFHeight)
		tabTextLen[#tabTextLen+1] = nLen
		nTotalLen = nTotalLen + nLen
	end
	
	local nStart = (nFWidth-nTotalLen)/2
	for Idx=1, #tabTextLen do
		local objText = self:GetControlObject("TextJoin.Text" .. tostring(Idx))
		objText:SetObjPos2(nStart, 0, tabTextLen[Idx], nFHeight)
		nStart = nStart+tabTextLen[Idx]
	end
end
--

function OnNoticeAniFinish(obj)
	
end

function UpdateNoticeData(tabData)
	if g_posChangeAni ~= nil then
		g_posChangeAni:Stop()
		g_posChangeAni = nil
	end
	if g_NoticeTimerId then
		timeMgr:KillTimer(g_NoticeTimerId)
		g_NoticeTimerId = nil
	end
	local objNoticeChild = g_objTree:GetUIObject("InviteRewardInfo.Page1.Notice.Child") 
	local objTop = g_objTree:GetUIObject("Notice.Child.Top") 
	local objButtom = g_objTree:GetUIObject("Notice.Child.Buttom") 
	
	local objNotice = g_objTree:GetUIObject("InviteRewardInfo.Page1.Notice") 
	local nFLeft, nFTop, nFRight, nFBottom = objNotice:GetObjPos()
	local startLeft, startTop, startRight, startBottom = 0, 0, (nFRight-nFLeft), (nFBottom-nFTop)*2
	local nTopIdx = 1
	local nButtomIdx = nTopIdx+1
	if nButtomIdx > #tabData then
		nButtomIdx = 1
	end
	objTop:SetText({"恭喜", tostring(tabData[nTopIdx]["nickname"]), "邀请", tostring(tabData[nTopIdx]["invite_total"]), "人，获得", tostring(NumberToFormatMoney(tabData[nTopIdx]["money"])), "元宝赏金"})
	objButtom:SetText({"恭喜", tostring(tabData[nButtomIdx]["nickname"]), "邀请", tostring(tabData[nButtomIdx]["invite_total"]), "人，获得", tostring(NumberToFormatMoney(tabData[nButtomIdx]["money"])), "元宝赏金"})
	
	local function OnAniFinish(obj)
		nTopIdx = nTopIdx+1
		if nTopIdx > #tabData then
			nTopIdx = 1
		end
		nButtomIdx = nTopIdx+1
		if nButtomIdx > #tabData then
			nButtomIdx = 1
		end
		objTop:SetText({"恭喜", tostring(tabData[nTopIdx]["nickname"]), "邀请", tostring(tabData[nTopIdx]["invite_total"]), "人，获得", tostring(NumberToFormatMoney(tabData[nTopIdx]["money"])), "元宝赏金"})
		objButtom:SetText({"恭喜", tostring(tabData[nButtomIdx]["nickname"]), "邀请", tostring(tabData[nButtomIdx]["invite_total"]), "人，获得", tostring(NumberToFormatMoney(tabData[nButtomIdx]["money"])), "元宝赏金"})
		if g_NoticeTimerId then
			timeMgr:KillTimer(g_NoticeTimerId)
			g_NoticeTimerId = nil
		end
		g_NoticeTimerId = SetOnceTimer(function(item, id)
			g_posChangeAni = nil
			g_posChangeAni = Helper.Ani:RunPosChangeAni(objNoticeChild, startLeft, startTop, startRight, startBottom, startLeft, startTop-16-2, startRight, startBottom-16-2, OnAniFinish(obj), 500)
		end, 2000)
	end
	g_posChangeAni = Helper.Ani:RunPosChangeAni(objNoticeChild, startLeft, startTop, startRight, startBottom, startLeft, startTop-16-2, startRight, startBottom-16-2, OnAniFinish(objNoticeChild), 500)
end

function UpdateCopyData()
	local tUserConfig = WorkModuleHelper:GetUserConfig()
	local strInviteCode = tFunctionHelper.FetchValueByPath(tUserConfig, {"tUserInfo", "strInviteCode"})
	
	
	local objText2Left = g_objTree:GetUIObject("CopyData.Text2.left") 
	local nLeft, nTop, nRight, nBottom = objText2Left:GetObjPos()
	local nHeight = nBottom - nTop
	local nStart = nLeft
	
	objText2Left:SetText("了好几十块；用")
	local nLen = objText2Left:GetTextExtent()
	objText2Left:SetObjPos2(nStart, nTop, nLen, nHeight)
	nStart = nStart + nLen+3
	
	local objText2Center = g_objTree:GetUIObject("CopyData.Text2.center")
	strInviteCode = "邀请码" .. tostring(strInviteCode)
	objText2Center:SetText(tostring(strInviteCode))
	nLen = objText2Center:GetTextExtent()
	objText2Center:SetObjPos2(nStart+3, nTop, nLen, nHeight)
	local objText2CenterBkg = g_objTree:GetUIObject("InviteRewardInfo.Text2.center.Bkg")
	objText2CenterBkg:SetObjPos2(nStart, nTop-1, nLen+6, 19)
	nStart = nStart + nLen+6 + 3
	
	local objText2Right = g_objTree:GetUIObject("CopyData.Text2.right")
	objText2Right:SetText("，还有额外惊喜~你也快试试！")
	nLen = objText2Right:GetTextExtent()
	objText2Right:SetObjPos2(nStart, nTop, nLen, nHeight)
		
	local objText3 = g_objTree:GetUIObject("CopyData.Text3")
	local strLink = "http://share4money.cn/?c=" .. tostring(strInviteCode)
	objText3:SetText(strLink)
end

function OnClickPreviousPage(self)
	local objPage2 = g_objTree:GetUIObject("InviteRewardInfo.Page2")
	objPage2:SetVisible(false)
	objPage2:SetChildrenVisible(false)
	
	local objPage1 = g_objTree:GetUIObject("InviteRewardInfo.Page1")
	objPage1:SetVisible(true)
	objPage1:SetChildrenVisible(true)
end

function OnClickNextPage(self)
	local objPage1 = g_objTree:GetUIObject("InviteRewardInfo.Page1")
	objPage1:SetVisible(false)
	objPage1:SetChildrenVisible(false)
	
	local objPage2 = g_objTree:GetUIObject("InviteRewardInfo.Page2")
	objPage2:SetVisible(true)
	objPage2:SetChildrenVisible(true)
end

local g_TipDestroyTimerId = nil
function OnClickCopyBtn(self)
	local objText1 = g_objTree:GetUIObject("CopyData.Text1")
	local strInfo = objText1:GetText()
	
	local objText2Left = g_objTree:GetUIObject("CopyData.Text2.left")
	local objText2Center = g_objTree:GetUIObject("CopyData.Text2.center")
	local objText2Right = g_objTree:GetUIObject("CopyData.Text2.right")
	strInfo = strInfo .. "\r\n" .. objText2Left:GetText() .. objText2Center:GetText() .. objText2Right:GetText()
	
	local objText3 = g_objTree:GetUIObject("CopyData.Text3")
	strInfo = strInfo .."\r\n" .. objText3:GetText()
	
	tipUtil:CopyTextToClipboard(strInfo)
	local objCopySuccess = g_objTree:GetUIObject("InviteRewardInfo.CopySuccess")
	local objTip = g_objTree:GetUIObject("InviteRewardInfo.CopySuccess.Tip")
	if g_TipDestroyTimerId then
		timeMgr:KillTimer(g_TipDestroyTimerId)
		g_TipDestroyTimerId = nil
	end
	if objTip then
		objCopySuccess:RemoveChild(objTip)
	end
	objTip = objFactory:CreateUIObject("InviteRewardInfo.CopySuccess.Tip", "InviteRewardTipObject")
	objCopySuccess:AddChild(objTip)
	objTip:SetObjPos2(0, 0, "father.width", "father.height")
	
	g_TipDestroyTimerId = SetOnceTimer(function(item, id)
		objCopySuccess:RemoveChild(objTip)
	end, 10000)
	
	local tStatInfo = {}
	tStatInfo.fu1 = "invotecode"	
	tStatInfo.fu5 = "copyinviteinfo"
	StatisticClient:SendClickReport(tStatInfo)
end

function OnClickClose(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:EndDialog(0)
end

function OnCreate(self)
	local userData = self:GetUserData()
	if userData and userData.parentWnd then
		local objTree = self:GetBindUIObjectTree()
		g_objTree = objTree
		local objContent = objTree:GetUIObject("InviteRewardInfo.Content")
		local nContentL, nContentT, nContentR, nContentB = objContent:GetObjPos()
		local nContentWidth  = nContentR - nContentL
		local nContentHeight = nContentB - nContentT
	
		local parentLeft, parentTop, parentRight, parentBottom = userData.parentWnd:GetWindowRect()
		local parentWidth  = parentRight - parentLeft
		local parentHeight = parentBottom - parentTop
		self:Move( parentLeft + (parentWidth - nContentWidth)/2, parentTop + (parentHeight - nContentHeight)/2, nContentWidth, nContentHeight)
		
	end
end

function LoadNoticeData()
	InviteReward:GetInviteNoticeInfo(function(tabData)
		if type(tabData["rewards"]) ~= "table" then
			return
		end
		local tabRewards = tabData["rewards"]
		for i=1, #tabRewards do
			if type(tabRewards[i]) == "table" 
				and IsRealString(tabRewards[i]["nickname"])
				and type(tabRewards[i]["invite_total"]) == "number"
				and type(tabRewards[i]["money"]) == "number" then
				for j=1, #g_tabDefaultData do
					if	g_tabDefaultData[j]["money"] < tabRewards[i]["money"] then
						g_tabDefaultData[j]["nickname"] = tabRewards[i]["nickname"]
						g_tabDefaultData[j]["invite_total"] = tabRewards[i]["invite_total"]
						g_tabDefaultData[j]["money"] = tabRewards[i]["money"]
					end	
					
				end
			end	
		end	
		UpdateNoticeData(g_tabDefaultData)
	end)
end

function OnShowWindow(self, bShow)
	local objTree = self:GetBindUIObjectTree()
	if bShow then 
		local objPage2 = objTree:GetUIObject("InviteRewardInfo.Page2")
		objPage2:SetVisible(false)
		objPage2:SetChildrenVisible(false)
		UpdateNoticeData(g_tabDefaultData)
		UpdateCopyData()
		LoadNoticeData()
	end	
end

function OnDestroy( self )
	if g_posChangeAni ~= nil then
		g_posChangeAni:Stop()
		g_posChangeAni = nil
	end
	if g_NoticeTimerId then
		timeMgr:KillTimer(g_NoticeTimerId)
		g_NoticeTimerId = nil
	end
	if g_TipDestroyTimerId then
		timeMgr:KillTimer(g_TipDestroyTimerId)
		g_TipDestroyTimerId = nil
	end
end


