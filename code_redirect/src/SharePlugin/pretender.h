#pragma once

#include <shlobj.h>
#include <list>
#include "ImagePreReader.h"
#define PLUGIN_KERNEL_NAME  "pluginkernel.dll"
class Pretender
{
public:
	Pretender() : m_bInitOK(FALSE), m_hKernel(NULL)
	{		
		CHAR szExePath[MAX_PATH] = {0};
		GetModuleFileNameA(NULL, szExePath, MAX_PATH);
		PathRemoveFileSpecA(szExePath);

		const CHAR *dllFileName[] = {
			("zlib1.dll"),   
			("xlfsio.dll"), 
			("xlluaruntime.dll"), 
			("libexpat.dll"), 
			("libpng13.dll"), 
			("xlgraphic.dll"), 
			("xlgraphicplus.dll"),
			("xlue.dll"),
			(PLUGIN_KERNEL_NAME)
		};
		PreReadDll(dllFileName, _countof(dllFileName),szExePath);
		m_hKernel = LoadLibraryA(PLUGIN_KERNEL_NAME);
		if (NULL == m_hKernel)
		{
			return;
		}
		m_bInitOK = TRUE;
	}

	~Pretender()
	{
		if (m_hKernel)
		{
			FreeLibrary(m_hKernel);
			m_hKernel = NULL;
		}

		for (std::list< HMODULE >::reverse_iterator rit = m_modList.rbegin();
			rit != m_modList.rend();
			++rit)
		{
			if (*rit)
			{
				//TSDEBUG(_T("About to FreeLibrary(0x%p)"), *rit);
				::FreeLibrary(*rit);
			}
		}
	}

	static void PreLoadDll(const TCHAR **rgszFileName, ULONG nFileCount, HMODULE *pResult)
	{
		for (unsigned int i = 0; i < nFileCount; ++i)
		{
			pResult[i] = ::LoadLibrary(rgszFileName[i]);
			DWORD dwLastError = ::GetLastError();
			//TSDEBUG(_T("LoadLibrary(%s) return 0x%p, dwLastError = %lu"), rgszFileName[i], pResult[i], dwLastError);
		}
	}

	static void PreReadDll(const CHAR **rgszFileName, ULONG nFileCount, const CHAR * szDir)
	{
		for (unsigned int i = 0; i < nFileCount; ++i)
		{
			const size_t kStepSize = 1024 * 1024;
			CHAR szTmp[MAX_PATH] = {0}; 
			PathCombineA(szTmp,szDir,rgszFileName[i]);
			CImagePreReader::PreReadImage(szTmp, 0, kStepSize);
		}
	}

	BOOL Init(LPTSTR lpCmdLine = NULL)
	{
		BOOL bRet = FALSE;
		if (m_bInitOK)
		{
			//1:先处理单例
			typedef HRESULT (STDAPICALLTYPE * PInitMsgWnd)();
			PInitMsgWnd pInitMsgWnd = (PInitMsgWnd)GetProcAddress(m_hKernel,"InitMsgWnd");
			if(NULL == pInitMsgWnd)
			{
				MessageBox(NULL, L"无法找到 'InitMsgWnd', 请重新安装", L"错误", MB_OK);
				TerminateProcess(GetCurrentProcess(), (UINT)-10);
				return -10;
			}
			HRESULT hr = pInitMsgWnd();
			if(FAILED( hr))
			{
				//处理过了
				TSDEBUG(_T("InitMsgWnd return false, so exit.lpCmdLine = %s"), lpCmdLine);
				return bRet;		
			}

			typedef BOOL (STDAPICALLTYPE * PInitXLUE)(wchar_t*);
			PInitXLUE pInitXLUE = (PInitXLUE)GetProcAddress(m_hKernel, "InitXLUE");
			if (pInitXLUE)
			{
				bRet = pInitXLUE(lpCmdLine);
			}
		}
		return bRet;
	}
private:
	HMODULE m_hKernel;
	BOOL	m_bInitOK;
	std::list< HMODULE > m_modList;
};