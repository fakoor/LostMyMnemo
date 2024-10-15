/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V2.0.0
  * @date		28-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#include <stdafx.h>

#include <iostream>
#include <chrono>
#include <thread>
#include <fstream>
#include <string>
#include <memory>
#include <sstream>
#include <iomanip>
#include <vector>
#include <map>
#include <omp.h>



#include "Dispatcher.h"
#include "GPU.h"
#include "AdaptiveBase.h"

#include "KernelStride.hpp"
#include "Helper.h"


#include "cuda_runtime.h"
#include "device_launch_parameters.h"


#include "../Tools/tools.h"
#include "../Tools/utils.h"
#include "../config/Config.hpp"
#include "../Tools/segwit_addr.h"

#include "DispatchDictionaryScan.cuh"




static std::thread save_thread;

int Generate_Mnemonic(void)
{
	std::cout << "Compiled on Date *** : " << __DATE__ << ", Time:" << __TIME__ << std::endl;

	ConfigClass Config;
	cudaError_t cudaStatus = cudaSuccess;
	int err;

	if (ApplyConfig(Config) == false) {
		goto Error;
	}

	uint64_t number_of_generated_mnemonics = (Config.number_of_generated_mnemonics / (Config.cuda_block * Config.cuda_grid)) * (Config.cuda_block * Config.cuda_grid);
	if ((Config.number_of_generated_mnemonics % (Config.cuda_block * Config.cuda_grid)) != 0) number_of_generated_mnemonics += Config.cuda_block * Config.cuda_grid;
	Config.number_of_generated_mnemonics = number_of_generated_mnemonics;


	int nDevCount = devicesInfo();



	uint32_t num_device = 0;
	if (nDevCount != 1) { //select only cuda device automatically
#ifndef TEST_MODE
		std::cout << "\n\nEnter number of device: ";
		std::cin >> num_device;
#endif //TEST_MODE
	}
	else {
		std::cout << " The only CUDA capable device selected automatically." << std::endl;
	}
	cudaStatus = cudaSetDevice(num_device);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
		return -1;
	}

	size_t num_wallets_gpu = Config.cuda_grid * Config.cuda_block;
	if (num_wallets_gpu < NUM_PACKETS_SAVE_IN_FILE)
	{
		std::cerr << "Error num_wallets_gpu < NUM_PACKETS_SAVE_IN_FILE!" << std::endl;
		return -1;
	}
	uint32_t num_bytes = 0;
	if (Config.chech_equal_bytes_in_adresses == "yes")
	{
#ifdef TEST_MODE
		num_bytes = 5;
#else
		num_bytes = 8;
#endif //TEST_MODE
	}

	std::cout << "\nNUM WALLETS IN PACKET GPU: " << tools::formatWithCommas(num_wallets_gpu) << std::endl << std::endl;
	data_class* Data = new data_class();
	stride_class* Stride = new stride_class(Data);
	size_t num_addresses_in_tables = 0;

	std::cout << "READ TABLES! WAIT..." << std::endl;
	tools::clearFiles();
	if((Config.generate_path[0] != 0) || (Config.generate_path[1] != 0) || (Config.generate_path[2] != 0) || (Config.generate_path[3] != 0) || (Config.generate_path[4] != 0)
		|| (Config.generate_path[5] != 0))
	{
		std::cout << "READ TABLES LEGACY(BIP32, BIP44)..." << std::endl;
	err = tools::readAllTables(Data->host.tables_legacy, Config.folder_tables_legacy, "", &num_addresses_in_tables);
	if (err == -1) {
		std::cerr << "Error readAllTables legacy!" << std::endl;
		goto Error;
	}
	}

	bool bCfgSaveResultsIntoFile = (Config.save_generation_result_in_file == "yes")?true:false;
	bool bCfgUseOldMethod = (Config.use_old_random_method == "yes")?true:false;


	//if (bCfgUseOldMethod) {
		if ((Config.generate_path[6] != 0) || (Config.generate_path[7] != 0))
		{
			std::cout << "READ TABLES SEGWIT(BIP49)..." << std::endl;
			err = tools::readAllTables(Data->host.tables_segwit, Config.folder_tables_segwit, "", &num_addresses_in_tables);
			if (err == -1) {
				std::cerr << "Error readAllTables segwit!" << std::endl;
				goto Error;
			}
		}
		if ((Config.generate_path[8] != 0) || (Config.generate_path[9] != 0))
		{
			std::cout << "READ TABLES NATIVE SEGWIT(BIP84)..." << std::endl;
			err = tools::readAllTables(Data->host.tables_native_segwit, Config.folder_tables_native_segwit, "", &num_addresses_in_tables);
			if (err == -1) {
				std::cerr << "Error readAllTables native segwit!" << std::endl;
				goto Error;
			}
		}
		std::cout << std::endl << std::endl;

		if (num_addresses_in_tables == 0) {
			std::cerr << "ERROR READ TABLES!! NO ADDRESSES IN FILES!!" << std::endl;
			goto Error;
		}
