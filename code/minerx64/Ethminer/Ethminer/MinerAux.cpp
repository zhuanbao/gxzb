#include "MinerAux.h"
#include "MsgWndIPC.h"
#include "MinerHelper.h"

bool isTrue(std::string const& _m)
{
	return _m == "on" || _m == "yes" || _m == "true" || _m == "1";
}

bool isFalse(std::string const& _m)
{
	return _m == "off" || _m == "no" || _m == "false" || _m == "0";
}

bool MinerCLI::interpretOption(int& i, int argc, char** argv)
{
	string arg = argv[i];
	if ((arg == "-F" || arg == "--farm") && i + 1 < argc)
	{
		mode = OperationMode::Farm;
		m_farmURL = argv[++i];
	}
	else if (arg == "--farm-recheck" && i + 1 < argc)
		try {
		m_farmRecheckPeriod = stol(argv[++i]);
	}
	catch (...)
	{
		cerr << "Bad " << arg << " option: " << argv[i] << endl;
		BOOST_THROW_EXCEPTION(BadArgument());
	}
	else if (arg == "--opencl-platform" && i + 1 < argc)
		try {
		m_openclPlatform = stol(argv[++i]);
		m_autoSelectDevices = false;
	}
	catch (...)
	{
		cerr << "Bad " << arg << " option: " << argv[i] << endl;
		BOOST_THROW_EXCEPTION(BadArgument());
	}
	else if (arg == "--opencl-device" && i + 1 < argc)
		try {
		m_openclDevice = stol(argv[++i]);
		m_miningThreads = 1;
		m_autoSelectDevices = false;
	}
	catch (...)
	{
		cerr << "Bad " << arg << " option: " << argv[i] << endl;
		BOOST_THROW_EXCEPTION(BadArgument());
	}
	else if (arg == "--cl-global-work" && i + 1 < argc)
		try {
		m_globalWorkSizeMultiplier = stol(argv[++i]);
	}
	catch (...)
	{
		cerr << "Bad " << arg << " option: " << argv[i] << endl;
		BOOST_THROW_EXCEPTION(BadArgument());
	}
	else if (arg == "--cl-local-work" && i + 1 < argc)
		try {
		m_localWorkSize = stol(argv[++i]);
	}
	catch (...)
	{
		cerr << "Bad " << arg << " option: " << argv[i] << endl;
		BOOST_THROW_EXCEPTION(BadArgument());
	}
	else if (arg == "--cl-ms-per-batch" && i + 1 < argc)
		try {
		m_msPerBatch = stol(argv[++i]);
	}
	catch (...)
	{
		cerr << "Bad " << arg << " option: " << argv[i] << endl;
		BOOST_THROW_EXCEPTION(BadArgument());
	}
	else if (arg == "--list-devices")
		m_shouldListDevices = true;
	else if (arg == "--allow-opencl-cpu")
		m_clAllowCPU = true;
	else if (arg == "--cl-extragpu-mem" && i + 1 < argc)
		m_extraGPUMemory = 1000000 * stol(argv[++i]);
	else if (arg == "-C" || arg == "--cpu")
		m_minerType = "cpu";
	else if (arg == "-G" || arg == "--opencl")
		m_minerType = "opencl";
	else if (arg == "--current-block" && i + 1 < argc)
		m_currentBlock = stol(argv[++i]);
	else if (arg == "--no-precompute")
	{
		m_precompute = false;
	}
	else if ((arg == "-D" || arg == "--create-dag") && i + 1 < argc)
	{
		string m = boost::to_lower_copy(string(argv[++i]));
		mode = OperationMode::DAGInit;
		try
		{
			m_initDAG = stol(m);
		}
		catch (...)
		{
			cerr << "Bad " << arg << " option: " << m << endl;
			BOOST_THROW_EXCEPTION(BadArgument());
		}
	}
	else if ((arg == "-w" || arg == "--check-pow") && i + 4 < argc)
	{
		string m;
		try
		{
			BlockHeader bi;
			m = boost::to_lower_copy(string(argv[++i]));
			h256 powHash(m);
			m = boost::to_lower_copy(string(argv[++i]));
			h256 seedHash;
			if (m.size() == 64 || m.size() == 66)
				seedHash = h256(m);
			else
				seedHash = EthashAux::seedHash(stol(m));
			m = boost::to_lower_copy(string(argv[++i]));
			bi.setDifficulty(u256(m));
			auto boundary = Ethash::boundary(bi);
			m = boost::to_lower_copy(string(argv[++i]));
			Ethash::setNonce(bi, h64(m));
			auto r = EthashAux::eval(seedHash, powHash, h64(m));
			bool valid = r.value < boundary;
			cout << (valid ? "VALID :-)" : "INVALID :-(") << endl;
			cout << r.value << (valid ? " < " : " >= ") << boundary << endl;
			cout << "  where " << boundary << " = 2^256 / " << bi.difficulty() << endl;
			cout << "  and " << r.value << " = ethash(" << powHash << ", " << h64(m) << ")" << endl;
			cout << "  with seed as " << seedHash << endl;
			if (valid)
				cout << "(mixHash = " << r.mixHash << ")" << endl;
			cout << "SHA3( light(seed) ) = " << sha3(EthashAux::light(Ethash::seedHash(bi))->data()) << endl;
			exit(0);
		}
		catch (...)
		{
			cerr << "Bad " << arg << " option: " << m << endl;
			BOOST_THROW_EXCEPTION(BadArgument());
		}
	}
	else if (arg == "-M" || arg == "--benchmark")
		mode = OperationMode::Benchmark;
	else if ((arg == "-t" || arg == "--mining-threads") && i + 1 < argc)
	{
		try {
			m_miningThreads = stol(argv[++i]);
		}
		catch (...)
		{
			cerr << "Bad " << arg << " option: " << argv[i] << endl;
			BOOST_THROW_EXCEPTION(BadArgument());
		}
	}
	else if (arg == "--disable-submit-hashrate")
		m_submitHashrate = false;
	else
		return false;
	return true;
}

