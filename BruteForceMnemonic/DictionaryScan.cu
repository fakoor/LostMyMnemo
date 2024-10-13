#include <stdafx.h>

#include <iostream>
#include <thread>

#include "cuda_runtime.h"

#include "DictionaryScan.cuh"

#include "consts.h"
#include "AdaptiveBase.h"


#include "../Tools/tools.h"
#include "../Tools/utils.h"
#include "Helper.h"

bool  DispatchDictionaryScan(ConfigClass* Config, data_class* Data, stride_class* Stride) {

	int16_t curDigits[MAX_ADAPTIVE_BASE_POSITIONS];
	uint64_t trunkInitEntropy[2];
	uint8_t reqChecksum;

	//TODO: fill host_EntropyAbsolutePrefix64 and host_EntropyBatchNext24
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] = 0;
	host_EntropyNextPrefix2[PTR_AVOIDER] = 0;

	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[0]) << 53;
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[1]) << 42;
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[2]) << 31;
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[3]) << 20;
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[4]) << 9;

	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[5]) >> 2;
	host_EntropyNextPrefix2[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[5]) << 62; //two bits from main 6 words

	if (SyncWorldWideJobVariables() == false)
		return false;



	AdaptiveDigitsToEntropy(
		host_AdaptiveBaseCurrentBatchInitialDigits
		, host_AdaptiveBaseDigitCarryTrigger
		, host_AdaptiveBaseDigitSet
		, host_EntropyAbsolutePrefix64
		, host_EntropyNextPrefix2
		, host_AdaptiveBaseCurrentBatchInitialDigits
		, trunkInitEntropy,
		&reqChecksum);

	if (trunkInitEntropy[0] == host_EntropyAbsolutePrefix64[0]) {
		std::cout << "Init Entropy Sucessfully initialized by higher bits " << trunkInitEntropy[0] << std::endl;
		if (host_EntropyNextPrefix2[0] == trunkInitEntropy[1]) {
			std::cout << "Init Entropy Sucessfully tested for lower bits " << trunkInitEntropy[1] << std::endl;

		}
	}

	host_EntropyNextPrefix2[0] &= 0xFFFFFF0000000000ULL; //test done, revert nack to only 24 msbs


	size_t copySize = sizeof(int16_t) * MAX_ADAPTIVE_BASE_POSITIONS * MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION;
	cudaError_t cudaResult = cudaMemcpyToSymbol(dev_AdaptiveBaseDigitSet, host_AdaptiveBaseDigitSet, copySize, 0, cudaMemcpyHostToDevice);
	if (cudaResult != cudaSuccess)
	{
		std::cerr << "dev_AdaptiveBaseCurrentBatchInitialDigits copying " << copySize << " bytes to dev_AdaptiveBaseDigitSet failed!: " << cudaResult << std::endl;
		return false;
	}


	//Initial zeroing
	//host_nProcessedFromBatch[0] = 0;
	//host_nProcessedMoreThanBatch[0] = 0;




	int nPlannedTrunks = 1;//host_AdaptiveBaseDigitCarryTrigger[0] * host_AdaptiveBaseDigitCarryTrigger[1];

	uint64_t nPrevBatchProcessed = 0;

	uint64_t nPlanned44BitCombos = host_AdaptiveBaseDigitCarryTrigger[2]
		* host_AdaptiveBaseDigitCarryTrigger[3]
		* host_AdaptiveBaseDigitCarryTrigger[4]
		* host_AdaptiveBaseDigitCarryTrigger[5];

	uint64_t nUniversalMax =
		host_AdaptiveBaseDigitCarryTrigger[0]
		* host_AdaptiveBaseDigitCarryTrigger[1]
		* host_AdaptiveBaseDigitCarryTrigger[2]
		* host_AdaptiveBaseDigitCarryTrigger[3]
		* host_AdaptiveBaseDigitCarryTrigger[4]
		* host_AdaptiveBaseDigitCarryTrigger[5];//nPlanned24BitTrunks* nPlanned44BitCombos;

	uint64_t nUniversalProcessed = 0;

	uint64_t nThreadsInBatch = Config->cuda_block * Config->cuda_grid;

	uint64_t nBatchMax = nUniversalMax / nThreadsInBatch;

	if (nBatchMax * nThreadsInBatch < nUniversalMax)
		nBatchMax++;

	int nBatch = 0;


	std::cout << ">> (" << __DATE__ << "@" << __TIME__ << ") ->" << "Planing to check total " << nUniversalMax << " combinations structured in maximum " << nBatchMax << " batches "
		" of " << nThreadsInBatch << " threads each" << std::endl;


	uint64_t nTrunk = 0;
	do
	{
		if (nTrunk >= nPlannedTrunks) {
			break;
		}

		std::cout << "> Starting Dictionary SCAN -- " << std::endl;

		if (SyncWorldWideJobVariables() == false)
			return false;


		nBatch = 0;

		int16_t batchDigits[MAX_ADAPTIVE_BASE_POSITIONS];
		if (IncrementAdaptiveDigits(host_AdaptiveBaseDigitCarryTrigger
			, host_AdaptiveBaseCurrentBatchInitialDigits
			, 0 //kinda copy
			, batchDigits)) {
			//printf("Batch digits initialized for the first time.\r\n");
		}

		//std::cout << "ALL VARIANTS:" << std::endl;

		//uint64_t batchMnemo[2];
		//batchMnemo[0] = host_EntropyAbsolutePrefix64[0];
		//batchMnemo[1] = host_EntropyNextPrefix2[0] & 0xB0000000; //scrutinize;

		//for (int i = 0; i < 4; i++) {
		//	PrintNextMnemo(batchMnemo, i, host_AdaptiveBaseDigitCarryTrigger , host_AdaptiveBaseCurrentBatchInitialDigits, host_AdaptiveBaseDigitSet);
		//}

		//for (int i = 0; i < MAX_ADAPTIVE_BASE_POSITIONS; i++) {
		//	std::cout << host_AdaptiveBaseCurrentBatchInitialDigits[i] << "=" << batchDigits[i] << std::endl;
		//}

		size_t copySize;
		cudaError cudaResult;

		copySize = sizeof(uint64_t);
		cudaResult = cudaMemcpyToSymbol(dev_EntropyAbsolutePrefix64, host_EntropyAbsolutePrefix64, copySize, 0, cudaMemcpyHostToDevice);
		if (cudaResult != cudaSuccess)
		{
			std::cerr << "cudaMemcpyToSymbol copying " << copySize << " bytes to dev_EntropyAbsolutePrefix64 failed!: " << cudaResult << std::endl;
			return false;
		}

		copySize = sizeof(host_AdaptiveBaseDigitCarryTrigger[0]) * MAX_ADAPTIVE_BASE_POSITIONS;
		cudaResult = cudaMemcpyToSymbol(dev_AdaptiveBaseDigitCarryTrigger, host_AdaptiveBaseDigitCarryTrigger, copySize, 0, cudaMemcpyHostToDevice);
		if (cudaResult != cudaSuccess)
		{
			std::cerr << "cudaMemcpyToSymbol copying " << copySize << " bytes to dev_AdaptiveBaseDigitCarryTrigger failed!: " << cudaResult << std::endl;
			return false;
		}

		do { //batch


			//TODO: increment entropy here accordingto grid , processed and extra

			const int elemSize = sizeof(int16_t);
			copySize = elemSize * MAX_ADAPTIVE_BASE_POSITIONS;

			cudaResult = cudaMemcpyToSymbol(dev_AdaptiveBaseCurrentBatchInitialDigits, batchDigits, copySize, 0, cudaMemcpyHostToDevice);
			if (cudaResult != cudaSuccess)
			{
				std::cerr << "cudaMemcpyToSymbol copying " << copySize << " bytes to dev_AdaptiveBaseCurrentBatchInitialDigits failed!: " << cudaResult << std::endl;
				return false;
			}



			std::cout << "BATCH #"
				<< nBatch << " of " << nBatchMax << std::endl;

			*Data->host.host_nProcessedFromBatch = 0;
			*Data->host.host_nProcessedMoreThanBatch = 0;

			if (cudaSuccess != cudaMemcpy(Data->dev.dev_nProcessedFromBatch, Data->host.host_nProcessedFromBatch, 8, cudaMemcpyHostToDevice)) {
				std::cout << "Error-Line--" << __LINE__ << std::endl;
			}

			if (cudaSuccess != cudaMemcpy(Data->dev.dev_nProcessedMoreThanBatch, Data->host.host_nProcessedMoreThanBatch, 8, cudaMemcpyHostToDevice)) {
				std::cout << "Error-Line--" << __LINE__ << std::endl;
			}

			tools::start_time();

			if (Stride->startDictionaryAttack(Config->cuda_grid, Config->cuda_block) != 0) {
				std::cerr << "Error START!!" << std::endl;
				return false;
			}

			//TODO: Handled by dictionary attack with index
			std::cout << "Waiting for batch " << nBatch << " to finish." << std::endl;
			//if (save_thread.joinable()) save_thread.join();

			if (Stride->endDictionaryAttack() != 0) {
				std::cerr << "Error END!!" << std::endl;
				return false;
			}

			//if (bCfgSaveResultsIntoFile) {
			//	save_thread = std::thread(&tools::saveResult, (char*)Data->host.mnemonic, (uint8_t*)Data->host.hash160, Data->wallets_in_round_gpu, Data->num_all_childs, Data->num_childs, Config->generate_path);
			//}

			if (cudaSuccess != cudaMemcpy(Data->host.host_nProcessedFromBatch, Data->dev.dev_nProcessedFromBatch, 8, cudaMemcpyDeviceToHost)) {
				std::cout << "Error-Line--" << __LINE__ << std::endl;
			}

			if (cudaSuccess != cudaMemcpy(Data->host.host_nProcessedMoreThanBatch, Data->dev.dev_nProcessedMoreThanBatch, 8, cudaMemcpyDeviceToHost)) {
				std::cout << "Error-Line--" << __LINE__ << std::endl;
			}

			uint64_t nTotalThisBatch = 0;
			uint64_t v1 = *Data->host.host_nProcessedFromBatch;
			uint64_t v2 = *Data->host.host_nProcessedMoreThanBatch;
			if (nBatch != nBatchMax && v1 != nThreadsInBatch) {
				printf("This batch appears to be the last one!\r\n");
			}
			nTotalThisBatch = v1 + v2;

			printf("checking results of %ul + %ul = %ul checkups\r\n", v1, v2, nTotalThisBatch);
			tools::checkResult(Data->host.ret);

			float delay;
			tools::stop_time_and_calc_sec(&delay);
			std::cout << std::endl << "PROCESSED: at " << tools::formatPrefix((double)nTotalThisBatch / delay) << " COMBO/Sec" << std::endl;
			//std::cout << "\rGENERATE: " << tools::formatWithCommas((double)Data->wallets_in_round_gpu / delay) << " MNEMONICS/SEC AND "
			//	<< tools::formatWithCommas((double)(Data->wallets_in_round_gpu * Data->num_all_childs) / delay) << " ADDRESSES/SEC"
			//	<< " | SCAN: " << tools::formatPrefix((double)(Data->wallets_in_round_gpu * Data->num_all_childs * num_addresses_in_tables) / delay) << " ADDRESSES/SEC"
			//	<< " | ROUND: " << nTrunk;

			//nPrevBatchProcessed = Data->host.host_nProcessedFromBatch[PTR_AVOIDER]
			//	+ Data->host.host_nProcessedMoreThanBatch[PTR_AVOIDER];
			//std::cout << ">>>This batch (#" << nBatch << ") completed processing " << nPrevBatchProcessed << " combos." << std::endl;
//				nCumulativeCombosProcessedInTrunk += nPrevBatchProcessed;

			if (IncrementAdaptiveDigits(host_AdaptiveBaseDigitCarryTrigger
				, host_AdaptiveBaseCurrentBatchInitialDigits
				, nTotalThisBatch
				, batchDigits) == false) {
				printf("Nothing more to traverse\r\n");
			}
			//memcpy(&host_AdaptiveBaseCurrentBatchInitialDigits[0], &batchDigits[0], sizeof(int16_t) * MAX_ADAPTIVE_BASE_POSITIONS)
			for (int x = 0; x < MAX_ADAPTIVE_BASE_POSITIONS; x++) {
				host_AdaptiveBaseCurrentBatchInitialDigits[x] = batchDigits[x];
			}

			nUniversalProcessed += nTotalThisBatch;

			nBatch++;
		} while (nUniversalProcessed < nUniversalMax); //batch

		std::cout << ">>This Trunk (#" << nTrunk << ") completed processing " << nUniversalProcessed << "/" << nUniversalMax << "  combinations" << std::endl;
		//nCumulativeCombosProcessedInTrunk = 0;

	} while (false);//trunk
	return true;
}


bool SyncWorldWideJobVariables()
{
	AdaptiveUpdateMnemonicLow64(host_EntropyNextPrefix2
		, host_AdaptiveBaseDigitSet
		, host_AdaptiveBaseCurrentBatchInitialDigits);

	host_EntropyNextPrefix2[0] &= 0xFFFFFF00000000;
	size_t copySize = sizeof(uint64_t);
	cudaError_t cudaResult = cudaMemcpyToSymbol(dev_EntropyNextPrefix2, host_EntropyNextPrefix2, copySize, 0, cudaMemcpyHostToDevice);
	if (cudaResult != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol copying " << copySize << " bytes to dev_EntropyBatchNext24 failed!: " << cudaResult << std::endl;
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
