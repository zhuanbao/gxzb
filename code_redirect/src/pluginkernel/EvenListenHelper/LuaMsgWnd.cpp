#include "stdafx.h"
#include "XLFS.h"
#include "XLUE.h"
#include "XLGraphicPlus.h"


#include "LuaMsgWnd.h"

#include "shellapi.h"
#include "atlapp.h"
#include "atldlgs.h"
#include <atlconv.h>
#include "Wininet.h"
#include <fstream>
#pragma comment(lib, "Wininet.lib")
#include "..\XLUEApplication.h"
#include "..\Utility\LuaAPIHelper.h"
#include "..\Utility\StringOperation.h"
LuaMsgWindow::LuaMsgWindow(void)
{
	TSAUTO();
}

LuaMsgWindow::~LuaMsgWindow(void)
{
	TSAUTO();	
}

bool LuaMsgWindow::InitMsgWnd()
{
	if (m_hWnd == NULL)
		Create(HWND_MESSAGE);
	return true;
}

int LuaMsgWindow::AttachListener(DWORD userdata1,DWORD userdata2,funResultCallBack pfn, const void* pfun)
{
	TSAUTO();
	CallbackNode newNode = {0};
	newNode.pCallBack = pfn;
	newNode.userData1 = userdata1;
	newNode.userData2 = userdata2;
	newNode.luaFunction = pfun;
	int k = m_allCallBack.size();
	m_allCallBack.push_back(newNode);
	TSDEBUG4CXX(" userdata1 : "<<newNode.userData1<<" userData2 : "<< newNode.userData2<<", pfn : "<<pfn << ", pfun : " << pfun);
	 
	return 0;
}

int LuaMsgWindow::DetachListener(DWORD userData1, const void* pfun)
{
	TSAUTO();
	std::vector<CallbackNode>::iterator it = m_allCallBack.begin();
	for(; it != m_allCallBack.end(); it++)
	{
		if(it->luaFunction == pfun)
		{
			luaL_unref((lua_State *)(ULONG_PTR)userData1, LUA_REGISTRYINDEX, (int)it->userData2);
			m_allCallBack.erase(it);
			break;
		}
	}
	return 0;
}

LRESULT LuaMsgWindow::OnCopyData(UINT /*uMsg*/, WPARAM wParam, LPARAM lParam, BOOL& /*bHandled*/)
{
	
	TSAUTO();
	USES_CONVERSION;

	COPYDATASTRUCT * pcs = (COPYDATASTRUCT *)lParam;
	TSDEBUG4CXX("OnCopyData : dwData = "<<pcs->dwData);
	LPCWSTR pcszCommandLine = (LPCWSTR)pcs->lpData;
	TSDEBUG4CXX(" commandline : "<<pcszCommandLine);	
	if(pcszCommandLine && wcslen(pcszCommandLine) > 0)
	{
		CComVariant vParam[1];
		vParam[0] = (LPWSTR)pcszCommandLine;

		DISPPARAMS params = { vParam, NULL, 1, 0 };
		Fire_LuaEvent("OnCommandLine", &params);
	}	
	return 0;
}

LRESULT LuaMsgWindow::OnP2SDownloadFinish(UINT /*uMsg*/, WPARAM wParam, LPARAM lParam, BOOL& /*bHandled*/)
{
	P2S_DOWNLOAD_FINISH* finsih = (P2S_DOWNLOAD_FINISH*)wParam;
	std::wstring wstrUrl = ultra::_A2T(finsih->strUrl);
	std::wstring wstrPath = ultra::_A2T(finsih->strPath);
	delete finsih;

	CComVariant vParam[2];
	vParam[0] = (LPWSTR)wstrUrl.c_str();
	vParam[1] = (LPWSTR)wstrPath.c_str();

	DISPPARAMS params = { vParam, NULL, 2, 0 };
	Fire_LuaEvent("OnP2SDownloadFinish", &params);
	return 0;
}

LRESULT LuaMsgWindow::OnP2SDownloadError(UINT /*uMsg*/, WPARAM wParam, LPARAM lParam, BOOL& /*bHandled*/)
{
	P2S_DOWNLOAD_ERROR* error = (P2S_DOWNLOAD_ERROR*)wParam;
	std::wstring wstrUrl = ultra::_A2T(error->strUrl);
	DWORD dwErrorCode = error->dwCode;
	delete error;

	CComVariant vParam[2];
	vParam[0] = (LPWSTR)wstrUrl.c_str();
	vParam[1] = dwErrorCode;

	DISPPARAMS params = { vParam, NULL, 2, 0 };
	Fire_LuaEvent("OnP2SDownloadError", &params);
	return 0;
}

LRESULT LuaMsgWindow::OnP2SDownloadProgress(UINT /*uMsg*/, WPARAM wParam, LPARAM lParam, BOOL& /*bHandled*/)
{
	TSAUTO();
	P2S_DOWNLOAD_PROGRESS* progress = (P2S_DOWNLOAD_PROGRESS*)wParam;
	std::wstring wstrUrl = ultra::_A2T(progress->strUrl);
	DWORD dwFileSize = progress->dwFileSize;
	float fPercent = progress->fPercent;
	float fSpeed = progress->fSpeed;
	delete progress;

	CComVariant vParam[4];
	vParam[0] = (LPWSTR)wstrUrl.c_str();
	vParam[1] = (DWORD)dwFileSize;
	vParam[2] = (float)fPercent;
	vParam[3] = (float)fSpeed;
	DISPPARAMS params = { vParam, NULL, 4, 0 };
	Fire_LuaEvent("OnP2SDownloadProgress", &params);
	return 0;
}

void LuaMsgWindow::SetKeyboardHook()
{
	if (NULL==m_hKeyboardHook)
	{
		m_hKeyboardHook = ::SetWindowsHookEx(WH_KEYBOARD, LuaMsgWindow::Instance()->KeyboardProc, NULL, GetCurrentThreadId()); 	
	}
	return ;
}

void LuaMsgWindow::DelKeyboardHook()
{	
	if (m_hKeyboardHook)
	{
		::UnhookWindowsHookEx(m_hKeyboardHook);	
		m_hKeyboardHook = NULL;
	}
	return ;
}

LRESULT CALLBACK LuaMsgWindow::KeyboardProc(int code, WPARAM wParam, LPARAM lParam)
{
	if(HC_NOREMOVE == code)
		return CallNextHookEx (LuaMsgWindow::Instance()->m_hKeyboardHook, code, wParam, lParam);
	HWND hFocus = ::GetActiveWindow();

	
	CComVariant avarParams[5];
	avarParams[1] = CComVariant((LONG)wParam);
	avarParams[0] = CComVariant((LONG)(ULONG_PTR)hFocus);
	TSDEBUG4CXX("VKey : "<<(const unsigned int)wParam);
	CComVariant varResult;
	DISPPARAMS params = { avarParams, NULL, 2, 0 };
	if(lParam & 0x80000000) //µ¯Æð
	{
		LuaMsgWindow::Instance()->Fire_LuaEvent("OnKeyUp", &params);
	}
	else
	{
		LuaMsgWindow::Instance()->Fire_LuaEvent("OnKeyDown", &params);
	}

	return CallNextHookEx (LuaMsgWindow::Instance()->m_hKeyboardHook, code, wParam, lParam);
}

void LuaMsgWindow::CloseWnd()
{	
	if (m_hWnd != NULL)
	{
		DestroyWindow();
		m_hWnd = NULL;
	}
}