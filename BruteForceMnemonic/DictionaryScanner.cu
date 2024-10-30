#include <stdafx.h>
#include <stdio.h>


#include <cuda.h>
#include "cuda_runtime.h"

#include "GPU.h"
#include "AdaptiveBase.h"

#include "EntropyTools.cuh"
#include "DictionaryScanner.cuh"
#include "Bip39Tools.cuh"



static inline __device__ int device_hashcmp(const  uint32_t* p1, const uint32_t* p2) {
#pragma unroll
	for (auto i = 0; i < 20/4; ++i) {
		if (p1[i] != p2[i]) {
			return p1[i] < p2[i] ? -1 : 1; // Return -1 if p1 < p2, 1 if p1 > p2
		}
	}
	return 0; // Memory regions are equal
}


__global__ void gl_DictionaryScanner(
	const uint64_t* __restrict__ nProcessingIteration,
	uint64_t* nProcessedInstances
)
{
	unsigned int effective_idx = blockIdx.x * blockDim.x + threadIdx.x;

	uint32_t nTotalThreads = blockDim.x * gridDim.x;

	__shared__ uint64_t ourBlockProcNormal;
	__shared__ uint64_t nGridJobCap;
	__shared__ uint8_t bDone;

	int16_t local_static_word_index[12];

	// Initialize the shared variable (first thread of each block)
	if (threadIdx.x == 0) {
		ourBlockProcNormal = 0;
		nGridJobCap = ULLONG_MAX;
		bDone = 0;
	}
	__syncthreads(); // Synchronize to ensure the initialization is complete

	for (int i = 0; i < 6; i++) {
		local_static_word_index[i] = dev_static_words_indices[i];
	}


	uint64_t curEntropy[2];
	curEntropy[0] = dev_EntropyAbsolutePrefix64[PTR_AVOIDER];
	curEntropy[1] = dev_EntropyNextPrefix2[PTR_AVOIDER];


	int16_t curDigits[MAX_ADAPTIVE_BASE_POSITIONS] = {
		 dev_AdaptiveBaseCurrentBatchInitialDigits[0]
		,dev_AdaptiveBaseCurrentBatchInitialDigits[1]
		,dev_AdaptiveBaseCurrentBatchInitialDigits[2]
		,dev_AdaptiveBaseCurrentBatchInitialDigits[3]
		,dev_AdaptiveBaseCurrentBatchInitialDigits[4]
		,dev_AdaptiveBaseCurrentBatchInitialDigits[5]
	};

	//TODO block: prefix is based on  words 9 and 10 while the last word 11 is iterated inside the thread

	const int16_t nPosElevenAdaptiveIdx = MAX_ADAPTIVE_BASE_POSITIONS - 1;
	const int16_t nPosElevenCarryTrig = dev_AdaptiveBaseDigitCarryTrigger[nPosElevenAdaptiveIdx];
	const int16_t nPostTenAdaptiveIdx = nPosElevenAdaptiveIdx - 1;
	const int16_t nPosTenCarryTrig = dev_AdaptiveBaseDigitCarryTrigger[nPostTenAdaptiveIdx];

	//instead of effective_idx, increment so that bypass and leave last word iteration completely to this thread

	SyncBipIndexFromAdaptiveDigits(local_static_word_index, dev_AdaptiveBaseDigitSet, curDigits);

	//Work with Current Entropy
	uint8_t mnemonic_phrase[SIZE_MNEMONIC_FRAME] = { 0 };
	uint8_t* mnemonic = mnemonic_phrase;
	uint64_t nLoopMasterOffset = effective_idx * nPosElevenCarryTrig * nPosTenCarryTrig 
		+ *nProcessingIteration * (nTotalThreads * nPosElevenCarryTrig * nPosTenCarryTrig);

	uint8_t checkSumInputBlock[16];//with constant portion initalization
	checkSumInputBlock[7] = dev_EntropyAbsolutePrefix64[0] & 0xFF;
	checkSumInputBlock[6] = (dev_EntropyAbsolutePrefix64[0] >> 8) & 0xFF;
	checkSumInputBlock[5] = (dev_EntropyAbsolutePrefix64[0] >> 16) & 0xFF;
	checkSumInputBlock[4] = (dev_EntropyAbsolutePrefix64[0] >> 24) & 0xFF;
	checkSumInputBlock[3] = (dev_EntropyAbsolutePrefix64[0] >> 32) & 0xFF;
	checkSumInputBlock[2] = (dev_EntropyAbsolutePrefix64[0] >> 40) & 0xFF;
	checkSumInputBlock[1] = (dev_EntropyAbsolutePrefix64[0] >> 48) & 0xFF;
	checkSumInputBlock[0] = (dev_EntropyAbsolutePrefix64[0] >> 56) & 0xFF;


	//#pragma unroll
	for (int16_t nWordTenOffset = 0; nWordTenOffset < nPosTenCarryTrig; nWordTenOffset++) {
		for (int16_t nWordElevenOffset = 0; nWordElevenOffset < nPosElevenCarryTrig; nWordElevenOffset++) {
			uint64_t nInstanceOffset = 
				  nLoopMasterOffset 
				+ nWordTenOffset * nPosElevenCarryTrig
				+ nWordElevenOffset
			;
			if (nInstanceOffset > nGridJobCap) {
				break;
			}

			if (false == IncrementAdaptiveDigits(
				dev_AdaptiveBaseDigitCarryTrigger
				, dev_AdaptiveBaseCurrentBatchInitialDigits
				, nInstanceOffset, curDigits)) {

				atomicMin(&nGridJobCap, nInstanceOffset);
				break;
			}
			atomicAdd(&ourBlockProcNormal, 1);


			SyncBipIndexFromAdaptiveDigits(local_static_word_index, dev_AdaptiveBaseDigitSet, curDigits);

			curEntropy[1] = dev_EntropyNextPrefix2[PTR_AVOIDER];
			AdaptiveUpdateMnemonicLow64(&curEntropy[1], dev_AdaptiveBaseDigitSet, curDigits);
			int16_t wordElevenBipVal = local_static_word_index[11];


			uint8_t reqChecksum = wordElevenBipVal & 0x000F;
			bool bChkMatched = CheckSumValidate(checkSumInputBlock, curEntropy, reqChecksum);


			if (!bChkMatched) {
				continue;
			}
			//NOTE : If we reach here the checksum is already matching, just need to check the address
			//__syncthreads(); // Synchronize to and check if have a valid checksum to continue with
			//if (bChkMatched) { //scrutinize : bCouldAdd

			uint8_t mnemonic_phrase[SIZE_MNEMONIC_FRAME] = { 0 };
			uint8_t* mnemonic = mnemonic_phrase;
			uint32_t ipad[256 / 4];
			uint32_t opad[256 / 4];
			uint32_t seed[64 / 4];


			//Work with Current Entropy
			//entropy_to_mnemonic_with_offset(curEntropy, mnemonic, 0, local_static_word_index);
			IndicesToMnemonic(local_static_word_index, (uint8_t*)mnemonic, words, word_lengths);

#pragma unroll
			for (int x = 0; x < 120 / 8; x++) {
				*(uint64_t*)((uint64_t*)ipad + x) = 0x3636363636363636ULL ^ SWAP512(*(uint64_t*)((uint64_t*)mnemonic + x));
			}
#pragma unroll
			for (int x = 0; x < 120 / 8; x++) {
				*(uint64_t*)((uint64_t*)opad + x) = 0x5C5C5C5C5C5C5C5CULL ^ SWAP512(*(uint64_t*)((uint64_t*)mnemonic + x));
			}
#pragma unroll
			for (int x = 120 / 4; x < 128 / 4; x++) {
				ipad[x] = 0x36363636;
			}
#pragma unroll
			for (int x = 120 / 4; x < 128 / 4; x++) {
				opad[x] = 0x5C5C5C5C;
			}
#pragma unroll
			for (int x = 0; x < 16 / 4; x++) {
				ipad[x + 128 / 4] = *(uint32_t*)((uint32_t*)&salt_swap + x);
			}
			sha512_swap((uint64_t*)ipad, 140, (uint64_t*)&opad[128 / 4]);
			sha512_swap((uint64_t*)opad, 192, (uint64_t*)&ipad[128 / 4]);
#pragma unroll
			for (int x = 0; x < 64 / 4; x++) {
				seed[x] = ipad[128 / 4 + x];
			}
			for (int x = 1; x < 2048; x++) {
				sha512_swap((uint64_t*)ipad, 192, (uint64_t*)&opad[128 / 4]);
				sha512_swap((uint64_t*)opad, 192, (uint64_t*)&ipad[128 / 4]);
#pragma unroll
				for (int x = 0; x < 64 / 4; x++) {
					seed[x] = seed[x] ^ ipad[128 / 4 + x];
				}
			}
#pragma unroll
			for (int x = 0; x < 16 / 4; x++) {
				ipad[x] = 0x36363636 ^ *(uint32_t*)((uint32_t*)&key_swap + x);
			}
#pragma unroll
			for (int x = 0; x < 16 / 4; x++) {
				opad[x] = 0x5C5C5C5C ^ *(uint32_t*)((uint32_t*)&key_swap + x);
			}
#pragma unroll
			for (int x = 16 / 4; x < 128 / 4; x++) {
				ipad[x] = 0x36363636;
			}
#pragma unroll
			for (int x = 16 / 4; x < 128 / 4; x++) {
				opad[x] = 0x5C5C5C5C;
			}
#pragma unroll
			for (int x = 0; x < 64 / 4; x++) {
				ipad[x + 128 / 4] = seed[x];
			}
			//ipad[192 / 4] = 0;
			//opad[192 / 4] = 0;
			sha512_swap((uint64_t*)ipad, 192, (uint64_t*)&opad[128 / 4]);
			sha512_swap((uint64_t*)opad, 192, (uint64_t*)&ipad[128 / 4]);
#pragma unroll
			for (int x = 0; x < 128 / 8; x++) {
				*(uint64_t*)((uint64_t*)&ipad[128 / 4] + x) = SWAP512(*(uint64_t*)((uint64_t*)&ipad[128 / 4] + x));
			}

			{
				const extended_private_key_t* master_private = (extended_private_key_t*)&ipad[128 / 4];

				uint32_t hash[(20 / 4)];
				extended_private_key_t target_key;
				extended_private_key_t target_key_fo_pub;
				extended_private_key_t master_private_fo_extint;
				extended_public_key_t target_public_key;

				for (uint8_t accNo = dev_accntMinMax[0]; accNo <= dev_accntMinMax[1]; accNo++) {
					hardened_private_child_from_private(master_private, &target_key, 44);
					hardened_private_child_from_private(&target_key, &target_key, 0);
					hardened_private_child_from_private(&target_key, &master_private_fo_extint, accNo); //acount-number
					normal_private_child_from_private(&master_private_fo_extint, &target_key, 0); //extension-0-internal-external
					//m/44'/0'/0'/0/x
					for (int x = dev_childrenMinMax[0]; x <= dev_childrenMinMax[1]; x++) {

						normal_private_child_from_private(&target_key, &target_key_fo_pub, x); //child x
						calc_public(&target_key_fo_pub, &target_public_key);
						calc_hash160(&target_public_key, hash);


						if (device_hashcmp((uint32_t*)hash, (uint32_t*)dev_uniqueTargetAddressBytes) == 0) {
							dev_retEntropy[0] = curEntropy[0];
							dev_retEntropy[1] = curEntropy[1];
							dev_retAccntPath[0] = accNo;
							dev_retAccntPath[1] = x;
							bDone = 1;
							break;
						}
						if (bDone != 0)
							break;
					}
					if (bDone != 0)
						break;
				}//accNo
				if (bDone != 0)
					break;
			}
		}//for word 11 
	}//word 10
	__syncthreads(); // Synchronize to ensure all data is loaded
	if (threadIdx.x == 0) {
		atomicAdd(nProcessedInstances, ourBlockProcNormal);
	}
}//DICTIONARY ATTACK
