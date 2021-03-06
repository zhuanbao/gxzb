#pragma once

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
/** @file MinerAux.cpp
 * @author Gav Wood <i@gavwood.com>
 * @date 2014
 * CLI module for mining.
 */

#include <thread>
#include <chrono>
#include <fstream>
#include <iostream>
#include <signal.h>
#include <random>

#include <boost/algorithm/string.hpp>
#include <boost/algorithm/string/trim_all.hpp>
#include <boost/optional.hpp>

#include <libdevcore/FileSystem.h>
#include <libdevcore/StructuredLogger.h>
#include <libethcore/Exceptions.h>
#include <libdevcore/SHA3.h>
#include <libdevcore/CommonJS.h>
#include <libethcore/EthashAux.h>
#include <libethcore/EthashCUDAMiner.h>
#include <libethcore/EthashGPUMiner.h>
#include <libethcore/EthashCPUMiner.h>
#include <libethcore/Farm.h>
#if ETH_ETHASHCL || !ETH_TRUE
#include <libethash-cl/ethash_cl_miner.h>
#endif
#if ETH_ETHASHCUDA || !ETH_TRUE
#include <libethash-cuda/ethash_cuda_miner.h>
#endif
#if ETH_JSONRPC || !ETH_TRUE
#include <jsonrpccpp/server/connectors/httpserver.h>
#include <jsonrpccpp/client/connectors/httpclient.h>
#endif
#include "BuildInfo.h"
#if ETH_JSONRPC || !ETH_TRUE
#include "PhoneHome.h"
#include "FarmClient.h"
#endif
#if ETH_STRATUM || !ETH_TRUE
#include <libstratum/EthStratumClient.h>
#include <libstratum/EthStratumClientV2.h>
#endif
using namespace std;
using namespace dev;
using namespace dev::eth;
using namespace boost::algorithm;

#undef RETURN


inline std::string credits()
{
	std::ostringstream out;
	out
		<< "Ethereum (++) " << dev::Version << endl
		<< "  Code by Gav Wood et al, (c) 2013, 2014, 2015." << endl;
	return out.str();
}

class BadArgument: public Exception {};
struct MiningChannel: public LogChannel
{
	static const char* name() { return "miner"; }
	static const int verbosity = 2;
	static const bool debug = false;
};
#define minelog clog(MiningChannel)

class MinerCLI
{
public:
	enum class OperationMode
	{
		None,
		DAGInit,
		Benchmark,
		Simulation,
		Farm,
		Stratum
	};

	MinerCLI(OperationMode _mode = OperationMode::None): mode(_mode) {}

	~MinerCLI()
	{
		//m_pfarm.reset();
		if (m_pfarm)
		{
			delete m_pfarm;
			m_pfarm = NULL;
		}

	}

	bool interpretOption(int& i, int argc, char** argv);

	bool IsIntegratedGraphics(std::string strDevicesName);
	//先找最大Global_Men_Size的平台，再优先找平台中不带集显的平台优先，最后选排除集显后个数最多的
	bool FilterGpuDevices(uint32_t& platformID, std::vector<uint32_t> &deviceID);

	void listDevices()
	{
		EthashGPUMiner::listDevices();
		exit(0);
	}

	void InitOpenCLParam();

	
	void ProcessDagProgress(int _precent);

	void start();

	void setSpeedLimitParam(unsigned _globalWorkSizeMultiplier, unsigned _msPerBatch);

	MinerType minerType() const { return m_minerType; }

private:
	
	void doFarm(MinerType _m, string & _remote, unsigned _recheckPeriod);

	void doStratum();


	/// Operating mode.
	OperationMode mode;

	/// Mining options
	bool m_running = true;
	MinerType m_minerType = MinerType::CPU;
	unsigned m_openclPlatform = 0;
	unsigned m_openclDevice = 0;

	unsigned m_miningThreads = UINT_MAX;
	bool m_shouldListDevices = false;
	bool m_clAllowCPU = false;
#if ETH_ETHASHCL || !ETH_TRUE
	unsigned m_openclDeviceCount = 0;
	unsigned m_openclDevices[16];
#if !ETH_ETHASHCUDA || !ETH_TRUE
	unsigned m_globalWorkSizeMultiplier = ethash_cl_miner::c_defaultGlobalWorkSizeMultiplier;
	unsigned m_localWorkSize = ethash_cl_miner::c_defaultLocalWorkSize;
	unsigned m_msPerBatch = ethash_cl_miner::c_defaultMSPerBatch;
#endif
#endif
#if ETH_ETHASHCUDA || !ETH_TRUE
	unsigned m_globalWorkSizeMultiplier = ethash_cuda_miner::c_defaultGridSize;
	unsigned m_localWorkSize = ethash_cuda_miner::c_defaultBlockSize;
	unsigned m_cudaDeviceCount = 0;
	unsigned m_cudaDevices[16];
	unsigned m_numStreams = ethash_cuda_miner::c_defaultNumStreams;
	unsigned m_cudaSchedule = 4; // sync
#endif
	// default value was 350MB of GPU memory for other stuff (windows system rendering, e.t.c.)
	unsigned m_extraGPUMemory = 0;// 350000000; don't assume miners run desktops...
	unsigned m_dagLoadMode = 0; // parallel
	unsigned m_dagCreateDevice = 0;
	/// Benchmarking params
	bool m_phoneHome = false;
	unsigned m_benchmarkWarmup = 15;
	unsigned m_benchmarkTrial = 3;
	unsigned m_benchmarkTrials = 5;
	unsigned m_benchmarkBlock = 0;
	

	GenericFarm<EthashProofOfWork>* m_pfarm = NULL;

	string m_farmURL = "http://127.0.0.1:8545";
	string m_farmFailOverURL = "";
	

	string m_activeFarmURL = m_farmURL;
	unsigned m_farmRetries = 0;
	unsigned m_maxFarmRetries = 3;
	unsigned m_farmRecheckPeriod = 500;
	unsigned m_defaultStratumFarmRecheckPeriod = 200;
	bool m_farmRecheckSet = false;
	int m_worktimeout = 180;

#if ETH_STRATUM || !ETH_TRUE
	int m_stratumClientVersion = 1;
	int m_stratumProtocol = STRATUM_PROTOCOL_STRATUM;
	string m_user;
	string m_pass;
	string m_port;
	string m_fuser = "";
	string m_fpass = "";
	string m_email = "";
#endif
	string m_fport = "";
//

	bool m_bCompleteDAGOnce = false;
	int m_iCurrentPrecent = 0;
	mutable dev::SharedMutex x_dagprecent;
};
