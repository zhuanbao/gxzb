class WinApiHooker {
	typedef BOOL (WINAPI *ExitWindowsEx_FuncType)(UINT uFlags,  DWORD dwReason);
	typedef BOOL (WINAPI *InitiateSystemShutdown_FuncType)(LPTSTR lpMachineName, LPTSTR lpMessage, DWORD dwTimeout, BOOL bForceAppsClosed, BOOL bRebootAfterShutdown);
	typedef BOOL (WINAPI *InitiateSystemShutdownEx_FuncType)(LPTSTR lpMachineName, LPTSTR lpMessage, DWORD dwTimeout, BOOL bForceAppsClosed, BOOL bRebootAfterShutdown, DWORD dwReason);
private:

	static ExitWindowsEx_FuncType Real_ExitWindowsEx;
	static InitiateSystemShutdown_FuncType Real_InitiateSystemShutdown;
	static InitiateSystemShutdownEx_FuncType Real_InitiateSystemShutdownEx;
private:
	static bool IsHooked;
private:

public:
	static BOOL WINAPI Hooked_ExitWindowsEx(UINT uFlags,  DWORD dwReason);
	static BOOL WINAPI Hooked_InitiateSystemShutdown(LPTSTR lpMachineName, LPTSTR lpMessage, DWORD dwTimeout, BOOL bForceAppsClosed, BOOL bRebootAfterShutdown);
	static BOOL WINAPI Hooked_InitiateSystemShutdownEx(LPTSTR lpMachineName, LPTSTR lpMessage, DWORD dwTimeout, BOOL bForceAppsClosed, BOOL bRebootAfterShutdown, DWORD dwReason);
public:
	static bool AttachHook();
	static void DetachHook();
};