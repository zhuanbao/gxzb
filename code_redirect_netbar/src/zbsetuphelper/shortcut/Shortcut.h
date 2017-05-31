
#pragma once
#include "..\stdafx.h"
#include "utility.h"
#include <shlobj.h>
#include "InvokeShellVerb.h"
using namespace std;
extern "C" typedef HRESULT (__stdcall *PSHGetKnownFolderPath)(  const  GUID& rfid, DWORD dwFlags, HANDLE hToken, PWSTR* pszPath);
// 
//5386 - Pin to taskbar
//5387 - Unpin form taskbar
//51201 - Pin to Windows 10 Start Menu
//51394 - Unpin from Windows 10 Start Menu


#define DEFINE_KNOWN_FOLDER(name, l, w1, w2, b1, b2, b3, b4, b5, b6, b7, b8) \
	EXTERN_C const GUID DECLSPEC_SELECTANY name \
	= { l, w1, w2, { b1, b2,  b3,  b4,  b5,  b6,  b7,  b8 } }

DEFINE_KNOWN_FOLDER(FOLDERID_UserPinned, 0x9E3995AB, 0x1F9C, 0x4F13, 0xB8, 0x27, 0x48, 0xB2, 0x4B, 0x6C, 0x71, 0x74);

BOOL SetAppID4Shortcut(CONST TCHAR* szShortcutPath,CONST TCHAR* szAppID = L"IconAppID_{FEE8E80D-0A47-44DD-AD58-9E7F6F08C4E8}");
BOOL BuildShortcut(CONST TCHAR* szFilePath, CONST TCHAR* szTargetPath, CONST TCHAR* szDescription, CONST TCHAR* szParam = NULL, CONST TCHAR* szIcon = NULL)
{
	TSAUTO();
	CONST TCHAR * szDestPath = szFilePath;
	CONST TCHAR* szSrcPath = szTargetPath;
	//assert(NULL != szDestPath && NULL != szSrcPath);
	if (NULL == szDestPath || NULL == szSrcPath)
	{
		return FALSE;
	}

	TSDEBUG4CXX("<gxzbsetup>shortcut src="<<szSrcPath<<" dest="<<szDestPath<<" param="<<szParam<<" szIcon="<<szIcon);
	CComPtr<IShellLink> psl;
	CComPtr<IPersistFile> ppf;
	HRESULT hRes = ::CoCreateInstance( CLSID_ShellLink, NULL,CLSCTX_INPROC_SERVER, IID_IShellLink,(void **)&psl) ;
	if(FAILED(hRes) && psl)
	{
		TSDEBUG4CXX("Create ShellLink Instance FAILED!!!");
		return FALSE;
	}

	if(NULL != szIcon && PathFileExists(szIcon))
	{
		psl->SetIconLocation(szIcon, 0);
	}		
	else
	{
		psl->SetIconLocation(szSrcPath,0);
	}
	

	psl->SetPath(szSrcPath);
	psl->SetDescription(szDescription);
	psl->SetArguments(szParam);
	TCHAR szWorkDir[MAX_PATH+1] = {0};
	_stprintf_s(szWorkDir,MAX_PATH, _T("%s"),szSrcPath);
	::PathAppend(szWorkDir, TEXT("..\\"));
	psl->SetWorkingDirectory(szWorkDir);

	hRes = psl->QueryInterface( IID_IPersistFile, (void**)&ppf);
	if(FAILED(hRes) && ppf)
	{
		return FALSE;
	}
	hRes = ppf->Save( szDestPath, STGM_READWRITE);
	TSDEBUG4CXX("returns "<< SUCCEEDED(hRes));
	return SUCCEEDED(hRes); 
}

