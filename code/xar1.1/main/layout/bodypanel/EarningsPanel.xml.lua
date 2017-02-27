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





--------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------
----------------------------------------------柱形图部分------------------------------------------------------------

function BarChartUpdate(self, fnConvert)
	local attr = self:GetAttribute()
	if not attr or type(attr.Data) ~= "table" or #attr.Data == 0 then
		return
	end
	--[[table.sort(attr.Data, function(t1, t2)
		return t1[1] < t2[1]
	end)]]
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
	if ymax == 0 then
		return
	end
	local l, t, r, b = self:GetObjPos()
	--减去横纵坐标的宽度
	local w, h = r - l -2, b - t - 2
	local objFactory = XLGetObject("Xunlei.UIEngine.ObjectFactory")
	--显示纵坐标刻度
	--[[for i = 1, #attr.Data do
		if type(attr.Data[i]) == "table" then
			local ytmp = h*i/#attr.Data
			if ytmp <= h then
				local yreal = h - ytmp
				local newTextObject = objFactory:CreateUIObject("", "TextObject")
				newTextObject:SetText(tostring(math.abs(ymax*i/#attr.Data)))
				barchartpanel:AddChild(newTextObject)
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
		barchartpanel:AddChild(newTextObject)
		newTextObject:SetObjPos(-50, yreal-8, 0, yreal+8)
		newTextObject:SetVAlign("center")
		newTextObject:SetHAlign("center")
		newTextObject:SetTextColorResID("system.black")
		newTextObject:SetTextFont("font.text10")
	end
	local itemw = w/(#attr.Data*2-1)
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
		newTextObject:SetTextColorResID("system.black")
		newTextObject:SetTextFont("font.text10")
	end
	--将数据转换为坐标系中的点
	local function ConvertData2Point(xindex, ydata)
		--local xreal = (#attr.Data == 1 and 0 or w*(xindex-1)/(#attr.Data)) + 2
		local xreal = (#attr.Data == 1 and 0 or 2*(xindex-1)*itemw) + 2 
		local yreal = h - h*ydata/ymax
		return math.floor(xreal), math.floor(yreal)
	end
	local xstart=0
	local function DrawBar()
		for i, dat in ipairs(attr.Data) do
			if type(dat) == "table" and i <= #attr.Data and type(dat[1]) == "number" and type(dat[2]) == "number" then
				local newFillObject = objFactory:CreateUIObject("", "FillObject")
				barchartpanel:AddChild(newFillObject)
				local xsrc, ysrc = ConvertData2Point(i, dat[2])
				local l, t, r, b = xsrc, ysrc, xsrc+itemw, h
				if #attr.Data == i then
					r = w+2
				end
				if t == b then
					t = b - 1
				end
				if i == 1 or xsrc + itemw/2 - xstart > 60 then
					xstart = xsrc + itemw/2
					Drawxline(xstart, attr.Data[i][1])
				end
				newFillObject:SetSrcColor(attr.ColumnColorSrc)
				--newFillObject:SetDestColor(attr.ColumnColorDest)
				newFillObject:SetSrcPt(0, 0)
				newFillObject:SetDestPt(r-l, b-t)
				newFillObject:SetObjPos(l, t, r, b)
				--newFillObject:SetFillType("Line")
			end
		end
	end
	DrawBar()
end

function OnClickHourBtnBarChart(self)
	local barobj = self:GetObject("control:EarningsPanel.BarChart")
	local attr = barobj:GetAttribute()
	if attr.currentpanel ~= 2 then
		return
	end
	attr.currentpanel = 1
	attr.Data = {{1, 1000}, {2, 1800}, {4, 9000}, {3, 4000}, {6, 5000}, {5, 1200}, {8, 500}, {7, 2100}, {10, 1700}, {9, 2900}, {11, 4800}, {12, 3100}, {13, 400}, {14, 8000}, {15, 1000}, {16, 1800}, {17, 9000}, {18, 4000}, {19, 5000}, {20, 1200}, {21, 500}, {22, 2100}, {23, 1700}, {24, 2900}}
	barobj:Update()
end

function OnClickDayBtnBarChart(self)
	local barobj = self:GetObject("control:EarningsPanel.BarChart")
	local attr = barobj:GetAttribute()
	if attr.currentpanel == 2 then
		return
	end
	attr.currentpanel = 2
	attr.Data = {{11, 7002}, {12, 3003}, {13, 6580}, {14, 1021}, {15, 9000}}
	barobj:Update()
end