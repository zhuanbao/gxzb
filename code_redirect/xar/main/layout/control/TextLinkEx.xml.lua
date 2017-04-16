function OnMouseHover(self)
	local ownerControl = self:GetOwnerControl()
	local attr = ownerControl:GetAttribute()
	if not attr.Enable then
		return 0,false
	end
	ownerControl:FireExtEvent("OnTextLinkMouseHover")
    return 0, false
end

function GetTextExtent(self)
    local textobj = self:GetControlObject("textlink.text")
	local textwidth, textheight = textobj:GetTextExtent()
	return textwidth,textheight
end

function SetAlpha(self,nAlpha)
	local obj = self:GetControlObject("textlink.text")
	obj:SetAlpha(nAlpha)
end

function Show(self, bshow)
    local attr = self:GetAttribute()
    local layoutobj = self:GetControlObject("textlink.layout")
	if bshow then
	    self:SetVisible(true)
		self:SetChildrenVisible(true)
		attr.Show = true
	else
	    self:SetVisible(false)
		self:SetChildrenVisible(false)
		attr.Show = false
	end
end

function IsShow(self)
    local attr = self:GetAttribute()
	return attr.Show
end

function OnMouseMove(self, x, y)
	local ownerControl = self:GetOwnerControl()
	local attr = ownerControl:GetAttribute()
	if not attr.Enable then
		return 0,false
	end
	
	local font = self:GetTextFontResID()
	if attr.NoSpaceCursor then
		local width,height = self:GetTextExtent()
		local left,top,right,bottom = self:GetObjPos()
		local textLeft,textTop,textRight,textBottom
		if attr.HAlign == "center" then
			textLeft = (left + right - width)/2
		elseif attr.HAlign == "right" then
			textLeft = right - width
		else
			textLeft = left
		end
		
		if attr.VAlign == "center" then
			textTop = (top + bottom - height)/2
		elseif attr.HAlign == "bottom" then
			textTop = bottom - height
		else
			textTop = top
		end
		
		textRight = textLeft + width
		textBottom = textTop + height
		if x>= textLeft and x <= textRight and y >= textTop and y <= textBottom then
			if not attr.ishover then
				attr.ishover = true
				self:SetCursorID("IDC_HAND")
				self:SetTextColorResID(attr.TextHoverColor)
				if attr.Underline then
					self:SetTextFontResID(font .. ".underline")
				end
			end
		else
			if attr.ishover then
				attr.ishover = false
				self:SetCursorID("")
				self:SetTextColorResID(attr.TextColor)
				if attr.Underline then
					self:SetTextFontResID(string.sub(font, 1, -11))
				end
			end
		end
	else
		if not attr.ishover then
			attr.ishover = true
			self:SetCursorID("IDC_HAND")
			self:SetTextColorResID(attr.TextHoverColor)
			if attr.Underline then
				self:SetTextFontResID( font .. ".underline" )
			end
		end
	end
	self:RouteToFather()
	return 0, false
end

function OnMouseLeave(self)
	local ownerControl = self:GetOwnerControl()
	local attr = ownerControl:GetAttribute()
	if not attr.Enable then
		return 0,false
	end

	local font = self:GetTextFontResID()
	if attr.ishover then
		attr.ishover = false
		self:SetCursorID("")
		if attr.Underline then
			self:SetTextFontResID(string.sub(font, 1, -11))
		end
	end
	self:SetTextColorResID(attr.TextColor)
	ownerControl:FireExtEvent("OnTextLinkMouseLeave")
	self:RouteToFather()
    return 0, false
end

function OnLButtonUp(self, x, y)
	local ownerControl = self:GetOwnerControl()
	local attr = ownerControl:GetAttribute()
	if not attr.Enable then
		return
	end

	if attr.NoSpaceCursor then
		local width,height = self:GetTextExtent()
		local left,top,right,bottom = self:GetObjPos()
		local textLeft,textTop,textRight,textBottom
		if attr.HAlign == "center" then
			textLeft = (left + right - width)/2
		elseif attr.HAlign == "right" then
			textLeft = right - width
		else
			textLeft = left
		end
		
		if attr.VAlign == "center" then
			textTop = (top + bottom - height)/2
		elseif attr.HAlign == "bottom" then
			textTop = bottom - height
		else
			textTop = top
		end
		
		textRight = textLeft + width
		textBottom = textTop + height
		if x < textLeft or x > textRight or y < textTop or y > textBottom  then
			return
		end
	end
	
	
	ownerControl:FireExtEvent("OnClick")

	
end

function OnBind(self)
    local control = self:GetOwnerControl()
    local cattr = control:GetAttribute()
	if cattr.Text ~= nil then
		self:SetText(cattr.Text) 
	end
	control:Show(cattr.Show)
end

function GetText(self)
    local attr = self:GetAttribute()
    return attr.Text
end

function SetText(self, text)
    local attr = self:GetAttribute()
    attr.Text = text
    local t = self:GetControlObject("textlink.text")
    t:SetText(text)
end

function GetEnable(self)
    local attr = self:GetAttribute()
    return attr.Enable
end

function SetEnable(self, bEnable)
	if bEnable==nil then
		bEnable = false
	end
    local attr = self:GetAttribute()
    attr.Enable = bEnable
	local t = self:GetControlObject("textlink.text")
	if bEnable then
		 t:SetTextColorResID(attr.TextColor)
	else
		 t:SetTextColorResID(attr.DisableTextColor)
	end
end

function GetTextColorID(self)
    local attr = self:GetAttribute()
    return attr.TextColor
end

function SetTextColorID(self, textColorID)
    local attr = self:GetAttribute()
    attr.TextColor = textColorID
    local t = self:GetControlObject("textlink.text")
    t:SetTextColorResID(attr.TextColor)
end

function GetTextHoverColorID(self)
    local attr = self:GetAttribute()
    return attr.TextHoverColor
end

function SetTextHoverColorID(self, textHoverColorID)
    local attr = self:GetAttribute()
    attr.TextHoverColor = textHoverColorID
    local t = self:GetControlObject("textlink.text")
    t:SetTextColorResID(attr.TextHoverColor)
end

function GetDisableTextColorID(self)
    local attr = self:GetAttribute()
    return attr.DisableTextColor
end

function SetDisableTextColorID(self, textColorID)
    local attr = self:GetAttribute()
    attr.DisableTextColor = textColorID
end

function GetVAlign(self)
    local attr = self:GetAttribute()
    return attr.VAlign
end

function SetVAlign(self, vAlign)
    local attr = self:GetAttribute()
	if attr.VAlign == vAlign then
		return
	end
	
    attr.VAlign = vAlign
	local t = self:GetControlObject("textlink.text")
	t:SetVAlign(attr.VAlign)
end

function GetHAlign(self)
    local attr = self:GetAttribute()
    return attr.VAlign
end

function SetHAlign(self, hAlign)
    local attr = self:GetAttribute()
	if attr.HAlign == hAlign then
		return
	end
	
    attr.HAlign = hAlign
	local t = self:GetControlObject("textlink.text")
	t:SetHAlign(attr.HAlign)
end

function OnInitControl(self)
	local owner = self:GetOwnerControl()
    local attr = owner:GetAttribute()
	self:SetTextFontResID( attr.Font )
	self:SetVAlign(attr.VAlign)
	self:SetHAlign(attr.HAlign)
	if attr.Enable then
		 self:SetTextColorResID(attr.TextColor)
	else
		 self:SetTextColorResID(attr.DisableTextColor)
	end
end

function GetTextExtent(self)
	local t = self:GetControlObject("textlink.text")
	return t:GetTextExtent()
end
