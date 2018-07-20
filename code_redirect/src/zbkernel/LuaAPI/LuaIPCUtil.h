#pragma once

#define IPC_UTIL_CLASS	"IPC.Util.Class"
#define IPC_UTIL_OBJ		"IPC.Util"

#include "..\Utility\Lock.h"
#include "..\MinerType\MinerClient.h"
#include <map>
#include <boost/thread/shared_mutex.hpp>
#include <boost/thread.hpp>

typedef struct __WORKINST
{
	UINT	 uMode;      // 1.GPU 2.CPU 等等.
	UINT	 uClientType;  // Host端口号.
	UINT     uStartCnt;   //启动轮数，相同的客户端通过这个来判断是否需要重启 
	wchar_t  wszParam[1024]; //命令行参数
	BOOL	 bQuit;
}WORKINST;


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
	static int StartModeClient(lua_State* pLuaState);
	static int QuitMode(lua_State* pLuaState);
	static int Quit(lua_State* pLuaState);
	static int ForceQuit(lua_State* pLuaState);

private:
	static XLLRTGlobalAPI sm_LuaMemberFunctions[];
	
	typedef std::map<UINT, WORKINST*> WorkInstMap;
	typedef WorkInstMap::iterator WorkInstMapIter;
	static WorkInstMap m_mapWorkInst;

	typedef boost::shared_mutex rwmutex;
	typedef boost::shared_lock<rwmutex> readLock;
	typedef boost::unique_lock<rwmutex> writeLock;	
	
	static rwmutex m_rwmutex;
	//static mutable XMLib::CriticalSection m_cs;

public:
	static UINT WINAPI Run(PVOID pArg);
	static CMinerClient * CreateClient(UINT uClientType);
	static BOOL StartProcess(std::wstring wParam, HANDLE & hWorkProcess, HANDLE & hWorkStdOutRead);
	
	static void TerminateAllClient();
	static BOOL EnableDebugPrivilege();
};