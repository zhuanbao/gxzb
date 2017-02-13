// ethsetuphelper.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"
#define __CL_ENABLE_EXCEPTIONS
#include "cl.hpp"
#include <vector>
#include <iostream>
#include<algorithm>
using namespace std;


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
			transform(name.begin(), name.end(), name.begin(),  toupper);   
			//必须是非Intel的GPU设备， 排除集显, 显存必须大于等于2G
			if (name.find("intel") == string::npos && nType == CL_DEVICE_TYPE_GPU && result >= 2147483648){
				//if (result >= 2147483648 && result > maxRet) {
				if (result > maxRet) {
					maxRet = result;
					idxPlatform = i;
					idxDevice = j;
					//cout<<"GetBestPlatform begin get one, idxPlatform = "<<idxPlatform<<", idxDevice = "<<idxDevice<<endl;
				}
			}
		}
	}	
}

int _tmain(int argc, _TCHAR* argv[])
{
	unsigned int i = 0xFFFFFFFF, j = 0xFFFFFFFF;
	GetBestPlatform(i, j);
	if (i != 0xFFFFFFFF && j != 0xFFFFFFFF){
		cout<<"i = "<<i<<", j = "<<j<<endl;
		return 0;
	}
	else{
		cout<<"null"<<endl;
		/*char szPath[MAX_PATH+1] = {0};
		GetModuleFileNameA(NULL, szPath, MAX_PATH);
		cout<<szPath<<endl;
		char* pTail = (char*)strrchr(szPath, '\\');
		if (pTail == NULL){
			 pTail = strrchr(szPath, '/');
		}
		if (pTail != NULL){
			++pTail;
			while (*pTail != '\0'){
				*pTail = '\0';
				++pTail;
			}
			strcat(szPath, "error");
			cout<<szPath<<endl;
			CreateFileA(szPath, GENERIC_WRITE, FILE_SHARE_READ, NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
		}*/
		return 1;
	}
}

