// ethsetuphelper.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"
#define __CL_ENABLE_EXCEPTIONS
#include "cl.hpp"
#include <vector>
#include <iostream>
#include <sstream>
#include<algorithm>
#include <shlwapi.h>
#pragma comment(lib,"shlwapi.lib")
using namespace std;

bool GetConfigIniFilePath(std::string &strCfgPath)
{
	char szPath[MAX_PATH] = {0};
	GetModuleFileNameA(NULL, szPath, MAX_PATH);
	PathRemoveFileSpecA(szPath);
	PathRemoveFileSpecA(szPath);
	char szCfgPath[MAX_PATH] = {0}; 
	PathCombineA(szCfgPath,szPath,"config\\reg.ini");
	if (!PathFileExistsA(szCfgPath))
	{
		return false;
	}
	strCfgPath = szCfgPath;
	return true;
}
void SetOpenclPlatform(unsigned int uPlatform)
{
	static BOOL bPlatForm = FALSE;
	if (bPlatForm)
	{
		return;
	}
	bPlatForm = TRUE;
	std::string strCfgPath;
	if (!GetConfigIniFilePath(strCfgPath))
	{
		return;
	}
	std::string strPlatform;
	{
		std::stringstream ss;
		ss << uPlatform;
		ss >> strPlatform;
	}
	::WritePrivateProfileStringA("HKCR", "openclplatform", strPlatform.c_str(), strCfgPath.c_str());
}

std::vector<cl::Platform> getPlatforms()
{
	vector<cl::Platform> platforms;
	try
	{
		cl::Platform::get(&platforms);
	}
	catch(cl::Error const& err)
	{

		//if (err.err() == CL_PLATFORM_NOT_FOUND_KHR)
		//ETHCL_LOG("No OpenCL platforms found");
		//else
		//throw err;
	}
	return platforms;
}
#define ETHCL_QUERIED_DEVICE_TYPES (CL_DEVICE_TYPE_GPU | CL_DEVICE_TYPE_ACCELERATOR)

std::vector<cl::Device> getDevices(std::vector<cl::Platform> const& _platforms, unsigned _platformId)
{
	vector<cl::Device> devices;
	unsigned platform_num = min<unsigned>(_platformId, _platforms.size() - 1);
	try
	{
		_platforms[platform_num].getDevices(
			ETHCL_QUERIED_DEVICE_TYPES,
			&devices
			);
	}
	catch (cl::Error const& err)
	{
		// if simply no devices found return empty vector
		//if (err.err() != CL_DEVICE_NOT_FOUND)
		//	throw err;
	}
	return devices;
}

void GetBestPlatform(unsigned int& idxPlatform, unsigned int& idxDevice) {
	//cout<<"GetBestPlatform entry"<<endl;
	cl_ulong maxRet = 0;
	vector<cl::Platform> platforms = getPlatforms();
	if (platforms.empty())
		return;
	//cout<<"GetBestPlatform begin get list..."<<endl;
	for (unsigned i = 0; i < platforms.size(); ++i) {
		vector<cl::Device> devices = getDevices(platforms, i);
		for (unsigned j = 0; j < devices.size(); ++j) {
			cl::Device _device = devices[j];
			cl_ulong result;
			cl::STRING_CLASS name = _device.getInfo<CL_DEVICE_NAME>();
			cl_device_type nType =  _device.getInfo<CL_DEVICE_TYPE>();
			cl_uint maxClockfr =  _device.getInfo<CL_DEVICE_MAX_CLOCK_FREQUENCY>();
			cout<<"maxClockfr = "<<maxClockfr<<endl;
			_device.getInfo(CL_DEVICE_GLOBAL_MEM_SIZE, &result);
			transform(name.begin(), name.end(), name.begin(),  tolower);   
			//必须是非Intel的GPU设备， 排除集显, 显存必须大于等于3G
			if (name.find("intel") == string::npos && nType == CL_DEVICE_TYPE_GPU && result >= 3221225472){
				//if (result >= 2147483648 && result > maxRet) {
				if (result > maxRet) {
					maxRet = result;
					idxPlatform = i;
					idxDevice = j;
					SetOpenclPlatform(idxPlatform);
					//cout<<"GetBestPlatform begin get one, idxPlatform = "<<idxPlatform<<", idxDevice = "<<idxDevice<<endl;
				}
			}
		}
	}	
}

int WINAPI _tWinMain(HINSTANCE hInstance, HINSTANCE /*hPrevInstance*/, LPTSTR lpstrCmdLine, int nCmdShow)
{
	if (LoadLibraryA("opencl.dll") == NULL){
		return 1;
	}
	else{
		unsigned int i = 0xFFFFFFFF, j = 0xFFFFFFFF;
		GetBestPlatform(i, j);
		if (i != 0xFFFFFFFF && j != 0xFFFFFFFF){
			return 0;
		}
		else{
			return 2;
		}
	}
}

