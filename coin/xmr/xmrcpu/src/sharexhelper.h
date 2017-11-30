#pragma once
#ifndef __SHAREXHELPER_H__
#define __SHAREXHELPER_H__

#include<Windows.h>
#include<shlwapi.h>
#include<shlobj.h>
#pragma comment(lib,"shlwapi.lib")
#ifndef FOLDERID_Public

#ifndef DEFINE_KNOWN_FOLDER
#define DEFINE_KNOWN_FOLDER(name, l, w1, w2, b1, b2, b3, b4, b5, b6, b7, b8) \
	EXTERN_C const GUID DECLSPEC_SELECTANY name \
	= { l, w1, w2, { b1, b2,  b3,  b4,  b5,  b6,  b7,  b8 } }
#endif

DEFINE_KNOWN_FOLDER(FOLDERID_Public, 0xDFDF76A2, 0xC82A, 0x4D63, 0x90, 0x6A, 0x56, 0x44, 0xAC, 0x45, 0x73, 0x85);
#endif

extern "C" typedef HRESULT(__stdcall *PSHGetKnownFolderPath)(const  GUID& rfid, DWORD dwFlags, HANDLE hToken, PWSTR* pszPath);



class ShareXHelper
{
public:
	static bool getConfigPath(char* buffer, size_t* size);
	static bool isSaveConfig();
private:
	static char *m_defaultFileName;
};


#endif /* __SHAREXHELPER_H__ */
