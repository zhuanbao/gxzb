#include "stdafx.h"

#include <windows.h>
#include <iostream>
#include "NvidiaInfo.h"
namespace Nvidia {
// magic numbers, do not change them


// function pointer types

	BOOL NvidiaInfo::Init()
	{
		HMODULE hmod = LoadLibraryA("nvapi.dll");
		if (hmod == NULL)
		{
			//std::cerr << "[GetNvidiaGpuUsgae] Couldn't find nvapi.dll" << std::endl;
			TSDEBUG4CXX(L"[GetNvidiaGpuUsgae] Couldn't find nvapi.dll");
			return -1;
		}

		// nvapi.dll internal function pointers
		NvAPI_QueryInterface_t      NvAPI_QueryInterface = NULL;
		NvAPI_Initialize_t          NvAPI_Initialize = NULL;
		NvAPI_EnumPhysicalGPUs_t    NvAPI_EnumPhysicalGPUs = NULL;
		//NvAPI_GPU_GetUsages_t       NvAPI_GPU_GetUsages = NULL;

		// nvapi_QueryInterface is a function used to retrieve other internal functions in nvapi.dll
		NvAPI_QueryInterface = (NvAPI_QueryInterface_t)GetProcAddress(hmod, "nvapi_QueryInterface");

		// some useful internal functions that aren't exported by nvapi.dll
		NvAPI_Initialize = (NvAPI_Initialize_t)(*NvAPI_QueryInterface)(0x0150E828);
		NvAPI_EnumPhysicalGPUs = (NvAPI_EnumPhysicalGPUs_t)(*NvAPI_QueryInterface)(0xE5AC921F);
		m_NvAPI_GPU_GetUsages = (NvAPI_GPU_GetUsages_t)(*NvAPI_QueryInterface)(0x189A1FDF);

		if (NvAPI_Initialize == NULL || NvAPI_EnumPhysicalGPUs == NULL ||
			NvAPI_EnumPhysicalGPUs == NULL || m_NvAPI_GPU_GetUsages == NULL)
		{
			//std::cerr << "Couldn't get functions in nvapi.dll" << std::endl;
			TSDEBUG4CXX(L"[GetNvidiaGpuUsgae] Couldn't get functions in nvapi.dll");
			FreeLibrary(hmod);
			return -2;
		}

		// initialize NvAPI library, call it once before calling any other NvAPI functions
		(*NvAPI_Initialize)();

		//int          gpuCount = 0;
		//int         *gpuHandles[NVAPI_MAX_PHYSICAL_GPUS] = { NULL };
		//unsigned int gpuUsages[NVAPI_MAX_USAGES_PER_GPU] = { 0 };

		m_gpuUsages[0] = (NVAPI_MAX_USAGES_PER_GPU * 4) | 0x10000;
		(*NvAPI_EnumPhysicalGPUs)(m_gpuHandles, &m_gpuCount);
		m_bCanGet = TRUE;
		TSDEBUG4CXX(L"[GetNvidiaGpuUsgae] init ok");
		return 0;

	}
	int NvidiaInfo::GetGpuUsgae()
	{
		static BOOL bInit = FALSE;
		if (!bInit)
		{
			bInit = TRUE;
			Init();
		}
		if (m_bCanGet)
		{
			(*m_NvAPI_GPU_GetUsages)(m_gpuHandles[0], m_gpuUsages);
			int usage = m_gpuUsages[3];
			//TSDEBUG4CXX(L"[GetNvidiaGpuUsgae] usage = " << usage);
			//FreeLibrary(hmod);
			return usage;
		}
		return 0;
	}

}