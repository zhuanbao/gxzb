#include "stdafx.h"
#include "RegisterLuaAPI.h"
#include "LuaAPI/LuaAPIUtil.h"
#include "LuaAPI/LuaAsynAPIUtil.h"
#include "LuaAPI/LuaNotifyIcon.h"
#include "EvenListenHelper/LuaListenPre.h"
#include "EvenListenHelper/LuaPrefactory.h"
#include "LuaAPI/LuaP2SDownload.h"

CRegisterLuaAPI::CRegisterLuaAPI()
{

}

CRegisterLuaAPI::~CRegisterLuaAPI()
{

}

BOOL CRegisterLuaAPI::Init(LPCTSTR lpCmdLine, LPVOID lpHookObj)
{
	TSTRACEAUTO();
	XL_LRT_ENV_HANDLE hEnv = XLLRT_GetEnv(NULL);
	if (NULL == hEnv)
	{
		TSDEBUG4CXX(L"XLLRT_GetEnv error!  hEnv == NULL");
		return FALSE;
	}
	LuaAPIUtil::RegisterObj(hEnv);
	LuaAsynUtil::RegisterSelf(hEnv);
	LuaP2SUtil::RegisterObj(hEnv);

	LuaNotifyIcon::RegisterSelf(hEnv);
	LuaListenPreFactory::RegisterObj(hEnv);
	LuaListenPre::RegisterClass(hEnv);

	XLLRT_ReleaseEnv(hEnv);
	return TRUE;
}