//	}

	if (Data->malloc(Config.cuda_grid, Config.cuda_block, Config.num_paths, Config.num_child_addresses, bCfgSaveResultsIntoFile) != 0) {
		std::cerr << "Error Data->malloc()!" << std::endl;
		goto Error;
	}

	if (Stride->init() != 0) {
		std::cerr << "Error INIT!!" << std::endl;
		goto Error;
	}

	Data->host.freeTableBuffers();

	std::cout << "START GENERATE ADDRESSES!" << std::endl;
	std::cout << "PATH: " << std::endl;

	//if (bCfgUseOldMethod) {
		if (Config.generate_path[0] != 0) std::cout << "m/0/0.." << (Config.num_child_addresses - 1) << std::endl;
		if (Config.generate_path[1] != 0) std::cout << "m/1/0.." << (Config.num_child_addresses - 1) << std::endl;
		if (Config.generate_path[2] != 0) std::cout << "m/0/0/0.." << (Config.num_child_addresses - 1) << std::endl;
		if (Config.generate_path[3] != 0) std::cout << "m/0/1/0.." << (Config.num_child_addresses - 1) << std::endl;
//	}
	if (Config.generate_path[4] != 0) std::cout << "m/44'/0'/0'/0/0.." << (Config.num_child_addresses - 1) << std::endl;

//	if (bCfgUseOldMethod) {
		if (Config.generate_path[5] != 0) std::cout << "m/44'/0'/0'/1/0.." << (Config.num_child_addresses - 1) << std::endl;
		if (Config.generate_path[6] != 0) std::cout << "m/49'/0'/0'/0/0.." << (Config.num_child_addresses - 1) << std::endl;
		if (Config.generate_path[7] != 0) std::cout << "m/49'/0'/0'/1/0.." << (Config.num_child_addresses - 1) << std::endl;
		if (Config.generate_path[8] != 0) std::cout << "m/84'/0'/0'/0/0.." << (Config.num_child_addresses - 1) << std::endl;
		if (Config.generate_path[9] != 0) std::cout << "m/84'/0'/0'/1/0.." << (Config.num_child_addresses - 1) << std::endl;
