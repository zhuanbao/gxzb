//USER0: 2345


#define USER0

#if defined (USER0)
	#define  Z_ACCOUNT  L"t1dv5fUkQgdkjePcuDTUBXa3ESFwwD9vfEv"
	#define  X_ACCOUNT  L"47knn7zNdNNiGxs211vzTRUEQ3w5fhRsWWWL9UYdWaJPCbbDfobbvvhFZPNAzHBtuh2CJNVr8DtE37WiyJ4hnkEYGThvZtP"
	#define  CHANNEL  L"0001"
	#define  CHECKCARD  true
	#define  NOT_MONITOR  false
	#define  ZA_CMD  L"-zpool zec.f2pool.com:3357 -zwal %s.%s -zpsw x -i 0 -li 1 -dbg -1"
	#define  GPU_MEMORYSIZE  2000000000
	#define  GPU_N_NAME  {"950","960","970","980","1050","11060","1070","1080","2050","2060","2070","2080", "titan xp", "titan v", "titan z", "titan x"}

#elif defined (USER1)
	#define  ACCOUNT  L"t1dv5fUkQgdkjePcuDTUBXa3ESFwwD9vfEv"
	#define  CHANNEL  L"0001"
	#define  CLIENT_Z
	#define  CLIENT_X
	#define  CHECKCARD  true
	#define  NOT_MONITOR  false
	#define  ZA_CMD  L"-zpool zec.f2pool.com:3357 -zwal %s.%s -zpsw x -i 0 -li 1 -dbg -1"
	#define  GPU_MEMORYSIZE  2000000000
	#define  GPU_N_NAME  {"950","960","970","980","1050","1060","1070","1080","2050","2060","2070","2080", "titan xp", "titan v", "titan z", "titan x"}

#else
	//test
	//#define  ACCOUNT  L"t1UkC3HsNNe9AC28qTxBesiCGv2MXaQRgmZ"
	//#define  CHANNEL  L"0005"
	//#define  USERID_Z  L"wiaa35wm"
	////#define  USERID_X  L"wiaa4fg8"
	//#define  CHECKCARD  true
	//#define  NOT_MONITOR  false
	//#define  ZA_CMD  L"-zpool zec.f2pool.com:3357 -zwal %s.%s -zpsw x -i 0 -li 1 -dbg -1"
	//#define  GPU_MEMORYSIZE  2000000000
	//#define  GPU_N_NAME  {"950","960","970","980","1050","10601","1070","1080","2050","2060","2070","2080", "titan xp", "titan v", "titan z", "titan x"}
#endif