BOOL GetPathDirAndFileName( CONST TCHAR* szPath,TCHAR* szDir,TCHAR* szFileName)
{
	if (szPath ==NULL)
	{
		return FALSE;
	}
	_tcscpy(szFileName,szPath);
	PathStripPath(szFileName);

	wstring wstrPath(szPath);
	wstring wstrDir = wstrPath.substr(0,wcslen(wstrPath.c_str())-wcslen(szFileName));
	_tcscpy(szDir,wstrDir.c_str());
	return TRUE;
}
std::wstring GetUserPinPath()
{
	static std::wstring strUserPinPath(_T(""));

	if (strUserPinPath.length() <= 0)
	{
		HMODULE hModule = LoadLibrary( _T("shell32.dll") );
		if ( hModule == NULL )
		{
			return _T("");
		}
		PSHGetKnownFolderPath SHGetKnownFolderPath = (PSHGetKnownFolderPath)GetProcAddress( hModule, "SHGetKnownFolderPath" );
		if (SHGetKnownFolderPath)
		{
			PWSTR pszPath = NULL;
			HRESULT hr = SHGetKnownFolderPath( FOLDERID_UserPinned, 0, NULL, &pszPath );
			if (SUCCEEDED(hr))
			{
				TSDEBUG4CXX("UserPin Path: " << pszPath);
				strUserPinPath = pszPath;
				::CoTaskMemFree(pszPath);
			}
		}
		FreeLibrary(hModule);
	}
	return strUserPinPath;
}


std::wstring g_strInstDir;
#define PIN_TASKBAR 1
#define PIN_STARTMENU 2
#define UNPIN_TASKBAR 3
#define UNPIN_STARTMENU 4
typedef std::vector<std::wstring> VectorVerbName;
VectorVerbName*  GetVerbNames(BOOL bPin, int flag)
{
	TSAUTO();
	static bool bInit = false;
	static std::vector<std::wstring> vecPinTaskNames;
	static std::vector<std::wstring> vecUnPinTaskNames;
	static std::vector<std::wstring> vecPinStartMenuNames;
	static std::vector<std::wstring> vecUnPinStartMenuNames;
	if (!bInit )
	{	
		bInit = true;
		vecPinTaskNames.push_back(_T("Pin to Tas&kBar"));vecPinTaskNames.push_back(_T("锁定到任务栏"));
		vecPinTaskNames.push_back(_T("固定到任务栏"));
		vecUnPinTaskNames.push_back(_T("UnPin from Tas&kBar"));vecUnPinTaskNames.push_back(_T("从任务栏脱离"));
		vecUnPinTaskNames.push_back(_T("从任务栏取消固定"));
		vecPinStartMenuNames.push_back(_T("锁定到开始菜单"));vecPinStartMenuNames.push_back(_T("附到「开始」菜单"));
		vecUnPinStartMenuNames.push_back(_T("从「开始」菜单脱离"));vecUnPinStartMenuNames.push_back(_T("从「开始」菜单解锁"));
	}
	if (PIN_TASKBAR == flag)
	{	
		return bPin? &vecPinTaskNames : &vecUnPinTaskNames;
	}
	else
	{
		return bPin? &vecPinStartMenuNames : &vecUnPinStartMenuNames;
	}
}

bool VerbNameMatch(TCHAR* tszName, BOOL bPin,int flag)
{
	TSAUTO();
	VectorVerbName *pVec = GetVerbNames(bPin,flag);
	
	VectorVerbName::iterator iter = pVec->begin();
	VectorVerbName::iterator iter_end = pVec->end();

	while(iter!=iter_end)
	{
		std::wstring strName= *iter;
		if ( 0 == _wcsnicmp(tszName,strName.c_str(),strName.length()))
			return true;
		iter ++;
	}
	return false;
}

#define IF_FAILED_OR_NULL_BREAK(rv,ptr) \
{if (FAILED(rv) || ptr == NULL) break;}