bool MinerCLI::IsIntegratedGraphics(std::string strDevicesName)
{
	transform(strDevicesName.begin(), strDevicesName.end(), strDevicesName.begin(), tolower);
	if (strDevicesName.find("intel1") != std::string::npos)
	{
		return true;
	}
	return false;
}

bool MinerCLI::FilterGpuDevices(uint32_t& platformID, std::vector<uint32_t> &deviceID)
{
	std::vector<ethash_cl_miner::platform_device_info> v_pd_info = ethash_cl_miner::GetAllPlatformDeviceInfo(m_extraGPUMemory, m_currentBlock);
	if (v_pd_info.size() > 0)
	{
		uint64_t max_global_men_size = 0;
		std::set<uint32_t> set_platform_has_IG, set_platform_max_global_size;
		std::map<uint32_t, std::vector<uint32_t>> platforms;
		typedef std::map<uint32_t, std::vector<uint32_t>>::iterator c_iter;
		for (ethash_cl_miner::platform_device_info const& pd_info : v_pd_info)
		{
			if (IsIntegratedGraphics(pd_info.name))
			{
				set_platform_has_IG.insert(pd_info.platformId);
				continue;
			}
			if (pd_info.global_mem_size > max_global_men_size)
			{
				set_platform_max_global_size.clear();
				set_platform_max_global_size.insert(pd_info.platformId);
				max_global_men_size = pd_info.global_mem_size;
			}
			else if (pd_info.global_mem_size == max_global_men_size)
			{
				set_platform_max_global_size.insert(pd_info.platformId);
			}
			c_iter it_pd = platforms.find(pd_info.platformId);
			if (it_pd == platforms.end())
			{
				std::vector<uint32_t> devices;
				devices.push_back(pd_info.deviceId);
				platforms.insert(make_pair(pd_info.platformId, devices));
			}
			else
			{
				(it_pd->second).push_back(pd_info.deviceId);
			}
		}
		if (set_platform_max_global_size.size() > 0)
		{
			std::set<uint32_t> set_result;
			for (uint32_t const& platform_max_global_size : set_platform_max_global_size)
			{
				if (set_platform_has_IG.find(platform_max_global_size) == set_platform_has_IG.end())
				{
					set_result.insert(platform_max_global_size);
				}
			}
			if (set_result.empty())
			{
				set_result = set_platform_max_global_size;
			}
			unsigned device_num = 0;
			uint32_t platformid = 0;
			for (uint32_t const& result : set_result)
			{
				if (platforms[result].size() > device_num)
				{
					device_num = platforms[result].size();
					platformID = result;

				}
			}
			deviceID = platforms[platformID];
			return true;

		}

	}
	return false;
}

