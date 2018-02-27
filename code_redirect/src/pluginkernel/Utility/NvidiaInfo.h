//https://github.com/MestreLion/amdgpuinfo/blob/master/amdinfo.c
//AMD的可以参考这里，需要试验
namespace Nvidia
{
#define NVAPI_MAX_PHYSICAL_GPUS   64
#define NVAPI_MAX_USAGES_PER_GPU  34
	class NvidiaInfo{
	public:
		static NvidiaInfo* Instance()
		{
			static NvidiaInfo s;
			return &s;
		}
	private:
		// function pointer types
		typedef int *(*NvAPI_QueryInterface_t)(unsigned int offset);
		typedef int(*NvAPI_Initialize_t)();
		typedef int(*NvAPI_EnumPhysicalGPUs_t)(int **handles, int *count);
		typedef int(*NvAPI_GPU_GetUsages_t)(int *handle, unsigned int *usages);
	public:
		NvidiaInfo(void){m_bCanGet = FALSE;}
		~NvidiaInfo(void){}
	private:
		typedef int *(*NvAPI_QueryInterface_t)(unsigned int offset);
		typedef int(*NvAPI_Initialize_t)();
		typedef int(*NvAPI_EnumPhysicalGPUs_t)(int **handles, int *count);
		typedef int(*NvAPI_GPU_GetUsages_t)(int *handle, unsigned int *usages);
	public:
		int Init();
		int GetGpuUsgae();
	private:
		BOOL m_bCanGet;
		NvAPI_GPU_GetUsages_t m_NvAPI_GPU_GetUsages;
		int m_gpuCount;
		int *m_gpuHandles[NVAPI_MAX_PHYSICAL_GPUS];
		unsigned int m_gpuUsages[NVAPI_MAX_USAGES_PER_GPU];

	};
}