//	}
	std::cout << "\nGENERATE " << tools::formatWithCommas(Config.number_of_generated_mnemonics) << " MNEMONICS. " << tools::formatWithCommas(Config.number_of_generated_mnemonics * Data->num_all_childs) << " ADDRESSES. MNEMONICS IN ROUNDS " << tools::formatWithCommas(Data->wallets_in_round_gpu) << ". WAIT...\n\n";

	//TODO: Here we should create incremental task: /or here
	tools::generateRandomUint64Buffer(Data->host.entropy, Data->size_entropy_buf / (sizeof(uint64_t)));
	if (cudaMemcpyToSymbol(dev_num_bytes_find, &num_bytes, 4, 0, cudaMemcpyHostToDevice) != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol to num_bytes_find failed!" << std::endl;
		goto Error;
	}
	if (cudaMemcpyToSymbol(dev_generate_path, &Config.generate_path, sizeof(Config.generate_path), 0, cudaMemcpyHostToDevice) != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol to dev_generate_path failed!" << std::endl;
		goto Error;
	}
	if (cudaMemcpyToSymbol(dev_num_childs, &Config.num_child_addresses, 4, 0, cudaMemcpyHostToDevice) != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol to dev_num_child failed!" << std::endl;
		goto Error;
	}
	if (cudaMemcpyToSymbol(dev_num_paths, &Config.num_paths, 4, 0, cudaMemcpyHostToDevice) != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol to dev_num_paths failed!" << std::endl;
		goto Error;
	}
	if (cudaMemcpyToSymbol(dev_static_words_indices, &Config.words_indicies_mnemonic, 12*2, 0, cudaMemcpyHostToDevice) != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol to dev_gen_words_indices failed!" << std::endl;
		goto Error;
	}

	if (bCfgUseOldMethod == false) {
		if (!DispatchDictionaryScan(&Config, Data, Stride)) {
			goto Error;
		}
	}//NEW METHOD
	else {
		for (uint64_t step = 0; step < Config.number_of_generated_mnemonics / (Data->wallets_in_round_gpu); step++)
		{
			tools::start_time();

			if (bCfgSaveResultsIntoFile) {
				if (Stride->start_for_save(Config.cuda_grid, Config.cuda_block) != 0) {
					std::cerr << "Error START!!" << std::endl;
					goto Error;
				}
			}
			else
			{
				if (Stride->start(Config.cuda_grid, Config.cuda_block) != 0) {
					std::cerr << "Error START!!" << std::endl;
					goto Error;
				}
			}

			//TODO: Here we should create incremental task : /here
			tools::generateRandomUint64Buffer(Data->host.entropy, Data->size_entropy_buf / (sizeof(uint64_t)));

			if (save_thread.joinable()) save_thread.join();

			if (bCfgSaveResultsIntoFile) {
				if (Stride->end_for_save() != 0) {
					std::cerr << "Error END!!" << std::endl;
					goto Error;
				}
			}
			else
			{
				if (Stride->end() != 0) {
					std::cerr << "Error END!!" << std::endl;
					goto Error;
				}
			}
			

			if (bCfgSaveResultsIntoFile) {
				save_thread = std::thread(&tools::saveResult, (char*)Data->host.mnemonic, (uint8_t*)Data->host.hash160, Data->wallets_in_round_gpu, Data->num_all_childs, Data->num_childs, Config.generate_path);
				//tools::saveResult((char*)Data->host.mnemonic, (uint8_t*)Data->host.hash160, Data->wallets_in_round_gpu, Data->num_all_childs, Data->num_childs, Config.generate_path);
			}

			tools::checkResult(Data->host.ret);

			float delay;
			tools::stop_time_and_calc_sec(&delay);
			std::cout << "\rGENERATE: " << tools::formatWithCommas((double)Data->wallets_in_round_gpu / delay) << " MNEMONICS/SEC AND "
				<< tools::formatWithCommas((double)(Data->wallets_in_round_gpu * Data->num_all_childs) / delay) << " ADDRESSES/SEC"
				<< " | SCAN: " << tools::formatPrefix((double)(Data->wallets_in_round_gpu * Data->num_all_childs * num_addresses_in_tables) / delay) << " ADDRESSES/SEC"
				<< " | ROUND: " << step;

		}//for (step)

	}

	std::cout << "\n\nEND!" << std::endl;
	if (save_thread.joinable()) save_thread.join();
	// cudaDeviceReset must be called before exiting in order for profiling and
	// tracing tools such as Nsight and Visual Profiler to show complete traces.


	cudaStatus = cudaDeviceReset();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceReset failed!");
		return -1;
	}


	return 0;