#define SAFE_RELEASE(p) { if(p) { (p)->Release(); (p)=NULL; } }
bool PinTo(BOOL bPin,int flag, CONST TCHAR* szPath)
{
	TSAUTO();
	
	TCHAR file_dir[MAX_PATH + 1] = {0};
	TCHAR *file_name;

	wcscpy_s(file_dir,MAX_PATH,szPath);

	PathRemoveFileSpecW(file_dir);
	file_name = PathFindFileName(szPath);


	CComPtr<IShellDispatch> pShellDisp;
	CComPtr<Folder> folder_ptr;
	CComPtr<FolderItem> folder_item_ptr;
	CComPtr<FolderItemVerbs> folder_item_verbs_ptr;


	HRESULT rv = CoCreateInstance( CLSID_Shell, NULL, CLSCTX_SERVER,IID_IDispatch, (LPVOID *) &pShellDisp );
	do 
	{
		IF_FAILED_OR_NULL_BREAK(rv,pShellDisp);
		rv = pShellDisp->NameSpace(_variant_t(file_dir),&folder_ptr);

		IF_FAILED_OR_NULL_BREAK(rv,folder_ptr);
		rv = folder_ptr->ParseName(CComBSTR(file_name),&folder_item_ptr);

		IF_FAILED_OR_NULL_BREAK(rv,folder_item_ptr);
		rv = folder_item_ptr->Verbs(&folder_item_verbs_ptr);

		IF_FAILED_OR_NULL_BREAK(rv,folder_item_verbs_ptr);
		long count = 0;
		folder_item_verbs_ptr->get_Count(&count);

		for (long i = 0; i < count ; ++i)
		{
			FolderItemVerb* item_verb = NULL;
			rv = folder_item_verbs_ptr->Item(_variant_t(i),&item_verb);
			if (SUCCEEDED(rv) && item_verb)
			{
				CComBSTR bstrName;
				item_verb->get_Name(&bstrName);

				if ( VerbNameMatch(bstrName,bPin,flag) )
				{
					TSDEBUG4CXX("Find Verb to Pin:"<< bstrName);
					int i = 0;
					do
					{
						rv = item_verb->DoIt();
						TSDEBUG4CXX("Try Do Verb. NO." << i+1 << ", return="<<rv);
						if (SUCCEEDED(rv))
						{
							::SHChangeNotify(SHCNE_UPDATEDIR|SHCNE_INTERRUPT|SHCNE_ASSOCCHANGED, SHCNF_IDLIST |SHCNF_FLUSH | SHCNF_PATH|SHCNE_ASSOCCHANGED,
								szPath,0);
							Sleep(500);
							return true;
						}else
						{
							Sleep(500);
							rv = item_verb->DoIt();
						}
					}while ( i++ < 3);
						
					break;
				}
			}
		}
	} while (0);
	return false;
}
BOOL InvokeShellVerb(CONST TCHAR* szPath,int type)
{
	if (szPath == NULL)
	{
		return FALSE;
	}

	DWORD id = 0;
	if (type == PIN_TASKBAR)
	{
		id = 5386;
	}
	else if (type == UNPIN_TASKBAR)
	{
		id = 5387;
	}
	else if (type == PIN_STARTMENU)
	{
		id = 51201;
	}
	else if (type == UNPIN_STARTMENU)
	{
		id = 51394;
	}
	else
	{
		return FALSE;
	}
	TCHAR szDir[MAX_PATH] = {0};
	TCHAR szName[MAX_PATH] = {0};
	if (GetPathDirAndFileName(szPath,szDir,szName) == TRUE)
	{
		DWORD id = 5386;
		MyInvokeShellVerb(szDir, szName, &id, true);
	}
	else
	{
		return FALSE;
	}
}

#include <sstream>
extern "C" __declspec(dllexport) void SetInstDir(const char* szInstDir){
	string strInstDir = szInstDir;
	g_strInstDir.clear();
	g_strInstDir.resize(strInstDir.length(), L' ');
	std::copy(strInstDir.begin(), strInstDir.end(), g_strInstDir.begin());
	TSDEBUG4CXX("<gxzbsetup> g_strInstDir:"<< g_strInstDir);
}

