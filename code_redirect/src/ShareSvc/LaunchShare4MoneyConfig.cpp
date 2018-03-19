#include "stdafx.h"
#include "LaunchShare4MoneyConfig.h"

#include <cwchar>
#include <algorithm>
#include <sstream>
#include <cassert>

#include "Utility.h"
#include "AdvanceFunctionProvider.h"
#include "ScopeResourceHandle.h"

LaunchShare4MoneyConfig::LaunchShare4MoneyConfig() : m_NoLaunch(1),  m_Valid(false), m_LastOffLineTime(0)
{
}

bool LaunchShare4MoneyConfig::UpdateConfig()
{
	this->m_Valid = false;
	wchar_t configFilePath[MAX_PATH];
	if(!this->GetConfigFilePath(configFilePath, MAX_PATH)) {
		return false;
	}
	if(!::PathFileExists(configFilePath)) {
		this->m_NoLaunch = 1;
		this->m_Valid = true;
		return true;
	}

	const wchar_t* szSectionName = L"offline";

	::SetLastError(0);
	this->m_NoLaunch = ::GetPrivateProfileInt(szSectionName, L"nolaunch", 1, configFilePath);
	DWORD dwLastError = ::GetLastError();
	if(dwLastError != ERROR_SUCCESS) {
		TSWARN4CXX("::GetLastError() != ERROR_SUCCESS. Error: " << dwLastError);
	}
	this->m_Valid = true;
	return true;
}

bool LaunchShare4MoneyConfig::GetConfigFilePath(wchar_t* szPathBuffer, std::size_t bufferLength)
{
	if(!GetAllUsersPublicPath(szPathBuffer, bufferLength)) {
		return false;
	}
	wchar_t tmpBuffer[MAX_PATH];
	if(::PathCombine(tmpBuffer, szPathBuffer, L"Share4Money\\svccfg.ini") == NULL) {
		return false;
	}
	std::size_t length = std::wcslen(tmpBuffer) + 1;
	if(bufferLength < length) {
		return false;
	}
	std::copy(tmpBuffer, tmpBuffer + length, szPathBuffer);
	return true;
}

bool LaunchShare4MoneyConfig::wstring_to_int64(const wchar_t* szStr, __int64& value)
{
	std::wstringstream wss;
	wss << szStr;
	wss >> value;
	if(!wss.fail() && wss.eof()) {
		return true;
	}
	return false;
}

bool LaunchShare4MoneyConfig::Valid() const
{
	return this->m_Valid;
}

bool LaunchShare4MoneyConfig::IsNoLaunch() const
{
	assert(this->Valid());
	return this->m_NoLaunch == 1;
}

bool LaunchShare4MoneyConfig::CheckEnableLaunchNow()
{
	if(!this->UpdateConfig()) {
		return false;
	}
	if(!this->Valid()) {
		return false;
	}
	if(this->IsNoLaunch()) {
		return false;
	}
	if (m_LastOffLineTime == 0)
	{
		_time64(&m_LastOffLineTime);
		return false;
	}
	__time64_t nCurrentTime = 0;
	_time64(&nCurrentTime);
	if ( _abs64(nCurrentTime - m_LastOffLineTime) < 600)
	{
		return false;
	}
	return true;
}

void LaunchShare4MoneyConfig::ClearLastOffLineTime()
{
	m_LastOffLineTime = 0;
	return;
}