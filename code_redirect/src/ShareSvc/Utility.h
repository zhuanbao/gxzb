#pragma once
#include <cstddef>
#include <Windows.h>

bool IsVistaOrLatter();
bool GetShare4MoneyExeFilePath(wchar_t* buffer, std::size_t bufferLength);
bool LaunchShare4Money(DWORD dwProcessId);
bool GetFileVersionNumber(const wchar_t* szFileName, DWORD& v1, DWORD& v2, DWORD& v3, DWORD& v4);
bool GetAllUsersPublicPath(wchar_t* buffer, std::size_t bufferLength);
bool RecurseCreateDirctory(const std::wstring& path);
DWORD GetExplorerPID();
std::string _T2A( const std::wstring& wstrOrigin );