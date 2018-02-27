#pragma once
#include "atlwin.h"
#include "map"
#include "..\P2SDownload\P2SDownloadDefine.h"

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
	bool InitMsgWnd();
	void CloseWnd();
	HWND GetWndMsgHwnd()
	{
		return m_hWnd;
	}
	//DECLARE_WND_CLASS(L"PluginWnd_{FEE8E80D-0A47-44DD-AD58-9E7F6F08C4E8}")
	static BOOL GetArgvValueByKey(const wchar_t* wszKey, std::wstring & wstrValue) 
	{
		LPWSTR lpstrCmdLine = ::GetCommandLineW();
		if (NULL == lpstrCmdLine)
		{
			return FALSE;
		}
		int nNumArgs = 0;
		LPWSTR * pszArgs = CommandLineToArgvW(lpstrCmdLine, &nNumArgs);
		for (int i = 1; i < nNumArgs; i++)
		{
			if(0 == _tcsicmp(pszArgs[i], wszKey))
			{
				i++;
				if(i < nNumArgs && NULL != pszArgs[i] )
				{
					wstrValue = pszArgs[i];
					return TRUE;
				}
			}
		}
		return FALSE;
	}

	static ATL::CWndClassInfo& GetWndClassInfo() 
	{ 
		static wchar_t szWndClassName[1024] = {0};
		if (szWndClassName[0] == L'\0')
		{
			std::wstring wstrWndID = L"";
			GetArgvValueByKey(L"/wndid",wstrWndID);


			swprintf(szWndClassName,L"PluginWnd_{FEE8E80D-0A47-44DD-AD58-9E7F6F08C4E8}_%s",wstrWndID.c_str());
			TSDEBUG(L"Msg wnd class name is [%s]", szWndClassName);
		}
		
		static ATL::CWndClassInfo wc = 
		{ 
			{ sizeof(WNDCLASSEX), CS_HREDRAW | CS_VREDRAW | CS_DBLCLKS, StartWindowProc, 
			0, 0, NULL, NULL, NULL, (HBRUSH)(COLOR_WINDOW + 1), NULL, szWndClassName, NULL }, 
			NULL, NULL, IDC_ARROW, TRUE, 0, _T("") 
		}; 
		return wc; 
	}
	BEGIN_MSG_MAP(LuaMsgWindow)
		MESSAGE_HANDLER(WM_COPYDATA, OnCopyData)
		MESSAGE_HANDLER(WM_P2SDOWNLOADFINISH, OnP2SDownloadFinish)
		MESSAGE_HANDLER(WM_P2SDOWNLOADERROR, OnP2SDownloadError)
		MESSAGE_HANDLER(WM_P2SDOWNLOADPROGRESS, OnP2SDownloadProgress)
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
	//HWND m_hMsgWnd;

public:
	LRESULT OnCopyData(UINT , WPARAM , LPARAM , BOOL&);
	LRESULT OnP2SDownloadFinish(UINT , WPARAM , LPARAM , BOOL&);
	LRESULT OnP2SDownloadError(UINT , WPARAM , LPARAM , BOOL&);
	LRESULT OnP2SDownloadProgress(UINT , WPARAM , LPARAM , BOOL&);
public:
	void SetKeyboardHook(void);
	void DelKeyboardHook(void);
private:
	static LRESULT CALLBACK  KeyboardProc(int code, WPARAM wParam, LPARAM lParam);
public:
	HHOOK m_hKeyboardHook;
};
