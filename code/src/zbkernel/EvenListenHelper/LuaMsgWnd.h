#pragma once
#include "atlwin.h"
#include "map"

#define LUA_MSG_WND_CALSS _T("UserWnd_{FEE8E80D-0A47-44DD-AD58-9E7F6F08C4E8}")
#define LUA_MSG_MUTEX _T("{MutexWnd_{FEE8E80D-0A47-44DD-AD58-9E7F6F08C4E8}")

#define WM_MINING_COUNT		WM_USER+800
#define WM_CONNECT_FAIL		WM_USER+801
#define WM_INITDAG_RET		WM_USER+802

#include <XLLuaRuntime.h>
typedef void (*funResultCallBack) (DWORD userdata1,DWORD userdata2, const char* pszKey,  DISPPARAMS* pParams);

struct SOLUTION_SS
{
	char sz_nonce[MAX_PATH];
	char sz_headerHash[MAX_PATH];
	char sz_mixHash[MAX_PATH];

};


struct CallbackNode
{
	funResultCallBack pCallBack;
	DWORD userData1;
	DWORD userData2;
	const void* luaFunction;
};

class LuaMsgWindow : public  CWindowImpl<LuaMsgWindow>
{
public:
	static LuaMsgWindow* Instance()
	{
        static LuaMsgWindow s;
		return &s;
	}

	int AttachListener(DWORD userData1,DWORD userData2,funResultCallBack pfn, const void* pfun);
	int DetachListener(DWORD userData1, const void* pfun);
	void CloseSingletonMutex();
	bool HandleSingleton();
	DECLARE_WND_CLASS(LUA_MSG_WND_CALSS)
	BEGIN_MSG_MAP(LuaMsgWindow)
		MESSAGE_HANDLER(WM_COPYDATA, OnCopyData)
		MESSAGE_HANDLER(WM_MINING_COUNT, OnMiningCount)
		MESSAGE_HANDLER(WM_CONNECT_FAIL, OnConnectFail)
		MESSAGE_HANDLER(WM_INITDAG_RET, OnInitDagRet)
	END_MSG_MAP()
private:
	LuaMsgWindow(void);
	~LuaMsgWindow(void);
	std::vector<CallbackNode> m_allCallBack;

	void Fire_LuaEvent(const char* pszKey, DISPPARAMS* pParams)
	{
		TSAUTO();
		for(size_t i = 0;i<m_allCallBack.size();i++)
		{
 			m_allCallBack[i].pCallBack(m_allCallBack[i].userData1,m_allCallBack[i].userData2, pszKey,pParams);
		}
	}
private:
	HANDLE m_hMutex;

public:
	LRESULT OnCopyData(UINT , WPARAM , LPARAM , BOOL&);
	LRESULT OnMiningCount(UINT , WPARAM , LPARAM , BOOL&);
	LRESULT OnConnectFail(UINT , WPARAM , LPARAM , BOOL&);
	LRESULT OnInitDagRet(UINT , WPARAM , LPARAM , BOOL&);
public:
	void SetKeyboardHook(void);
	void DelKeyboardHook(void);
private:
	static LRESULT CALLBACK  KeyboardProc(int code, WPARAM wParam, LPARAM lParam);
public:
	HHOOK m_hKeyboardHook;
};
