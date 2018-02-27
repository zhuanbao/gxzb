#pragma once
#define IPC_UTIL_CLASS	"P2S.Util.Class"
#define IPC_UTIL_OBJ		"P2S.Util"
#include "..\P2SDownload\DownLoadWrap.h"

struct P2S_PARAM
{
	std::string strUrl;
	std::string strSaveDir;
};
class LuaP2SUtil
{
public:
	LuaP2SUtil(void);
	~LuaP2SUtil(void);

private:
	static UINT WINAPI ThreadDownLoad(void* pParam);
	static void OnProgress(const string & strUrl, DWORD dwFileSize, float fPercent,  float fSpeed);
	static void OnFinish(const string & strUrl, const string& strPath);
	static void OnError(const string & strUrl, DWORD dwCode);
public:
	static LuaP2SUtil * __stdcall Instance(void *);
	static void RegisterObj(XL_LRT_ENV_HANDLE hEnv);

public:
	static int DownloadFile(lua_State* luaState);

private:
	static XLLRTGlobalAPI sm_LuaMemberFunctions[];
};
