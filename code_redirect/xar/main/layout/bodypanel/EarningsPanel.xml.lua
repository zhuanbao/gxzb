local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")

function UpdateUserBalance(self, nBalance)
	local bottomText = self:GetObject("BottomTextBalance")
	if bottomText then
		bottomText:SetText(tFunctionHelper.NumberToFormatMoney(nBalance or 0))
		local textHead = self:GetObject("BottomTextHead")
		local textTail = self:GetObject("BottomTextTail")
		local fater = self:GetObject("BottomLayout")
		local l, t, r, b = fater:GetObjPos()
		local w, h = r - l, b - t
		--处是给一个较大的宽度
		w = 200
		local nLenHead = textHead:GetTextExtent()
		local nLenTail = textTail:GetTextExtent()
		local nLenBalance = bottomText:GetTextExtent()
		local gap = 1
		local nMax = w - (nLenHead + gap + nLenTail + gap) 
		if nLenBalance > nMax then
			nLenBalance = nMax
		end
		local nNewLeft = 0
		textHead:SetObjPos(nNewLeft, 0, nNewLeft+nLenHead, h)
		bottomText:SetObjPos(nNewLeft + (nLenHead + gap), 0, nNewLeft + (nLenHead + gap) + nLenBalance, h)
		textTail:SetObjPos(nNewLeft + (nLenHead + gap) + (nLenBalance + gap), 0, nNewLeft + (nLenHead + gap) + (nLenBalance + gap) + nLenTail, h)
		local totalLen = nNewLeft + (nLenHead + gap) + (nLenBalance + gap) + nLenTail + 4
		fater:SetObjPos("(father.width-"..totalLen..")/2", "father.height + 20", "father.width/2+"..totalLen.."/2", "father.height + 40")
	end
end

--相当于强制刷新
function UpdateClientUnBindState(self)
	local attr = self:GetAttribute()
	local reqID = "h24"
	if attr.currentpanel == 2 then
		reqID = "d30"
	end
	tFunctionHelper.GetHistoryToServer(reqID, function(bRet, tabInfo)
			attr.Data = tabInfo
			attr.Data["reqFailed"] = not bRet
			attr.Data["balance"] = tFunctionHelper.GetUserCurrentBalance()
			self:Update()
		end)
end

