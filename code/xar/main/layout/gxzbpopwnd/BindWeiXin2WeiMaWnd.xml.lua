local tipUtil = XLGetObject("API.Util")
local FunctionObj = XLGetGlobal("Global.FunctionHelper")
local gBindWeiXinTimerID = nil
local timerManager = XLGetObject("Xunlei.UIEngine.TimerManager")
local gSecond = 0
local gClosedDialog = false

function TipLog(strLog)
	if type(tipUtil.Log) == "function" then
		tipUtil:Log("@@BindWeiXin2WeiMaWnd: " .. tostring(strLog))
	end
end


function OnCreate( self )
	gClosedDialog = false
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
		local textObject = objtree:GetUIObject("BindWeiXin2WeiMaWnd.Caption.Wait")
		if textObject then
			gTimeoutTimerId = timerManager:SetTimer(function(Itm, id)
				if gClosedDialog then
					return
				end
				local strText = "获取二维码图片中"
				gSecond = gSecond+1
				local numPoint = gSecond%3
				for i=0, numPoint do
					strText = strText .. "."
				end
				textObject:SetText(tostring(strText))
			end, 1000)
		end
		FunctionObj.DownLoadTempQrcode(function(bRet,info)
			if gClosedDialog then
				return
			end
			if not bRet then
				if gTimeoutTimerId ~= nil then
					timerManager:KillTimer(gTimeoutTimerId)
					gTimeoutTimerId = nil
				end
				textObject:SetText(tostring(info))
				return
			end
			local imgObject = objtree:GetUIObject("BindWeiXin2WeiMaWnd.Caption.2WeiMa")
			if imgObject then
				local objGraphicFac = XLGetObject("Xunlei.XLGraphic.Factory.Object")
				local objBitmap = objGraphicFac:CreateBitmap(info["qrcodePath"], "ARGB32")
				if objBitmap then
					if gTimeoutTimerId ~= nil then
						timerManager:KillTimer(gTimeoutTimerId)
						gTimeoutTimerId = nil
					end
					textObject:SetVisible(false)
					imgObject:SetBitmap(objBitmap)
					imgObject:SetVisible(true)
					local textTipObject = objtree:GetUIObject("BindWeiXin2WeiMaWnd.Caption.Tip")
					
					local nCnt = 0
					local nTotalTime = info["expire"]/1000
					local strText = "请扫描以下二维码进行微信绑定，二维码剩余有效期 " .. nTotalTime .. "秒"
					textTipObject:SetText(tostring(strText))
						
					local bTimeOut = false
					local tServerConfig = FunctionObj.GetServerConfig()
					local tServerInterfaceCfg = tServerConfig["tServerInterfaceCfg"]
					if type(tServerInterfaceCfg) ~= "table" then
						tServerInterfaceCfg = {}
					end
					local nAskBindPeriod = info["interval"] or tServerInterfaceCfg["nAskBindPeriod"] or 10
					--TEST 
					local bAsking = false
					
					gTimeoutTimerId = timerManager:SetTimer(function(Itm, id)
						if gClosedDialog then
							return	
						end
						if nTotalTime < 1 then
							bTimeOut = true
							timerManager:KillTimer(gTimeoutTimerId)
							gTimeoutTimerId = nil
							local strText = "绑定超时,请关闭程序重新获取二维码"
							textTipObject:SetText(tostring(strText))
							return
						end
						nTotalTime = nTotalTime - 1
						local strText = "请扫描以下二维码进行微信绑定，二维码剩余有效期 " .. nTotalTime .. "秒"
						textTipObject:SetText(tostring(strText))
						if not bAsking and nCnt > nAskBindPeriod then
							TipLog("CycleQuerySeverForBindResult cycle")
							bAsking = true
							nCnt = 0
							FunctionObj.CycleQuerySeverForBindResult(info["sceneID"], function(bRet,info)
								if gClosedDialog then
									return
								end
								if not bRet then
									TipLog("CycleQuerySeverForBindResult return false")
									bAsking = false
									return 
								end
								timerManager:KillTimer(gTimeoutTimerId)
								gTimeoutTimerId = nil
								FunctionObj.SetUserBindInfo(info)
								textObject:SetText("恭喜您，绑定成功")
								textObject:SetVisible(true)
								imgObject:SetVisible(false)
								--self:EndDialog(0)
							end, nAskBindPeriod)
						end
						nCnt = nCnt + 1
					end, 1000)
				end
			end
		end)
	end
end

function StopConnect()
	if gTimeoutTimerId ~= nil then
		timerManager:KillTimer(gTimeoutTimerId)
		gTimeoutTimerId = nil
	end
end

function OnDestroy( self )
	gClosedDialog = true
	StopConnect()
end

function OnCloseDialog(self)
	local objTree = self:GetOwner()
	local objHostWnd = objTree:GetBindHostWnd()
	objHostWnd:EndDialog(0)
end
