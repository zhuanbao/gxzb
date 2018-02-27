#pragma once
class CFileHelper  
{
public:
	CFileHelper();
	virtual ~CFileHelper();

public:
	BOOL FileExists(LPCSTR lpszFileName);
	FILE* GetFilePointer(LPCSTR lpszFileName);
	DWORD GetFileSizeByName(LPCSTR lpszFileName);
	string GetDownLoadPath(const string& strFolder, const string& strFileName);
};