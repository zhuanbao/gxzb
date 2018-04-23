local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("FunctionHelper")
local timerManager = XLGetObject("Xunlei.UIEngine.TimerManager")

local gOwnerCtrl = nil
local gCookie = nil
local gAutoPosTimerId = nil

function IsRealString(AString)
    return type(AString) == "string" and AString ~= ""
end

function SaveLastShowUTC()
	local tUserConfig = tFunctionHelper.ReadConfigFromMemByKey("tUserConfig") or {}
	tUserConfig["tConfig"] = tUserConfig["tConfig"] or {}
	tUserConfig["tConfig"]["tUserIntroduce"] = tUserConfig["tConfig"]["tUserIntroduce"] or {}
	tUserConfig["tConfig"]["tUserIntroduce"]["nLastShowTime"] = tFunctionHelper.GetCurrentServerTime()
	tFunctionHelper.SaveConfigToFileByKey("tUserConfig")
end

function FinishUserIntroduce()	
	StopPosNextPage()
	if gCookie then
		local wndMain = UIInterface:GetMainHostWnd()
		wndMain:RemoveListener("OnShowWindow", gCookie)
		gCookie = nil
	end	
	UIInterface:RemoveUserIntroduce()
end

function OnClickSkip(self)
	FinishUserIntroduce()
end

function OnClickStart(self)
	FinishUserIntroduce()
	if not ClientWorkModule:CheckIsWorking() then
		ClientWorkModule:NotifyStart()
	end
	local tStatInfo = {}
	tStatInfo.fu1 = "startworking"
	tStatInfo.fu5 = "userintroduce"
	StatisticClient:SendClickReport(tStatInfo)
end

function OnClickLeftPage(self)
	local OwnerAttr = gOwnerCtrl:GetAttribute()
	local nIdx = OwnerAttr.nCurPage
	if nIdx > 1 then
		ShowPage(nIdx-1)
	end
end

function OnClickRightPage(self)
	local OwnerAttr = gOwnerCtrl:GetAttribute()
	local nIdx = OwnerAttr.nCurPage
	if nIdx < 4 then
		ShowPage(nIdx+1)
	end
end

function OnClickPos(self)
	local strID = self:GetID()
	local _, _, strIdx = string.find(strID, "UserIntroduce.Position.Bnt(%d)")
	ShowPage(tonumber(strIdx))
end

function OnLButtonUpOpenPacket(self, x, y)
	FinishUserIntroduce()
	UIInterface:ChangeMainBodyPanel("QRCodePanel")
	local tStatInfo = {}
	tStatInfo.fu1 = "showpanel"
	tStatInfo.fu5 = "qrcode"
	tStatInfo.fu6 = "userintroduce"
	StatisticClient:SendClickReport(tStatInfo)
end

function OnMouseMoveOpenPacket(self, x, y)

end

function OnMouseLeaveOpenPacket(self)

end

function OnInitControl(self)
	gOwnerCtrl = self
	ShowPage(1)
	local wndMain = UIInterface:GetMainHostWnd()
	if not wndMain:GetVisible() then
		StopPosNextPage()
	else
		StatisticClient:SendOnceReport("event", "showuserintroduce", function()
            local tStatInfo = {}
		    tStatInfo.fu1 = "showuserintroduce"
            StatisticClient:SendEventReport(tStatInfo)
        end)
		SaveLastShowUTC()
	end	
	local wndMain = UIInterface:GetMainHostWnd()
	gCookie = wndMain:AttachListener("OnShowWindow", false, function(wnd, bShow)
		if bShow then
			StartPosNextPage()
			StatisticClient:SendOnceReport("event", "showuserintroduce", function()
				local tStatInfo = {}
				tStatInfo.fu1 = "showuserintroduce"
				StatisticClient:SendEventReport(tStatInfo)
			end)
			SaveLastShowUTC()
		else
			StopPosNextPage()
		end
	end)
end

function OnMouseMove(self, x, y)
   
end

function OnMouseLeave(self)
	
end

function OnMouseHover( self, x, y )

end

function ShowPage(nIdx)
	local strID = "UserIntroduce.Page"
	for i=1, 4 do
		local ObjPage = gOwnerCtrl:GetControlObject(strID .. tostring(i))
		local bShow = false
		local strBtnBkgID = "GXZB.UserIntroduce.PagePos.unselect"
		if nIdx == i then
			bShow = true
			strBtnBkgID = "GXZB.UserIntroduce.PagePos.select"
		end
		local ObjBtn = gOwnerCtrl:GetControlObject("UserIntroduce.Position.Bnt" .. tostring(i))
		local ObjBtnAttr = ObjBtn:GetAttribute()
		ObjBtnAttr.NormalBkgID = strBtnBkgID
		ObjBtnAttr.DownBkgID = strBtnBkgID
		ObjBtnAttr.HoverBkgID = strBtnBkgID
		ObjBtnAttr.DisableBkgID = strBtnBkgID
		ObjBtn:Updata()
			
		ObjPage:SetChildrenVisible(bShow)
		ObjPage:SetVisible(bShow)
	end
	local OwnerAttr = gOwnerCtrl:GetAttribute()
	OwnerAttr.nCurPage = nIdx
	
	local ObjLeftBtn = gOwnerCtrl:GetControlObject("UserIntroduce.LeftBtn")
	if nIdx == 1 then
		ObjLeftBtn:Show(false)
	else
		ObjLeftBtn:Show(true)
	end
	
	local ObjRightBtn = gOwnerCtrl:GetControlObject("UserIntroduce.RightBtn")
	if nIdx == 4 then
		ObjRightBtn:Show(false)
		OwnerAttr.bFinishAutoPosPage = true
	else
		ObjRightBtn:Show(true)
		StartPosNextPage()
	end
end

function StartPosNextPage()
	StopPosNextPage()
	local OwnerAttr = gOwnerCtrl:GetAttribute()
	if OwnerAttr.bFinishAutoPosPage then
		return
	end
	gAutoPosTimerId = timerManager:SetOnceTimer(function () 
		local nIdx = OwnerAttr.nCurPage
		if nIdx < 4 then
			ShowPage(nIdx+1)
		end 
	end, 3000)
end

function StopPosNextPage()
	if gAutoPosTimerId ~= nil then
		timerManager:KillTimer(gAutoPosTimerId)
		gAutoPosTimerId = nil
	end
end