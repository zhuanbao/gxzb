local tipUtil = XLGetObject("API.Util")
local tFunctionHelper = XLGetGlobal("Global.FunctionHelper")

local g_tPanelCtrlList = {
	"ChildCtrl_MinerInfo",
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
	local objMainBodyCtrl = objRootCtrl:GetControlObject("TipCtrl.MainWnd.MainBody")
	if objMainBodyCtrl == nil then
		return false
	end
	
	local bSucc = objMainBodyCtrl:InitPanelList(g_tPanelCtrlList)
	if not bSucc then
		return false
	end
	
	local bSucc = objMainBodyCtrl:ChangePanel("ChildCtrl_MinerInfo")
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
			if tostring(key) == "OnMinerSpeed" then
				OnMinerSpeed(tParam)
			elseif tostring(key) == "OnSolutionFind" then
				OnSolutionFind(tParam)
			elseif tostring(key) == "OnDagInit" then
				OnDagInit(tParam)
			elseif tostring(key) == "OnCommandLine" then
				OnCommandLine(tParam)
			end		
		end
	)
	
	function OnMinerSpeed(tInfo)
		local strSpeed = tInfo[1]
		tFunctionHelper.TipLog("[OnMinerSpeed] strSpeed = " .. tostring(strSpeed))
	end

	function OnSolutionFind(tInfo)
		local strNonce, strHeaderHash, strMixHash = tInfo[1],tInfo[2],tInfo[3]
		tFunctionHelper.TipLog("[OnSolutionFind] strNonce = " .. tostring(strNonce) .. ", strHeaderHash = " .. tostring(strHeaderHash) .. ", strMixHash = " .. tostring(strHeaderHash))
	end
	
	function OnDagInit(tInfo)
		local nState, nProgress = tInfo[1],tInfo[2]
		tFunctionHelper.TipLog("[OnDagInit] OnDagInit = " .. tostring(nState) .. ", nProgress = " .. tostring(nProgress))
	end
	
	function OnCommandLine(tInfo)
		local strCommand = tInfo[1]
		if not IsRealString(strCommand) then
			return
		end

	end	
end

function IsRealString(AString)
    return type(AString) == "string" and AString ~= ""
end
