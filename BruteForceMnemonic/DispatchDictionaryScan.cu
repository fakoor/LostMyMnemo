#include <stdafx.h>

#include <iostream>
#include <thread>

#include "cuda_runtime.h"

#include "DispatchDictionaryScan.cuh"
#include "DictionaryScanner.cuh"

#include "consts.h"
#include "AdaptiveBase.h"


#include "../Tools/tools.h"
#include "../Tools/utils.h"
#include "Helper.h"
#include "EntropyTools.cuh"

bool  DispatchDictionaryScan(ConfigClass* Config, data_class* Data, stride_class* Stride) {

	if (InitalSync(Config) == false)
		return false;



	uint64_t nProblemPower =
		(uint64_t)host_AdaptiveBaseDigitCarryTrigger[0]
		* host_AdaptiveBaseDigitCarryTrigger[1]
		* host_AdaptiveBaseDigitCarryTrigger[2]
		* host_AdaptiveBaseDigitCarryTrigger[3]
		* host_AdaptiveBaseDigitCarryTrigger[4]
		* host_AdaptiveBaseDigitCarryTrigger[5];


	uint64_t nSolverThreads = Config->cuda_block * Config->cuda_grid;
	uint64_t nIterationPower = nSolverThreads * host_AdaptiveBaseDigitCarryTrigger[5];
	uint64_t nIterationsNeeded = nProblemPower / nIterationPower;

	if (nIterationsNeeded * nIterationPower < nProblemPower)
		nIterationsNeeded++;



	std::cout << "-- Starting Dictionary SCAN -- " << std::endl;

	std::cout << " Going to dispatch " << nProblemPower << " total COMBOs"
		<< " via " << nIterationsNeeded << " iterations "
		" (each able to process " << nIterationPower << " instances)." << std::endl;

	uint64_t nUniversalProcessed = 0;


	uint64_t nBatchMax = 1;

	int nBatch = 0;


	
	size_t copySize;
	cudaError cudaResult;

	//uint64_t nMasterIteration = 0;
	*Data->host.nProcessedInstances = 0;
	*Data->host.nProcessedIterations = 0;

	if (cudaSuccess != cudaMemcpy(Data->dev.nProcessedInstances, Data->host.nProcessedInstances, 8, cudaMemcpyHostToDevice)) {
		std::cout << "Error-Line--" << __LINE__ << std::endl;
	}


	do
	{
		//Set Master Iteration
		if (cudaSuccess != cudaMemcpy(Data->dev.nProcessedIterations, Data->host.nProcessedIterations, 8, cudaMemcpyHostToDevice)) {
			std::cout << "Error-Line--" << __LINE__ << std::endl;
		}

		//Zero Previous Count
		*Data->host.nProcessedInstances = 0;
		if (cudaSuccess != cudaMemcpy( Data->dev.nProcessedInstances, Data->host.nProcessedInstances, 8, cudaMemcpyHostToDevice)) {
			std::cout << "Error-Line--" << __LINE__ << std::endl;
		}


		printf("Iteration: %llu started.\r\n", *Data->host.nProcessedIterations);



		tools::start_time();

		if (Stride->startDictionaryAttack(Config->cuda_grid, Config->cuda_block) != 0) {
			std::cerr << "Error START!!" << std::endl;
			return false;
		}


		if (Stride->endDictionaryAttack() != 0) {
			std::cerr << "Error END!!" << std::endl;
			return false;
		}

		//if (bCfgSaveResultsIntoFile) {
		//	save_thread = std::thread(&tools::saveResult, (char*)Data->host.mnemonic, (uint8_t*)Data->host.hash160, Data->wallets_in_round_gpu, Data->num_all_childs, Data->num_childs, Config->generate_path);
		//}



		if (cudaSuccess != cudaMemcpy(Data->host.nProcessedInstances, Data->dev.nProcessedInstances, 8, cudaMemcpyDeviceToHost)) {
			std::cout << "Error-Line--" << __LINE__ << std::endl;
		}

		printf("Checking results of %llu checkups.\r\n", *Data->host.nProcessedInstances);
		tools::checkResult(Data->host.ret);

		float delay;
		tools::stop_time_and_calc_sec(&delay);
		//std::cout << std::endl << "PROCESSED: at " << tools::formatPrefix((double)*Data->host.nProcessedInstances / delay) << " COMBO/Sec" << std::endl;

		std::cout << "Iteration " << *Data->host.nProcessedIterations
			<< " completed we have processed  " << *Data->host.nProcessedInstances << " COMBOs  at " << tools::formatPrefix((double)*Data->host.nProcessedInstances / delay) << " COMBO/Sec" << std::endl;
		++*Data->host.nProcessedIterations;
	} while (*Data->host.nProcessedIterations < nIterationsNeeded);//trunk
	return true;
}


