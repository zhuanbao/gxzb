#pragma once

#define IPC_UTIL_CLASS	"IPC.Util.Class"
#define IPC_UTIL_OBJ		"IPC.Util"

#include "..\MinerType\MinerClient.h"
/*定义挖矿客户端类型*/
typedef enum
{
	MINER_GENOIL = 1,
	MINER_ZCASH = 2,
}MinerType;


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
	static int Init(lua_State* pLuaState);
	static int Start(lua_State* pLuaState);
	static int Quit(lua_State* pLuaState);
	static int Pause(lua_State* luaState);
	static int Resume(lua_State* luaState);
	static int IsWorkProcessRunning(lua_State* pLuaState);
private:
	static XLLRTGlobalAPI sm_LuaMemberFunctions[];
	static HANDLE m_hWorkProcess;
	static HANDLE m_hPipeThread;

	//定义句柄: 构成stdin管道的两端句柄    
	static HANDLE  m_hStdInRead;         //子进程用的stdin的读入端    
	static HANDLE  m_hStdInWrite;        //主程序用的stdin的读入端    

	//定义句柄: 构成stdout管道的两端句柄    
	static HANDLE  m_hStdOutRead;     ///主程序用的stdout的读入端    
	static HANDLE  m_hStdOutWrite;    ///子进程用的stdout的写入端
public:
	static void CycleHandleInfoFromPipe();
	static void  CycleHandleInfoFromPipeEx();
	static void Clear();
	static void TerminateMiningProcess();
	static BOOL EnableDebugPrivilege();
};