#pragma  once
class CMinerClient
{
public:
	CMinerClient(void)
	{

	}
	~CMinerClient(void)
	{
	}
	
	virtual void ProcessString(const char *szBuffer) = 0;
	virtual void TerminateAllClientInstance() = 0;
	virtual void OnAutoExit(DWORD dwExitCode) = 0;
	virtual void RetSet() = 0;
};