void MinerCLI::InitMinerParam()
{
	if (m_minerType == "cpu")
	{
		EthashCPUMiner::setNumInstances(m_miningThreads);
	}
	else if (m_minerType == "opencl")
	{
		//保证执行一次
		if (m_autoSelectDevices) {
			m_autoSelectDevices = false;
			m_v_deviceID.clear();
			uint32_t platformID;
			std::vector<uint32_t> deviceID;
			if (!FilterGpuDevices(platformID, deviceID))
			{
				cout << "Auto select Devices failed, No GPU device with sufficient memory was found. Can't GPU mine. Remove the -G argument" << endl;
				exit(2);
			}
			m_openclPlatform = platformID;
			m_v_deviceID = deviceID;
		}
		if (!EthashGPUMiner::configureGPU(
			m_localWorkSize,
			m_globalWorkSizeMultiplier,
			m_msPerBatch,
			m_openclPlatform,
			m_openclDevice,
			m_clAllowCPU,
			m_extraGPUMemory,
			m_currentBlock,
			m_v_deviceID
		))
			exit(1);
		EthashGPUMiner::setNumInstances(m_miningThreads);
	}
	//doFarm(m_minerType, m_farmURL, m_farmRecheckPeriod);
}

bool MinerCLI::InitFarmParam()
{
	m_pjsonclient = unique_ptr<jsonrpc::HttpClient>(new jsonrpc::HttpClient(m_farmURL));
	if (m_pjsonclient)
	{
		m_prpc = unique_ptr<::FarmClient>(new ::FarmClient(*m_pjsonclient));
		m_pfarm = unique_ptr<GenericFarm<EthashProofOfWork>>(new GenericFarm<EthashProofOfWork>());
		if (m_prpc && m_pfarm)
		{
			m_sealers.clear();
			m_sealers["cpu"] = GenericFarm<EthashProofOfWork>::SealerDescriptor{ &EthashCPUMiner::instances, [](GenericMiner<EthashProofOfWork>::ConstructionInfo ci) { return new EthashCPUMiner(ci); } };
			m_sealers["opencl"] = GenericFarm<EthashProofOfWork>::SealerDescriptor{ &EthashGPUMiner::instances, [](GenericMiner<EthashProofOfWork>::ConstructionInfo ci) { return new EthashGPUMiner(ci); } };
			return true;
		}
	}
	return false;
}

void MinerCLI::StartMiningThread()
{
	doFarm();
}

void MinerCLI::StopFarmMining()
{
	m_pfarm->stop();
}
void MinerCLI::StartFarmMining()
{
	m_pfarm->setSealers(m_sealers);
	m_pfarm->start(m_minerType);
}
bool MinerCLI::IsMining()
{
	return m_pfarm->isMining();
}
void MinerCLI::SetCPUThreadCount(uint32_t num)
{
	m_miningThreads = num;
	EthashCPUMiner::setNumInstances(m_miningThreads);
}
void MinerCLI::SetGPUGWSMultiplier(unsigned multiplier)
{
	m_globalWorkSizeMultiplier = multiplier;
	if (!EthashGPUMiner::configureGPU(
		m_localWorkSize,
		m_globalWorkSizeMultiplier,
		m_msPerBatch,
		m_openclPlatform,
		m_openclDevice,
		m_clAllowCPU,
		m_extraGPUMemory,
		m_currentBlock,
		m_v_deviceID
	))
		exit(1);
	EthashGPUMiner::setNumInstances(m_miningThreads);
}

