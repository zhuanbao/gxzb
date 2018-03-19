#pragma once

class CheckAutoRun {
private:
	static bool IsSysAutoRunExist();
	static bool IsSoftwareAutoRunExist();
	static bool IsRealRebootSystem();
public:
	static bool ShouldFixAutoRun();
	static void FixAutoRun();
};
