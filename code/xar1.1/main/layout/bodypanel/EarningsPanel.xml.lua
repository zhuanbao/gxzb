local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")

function LineChartUpdate(self, fnConvert)
	local attr = self:GetAttribute()
	if not attr or type(attr.Data) ~= "table" or #attr.Data == 0 then
		return
	end
	table.sort(attr.Data, function(t1, t2)
		return t1[1] < t2[1]
	end)
	local linepanel = self:GetObject("linepanel")
	linepanel:RemoveAllChild()
	local ymax, xmax, xmin = 0, 0, 0
	for _, dat in ipairs(attr.Data) do
		if type(dat) == "table" then
			if type(dat[2]) == "number" and ymax < dat[2] then
				ymax = dat[2]
			end
			if type(dat[1]) == "number" and xmax < dat[1] then
				xmax = dat[1]
			end
			if type(dat[1]) == "number" and xmin == 0 then
				xmin = dat[1]
			end
			if type(dat[1]) == "number" and xmin > dat[1] then
				xmin = dat[1]
			end
		end
	end
	if ymax == 0 or xmax == 0 then
		return
	end
	local l, t, r, b = self:GetObjPos()
	local w, h = r - l, b - t
	local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")
	--显示纵坐标刻度
	--[[for i = 1, #attr.Data do
		if type(attr.Data[i]) == "table" then
			local ytmp = h*i/#attr.Data
			if ytmp <= h then
				local yreal = h - ytmp
				local newTextObject = objFactory:CreateUIObject("", "TextObject")
				newTextObject:SetText(tostring(math.abs(ymax*i/#attr.Data)))
				linepanel:AddChild(newTextObject)
				newTextObject:SetObjPos(-50, yreal-8, 0, yreal+8)
				newTextObject:SetVAlign("center")
				newTextObject:SetHAlign("center")
				newTextObject:SetTextColorResID("system.black")
				newTextObject:SetTextFont("font.text10")
			end
		end
	end]]
	for i = 1, 5 do
		local ytmp = h*i/5
		local yreal = h - ytmp
		local newTextObject = objFactory:CreateUIObject("", "TextObject")
		newTextObject:SetText(tostring(math.floor(ymax*i/5)))
		linepanel:AddChild(newTextObject)
		newTextObject:SetObjPos(-50, yreal-8, 0, yreal+8)
		newTextObject:SetVAlign("center")
		newTextObject:SetHAlign("center")
		newTextObject:SetTextColorResID("system.black")
		newTextObject:SetTextFont("font.text10")
	end
	--显示横坐标刻度
	for i = 1, 3 do
		local xreal = ((i-1)/(3-1))*w
		local newTextObject = objFactory:CreateUIObject("", "TextObject")
		newTextObject:SetText(tostring(i == 1 and xmin or (i == 2 and (xmax-xmin)/2+xmin or xmax)))
		linepanel:AddChild(newTextObject)
		newTextObject:SetObjPos(xreal-25, h+10, xreal+25, h+26)
		newTextObject:SetVAlign("center")
		newTextObject:SetHAlign("center")
		newTextObject:SetTextColorResID("system.black")
		newTextObject:SetTextFont("font.text10")
	end
	--将数据转换为坐标系中的点
	local function ConvertData2Point(xdata, ydata)
		local xreal = w*(xdata-xmin)/(xmax-xmin)
		local yreal = h - h*ydata/ymax
		return math.floor(xreal), math.floor(yreal)
	end
	local function DrawLine()
		for i, dat in ipairs(attr.Data) do
			if type(dat) == "table" and i < #attr.Data and type(dat[1]) == "number" and type(dat[2]) == "number" then
				local newLineObject = objFactory:CreateUIObject("", "LineObject")
				linepanel:AddChild(newLineObject)
				local xsrc, ysrc = ConvertData2Point(dat[1], dat[2])
				local xtar, ytar = ConvertData2Point(attr.Data[i+1][1], attr.Data[i+1][2])
				local l = xsrc > xtar and xtar or xsrc
				local r = xsrc > xtar and xsrc or xtar
				local t = ysrc > ytar and ytar or ysrc
				local b = ysrc > ytar and ysrc or ytar
				if t == b then
					b = t + 1
				end
				local ystart, yend = 0, 0
				if ysrc > ytar then
					ystart = math.abs(ytar-ysrc)
					yend = 0
				else
					ystart = 0
					yend = math.abs(ytar-ysrc)
				end
				
				--XLMessageBox(tostring(xsrc)..", "..tostring(ysrc).."\n"..tostring(xtar)..", "..tostring(ytar).."\n"..tostring(w)..", "..tostring(h).."\n"..tostring(attr.ColumnColor))
				newLineObject:SetLinePenResID("pen.solid")
				newLineObject:SetObjPos(l, t, r, b)
				newLineObject:SetLinePoint(0, ystart, math.abs(xtar-xsrc), yend)
				newLineObject:SetLineColorResID(attr.ColumnColor)
			end
		end
	end
	DrawLine()
end

function OnClickHourBtnLineChart(self)
	local lineobj = self:GetObject("control:LinePanel.LineChart")
	local attr = lineobj:GetAttribute()
	if attr.currentpanel ~= 2 then
		return
	end
	attr.currentpanel = 1
	attr.Data = {{1, 1000}, {2, 1800}, {4, 9000}, {3, 4000}, {6, 5000}, {5, 1200}, {8, 500}, {7, 2100}, {10, 1700}, {9, 2900}, {11, 4800}, {12, 3100}, {13, 400}, {14, 8000}, {15, 1000}, {16, 1800}, {17, 9000}, {18, 4000}, {19, 5000}, {20, 1200}, {21, 500}, {22, 2100}, {23, 1700}, {24, 2900}}
	lineobj:Update()
end

function OnClickDayBtnLineChart(self)
	local lineobj = self:GetObject("control:LinePanel.LineChart")
	local attr = lineobj:GetAttribute()
	if attr.currentpanel == 2 then
		return
	end
	attr.currentpanel = 2
	attr.Data = {{11, 7002}, {12, 3003}, {13, 6580}, {14, 1021}, {15, 9000}}
	lineobj:Update()
end

function OnShowPanel(self, bShow)
	
end



--------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------
----------------------------------------------柱形图部分------------------------------------------------------------
function UpdateUserBalance(self, nBalance)
	local bottomText = self:GetObject("BottomTextBalance")
	if bottomText then
		bottomText:SetText(tostring(nBalance or 0))
		local textHead = self:GetObject("BottomTextHead")
		local textTail = self:GetObject("BottomTextTail")
		local fater = self:GetObject("BottomLayout")
		local l, t, r, b = fater:GetObjPos()
		local w, h = r - l, b - t
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
	end
end

function BarChartUpdate(self, fnConvert)
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
	--最小显示7个刻度
	local minYnumber = 7
	if ymax == 0 then
		ymax = minYnumber
	end
	local l, t, r, b = barchartpanel:GetObjPos()
	local coorWidth = 1
	--减去横纵坐标的宽度
	local w, h = r - l - coorWidth, b - t - coorWidth
	local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")
	
	--初始化一些颜色配置
	attr.FailedColor = "DDDDDD"
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
	
	--显示纵坐标刻度
	for i = 1, minYnumber do
		local ytmp = h*i/minYnumber
		local yreal = h - ytmp
		local newTextObject = objFactory:CreateUIObject("", "TextObject")
		newTextObject:SetText(tostring(math.floor(ymax*i/minYnumber)))
		barchartpanel:AddChild(newTextObject)
		newTextObject:SetObjPos(-50, yreal-6, 0, yreal+6)
		newTextObject:SetVAlign("center")
		newTextObject:SetHAlign("center")
		newTextObject:SetTextColorResID(attr.LineColor)
		newTextObject:SetTextFont("font.text12")
	end
	--间隔宽度是柱子的一半
	local itemw = w/(#attr.Data*3-1)
	if itemw < 2 then
		itemw = 2
	end
	
	--显示横坐标刻度
	function Drawxline(xreal, text)
		local newTextObject = objFactory:CreateUIObject("", "TextObject")
		newTextObject:SetText(tostring(text))
		barchartpanel:AddChild(newTextObject)
		newTextObject:SetObjPos(xreal-25, h+10, xreal+25, h+26)
		newTextObject:SetVAlign("center")
		newTextObject:SetHAlign("center")
		newTextObject:SetTextColorResID(attr.LineColor)
		newTextObject:SetTextFont("font.text12")
	end
	--将数据转换为坐标系中的点
	local function ConvertData2Point(xindex, ydata)
		--local xreal = (#attr.Data == 1 and 0 or w*(xindex-1)/(#attr.Data)) + 2
		local xreal = (#attr.Data == 1 and 0 or (xindex-1)*(itemw*3)) + coorWidth 
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
			if type(dat) == "table" and i <= #attr.Data and type(dat[1]) == "number" and type(dat[2]) == "number" then
				local newFillObject = objFactory:CreateUIObject("", "FillObject")
				barchartpanel:AddChild(newFillObject)
				local xsrc, ysrc = ConvertData2Point(i, dat[2])
				local l, t, r, b = xsrc, ysrc, xsrc+itemw*2, h
				if #attr.Data == i then
					r = w + coorWidth
				end
				if t == b then
					t = b - 1
				end
				if i == 1 or i == #attr.Data/2 or i == #attr.Data  then
					xstart = xsrc + itemw
					Drawxline(xstart, attr.Data[i][1])
				end
				local normalColor = attr.Data["reqFailed"] and attr.FailedColor or attr.ColumnColorSrc
				newFillObject:SetSrcColor(normalColor)
				newFillObject:SetDestColor(normalColor)
				newFillObject:SetSrcPt(0, 0)
				newFillObject:SetDestPt(r-l, b-t)
				newFillObject:SetObjPos(l, t, r, b)
				newFillObject:AttachListener("OnMouseEnter", false, 
				function(self, x, y)
					local tips = barchartpanel:GetObject("tips")
					if not tips then
						tips = objFactory:CreateUIObject("tips", "BarChartTips")
						barchartpanel:AddChild(tips)
					end
					tips:SetText(""..dat[2].."\n"..dat[1])
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
					tips:GetObject("bkg"):SetResID(attr.TipRes)
					tips:SetObjPos(l + itemw - 35, t - 55, l + itemw + 36, t-1)
					tips:SetVisible(true)
					tips:SetChildrenVisible(true)
				end)
				
				newFillObject:AttachListener("OnMouseLeave", false, 
				function(self)
					newFillObject:SetSrcColor(normalColor)
					newFillObject:SetDestColor(normalColor)
					local tips = barchartpanel:GetObject("tips")
					if tips then
						tips:SetVisible(false)
						tips:SetChildrenVisible(false)
					end
				end)
				
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
	local textobj = self:GetObject("text")
	if textobj then
		textobj:SetText(text)
	end
end

function OnVisibleChange(self, bVisible)
	if not bVisible then return end
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
	barobj:SetObjPos("(father.width-191)/2", 70, "(father.width-191)/2 + 191", 70+246+30)
	attr.currentpanel = 1
	tFunctionHelper.GetHistoryToServer(0, function(bRet, tabInfo)
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
	barobj:SetObjPos("(father.width-240)/2", 70, "(father.width-240)/2 + 240", 70+246+30)
	attr.currentpanel = 2
	tFunctionHelper.GetHistoryToServer(1, function(bRet, tabInfo)
		attr.Data = tabInfo
		attr.Data["reqFailed"] = not bRet
		attr.Data["balance"] = tFunctionHelper.GetUserCurrentBalance()
		barobj:Update()
	end)
end