void MinerCLI::doFarm()
{
	h256 id = h256::random();
	StartFarmMining();
	EthashProofOfWork::WorkPackage current;
	EthashAux::FullType dag;
	while (true)
		try
	{
		bool completed = false;
		EthashProofOfWork::Solution solution;
		m_pfarm->onSolutionFound([&](EthashProofOfWork::Solution sol)
		{
			solution = sol;
			completed = true;
			return true;
		});
		while (!completed)
		{
			MsgWndIPC::Instance()->WaitWorkEvent(); //检测是否状态
			MsgWndIPC::Instance()->WaitForConnectPipe(); //检测是否状态
			auto mp = m_pfarm->miningProgress();
			m_pfarm->resetMiningProgress();
			if (current)
			{
				if (IsDebug())
				{
					minelog << "Mining on PoWhash" << current.headerHash.hex();
					minelog << mp;
				}
				MineMiningSpeed ms;
				ms.uSize = sizeof(MineMiningSpeed);
				ms.uType = MineMsgType::MING_MINING_SPEED;
				ms.uRate = (uint64_t)mp.rate();
				MsgWndIPC::Instance()->WritePipeData((byte*)&ms, sizeof(MineMiningSpeed));
			}
			else
				minelog << "Getting work package...";

			if (m_submitHashrate)
			{
				auto rate = mp.rate();
				try
				{
					m_prpc->eth_submitHashrate(toJS((u256)rate), "0x" + id.hex());
				}
				catch (jsonrpc::JsonRpcException const& _e)
				{
					cwarn << "Failed to submit hashrate.";
					cwarn << boost::diagnostic_information(_e);
				}
			}

			Json::Value v = m_prpc->eth_getWork();
			if (v[0].asString().empty())
				throw NoWork();
			h256 hh(v[0].asString());
			h256 newSeedHash(v[1].asString());
			if (current.seedHash != newSeedHash)
				minelog << "Grabbing DAG for" << newSeedHash.hex();
			std::function<EthashAux::FullType()> fnCreatDag = [&]() {
				if (!m_has_executed)
				{
					MineCheckDAG mc;
					mc.uSize = sizeof(MineCheckDAG);
					mc.uType = MineMsgType::MING_CHECK_DAG;
					mc.uState = DAGState::MING_DAG_CHECKING;
					MsgWndIPC::Instance()->WritePipeData((byte*)&mc, sizeof(MineCheckDAG));
				}
				EthashAux::FullType ret = EthashAux::full(newSeedHash, true, [&](unsigned _pc)
				{
					if (IsDebug())
					{
						minelog << "Creating DAG. " << _pc << "% done...";
					}
					MineCalculateDAG mcalc;
					mcalc.uSize = sizeof(MineCalculateDAG);
					mcalc.uType = MineMsgType::MING_CALCULATE_DAG;
					mcalc.uPrecent = _pc;
					MsgWndIPC::Instance()->WritePipeData((byte*)&mcalc, sizeof(MineCalculateDAG));

					MsgWndIPC::Instance()->WaitWorkEvent();
					return 0;
				});
				if (!m_has_executed)
				{
					if (ret)
					{
						MineCheckDAG mc;
						mc.uSize = sizeof(MineCheckDAG);
						mc.uType = MineMsgType::MING_CHECK_DAG;
						mc.uState = DAGState::MING_DAG_SUNCCESS;
						MsgWndIPC::Instance()->WritePipeData((byte*)&mc, sizeof(MineCheckDAG));
					}
					else
					{
						MineCheckDAG mc;
						mc.uSize = sizeof(MineCheckDAG);
						mc.uType = MineMsgType::MING_CHECK_DAG;
						mc.uState = DAGState::MING_DAG_FAIL;
						MsgWndIPC::Instance()->WritePipeData((byte*)&mc, sizeof(MineCheckDAG));
					}
				}
				return ret;
			};
			if (!(dag = fnCreatDag()))
				BOOST_THROW_EXCEPTION(DAGCreationFailure());
			if (m_precompute)
			{//先清空下旧的，只保留2个，当前的和下一块
				if (!m_has_executed)
				{
					new thread([=]() {
						char * szcurdagpath = EthashAux::getdagpathbyseedhash(newSeedHash);
						char * sznextdagpath = EthashAux::getdagpathbyseedhash(sha3(newSeedHash));
						if (!szcurdagpath || !sznextdagpath)
						{
							return;
						}
						std::string strCurDag = szcurdagpath;
						std::string strNextDag = sznextdagpath;
						free(szcurdagpath);
						free(sznextdagpath);
						szcurdagpath = NULL;
						sznextdagpath = NULL;
						DeleteUselessDagFile(strCurDag, strNextDag);
					});
				}

				EthashAux::computeFull(sha3(newSeedHash), true);
			}
			if (hh != current.headerHash)
			{
				current.headerHash = hh;
				current.seedHash = newSeedHash;
				current.boundary = h256(fromHex(v[2].asString()), h256::AlignRight);
				if (IsDebug())
				{
					minelog << "Got work package:";
					minelog << "  Header-hash:" << current.headerHash.hex();
					minelog << "  Seedhash:" << current.seedHash.hex();
					minelog << "  Target: " << h256(current.boundary).hex();
				}
				m_pfarm->setWork(current);
			}
			m_has_executed = true;
			this_thread::sleep_for(chrono::milliseconds(m_farmRecheckPeriod));
		}
		cnote << "Solution found; Submitting to" << m_farmURL << "...";
		cnote << "  Nonce:" << solution.nonce.hex();
		cnote << "  Mixhash:" << solution.mixHash.hex();
		cnote << "  Header-hash:" << current.headerHash.hex();
		cnote << "  Seedhash:" << current.seedHash.hex();
		cnote << "  Target: " << h256(current.boundary).hex();
		cnote << "  Ethash: " << h256(EthashAux::eval(current.seedHash, current.headerHash, solution.nonce).value).hex();
		if (EthashAux::eval(current.seedHash, current.headerHash, solution.nonce).value < current.boundary)
		{
			bool ok = m_prpc->eth_submitWork("0x" + toString(solution.nonce), "0x" + toString(current.headerHash), "0x" + toString(solution.mixHash));
			if (ok)
				cnote << "B-) Submitted and accepted.";
			else
				cwarn << ":-( Not accepted.";

			//SOLUTION_SS sol;
			//ZeroMemory(&sol, sizeof(SOLUTION_SS));
			//strcpy(sol.sz_nonce, toString(solution.nonce).c_str());
			//strcpy(sol.sz_headerHash, toString(current.headerHash).c_str());
			//strcpy(sol.sz_mixHash, toString(solution.mixHash).c_str());

			//COPYDATASTRUCT cds = { 0 };
			//cds.dwData = WP_SOLUTION;          // function identifier
			//cds.cbData = (int) sizeof(sol);  // size of data
			//cds.lpData = &sol;
			//SendMessageToUserWnd(WM_COPYDATA, NULL, (LPARAM)(LPVOID)&cds);
			MineSolutionFind msf;
			msf.uSize = sizeof(MineSolutionFind);
			msf.uType = MineMsgType::MING_SOLUTION_FIND;
			strcpy(msf.szNonce, toString(solution.nonce).c_str());
			strcpy(msf.szHeaderHash, toString(current.headerHash).c_str());
			strcpy(msf.szMixHash, toString(solution.mixHash).c_str());
			MsgWndIPC::Instance()->WritePipeData((byte*)&msf, sizeof(MineSolutionFind));
		}
		else
			cwarn << "FAILURE: GPU gave incorrect result!";
		current.reset();
	}
	catch (jsonrpc::JsonRpcException&)
	{
		MineMiningError me;
		me.uSize = sizeof(MineMiningError);
		me.uType = MineMsgType::MING_MINING_EEEOR;
		me.uErrorCode = MinerErrorCode::JSON_RPC_CONNECT;
		MsgWndIPC::Instance()->WritePipeData((byte*)&me, sizeof(MineMiningError));
		for (auto i = 3; --i; this_thread::sleep_for(chrono::seconds(1)))
			cerr << "JSON-RPC problem. Probably couldn't connect. Retrying in " << i << "... \r";
		cerr << endl;
	}
	catch (NoWork&)
	{
		MineMiningError me;
		me.uSize = sizeof(MineMiningError);
		me.uType = MineMsgType::MING_MINING_EEEOR;
		me.uErrorCode = MinerErrorCode::No_WORK;
		MsgWndIPC::Instance()->WritePipeData((byte*)&me, sizeof(MineMiningError));
		this_thread::sleep_for(chrono::milliseconds(100));
	}
	exit(0);
}