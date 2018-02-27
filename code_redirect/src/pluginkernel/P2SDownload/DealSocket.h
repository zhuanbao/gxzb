#pragma once
#include <WinSock.h>
class CDealSocket  
{
public:
	CDealSocket();
	virtual ~CDealSocket();

public:
	SOCKET GetConnect(const string& host ,int port);
	SOCKET Listening(int port);
	string GetResponse(SOCKET hSock);
};