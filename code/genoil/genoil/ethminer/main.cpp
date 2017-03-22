/*
	This file is part of cpp-ethereum.

	cpp-ethereum is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	cpp-ethereum is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with cpp-ethereum.  If not, see <http://www.gnu.org/licenses/>.
*/
/** @file main.cpp
 * @author Gav Wood <i@gavwood.com>
 * @date 2014
 * Ethereum client.
 */

// Solves the problem of including windows.h before including winsock.h
// as detailed here:
// http://stackoverflow.com/questions/1372480/c-redefinition-header-files-winsock2-h
#if defined(_WIN32)
#define _WINSOCKAPI_
#include <windows.h>
#endif

#include <thread>
#include <chrono>
#include <fstream>
#include <iostream>
#include <signal.h>
#include <boost/algorithm/string.hpp>
#include <boost/algorithm/string/trim_all.hpp>
#include <libdevcore/FileSystem.h>
#include "MinerAux.h"

#include "MsgWndIPC.h"
#include <libethcore/EthashGPUMiner.h>

using namespace std;
using namespace dev;
using namespace dev::eth;
using namespace boost::algorithm;

#undef RETURN

void version()
{
	cout << "ethminer version " << dev::Version << endl;
	cout << "Build: " << DEV_QUOTED(ETH_BUILD_PLATFORM) << "/" << DEV_QUOTED(ETH_BUILD_TYPE) << endl;
	exit(0);
}

int main(int argc, char** argv)
{
	/*
	cout << "Genoil's ethminer " << ETH_PROJECT_VERSION << endl;
	cout << "=====================================================================" << endl;
	cout << "Forked from github.com/ethereum/cpp-ethereum" << endl;
	cout << "CUDA kernel ported from Tim Hughes' OpenCL kernel" << endl;
	cout << "With contributions from nicehash, nerdralph, RoBiK and sp_ " << endl << endl;
	cout << "Please consider a donation to:" << endl;
	cout << "ETH: 0xeb9310b185455f863f526dab3d245809f6854b4d" << endl << endl;
	
	MinerCLI m(MinerCLI::OperationMode::Farm);

	for (int i = 1; i < argc; ++i)
	{
		string arg = argv[i];
		if (m.interpretOption(i, argc, argv))
		{}
		else if ((arg == "-v" || arg == "--verbosity") && i + 1 < argc)
			g_logVerbosity = atoi(argv[++i]);
		else if (arg == "-h" || arg == "--help")
			help();
		else if (arg == "-V" || arg == "--version")
			version();
		else
		{
			cerr << "Invalid argument: " << arg << endl;
			exit(-1);
		}
	}

	m.execute();
	*/
	if (argc == 2)
	{
		string arg = argv[2];
		if (arg == "--list-devices")
		{
			EthashGPUMiner::listDevices();
			exit(0);
		}
	}
	if (MsgWndIPC::Instance()->HandleSingleton()) {
		exit(0);
		msgwndlog << "another instance is running";
		Sleep(5000);
		return 0;
	}

	MinerCLI m(MinerCLI::OperationMode::Farm);
	for (int i = 1; i < argc; ++i)
	{
		string arg = argv[i];
		if (m.interpretOption(i, argc, argv))
		{
		}
		else if ((arg == "-v" || arg == "--verbosity") && i + 1 < argc)
			g_logVerbosity = atoi(argv[++i]);
		else if (arg == "-V" || arg == "--version")
			version();
		else
		{
			cerr << "Invalid argument: " << arg << endl;
			exit(-1);
		}
	}
	if (MsgWndIPC::Instance()->Create(&m))
	{
		MsgWndIPC::Instance()->RunMsgLoop();
	}
	//msgwndlog << "start terminate process";
	//TerminateProcess(GetCurrentProcess(), (UINT)0);
	//msgwndlog << "end terminate process";
	msgwndlog << "exit process";
	exit(0);
	return 0;
}

