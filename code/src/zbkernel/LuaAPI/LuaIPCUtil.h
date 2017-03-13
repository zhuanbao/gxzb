#pragma once

#define IPC_UTIL_CLASS	"IPC.Util.Class"
#define IPC_UTIL_OBJ		"IPC.Util"

#define PIPE_QUIT_EVENT  "UserPipeQuitEvent_{FEE8E80D-0A47-44DD-AD58-9E7F6F08C4E8}"

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
	static HANDLE m_hPipeQuitEvent;
	static HANDLE m_hPipeContinueEvent;
public:
	static BOOL WaitPipeQuitEvent();
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