local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")

local g_tPanelCtrlList = {
	"EarningsPanel",
	"MiningPanel",
	"QRCodePanel",
	"TakeCashPanel",
}

----方法----
function SetTipData(self, infoTab) 
	if infoTab == nil or type(infoTab) ~= "table" then
		return false
	end
	
	local bSucc = InitMainBodyCtrl(self)
	if not bSucc then
		tFunctionHelper.TipLog("[SetTipData] InitMainBodyCtrl failed")
		return false
	end
	
	CreateListener(self)
	return true
end

function InitMainBodyCtrl(objRootCtrl)
	local objMainBodyCtrl = objRootCtrl:GetControlObject("WndPanel.MainBody")
	if objMainBodyCtrl == nil then
		return false
	end
	
	local bSucc = objMainBodyCtrl:InitPanelList(g_tPanelCtrlList)
	if not bSucc then
		return false
	end
	local strPanel = "MiningPanel"
	--[[
	if tFunctionHelper.CheckShouldRemindBind() then
		strPanel = "QRCodePanel"
		tFunctionHelper.SaveLastRemindBindUTC()
	end
	--]]
	local bSucc = objMainBodyCtrl:ChangePanel(strPanel)
	if not bSucc then
		return false
	end
	return true
end

---------事件---------



--------辅助函数----
function CreateListener(objRootCtrl)
	local objFactory = XLGetObject("APIListen.Factory")
	if not objFactory then
		tFunctionHelper.TipLog("[CreateListener] not support APIListen.Factory")
		return
	end
	
	local objListen = objFactory:CreateInstance()	
	objListen:AttachListener(
		function(key,...)	
			tFunctionHelper.TipLog("[CreateListener] key: " .. tostring(key))
			local tParam = {...}	
			if tostring(key) == "OnCommandLine" then
				--OnCommandLine(tParam)
				--再次拉起时置顶
				local bHide = false
				if tFunctionHelper.IsHostComputerInNetBar() then
					if type(tParam) == "table" and type(tParam[1]) == "string" and string.find(tParam[1], "/embedding") then
						bHide = true
					end
				end	
				if not bHide then
					local mainwnd = tFunctionHelper.GetMainHostWnd()
					if mainwnd then
						mainwnd:BringWindowToTop(true)
					end
				end
			elseif tostring(key) == "OnGenOilMsg" then
				local ObjWorkClient = tFunctionHelper.GetWorkClient()
				ObjWorkClient.OnGenOilMsg(tParam)
			end				
		end
	)
end

function IsRealString(AString)
    return type(AString) == "string" and AString ~= ""
end