//注意：nsis只支持原生C类型， 这里的BOOL应该当做int看待，例如system::call "zbsetuphelper::Pin2Taskbar(i 1)"
extern "C" __declspec(dllexport) BOOL Pin2Taskbar(BOOL bPin)
{
	TSAUTO();
	BOOL ret = FALSE;
	std::wstring strGxzbPath = g_strInstDir + (_T("\\Share4Money.exe"));
	std::wstring strShortcutPath = g_strInstDir + (_T("\\共享赚宝.lnk"));
	
	std::wstring strPinShortcutPath = GetUserPinPath() + _T("\\TaskBar\\共享赚宝.lnk");
	
	if (PathFileExists(strPinShortcutPath.c_str()))
	{	
		TCHAR szPath[MAX_PATH +1] = {0};
		_stprintf_s(szPath,MAX_PATH,_T("%s"),strPinShortcutPath.c_str());
		::ShellExecute(NULL,_T("taskbarunpin"),szPath,NULL,NULL,SW_HIDE);
		DeleteFile(szPath);
		//InvokeShellVerb(szPath,UNPIN_TASKBAR);

		// 更新图标
		::SHChangeNotify(SHCNE_UPDATEDIR|SHCNE_INTERRUPT|SHCNE_ASSOCCHANGED, SHCNF_FLUSH | SHCNF_PATH|SHCNE_ASSOCCHANGED,
						strPinShortcutPath.c_str(),0);
		 Sleep(500);
	}	

	if (bPin)
	{
		ret = BuildShortcut(strShortcutPath.c_str(),strGxzbPath.c_str(),
			_T(""),_T("/sstartfrom toolbar"));

		SetAppID4Shortcut(strShortcutPath.c_str());

		if (ret)
		{
			if (Utility::IsWin10())
			{
				InvokeShellVerb(strShortcutPath.c_str(),PIN_TASKBAR);
			}
			else
			{
				::ShellExecute(NULL,_T("taskbarpin"),strShortcutPath.c_str(),NULL,NULL,SW_HIDE);
			}
		}

		return ret;
	}
	
	return false;
}

extern "C" __declspec(dllexport) BOOL Pin2StartMenu(BOOL bPin)
{
	TSAUTO();
	
	TCHAR tszShortcutPath[MAX_PATH + 1] = {0};
	::SHGetSpecialFolderPath(NULL, tszShortcutPath, CSIDL_COMMON_STARTMENU, FALSE);
	::PathAppend(tszShortcutPath, _T("共享赚宝.lnk"));

	if (Utility::IsVistaOrHigher())
	{
		std::wstring strPinStartMenuPath = GetUserPinPath() + _T("\\StartMenu\\共享赚宝.lnk");
		TCHAR szPath [MAX_PATH +1] = {0};
		_stprintf_s(szPath,MAX_PATH,_T("%s"),strPinStartMenuPath.c_str());
		if (PathFileExists(szPath))
		{	
			::ShellExecute(NULL,_T("startunpin"),szPath,NULL,NULL,SW_HIDE);
			DeleteFile(tszShortcutPath);
			//InvokeShellVerb(szPath,UNPIN_STARTMENU);
			Sleep(1000);
		}
	}else
	{
		PinTo(false,PIN_STARTMENU,tszShortcutPath);
		Sleep(1000);
		DeleteFile(tszShortcutPath);
	}
	
	BOOL ret = TRUE;
	if (bPin)
	{
		std::wstring strGxzbPath = g_strInstDir + _T("\\Share4Money.exe");
		ret = BuildShortcut(tszShortcutPath,strGxzbPath.c_str(),
			_T(""), _T("/sstartfrom startbar"));
		
		// 更新一下图标再pin
		::SHChangeNotify(SHCNE_UPDATEDIR|SHCNE_INTERRUPT|SHCNE_ASSOCCHANGED, SHCNF_IDLIST |SHCNF_FLUSH | SHCNF_PATH|SHCNE_ASSOCCHANGED,
			tszShortcutPath,0);

		Sleep(200);

		SetAppID4Shortcut(tszShortcutPath);

		
		if (Utility::IsVistaOrHigher())
		{
			if (Utility::IsWin10())
			{
				InvokeShellVerb(tszShortcutPath,PIN_STARTMENU);
			}
			else
			{
				::ShellExecute(NULL,_T("startpin"),tszShortcutPath,NULL,NULL,SW_HIDE);
			}
		}
		else
		{
			PinTo(bPin,PIN_STARTMENU,tszShortcutPath);
		}
	}else

	{
		
	}
	
	return ret;

}

