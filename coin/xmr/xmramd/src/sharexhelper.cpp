#include "sharexhelper.h"


char *ShareXHelper::m_defaultFileName = "configxa.json";

bool ShareXHelper::getConfigPath(char* buffer, size_t* size)
{
	HMODULE hModule = ::LoadLibraryA("shell32.dll");
	PSHGetKnownFolderPath SHGetKnownFolderPath = (PSHGetKnownFolderPath)GetProcAddress(hModule, "SHGetKnownFolderPath");
	if (SHGetKnownFolderPath)
	{
		PWSTR szPath = NULL;
		HRESULT hr = SHGetKnownFolderPath(FOLDERID_Public, 0, NULL, &szPath);
		if (FAILED(hr))
		{
			FreeLibrary(hModule);
			return false;
		}
		if (0 == WideCharToMultiByte(CP_ACP, 0, szPath, -1, buffer, MAX_PATH, NULL, NULL))
		{
			return false;
		}
		::CoTaskMemFree(szPath);
		FreeLibrary(hModule);
	}
	else
	{
		HRESULT hr = SHGetFolderPathA(NULL, CSIDL_COMMON_APPDATA, NULL, SHGFP_TYPE_CURRENT, buffer);
		if (FAILED(hr))
		{
			return false;
		}
	}
	::PathAppendA(buffer, "Share4Money\\ShareX");
	::PathAppendA(buffer, m_defaultFileName);
	return true;
}