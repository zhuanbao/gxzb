#pragma once

#define IPC_UTIL_CLASS	"IPC.Util.Class"
#define IPC_UTIL_OBJ		"IPC.Util"


class LuaIPCUtil
{
public:
	LuaIPCUtil(void);
	~LuaIPCUtil(void);

private:

public:
	static LuaIPCUtil * __stdcall Instance(void *);
	static void RegisterObj(XL_LRT_ENV_HANDLE hEnv);

public:
	static int StartWork(lua_State* pLuaState);
	static int StopWork(lua_State* luaState);
	static int Quit(lua_State* pLuaState);
	static int QueryWorkState(lua_State* pLuaState);
	static int ControlSpeed(lua_State* pLuaState);
	static int SendPoolUrl(lua_State* pLuaState);
	static int IsWorkProcessRunning(lua_State* pLuaState);
private:
	static XLLRTGlobalAPI sm_LuaMemberFunctions[];
	static HANDLE m_hPipeThread;
	static HANDLE m_hWorkProcess;
};


class CIPCMsgWindow :public CWindowImpl<CIPCMsgWindow>
{
public:
	CIPCMsgWindow()
	{

	}
	~CIPCMsgWindow()
	{

	}
	BEGIN_MSG_MAP(CIPCMsgWindow)
		//MESSAGE_HANDLER(WM_GETFOLDERS, OnGetFoldersFinish)
	END_MSG_MAP()
};