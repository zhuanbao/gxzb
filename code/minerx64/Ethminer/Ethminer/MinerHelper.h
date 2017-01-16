#pragma once
#include <tchar.h>
#include <vector>
#include <Windows.h>
#include <thread>
#include <iostream>
#include <shlobj.h>
#include <Shlwapi.h>
#include "MsgWindow.h"

//进程退出码 exitcode
//-1:参数错误
//1:没有找到合适的显卡设备，显存不够
//2:自动检测显卡设备，没有找到合适的显卡设备（排除了 interl显卡）



//消息
//创建DAG相关
#define WM_USER_DAG		WM_USER+701
//通过wParam指定DAG消息类型
#define DAG_START_CREATE 0
#define DAG_CREATE_PROGRESS 1
#define DAG_CREATE_SUCCESS 2
#define DAG_CREATE_FAIL 3


//WM_COPYDATA 通过wParam指定消息类型
//上报速度
#define WP_SPEED		    100

//上报找到答案
#define WP_SOLUTION		    200

struct SOLUTION_SS
{
	char sz_nonce[MAX_PATH];
	char sz_headerHash[MAX_PATH];
	char sz_mixHash[MAX_PATH];

};

inline void PostMessageToUserWnd(UINT Msg, WPARAM wParam, LPARAM lParam)
{
	static HWND hUserWnd = NULL;
	if (NULL == hUserWnd)
	{
		hUserWnd = FindWindowA("UserWnd_{FEE8E80D-0A47-44DD-AD58-9E7F6F08C4E8}", NULL);
	}
	if (hUserWnd && ::IsWindow(hUserWnd)) {
		PostMessageA(hUserWnd, Msg, wParam, lParam);
	}
}

inline void SendMessageToUserWnd(UINT Msg, WPARAM wParam, LPARAM lParam)
{
	static HWND hUserWnd = NULL;
	if (NULL == hUserWnd)
	{
		hUserWnd = FindWindowA("UserWnd_{FEE8E80D-0A47-44DD-AD58-9E7F6F08C4E8}", NULL);
	}
	if (hUserWnd && ::IsWindow(hUserWnd)) {
		SendMessageA(hUserWnd, Msg, wParam, lParam);
	}
}



inline std::string GetUpperPath(const std::string strPath)
{
	size_t nPos = strPath.rfind("\\");
	if (nPos == std::string::npos)
	{
		return strPath;
	}
	if (nPos == (strPath.length() - 1))
	{
		return GetUpperPath(std::string(strPath.c_str(), strPath.length() - 1));
	}
	return strPath.substr(0, nPos + 1);
}

inline void DeleteUselessDagFile(std::string &strCurDag, std::string &strNextDag)
{
	std::string strDir = GetUpperPath(strCurDag);
	std::string strCurtDagName = strCurDag.substr(strCurDag.find_last_of('\\') + 1);
	std::string strNextDagName = strNextDag.substr(strNextDag.find_last_of('\\') + 1);
	std::string strFlag = "*.*";
	CHAR szSearchPath[MAX_PATH] = { 0 };
	::PathCombineA(szSearchPath, strDir.c_str(), strFlag.c_str());
	WIN32_FIND_DATAA fd;
	HANDLE hFind = INVALID_HANDLE_VALUE;
	hFind = FindFirstFileA(szSearchPath, &fd);
	while (INVALID_HANDLE_VALUE != hFind)
	{
		if (stricmp(fd.cFileName, (".."))
			&& stricmp(fd.cFileName, ("."))
			&& stricmp(fd.cFileName, strCurtDagName.c_str())
			&& stricmp(fd.cFileName, strNextDagName.c_str())
			&& FILE_ATTRIBUTE_DIRECTORY != fd.dwFileAttributes)
		{
			CHAR szLnkFileTmp[MAX_PATH] = { 0 };
			PathCombineA(szLnkFileTmp, strDir.c_str(), fd.cFileName);
			cout << "delete dag file = " << szLnkFileTmp << endl;
			DeleteFileA(szLnkFileTmp);

		}

		if (FindNextFileA(hFind, &fd) == 0)
		{
			break;
		}
	}
	FindClose(hFind);

	return;
}

inline bool IsDebug()
{
#if defined _DEBUG
	return true;
#else
	return true;
#endif
}

