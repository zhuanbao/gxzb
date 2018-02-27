#include "stdafx.h"
#include "LuaP2SDownload.h"
#include "..\Utility\StringOperation.h"
#include "..\P2SDownload\P2SDownloadDefine.h"
#include "..\EvenListenHelper\LuaMsgWnd.h"

LuaP2SUtil::LuaP2SUtil(void)
{
}

LuaP2SUtil::~LuaP2SUtil(void)
{
	
}


XLLRTGlobalAPI LuaP2SUtil::sm_LuaMemberFunctions[] = 
{
	{"DownloadFile", DownloadFile},
	{NULL, NULL}
};

LuaP2SUtil* __stdcall LuaP2SUtil::Instance(void *)
{
	static LuaP2SUtil s_instance;
	return &s_instance;
}

void LuaP2SUtil::RegisterObj( XL_LRT_ENV_HANDLE hEnv )
{
	if (hEnv == NULL)
	{
		return;
	}

	XLLRTObject theObject;
	theObject.ClassName = IPC_UTIL_CLASS;
	theObject.MemberFunctions = sm_LuaMemberFunctions;
	theObject.ObjName = IPC_UTIL_OBJ;
	theObject.userData = NULL;
	theObject.pfnGetObject = (fnGetObject)LuaP2SUtil::Instance;

	XLLRT_RegisterGlobalObj(hEnv,theObject);
}

UINT WINAPI LuaP2SUtil::ThreadDownLoad(void* param)
{
	P2S_PARAM* pParam = (P2S_PARAM*)param;
	CDownLoadWrap dw;
	dw.SetOnError(LuaP2SUtil::OnError);
	dw.SetOnFinish(LuaP2SUtil::OnFinish);
	dw.SetOnProgress(LuaP2SUtil::OnProgress);
	dw.AddDownloadTask(pParam->strUrl, pParam->strSaveDir);
	dw.StartDownload();
	dw.join();
	delete pParam;
	return 0;
}

void LuaP2SUtil::OnProgress(const string & strUrl, DWORD dwFileSize, float fPercent,  float fSpeed)
{
	//printf("download [%s] ,filesize [%u], percent[%%%.2f], speed[%.2fKB/s]\r\n", strUrl.c_str(), dwFileSize, fPercent*100, fSpeed);
	//TSDEBUG(L"download [%s] ,filesize [%u], percent[%%%.2f], speed[%.2fB/s]\r\n", ultra::_A2T(strUrl).c_str(), dwFileSize, fPercent*100, fSpeed);
	P2S_DOWNLOAD_PROGRESS *progress = new P2S_DOWNLOAD_PROGRESS();
	progress->strUrl = strUrl;
	progress->dwFileSize = dwFileSize;
	progress->fPercent = fPercent;
	progress->fSpeed = fSpeed;
	PostMessageA(LuaMsgWindow::Instance()->GetWndMsgHwnd(),WM_P2SDOWNLOADPROGRESS,(WPARAM)progress,(LPARAM)0);

}

void LuaP2SUtil::OnFinish(const string & strUrl, const string& strPath)
{
	//printf("download [%s] complete, download path [%s]\r\n", strUrl.c_str(), strPath.c_str());
	P2S_DOWNLOAD_FINISH *finish = new P2S_DOWNLOAD_FINISH();
	finish->strUrl = strUrl;
	finish->strPath = strPath;
	PostMessageA(LuaMsgWindow::Instance()->GetWndMsgHwnd(),WM_P2SDOWNLOADFINISH,(WPARAM)finish,(LPARAM)0);
}

void LuaP2SUtil::OnError(const string & strUrl, DWORD dwCode)
{
	//printf("download [%s] fail, error code [%d]\r\n", strUrl.c_str(), dwCode);
	P2S_DOWNLOAD_ERROR *error = new P2S_DOWNLOAD_ERROR();
	error->strUrl = strUrl;
	error->dwCode = dwCode;
	PostMessageA(LuaMsgWindow::Instance()->GetWndMsgHwnd(),WM_P2SDOWNLOADERROR,(WPARAM)error,(LPARAM)0);
}

int LuaP2SUtil::DownloadFile(lua_State* pLuaState)
{
	const char* pUrl = lua_tostring(pLuaState, 2);
	const char* pSaveDir = lua_tostring(pLuaState, 3);
	std::string strAnsiUrl = ultra::_UTF2A(pUrl);
	std::string strAnsiDir = ultra::_UTF2A(pSaveDir);
	P2S_PARAM* pParam = new P2S_PARAM();
	pParam->strUrl = strAnsiUrl;
	pParam->strSaveDir = strAnsiDir;
	HANDLE hThread = (HANDLE)_beginthreadex(NULL, 0, ThreadDownLoad, (PVOID*)pParam, 0, NULL);
	lua_pushlightuserdata(pLuaState, hThread);
	return 1;
}
