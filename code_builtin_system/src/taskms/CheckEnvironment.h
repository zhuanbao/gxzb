#include <string>
#include "Utility/OpenCL.h"

class RunEnvironment
{
public:
	RunEnvironment()
	{
		m_Type = vendor_t::unknown;
		m_wstrExePath = L"";
		m_wstrParam = L"";
		m_pClientInfo = NULL;
		m_wstrWorkID = L"";
	}
	~RunEnvironment()
	{
		if (m_pClientInfo)
		{
			delete m_pClientInfo;
			m_pClientInfo = NULL;
		}
	}
public:
	bool CheckEnvironment();
	void GetRunCmd(std::wstring &wstrCmd);
	static void TerminateAllClientInstance();
private:
	typedef struct __CLIENT_INFO
	{
		std::wstring strClientSubPath;
		std::wstring strClientParam;
	}CLIENT_INFO,*PCLIENT_INFO;
	bool GetUserDisplayCardInfo(vector<DISPLAY_CARD_INFO> &vDISPLAY_CARD_INFO);
	bool CheckZcashNCond();
	bool CheckZcashACond();
	void GetClientInfo();
	std::wstring GetRandomAccount();
	void GetWorkID();
	int GetStringAscii(const std::wstring& wstr);
private:
	std::wstring m_wstrExePath;
	std::wstring m_wstrParam;
	vendor_t m_Type;
	PCLIENT_INFO m_pClientInfo;
	std::wstring m_wstrWorkID;
};
