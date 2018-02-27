#pragma once

bool IsInjected(DWORD dwPID);
bool InjectDll(DWORD dwPID, const wchar_t* dllPath);
