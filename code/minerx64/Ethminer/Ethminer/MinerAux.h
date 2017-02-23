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
#if defined(_WIN32)
#define _WINSOCKAPI_
#include <windows.h>
#endif // defined(_WIN32)

#include <boost/algorithm/string/case_conv.hpp>
#include <libdevcore/CommonJS.h>
#include <libethcore/BasicAuthority.h>
#include <libethcore/Exceptions.h>
#include <libethashseal/EthashGPUMiner.h>
#include <libethashseal/EthashCPUMiner.h>

#if ETH_ETHASHCL
	#include <libethash-cl/ethash_cl_miner.h>
#endif // ETH_ETHASHCL

#if ETH_JSONRPC
	#include <jsonrpccpp/client/connectors/httpclient.h>
	#include "FarmClient.h"
#endif // ETH_JSONRPC

#include "cpp-ethereum/BuildInfo.h"

// TODO - having using derivatives in header files is very poor style, and we need to fix these up.
//
// http://stackoverflow.com/questions/4872373/why-is-including-using-namespace-into-a-header-file-a-bad-idea-in-c
// 
// "However you'll virtually never see a using directive in a header file (at least not outside of scope).
// The reason is that using directive eliminate the protection of that particular namespace, and the effect last
// until the end of current compilation unit. If you put a using directive (outside of a scope) in a header file,
// it means that this loss of "namespace protection" will occur within any file that include this header,
// which often mean other header files."
//
// Bob has already done just that in https://github.com/bobsummerwill/cpp-ethereum/commits/cmake_fixes/ethminer,
// and we should apply those changes back to 'develop'.  It is probably best to defer that cleanup
// until after attempting to backport the Genoil ethminer changes, because they are fairly extensive
// in terms of lines of change, though all the changes are just adding explicit namespace prefixes.
// So let's start with just the subset of changes which minimizes the #include dependencies.
//
// See https://github.com/bobsummerwill/cpp-ethereum/commit/53af845268b91bc6aa1dab53a6eac675157a072b
// See https://github.com/bobsummerwill/cpp-ethereum/commit/3b9e581d7c04c637ebda18d3d86b5a24d29226f4
//
// More generally, the fact that nearly all of the code for ethminer is actually in the 'MinerAux.h'
// header file, rather than in a source file, is also poor style and should probably be addressed.
// Perhaps there is some historical reason for this which I am unaware of?

using namespace std;
using namespace dev;
using namespace dev::eth;



inline std::string credits()
{
	std::ostringstream out;
	out
		<< "cpp-ethereum " << dev::Version << endl
		<< "  By cpp-ethereum contributors, (c) 2013-2016." << endl
		<< "  See the README for contributors and credits." << endl;
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
		Farm
	};


	MinerCLI(OperationMode _mode = OperationMode::None): mode(_mode) {
		Ethash::init();
		NoProof::init();
		BasicAuthority::init();
	}
	~MinerCLI()
	{
		m_pjsonclient.reset();
		m_prpc.reset();
		m_pfarm.reset();
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
	void InitMinerParam();

	bool InitFarmParam();

	void StartMiningThread();
	void StopFarmMining();
	void StartFarmMining();
	bool IsMining();
	void SetCPUThreadCount(uint32_t num);
	void SetGPUGWSMultiplier(unsigned multiplier);
	enum class MinerType
	{
		CPU,
		GPU
	};

	std::string minerType() const { return m_minerType; }
	bool shouldPrecompute() const { return m_precompute; }

private:

	// dummy struct for special exception.
	struct NoWork {};
	void doFarm();

	/// Operating mode.
	OperationMode mode;

	/// Mining options
	std::string m_minerType = "cpu";
	unsigned m_openclPlatform = 0;
	unsigned m_openclDevice = 0;
	std::vector<uint32_t> m_v_deviceID;
	unsigned m_miningThreads = UINT_MAX;
	bool m_shouldListDevices = false;
	bool m_autoSelectDevices = true;
	bool m_clAllowCPU = false;
	unsigned m_globalWorkSizeMultiplier = ethash_cl_miner::c_defaultGlobalWorkSizeMultiplier;
	unsigned m_localWorkSize = ethash_cl_miner::c_defaultLocalWorkSize;
	unsigned m_msPerBatch = ethash_cl_miner::c_defaultMSPerBatch;

	uint64_t m_currentBlock = 0;
	// default value is 350MB of GPU memory for other stuff (windows system rendering, e.t.c.)
	unsigned m_extraGPUMemory = 350000000;

	/// DAG initialisation param.
	unsigned m_initDAG = 0;

	/// Farm params
	//
	unique_ptr<jsonrpc::HttpClient> m_pjsonclient = nullptr;
	unique_ptr<::FarmClient> m_prpc = nullptr;
	unique_ptr<GenericFarm<EthashProofOfWork>> m_pfarm = nullptr;
	map<string, GenericFarm<EthashProofOfWork>::SealerDescriptor> m_sealers;
	//
	string m_farmURL = "http://127.0.0.1:8545";
	unsigned m_farmRecheckPeriod = 500;
	bool m_precompute = true;
	bool m_submitHashrate = true;

	///
	bool m_has_executed = false;

	
};