bool InitalSync(ConfigClass* Config)
{
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] = 0;
	host_EntropyNextPrefix2[PTR_AVOIDER] = 0;

	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[0]) << 53;
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[1]) << 42;
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[2]) << 31;
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[3]) << 20;
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[4]) << 9;

	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[5]) >> 2;
	host_EntropyNextPrefix2[PTR_AVOIDER] = (uint64_t)(Config->words_indicies_mnemonic[5]) << 62; //two bits from main 6 words


	size_t copySize;
	cudaError_t cudaResult;

	copySize = sizeof(uint64_t);
	cudaResult = cudaMemcpyToSymbol(dev_EntropyAbsolutePrefix64, host_EntropyAbsolutePrefix64, copySize, 0, cudaMemcpyHostToDevice);
	if (cudaResult != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol copying " << copySize << " bytes to dev_EntropyAbsolutePrefix64 failed!: " << cudaResult << std::endl;
		return false;
	}

	copySize = sizeof(uint64_t);
	cudaResult = cudaMemcpyToSymbol(dev_EntropyNextPrefix2, host_EntropyNextPrefix2, copySize, 0, cudaMemcpyHostToDevice);
	if (cudaResult != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol copying " << copySize << " bytes to dev_EntropyBatchNext24 failed!: " << cudaResult << std::endl;
		return false;
	}


	copySize = sizeof(int16_t) * MAX_ADAPTIVE_BASE_POSITIONS * MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION;
	cudaResult = cudaMemcpyToSymbol(dev_AdaptiveBaseDigitSet, host_AdaptiveBaseDigitSet, copySize, 0, cudaMemcpyHostToDevice);
	if (cudaResult != cudaSuccess)
	{
		std::cerr << "dev_AdaptiveBaseCurrentBatchInitialDigits copying " << copySize << " bytes to dev_AdaptiveBaseDigitSet failed!: " << cudaResult << std::endl;
		return false;
	}

	copySize = sizeof(host_AdaptiveBaseDigitCarryTrigger[0]) * MAX_ADAPTIVE_BASE_POSITIONS;
	cudaResult = cudaMemcpyToSymbol(dev_AdaptiveBaseDigitCarryTrigger, host_AdaptiveBaseDigitCarryTrigger, copySize, 0, cudaMemcpyHostToDevice);
	if (cudaResult != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol copying " << copySize << " bytes to dev_AdaptiveBaseDigitCarryTrigger failed!: " << cudaResult << std::endl;
		return false;
	}

	copySize = sizeof(int16_t) * MAX_ADAPTIVE_BASE_POSITIONS;
	cudaResult = cudaMemcpyToSymbol(dev_AdaptiveBaseCurrentBatchInitialDigits, host_AdaptiveBaseCurrentBatchInitialDigits, copySize, 0, cudaMemcpyHostToDevice);
	if (cudaResult != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol copying " << copySize << " bytes to dev_AdaptiveBaseCurrentBatchInitialDigits failed!: " << cudaResult << std::endl;
		return false;
	}

	return true;
}