BOOL SetAppIDForShortcut( const TCHAR * szPath,TCHAR * szAppID )
{
	TSAUTO();
	::CoInitialize(NULL);
	HRESULT hr = S_OK;
	IShellLink *link = NULL;
	IPersistFile* file = NULL; 
	IPropertyStore* store = NULL; 

	hr = ::CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLink,(void**)(&link));
	if (FAILED(hr))
		goto Clear;

	hr = link->QueryInterface(IID_IPersistFile,(void**)(&file));
	if (FAILED(hr))
		goto Clear;

	hr = file->Load(szPath, STGM_READWRITE);
	if (FAILED(hr))
		goto Clear;
	hr = file->QueryInterface(IID_IPropertyStore,(void**)(&store));
	if (FAILED(hr))
		goto Clear;

	PROPERTYKEY key;
	CLSIDFromString(OLESTR("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), &key.fmtid);
	key.pid = 5;
	PROPVARIANT pv;
	hr = store->GetValue(key, &pv); //pv.vt == VT_EMPTY 或 VT_LPWSTR
	if (FAILED(hr))
		goto Clear;

	PropVariantClear(&pv);

	pv.vt = VT_LPWSTR;
	pv.pwszVal = szAppID;

	hr = store->SetValue(key, pv);
	if (FAILED(hr))
		goto Clear;

	hr = store->Commit();
	if (FAILED(hr))
		goto Clear;

	hr = file->Save(NULL,TRUE);
	if (FAILED(hr))
		goto Clear;
Clear:
	if(store)
		store->Release();
	if (file)
		file->Release();
	if (link)
		link->Release();

	::CoUninitialize();

	return SUCCEEDED(hr);

}

BOOL SetAppID4Shortcut(CONST TCHAR* szShortcutPath,CONST TCHAR* szAppID )
{
	TSAUTO();
	if (!szShortcutPath || _tcslen(szShortcutPath)<=0)
		return false;
	TSDEBUG4CXX("<gxzbsetup> szShortcutPath:"<< szShortcutPath);
	if (!Utility::IsVistaOrHigher())
	{
		TSDEBUG4CXX("<gxzbsetup> operation not Windows 7 or High");
		return false;
	}
	typedef BOOL (__cdecl *PFUN_SetAppIDForShortCut)(CONST TCHAR*,TCHAR*);
	BOOL ret = FALSE;
	static PFUN_SetAppIDForShortCut pFun_SetAppIDForShortCut = SetAppIDForShortcut;
	//安装的时候快捷方式和主程序起来的时候都不设置APPID就能使得图标重合
	if (NULL)
	{
		TSDEBUG4CXX("<gxzbsetup>pFun_SetAppIDForShortCut initialted");
		//多次尝试
		int i = 0;
		while((i++)<10)
		{
			TSDEBUG4CXX("<gxzbsetup>try  SetAppID for No."<< i);
			TCHAR _szAppID [MAX_PATH*10+1] = {0};
			wcsncpy_s(_szAppID,MAX_PATH*10,szAppID,_tcslen(szAppID));
			ret = pFun_SetAppIDForShortCut(szShortcutPath,_szAppID);
			if (ret)
				break;
			Sleep(200);
		}
	}
	TSDEBUG4CXX("<gxzbsetup>SetAppIDForShortCut returns "<< ret);
	return ret;
}