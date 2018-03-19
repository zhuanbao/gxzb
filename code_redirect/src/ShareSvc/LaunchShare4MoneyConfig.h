#pragma once
#include <Windows.h>
#include <cstddef>
#include <ctime>

class LaunchShare4MoneyConfig {
private:
	UINT m_NoLaunch;
	bool m_Valid;
	__time64_t m_LastOffLineTime;
public:
	LaunchShare4MoneyConfig();
	bool UpdateConfig();
	bool Valid() const;
	bool IsNoLaunch() const;
	bool CheckEnableLaunchNow();
	void ClearLastOffLineTime();
private:
	bool GetConfigFilePath(wchar_t* szPathBuffer, std::size_t bufferLength);
	bool wstring_to_int64(const wchar_t* szStr, __int64& value);
};
