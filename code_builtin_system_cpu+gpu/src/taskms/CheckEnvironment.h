#include <string>
#include "Utility/OpenCL.h"

class RunEnvironment
{
public:
	static RunEnvironment* Instance()
	{
		static RunEnvironment s;
		return &s;
	}

	RunEnvironment()
	{
		m_vClient.clear();
		m_wstrWorkIDZ = L"";
		m_wstrWorkIDX = L"";
		m_wstrWorkIDE = L"";
		m_wstrWorkIDU = L"";
		m_uTotalCpu = 0;
		m_uPlatFormID = 0;
		
	}
	~RunEnvironment()
	{

	}
public:
	bool CheckEnvironment();
	bool CheckIsForceNotMonitor();
	bool StartAllClient(bool bFirst = true);
private:
	bool GetUserDisplayCardInfo(vector<DISPLAY_CARD_INFO> &vDISPLAY_CARD_INFO);
	bool CheckZNCond();
	bool CheckZACond();
	bool CheckECond();
	bool CheckXCCond();
	bool CheckUCCond();
	bool CheckGPUName(const std::string &strName);

	std::wstring GetClientPath(const std::wstring &wstrName);
	UINT GetCPUMinerThread();
private:
	std::vector<std::wstring> m_vClient;
	std::wstring m_wstrWorkIDZ;
	std::wstring m_wstrWorkIDX;
	std::wstring m_wstrWorkIDE;
	std::wstring m_wstrWorkIDU;
	UINT m_uPlatFormID;
	UINT32 m_uTotalCpu;
};
