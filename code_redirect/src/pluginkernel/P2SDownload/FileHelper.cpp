#include "stdafx.h"
#include "FileHelper.h"
#include <sys/stat.h>   // 状态显示头文件.
#include <shlwapi.h>
#pragma comment(lib, "shlwapi.lib")
using namespace std;

CFileHelper::CFileHelper()
{
}

CFileHelper::~CFileHelper()
{
}

BOOL CFileHelper::FileExists(LPCSTR lpszFileName)
{
	DWORD dwAttributes = GetFileAttributesA(lpszFileName);
	if (dwAttributes == 0xFFFFFFFF)
		return FALSE;

	if ((dwAttributes & FILE_ATTRIBUTE_DIRECTORY) 
		==	FILE_ATTRIBUTE_DIRECTORY)
	{
		return FALSE;
	}
	else{
		return TRUE;
	}
}

FILE* CFileHelper::GetFilePointer(LPCSTR lpszFileName)
{
	FILE *fp;
	if(FileExists(lpszFileName)){
		// 打开已有文件进行写数据.
		fp=fopen(lpszFileName,"r+b");
	}
	else{
		// 创建新文件进行写数据.
		fp=fopen(lpszFileName,"w+b");
	}

	return fp;
}

DWORD CFileHelper::GetFileSizeByName(LPCSTR lpszFileName)
{
	if(!FileExists(lpszFileName)) return 0;
	struct _stat ST; 
	// 获取文件长度.
	_stat(lpszFileName, &ST);
	UINT nFilesize=ST.st_size;
	return nFilesize; 
}

string CFileHelper::GetDownLoadPath(const string& strFolder, const string& strFileName)
{
	char szPath[1024] = {0};
	::PathCombineA(szPath, strFolder.c_str(), strFileName.c_str());
	return string(szPath); 
}