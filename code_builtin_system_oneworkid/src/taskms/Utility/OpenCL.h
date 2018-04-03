#define __CL_ENABLE_EXCEPTIONS
#include "cl.hpp"
#include <vector>
using namespace std;
#define ETHCL_QUERIED_DEVICE_TYPES (CL_DEVICE_TYPE_GPU | CL_DEVICE_TYPE_ACCELERATOR)

enum vendor_t {
	intel,
	amd,
	nvidia,
	microsoft,
	qualcomm,
	unknown,
	cpu,
};

typedef struct __DISPLAY_CARD_INFO 
{
	vendor_t vendor;
	std::string name;
	std::string version;
	cl_ulong memory_size;
	cl_ulong cache_size;
	cl_uint platformid;

}DISPLAY_CARD_INFO,*PDISPLAY_CARD_INFO;


inline vendor_t Parse_Vendor(const char* name) {
	if(!stricmp(name, "Intel(R) Corporation"))
		return vendor_t::intel;
	else if(!stricmp(name, "Advanced Micro Devices, Inc."))
		return vendor_t::amd;
	else if(!stricmp(name, "NVIDIA Corporation"))
		return vendor_t::nvidia;
	else
		return vendor_t::unknown;
}

inline std::vector<cl::Platform> getPlatforms()
{
	vector<cl::Platform> platforms;
	try
	{
		cl::Platform::get(&platforms);
	}
	catch(cl::Error const& err)
	{
		err;
		//if (err.err() == CL_PLATFORM_NOT_FOUND_KHR)
		//ETHCL_LOG("No OpenCL platforms found");
		//else
		//throw err;
	}
	return platforms;
}

inline std::vector<cl::Device> getDevices(std::vector<cl::Platform> const& _platforms, unsigned _platformId)
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


inline void GetDisplayCardInfo(vector<DISPLAY_CARD_INFO> &vDISPLAY_CARD_INFO) 
{
	vector<cl::Platform> v_clPlatforms = getPlatforms();
	if (v_clPlatforms.empty())
		return;
	for (unsigned uPlatformIndex = 0; uPlatformIndex < v_clPlatforms.size(); ++uPlatformIndex)
	{
		vector<cl::Device> v_clDevices = getDevices(v_clPlatforms, uPlatformIndex);
		for (unsigned uIndex = 0; uIndex < v_clDevices.size(); ++uIndex) 
		{
			cl::Device _clDevice = v_clDevices[uIndex];
			
			cl::STRING_CLASS strName = _clDevice.getInfo<CL_DEVICE_NAME>();

			cl_device_type nType =  _clDevice.getInfo<CL_DEVICE_TYPE>();
			
			cl_ulong uGLOBAL_MEM_SIZE = 0;
			_clDevice.getInfo(CL_DEVICE_GLOBAL_MEM_SIZE, &uGLOBAL_MEM_SIZE);
			
			cl_ulong uGLOBAL_MEM_CACHE_SIZE = 0;
			_clDevice.getInfo(CL_DEVICE_GLOBAL_MEM_CACHE_SIZE, &uGLOBAL_MEM_CACHE_SIZE);

			cl::STRING_CLASS strVersion= _clDevice.getInfo<CL_DRIVER_VERSION>();

			cl::STRING_CLASS strVendor= _clDevice.getInfo<CL_DEVICE_VENDOR>();

			if (nType == CL_DEVICE_TYPE_GPU )
			{
				PDISPLAY_CARD_INFO pInfo = new  DISPLAY_CARD_INFO();
				pInfo->memory_size = uGLOBAL_MEM_SIZE;
				pInfo->cache_size = uGLOBAL_MEM_CACHE_SIZE;
				pInfo->vendor = Parse_Vendor(strVendor.c_str());
				pInfo->name = strName;
				pInfo->version = strVersion;
				pInfo->platformid = uPlatformIndex;
				vDISPLAY_CARD_INFO.push_back(*pInfo);

			}
		}
	}
}