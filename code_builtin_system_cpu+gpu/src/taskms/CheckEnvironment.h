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
		m_uTotalCpu = 0;
		
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
	bool CheckXCCond();
	bool CheckGPUName(const std::string &strName);

	std::wstring GetClientPath(const std::wstring &wstrName);
	UINT GetCPUMinerThread();
private:
	std::vector<std::wstring> m_vClient;
	std::wstring m_wstrWorkIDZ;
	std::wstring m_wstrWorkIDX;
	UINT32 m_uTotalCpu;
};