Error:
	std::cout << "\n\nERROR!" << std::endl;
	if (save_thread.joinable()) save_thread.join();
	// cudaDeviceReset must be called before exiting in order for profiling and
	// tracing tools such as Nsight and Visual Profiler to show complete traces.
	cudaStatus = cudaDeviceReset();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceReset failed!");
		return -1;
	}

	return -1;


}
bool ApplyConfig(ConfigClass& Config)
{
	try {

		for (int x = 0; x < MAX_ADAPTIVE_BASE_POSITIONS; x++) {
			host_AdaptiveBaseCurrentBatchInitialDigits[x] = 0;
		}

		parse_config(&Config, "config.cfg");

		std::vector<std::string> startFrom = tools::SplitWords(Config.static_words_starting_point);


		int nLastKnownPos = -1;
		std::vector<int> validIndexListPerPos[NUM_WORDS_MNEMONIC];

		for (int nemoIter = 0; nemoIter < NUM_WORDS_MNEMONIC; nemoIter++) {
			int16_t thisPosBipStarting;
			std::string thisPosStartFromWord = startFrom[nemoIter];
			tools::GetSingleWordIndex(thisPosStartFromWord, &thisPosBipStarting);
			//int16_t thisPosDicStarting = -1;



			std::vector<std::string> thisMnemoPosDictionaryLine = tools::SplitWords(Config.dynamic_words[nemoIter]);
			int thisPosLineWordCount = thisMnemoPosDictionaryLine.size();

			if (thisPosLineWordCount > MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION) {
				std::cout << "ERROR: Maximum Allowed word count per line is " << MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION << std::endl;
				//goto Error;
				return false;

			}

			int64_t adaptivePositionIdx = nemoIter - MAX_ADAPTIVE_BASE_POSITIONS;

			if (thisPosLineWordCount == 1) { //find consequtive count of single-word dictionaries
				int prev = nemoIter - 1;
				if (prev == nLastKnownPos)
					nLastKnownPos = nemoIter;
			}


			for (int16_t thisPosDictTraverseIdx = 0; thisPosDictTraverseIdx < thisPosLineWordCount; thisPosDictTraverseIdx++) {

				std::string thisWord = thisMnemoPosDictionaryLine[thisPosDictTraverseIdx];


				//Fill the digit-space for each adaptive base position (last 6 in our case)
				int16_t thisBipIdx;
				tools::GetSingleWordIndex(thisWord, &thisBipIdx);

				if (thisPosDictTraverseIdx == 0) {//leave old algorithm working for now with separated positions					
					Config.words_indicies_mnemonic[nemoIter] = thisBipIdx; //or even -1 when ? 
				}

				if (adaptivePositionIdx < 0)
					break;

				//FROM now on, we are on the second 6 words

				host_AdaptiveBaseDigitSet[adaptivePositionIdx][thisPosDictTraverseIdx] = thisBipIdx; //scrutinize what we do with -1 instances
				host_AdaptiveBaseDigitCarryTrigger[adaptivePositionIdx] = thisPosLineWordCount; //TODO: scrutinize (minus one needed?)

				//Check if we are going to start from this word, make adjustments and print info messages
				bool bStartsFromThisWord = (0 == strcmp(thisWord.c_str(), thisPosStartFromWord.c_str()));
				if (!bStartsFromThisWord)
					continue;

				//FROM now on, we start from this word

				std::ostringstream isAdaptiveStr;

				isAdaptiveStr.str("");

				host_AdaptiveBaseCurrentBatchInitialDigits[adaptivePositionIdx] = thisPosDictTraverseIdx;

				//std::cout << "SETTING " << adaptivePositionIdx << " @" << thisPosDictTraverseIdx << std::endl;

				if (adaptivePositionIdx >= 0) {
					isAdaptiveStr << "[Dynamic:" << thisPosLineWordCount << "]";
				}
				else if (thisPosLineWordCount == 1) {
					isAdaptiveStr.str("[STATIC]");
				}

				std::cout << "Postition " << nemoIter << isAdaptiveStr.str() << " starts from word: " << thisWord << " at PosDictionary: " << thisPosDictTraverseIdx << " BIP: " << thisBipIdx << " and carries at:" << host_AdaptiveBaseDigitCarryTrigger[nemoIter] << std::endl;

			}//single dictionary in each position
		} //nemo positions

		if (nLastKnownPos >= 0)
			std::cout << "Words up to position " << nLastKnownPos << " (out of 0 to 11) are known" << std::endl;
		else
			std::cout << "All words are dynamic" << std::endl;

		for (int pp = 0; pp < MAX_ADAPTIVE_BASE_POSITIONS; pp++) {
			std::cout << "The position:" << pp + MAX_ADAPTIVE_BASE_POSITIONS << " Carries at:" << host_AdaptiveBaseDigitCarryTrigger[pp] << " and starts from " << host_AdaptiveBaseCurrentBatchInitialDigits[pp] << std::endl;
		}


	}//try
	catch (...) {
		for (;;)
			std::this_thread::sleep_for(std::chrono::seconds(30));
	}//catch
	return true;
}
__host__ __device__
void PrintNextMnemo(uint64_t batchMnemo[2] , uint64_t nHowMuch, int16_t carry [MAX_ADAPTIVE_BASE_POSITIONS]
	, int16_t initDigits[MAX_ADAPTIVE_BASE_POSITIONS]
	, int16_t digitSet [MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION]
)
{
	int16_t  batchDigits[6];
	//uint64_t batchMnemo[2];
	//batchMnemo[0] = host_EntropyAbsolutePrefix64[0];
	//batchMnemo[1] = host_EntropyBatchNext24[0] & 0xB0000000; //scrutinize;
	printf("before->after::[%llu] == \n", nHowMuch  );

	if (IncrementAdaptiveDigits(carry, initDigits, nHowMuch, batchDigits) == false) {
		printf("Not able to add %llu\r\n", nHowMuch);
	}

	for (int i = 0; i < MAX_ADAPTIVE_BASE_POSITIONS; i++)
		printf("[ %d,  %d ] - ", initDigits[i] ,batchDigits[i]);

	AdaptiveUpdateMnemonicLow64(&batchMnemo[1]
		, digitSet
		, batchDigits);


	int16_t tmp2[12] = {
		(batchMnemo[0] >> 53) & 2047,
		(batchMnemo[0] >> 42) & 2047,
		(batchMnemo[0] >> 31) & 2047,
		(batchMnemo[0] >> 20) & 2047,
		(batchMnemo[0] >> 9) & 2047,
		((batchMnemo[0] & ((1 << 9) - 1)) << 2) | ((batchMnemo[1] >> 62) & 3),
		(batchMnemo[1] >> 51) & 2047,
		(batchMnemo[1] >> 40) & 2047,
		(batchMnemo[1] >> 29) & 2047,
		(batchMnemo[1] >> 18) & 2047,
		(batchMnemo[1] >> 7) & 2047,
		((batchMnemo[1] & ((1 << 7) - 1)) << 4)

	};

	int16_t temArr[6] = {
		digitSet[0][batchDigits[0]]
		,	digitSet[1][batchDigits[1]]
		,	digitSet[2][batchDigits[2]]
		,	digitSet[3][batchDigits[3]]
		,	digitSet[4][batchDigits[4]]
		,	digitSet[5][batchDigits[5]] };
	printf ("Stars from 2nd half [%llu] --> %s\r\n", nHowMuch , tools::GetMnemoString(temArr, 6).c_str() );
	printf ("Fully last checksum: [%llu] --> %s\r\n" ,nHowMuch, tools::GetMnemoString(tmp2, 12).c_str());
}








