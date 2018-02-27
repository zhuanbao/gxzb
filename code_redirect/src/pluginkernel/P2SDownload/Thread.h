#ifndef _THREAD_SPECIFICAL_H__
#define _THREAD_SPECIFICAL_H__

#define    WIN32_LEAN_AND_MEAN   //防止windows.h引入winsock.h与winsock2.h冲突
#include   <windows.h>   

static unsigned int __stdcall threadFunction(void *);

class Thread {
   friend unsigned int __stdcall threadFunction(void *);
public:
   Thread();
   virtual ~Thread();
   int start(void * = NULL);//线程启动函数，其输入参数是无类型指针。
   void stop();
   void* join();//等待当前线程结束
   void detach();//不等待当前线程
   static void sleep(unsigned int);//让当前线程休眠给定时间，单位为毫秒

protected:
   virtual void * run(void *) = 0;//用于实现线程类的线程函数调用

private:
   HANDLE threadHandle;
   bool started;
   bool detached;
   void * param;
   unsigned int threadID;
};

#endif