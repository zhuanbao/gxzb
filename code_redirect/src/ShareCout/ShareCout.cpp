// ShareCout.cpp : Defines the entry point for the console application.
//
#include "stdafx.h"
#include <windows.h>
#include <tchar.h>

#define TSLOG
#define TSLOG_GROUP "GXZB"	//可选,默认为 "TSLOG"
#include <tslog/tslog.h>

#define SLEEP_TIME 10 // reactivity: sleep time to wait for subprocess to output some more data

CONST COORD origin = { 0, 0 };

int _tmain(int argc, _TCHAR* argv[])
{
	// get pipe/console to output to
	HANDLE hOutput = GetStdHandle(STD_OUTPUT_HANDLE);
	DWORD dwDummy;

	// parse command line : skip to RTconsole's arguments
	LPTSTR pszCommandLine = GetCommandLine();
	if (*pszCommandLine == '"')
		pszCommandLine = _tcschr(pszCommandLine+1, _T('"'));
	else
		pszCommandLine = _tcspbrk(pszCommandLine, _T(" \t"));
	if (!pszCommandLine) return -1;
	pszCommandLine += _tcsspn(pszCommandLine+1, _T(" \t"))+1;
	if (pszCommandLine[0] == '\0') return -1;

	// prepare the console window & inherited screen buffer
	SECURITY_ATTRIBUTES sa;
	sa.nLength = sizeof(sa);
	sa.lpSecurityDescriptor = NULL;
	sa.bInheritHandle = TRUE;
	HANDLE hConsole = CreateConsoleScreenBuffer(GENERIC_READ|GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE,&sa,CONSOLE_TEXTMODE_BUFFER,NULL);
	FillConsoleOutputCharacter(hConsole, '\0', MAXLONG, origin, &dwDummy); // fill screen buffer with zeroes
	SetStdHandle(STD_OUTPUT_HANDLE, hConsole); // to be inherited by child process

	// start the subprocess
	PROCESS_INFORMATION pi;
	STARTUPINFO si;
	ZeroMemory(&si, sizeof(STARTUPINFO));
	si.cb = sizeof(STARTUPINFO);
	si.dwFlags = STARTF_FORCEOFFFEEDBACK; // we don't want the "app starting" cursor
	// all other default options are already good : we want subprocess to share the same console and to inherit our STD handles
	TSDEBUG4CXX(L"pszCommandLine = "<< pszCommandLine); 
	if (!CreateProcess(	NULL, pszCommandLine, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi))
	{
		TSDEBUG4CXX(L"create process failed, last error = "<< GetLastError()); 
		CloseHandle(hConsole);
		return -2;
	}
	CloseHandle(pi.hThread); // always close the hThread after a CreateProcess

	COORD lastpos = { 0, 0 };
	CONSOLE_SCREEN_BUFFER_INFO csbi;
	bool bExitNow = false;
	do
	{
		if (WaitForSingleObject(pi.hProcess, 0) != WAIT_TIMEOUT)
			bExitNow = true; // exit after this last iteration

		// get screen buffer state
		GetConsoleScreenBufferInfo(hConsole, &csbi);
		int iLineWidth = csbi.dwSize.X;

		if ((csbi.dwCursorPosition.X == lastpos.X) && (csbi.dwCursorPosition.Y == lastpos.Y))
			Sleep(SLEEP_TIME); // text cursor did not move, sleep a while
		else
		{
			DWORD dwCnt = (csbi.dwCursorPosition.Y-lastpos.Y)*iLineWidth+csbi.dwCursorPosition.X-lastpos.X;
			// read newly output characters starting from last cursor position
			LPTSTR szBuffer = (LPTSTR) LocalAlloc(0, dwCnt*sizeof(TCHAR));
			ReadConsoleOutputCharacter(hConsole, szBuffer, dwCnt, lastpos, &dwCnt);
			// fill screen buffer with zeroes
			FillConsoleOutputCharacter(hConsole, '\0', dwCnt, lastpos, &dwDummy);

			SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_TIME_CRITICAL);
			lastpos = csbi.dwCursorPosition;
			GetConsoleScreenBufferInfo(hConsole, &csbi);
			if ((csbi.dwCursorPosition.X == lastpos.X) && (csbi.dwCursorPosition.Y == lastpos.Y))
			{ // text cursor did not move since this treatment, hurry to reset it to home
				SetConsoleCursorPosition(hConsole, origin);
				lastpos = origin;
			}
			SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_NORMAL);

			// scan screen buffer and transmit character to real output handle
			LPTSTR szScan = szBuffer;
			do
			{
				if (*szScan)
				{
					DWORD dwLen = 1;
					while (szScan[dwLen] && (dwLen < dwCnt))
						dwLen++;
					WriteFile(hOutput, szScan, dwLen, &dwDummy, NULL);
					szScan += dwLen;
					dwCnt -= dwLen;
				}
				else
				{
					DWORD dwLen = 1;
					while (!szScan[dwLen] && (dwLen < dwCnt))
						dwLen++;
					szScan += dwLen;
					dwCnt -= dwLen;
					dwLen = (dwLen+iLineWidth-1)/iLineWidth;
					for (;dwLen;dwLen--)
						WriteFile(hOutput, "\r\n", 2, &dwDummy, NULL);
				}
			} while (dwCnt);
			//FlushFileBuffers(hOutput); // seems unnecessary
			LocalFree(szBuffer);
		}
		// loop until end of subprocess
	} while (!bExitNow);

	CloseHandle(hConsole);
	FlushFileBuffers(hOutput);
	// release subprocess handle
	DWORD dwExitCode;
	if (!GetExitCodeProcess(pi.hProcess, &dwExitCode))
		dwExitCode = -3;
	CloseHandle(pi.hProcess); 
	TSDEBUG4CXX(L"dwExitCode = "<< dwExitCode); 
	return dwExitCode;
}