local xylineFailedBitmap24 = nil
local xylineFailedBitmap30 = nil
local tipsFailedBitmap = nil
function BarChartUpdate(self)
	local attr = self:GetAttribute()
	if not attr or type(attr.Data) ~= "table" or #attr.Data == 0 then
		return
	end
	--[[table.sort(attr.Data, function(t1, t2)
		return t1[1] < t2[1]
	end)]]
	--更新余额
	UpdateUserBalance(self, attr.Data["balance"])
	local barchartpanel = self:GetObject("barchartpanel")
	barchartpanel:RemoveAllChild()
	local ymax = 0
	for _, dat in ipairs(attr.Data) do
		if type(dat) == "table" then
			if type(dat[2]) == "number" and ymax < dat[2] then
				ymax = dat[2]
			end
		end
	end
	--收益界面，纵向坐标刻度，建议分为10格
	--满格大小建议为10、5、2打头、后跟若干0的整数
	local ymaxBit = string.len(tostring(ymax))
	local ymaxBase = math.pow(10, ymaxBit-1)
	if ymax <= ymaxBase*2 then
		ymax = ymaxBase*2
	elseif ymax <= ymaxBase*5 then
		ymax = ymaxBase*5
	else
		ymax = ymaxBase*10
	end
	--显示10个刻度
	local minYnumber = 10
	if ymax < minYnumber then
		ymax = minYnumber
	end
	
	local l, t, r, b = barchartpanel:GetObjPos()
	local coorXWidth, coorYWidth = 1, 7
	--减去横纵坐标的宽度
	local w, h = r - l - coorYWidth, b - t - coorXWidth
	local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")
	
	--初始化一些颜色配置
	attr.FailedColor = "999999"
	attr.FailedHoverColor = "666666"
	if attr.currentpanel == 1 then
		attr.ColumnColorSrc = "FFDD92"
		attr.ColumnColorSrcHover = "EEB93B"
		attr.LineColor = "CDA140"
		attr.TipRes = "charttips-bkg"
	else
		attr.ColumnColorSrc = "FFC08D"
		attr.ColumnColorSrcHover = "FF7B39"
		attr.LineColor = "C57046"
		attr.TipRes = "charttips-bkg-day"
	end
	--坐标轴变色
	if attr.Data["reqFailed"] then
		--[[
		local xyLineBkg = self:GetObject("xyLineBkg")
		local xgp = XLGetObject("Xunlei.XLGraphic.Factory.Object")
		local clor = xgp:CreateColor(51, 51, 51, 255)
		local h, s, l = clor:ToHSL()
		if attr.currentpanel == 1 then
			if not xylineFailedBitmap24 then
				xylineFailedBitmap24 = xyLineBkg:GetBitmap():Clone()
				xylineFailedBitmap24:ModifyColor(h, s, l, 0)
			end
			xyLineBkg:SetBitmap(xylineFailedBitmap24)
		else
			if not xylineFailedBitmap30 then
				xylineFailedBitmap30 = xyLineBkg:GetBitmap():Clone()
				xylineFailedBitmap30:ModifyColor(h, s, l, 0)
			end
			xyLineBkg:SetBitmap(xylineFailedBitmap30)
		end
		--]]
	end
	local function GetNewTextObj(strText, valign, halign)
		local newTextObject = objFactory:CreateUIObject("", "TextObject")
		newTextObject:SetText(strText)
		barchartpanel:AddChild(newTextObject)
		newTextObject:SetVAlign(valign or "center")
		newTextObject:SetHAlign(halign or "center")
		--newTextObject:SetTextColorResID(attr.Data["reqFailed"] and attr.FailedColor or attr.LineColor)
		newTextObject:SetTextColorResID(attr.LineColor)
		newTextObject:SetTextFont("font.text12")
		return newTextObject, newTextObject:GetTextExtent()
	end
	--显示纵坐标刻度
	for i = 1, minYnumber do
		local ytmp = h*i/minYnumber
		local yreal = h - ytmp
		local newTextObject, needWidth = GetNewTextObj(tostring(math.floor(ymax*i/minYnumber)), "center", "right")
		newTextObject:SetObjPos(-needWidth-17, yreal-6, -7, yreal+6)
	end
	--显示单位
	local newTextObject = GetNewTextObj(attr.currentpanel == 1 and "每小时元宝产量(个)" or "每天元宝产量(个)", nil, "left")
	newTextObject:SetObjPos(-8, -18, 110, -4)
	--newTextObject = GetNewTextObj(attr.currentpanel == 1 and "h" or "date")
	--newTextObject:SetObjPos("father.width+3", "father.height-12", attr.currentpanel == 1 and "father.width+13" or "father.width+26", "father.height+1")
	--间隔宽度是柱子的1/3
	local itemw = w/(#attr.Data*4-1)
	if itemw < 2 then
		itemw = 2
	end
	
	--显示横坐标刻度
	function Drawxline(xreal, text)
		local newTextObject = GetNewTextObj(tostring(text), "top")
		newTextObject:SetObjPos(xreal-25, h+8, xreal+25, h+21)
	end
	--将数据转换为坐标系中的点
	local function ConvertData2Point(xindex, ydata)
		--local xreal = (#attr.Data == 1 and 0 or w*(xindex-1)/(#attr.Data)) + 2
		local xreal = (#attr.Data == 1 and 0 or (xindex-1)*(itemw*4)) + coorYWidth 
		local yreal = h-2
		if ydata > 0 then
			yreal = h - h*ydata/ymax
		end
		if yreal > h-2 then
			yreal = h-2
		end
		return math.floor(xreal), math.floor(yreal)
	end
	
	local xstart=0
	local function DrawBar()
		for i, dat in ipairs(attr.Data) do
			if type(dat) == "table" and i <= #attr.Data and type(dat[2]) == "number" then
				local newFillObject = objFactory:CreateUIObject("", "FillObject")
				barchartpanel:AddChild(newFillObject)
				local xsrc, ysrc = ConvertData2Point(i, dat[2])
				local l, t, r, b = xsrc, ysrc, xsrc+itemw*3, h
				--if #attr.Data == i then
				--	r = w + coorYWidth
				--end
				if t == b then
					t = b - 1
				end
				if i == 1 or i == #attr.Data/2 or i == #attr.Data  then
					xstart = xsrc + itemw*3/2
					Drawxline(xstart, attr.Data[i][1])
				end
				local normalColor = attr.Data["reqFailed"] and attr.FailedColor or attr.ColumnColorSrc
				newFillObject:SetSrcColor(normalColor)
				newFillObject:SetDestColor(normalColor)
				newFillObject:SetSrcPt(0, 0)
				newFillObject:SetDestPt(r-l, b-t)
				newFillObject:SetObjPos(l, t, r, b)
				local function event_mousenter(self, x, y)
					local tips = barchartpanel:GetObject("tips")
					if not tips then
						tips = objFactory:CreateUIObject("tips", "BarChartTips")
						barchartpanel:AddChild(tips)
						tips:SetZorder(100000)
						tips:GetObject("bkg"):SetResID(attr.TipRes)
						--tip变色
						if attr.Data["reqFailed"] then
							local xgp = XLGetObject("Xunlei.XLGraphic.Factory.Object")
							local clor = xgp:CreateColor(102, 102, 102, 255)
							local h, s, l = clor:ToHSL()
							if not tipsFailedBitmap then
								tipsFailedBitmap = tips:GetObject("bkg"):GetBitmap():Clone()
								tipsFailedBitmap:ModifyColor(h, s, l, 0)
							end
							tips:GetObject("bkg"):SetBitmap(tipsFailedBitmap)
						end
					end
					tips:SetText(""..dat[2].."个\n"..dat[1])
					local scal = 1-dat[2]/ymax
					if scal <= 0.4 then
						scal = 0.4
					elseif scal >= 0.8 then
						scal = 0.8
					end
					--不做自适应填充色
					--local fa = XLGetObject("Xunlei.XLGraphic.Factory.Object")
					--local cl = attr.Data["reqFailed"] and fa:CreateColor(scal*255, scal*255, scal*255, 255) or fa:CreateColor(0, 0, scal*255, 255)
					--newFillObject:SetSrcColor(cl)
					--newFillObject:SetDestColor(cl)
					--tips:ChangeColor(cl)
					local hoverColor = attr.Data["reqFailed"] and attr.FailedHoverColor or attr.ColumnColorSrcHover
					newFillObject:SetSrcColor(hoverColor)
					newFillObject:SetDestColor(hoverColor)
					tips:SetObjPos(l + itemw - 35, t - 55, l + itemw + 36, t-1)
					tips:SetVisible(true)
					tips:SetChildrenVisible(true)
				end
				local function event_mouseleave(self)
					newFillObject:SetSrcColor(normalColor)
					newFillObject:SetDestColor(normalColor)
					local tips = barchartpanel:GetObject("tips")
					if tips then
						tips:SetVisible(false)
						tips:SetChildrenVisible(false)
					end
				end
				newFillObject:AttachListener("OnMouseEnter", false, event_mousenter)		
				newFillObject:AttachListener("OnMouseLeave", false, event_mouseleave)
				
				--收益界面，柱子较短时，鼠标hover较高位置时，也应显示hover状态；
				if dat[2] < ymax then
					local blankL, blankT, blamkR, blankB = l, 0, r, t
					local newBlankObject = objFactory:CreateUIObject("", "LayoutObject")
					barchartpanel:AddChild(newBlankObject)
					newBlankObject:SetObjPos(blankL, blankT, blamkR, blankB)
					newBlankObject:AttachListener("OnMouseEnter", false, 
					function(self, x, y)
						event_mousenter(newFillObject, x, y)
					end)
					newBlankObject:AttachListener("OnMouseLeave", false, event_mouseleave)
				end
				--newFillObject:SetFillType("Line")
			end
		end
	end
	DrawBar()
end

function ChangeColor(self, cl)
	local image = self:GetObject("bkg")
	if image and cl then
		local bitmap = image:GetBitmap()
		bitmap:Fill(cl)
		image:SetBitmap(bitmap)
	end
end

function SetText(self, text)
	local _, _, strTop, strBottom = string.find(text, "(%S+)\n(%S+)")
	if not strTop or not strBottom then
		return
	end
	local textobj = self:GetObject("texttop")
	if textobj then
		textobj:SetText(strTop)
	end
	textobj = self:GetObject("textbottom")
	if textobj then
		textobj:SetText(strBottom)
	end
end

function OnVisibleChange(self, bVisible)
	if not bVisible then return end
	local barobj = self:GetObject("EarningsPanel.BarChart")
	UpdateUserBalance(barobj, 0)
	local attr = barobj:GetAttribute()
	attr.currentpanel = nil --初始化面板标记，使得点击按钮可以重新去请求数据
	local btn = self:GetObject("EarningsPanel.HourBtn")
	if btn then
		btn:FireExtEvent("OnClick", 0, 0)
	end
end

function ChangeBtnState(self, state)
	local otherbtn
	if state == 1 then
		otherbtn = self:GetObject("control:EarningsPanel.DayBtn")
	else
		otherbtn = self:GetObject("control:EarningsPanel.HourBtn")
	end
	local selfattr = self:GetAttribute()
	local otherattr = otherbtn:GetAttribute()
	selfattr.NormalBkgID = "earnings.btnsel"
	selfattr.DownBkgID = "earnings.btnsel"
	selfattr.HoverBkgID = "earnings.btnsel"
	selfattr.DisableBkgID = "earnings.btnsel"
	otherattr.NormalBkgID = "earnings.btnunsel"
	otherattr.DownBkgID = "earnings.btnunsel"
	otherattr.HoverBkgID = "earnings.btnunsel"
	otherattr.DisableBkgID = "earnings.btnunsel"
	self:Updata()
	otherbtn:Updata()
	self:SetTextColor("system.white")
	otherbtn:SetTextColor("B08756")
	local zorder = otherbtn:GetZorder()
	if type(zorder) == "number" then
		self:SetZorder(zorder+1)
	end
end

function OnClickHourBtnBarChart(self)
	local barobj = self:GetObject("control:EarningsPanel.BarChart")
	local attr = barobj:GetAttribute()
	if attr.currentpanel == 1 then
		return
	end
	ChangeBtnState(self, 1)
	barobj:GetObject("xyLineBkg"):SetResID("xyLineBkg24")
	barobj:SetObjPos("(father.width-197)/2 + 5", 89, "(father.width-197)/2 + 5 + 197", 89+246+30)
	attr.currentpanel = 1
	tFunctionHelper.GetHistoryToServer("h24", function(bRet, tabInfo)
		attr.Data = tabInfo
		attr.Data["reqFailed"] = not bRet
		attr.Data["balance"] = tFunctionHelper.GetUserCurrentBalance()
		barobj:Update()
	end)
end

function OnClickDayBtnBarChart(self)
	local barobj = self:GetObject("control:EarningsPanel.BarChart")
	local attr = barobj:GetAttribute()
	if attr.currentpanel == 2 then
		return
	end
	ChangeBtnState(self, 2)
	barobj:GetObject("xyLineBkg"):SetResID("xyLineBkg30")
	barobj:SetObjPos("(father.width-246)/2+4", 89, "(father.width-246)/2 + 4 + 246", 89+246+30)
	attr.currentpanel = 2
	tFunctionHelper.GetHistoryToServer("d30", function(bRet, tabInfo)
		attr.Data = tabInfo
		attr.Data["reqFailed"] = not bRet
		attr.Data["balance"] = tFunctionHelper.GetUserCurrentBalance()
		barobj:Update()
	end)
end