#pragma once
#include <Windows.h>
bool IsContainFileName(const wchar_t* szFileName, const wchar_t* szBlackName);
bool IsUser();
UINT WINAPI DoCheck(PVOID pArg);