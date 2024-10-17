#include <stdafx.h>
#include <stdio.h>


#include <cuda.h>
#include "cuda_runtime.h"

#include "GPU.h"
#include "AdaptiveBase.h"

#include "EntropyTools.cuh"

__global__ void gl_DictionaryScanner(
	const uint64_t* __restrict__ nProcessedIterations,
	uint64_t* nProcessedInstances,
	const tableStruct* __restrict__ tables_legacy,
	const tableStruct* __restrict__ tables_segwit,
	const tableStruct* __restrict__ tables_native_segwit,
	retStruct* __restrict__ ret
)
{
	unsigned int effective_idx = blockIdx.x * blockDim.x + threadIdx.x;

	uint32_t nTotalThreads = blockDim.x * gridDim.x;

	__shared__ uint64_t ourBlockProcNormal;
	__shared__ unsigned int nMoreIterated;
	__shared__ uint64_t bBulkJobeDoneAt;

	int16_t local_static_word_index[12];

	// Initialize the shared variable
	if (threadIdx.x == 0) {
		ourBlockProcNormal = 0; // Only the first thread initializes it

		nMoreIterated = 0;
		bBulkJobeDoneAt = 0xFFFFFFFFFFFFFFFFull;
	}
	__syncthreads(); // Synchronize to ensure the initialization is complete

	for (int i = 0; i < 6; i++) {
		local_static_word_index[i] = dev_static_words_indices[i];
	}


	uint64_t curEntropy[2];
	curEntropy[0] = dev_EntropyAbsolutePrefix64[PTR_AVOIDER];
	curEntropy[1] = dev_EntropyNextPrefix2[PTR_AVOIDER];


	uint8_t reqChecksum = 0;
	uint8_t achievedChecksum = 1;
	bool bChkMatched = false;

	int16_t curDigits[MAX_ADAPTIVE_BASE_POSITIONS] = { 
		 dev_AdaptiveBaseCurrentBatchInitialDigits[0]
		,dev_AdaptiveBaseCurrentBatchInitialDigits[1]
		,dev_AdaptiveBaseCurrentBatchInitialDigits[2]
		,dev_AdaptiveBaseCurrentBatchInitialDigits[3]
		,dev_AdaptiveBaseCurrentBatchInitialDigits[4]
		,dev_AdaptiveBaseCurrentBatchInitialDigits[5] 
	};

	//TODO block: prefix is based on  words 9 and 10 while the last word 11 is iterated inside the thread

	int nTried = 0;
	bool bCouldAdd = false;
	const int16_t lastPos_adaptive = MAX_ADAPTIVE_BASE_POSITIONS - 1;
	const int16_t lastPosCarryTrig = dev_AdaptiveBaseDigitCarryTrigger[lastPos_adaptive];

	//instead of effective_idx, increment so that bypass and leave last word iteration completely to this thread

	SyncBipIndexFromAdaptiveDigits(local_static_word_index , dev_AdaptiveBaseDigitSet , curDigits);

	//Work with Current Entropy
	uint8_t mnemonic_phrase[SIZE_MNEMONIC_FRAME] = { 0 };
	uint8_t* mnemonic = mnemonic_phrase;
	uint64_t nLoopMasterOffset = effective_idx * lastPosCarryTrig + *nProcessedIterations * nTotalThreads;
	for (int16_t nWordElevenOffset = 0; nWordElevenOffset < lastPosCarryTrig; nWordElevenOffset++) {
		//break on nTried < MAX_TRY_PER_THREAD
		uint64_t nInstanceOffset = nLoopMasterOffset + nWordElevenOffset;

		if (nInstanceOffset > bBulkJobeDoneAt) {
			//if (blockIdx.x == 0) {
			//	printf("\r\nBlock Job done at:%llu\r\n", nInstanceOffset);
			//}
			break;
		}

		bCouldAdd = IncrementAdaptiveDigits(
			dev_AdaptiveBaseDigitCarryTrigger
			, dev_AdaptiveBaseCurrentBatchInitialDigits
			, nInstanceOffset, curDigits);

		if (bCouldAdd == false /*&& lastPosCarryTrig == nWordElevenOffset*/) {
			//if (effective_idx == nMaxCloudAdd + 1) {
			//	printf("Can not add bulk at %x", lastPosCarryTrig);
			//}

			atomicExch(&bBulkJobeDoneAt, nInstanceOffset);
			break;
		}
		atomicAdd(&ourBlockProcNormal, 1);
		//else {
		//	atomicMax(&nMaxCloudAdd, effective_idx);
		//}

		SyncBipIndexFromAdaptiveDigits(local_static_word_index, dev_AdaptiveBaseDigitSet, curDigits);

		//int16_t word_11_BIP = dev_AdaptiveBaseDigitSet[lastPos_adaptive][nWordElevenOffset];
		//curDigits[lastPos_adaptive] = nWordElevenOffset;
		curEntropy[1] = dev_EntropyNextPrefix2[PTR_AVOIDER];
		AdaptiveUpdateMnemonicLow64(&curEntropy[1], dev_AdaptiveBaseDigitSet, curDigits);
		//local_static_word_index[11] = word_11_BIP;
		int16_t wordElevenBipVal = local_static_word_index[11];


#if 0 //not required for checksum comparison here
		entropy_to_mnemonic_with_offset(curEntropy, mnemonic, 0, local_static_word_index);
#endif
		reqChecksum = wordElevenBipVal & 0x000F;

		uint8_t entropy_hash[32];
		uint8_t bytes[16];
		uint64_t* entropy = curEntropy;

		bytes[15] = entropy[1] & 0xFF;
		bytes[14] = (entropy[1] >> 8) & 0xFF;
		bytes[13] = (entropy[1] >> 16) & 0xFF;
		bytes[12] = (entropy[1] >> 24) & 0xFF;
		bytes[11] = (entropy[1] >> 32) & 0xFF;
		bytes[10] = (entropy[1] >> 40) & 0xFF;
		bytes[9] = (entropy[1] >> 48) & 0xFF;
		bytes[8] = (entropy[1] >> 56) & 0xFF;

		bytes[7] = entropy[0] & 0xFF;
		bytes[6] = (entropy[0] >> 8) & 0xFF;
		bytes[5] = (entropy[0] >> 16) & 0xFF;
		bytes[4] = (entropy[0] >> 24) & 0xFF;
		bytes[3] = (entropy[0] >> 32) & 0xFF;
		bytes[2] = (entropy[0] >> 40) & 0xFF;
		bytes[1] = (entropy[0] >> 48) & 0xFF;
		bytes[0] = (entropy[0] >> 56) & 0xFF;

		sha256((uint32_t*)bytes, 16, (uint32_t*)entropy_hash);
		achievedChecksum = (entropy_hash[0] >> 4) & 0x0F;

		bChkMatched = (achievedChecksum == reqChecksum);

		nTried++;
#if 0
		if (effective_idx <= 2 || (effective_idx <= 242 && effective_idx >= 240)) {
			uint8_t word_11_text[10];
			GetWordFromBipIndex(wordElevenBipVal, word_11_text);
			//entropy_to_mnemonic_with_offset(curEntropy, mnemonic, 0, local_static_word_index);
			printf("idx:%u [+ %llu ] @%s (%d : %d) on [%s]  CHK: %s req=%u ach=%u \r\n"
				, effective_idx
				, nInstanceOffset
				, word_11_text
				, nWordElevenOffset
				, wordElevenBipVal
				, mnemonic
				, (bChkMatched) ?  "OK" : "Bad"
				, reqChecksum
				, achievedChecksum
			);
		}
#endif
#if 1
		if (!bChkMatched) {
			continue;
		}
#endif
		//__syncthreads(); // Synchronize to and check if have a valid checksum to continue with
		if (bChkMatched) { //scrutinize : bCouldAdd

			uint8_t mnemonic_phrase[SIZE_MNEMONIC_FRAME] = { 0 };
			uint8_t* mnemonic = mnemonic_phrase;
			uint32_t ipad[256 / 4];
			uint32_t opad[256 / 4];
			uint32_t seed[64 / 4];


			//Work with Current Entropy
			entropy_to_mnemonic_with_offset(curEntropy, mnemonic, 0, local_static_word_index);

			//if (idx == 0) {
	//			printf("nemo-%u  (retry.remain=%d/%d) = :%s \r\n\r\n", effective_idx,nTried,MAX_TRY_PER_THREAD, mnemonic);
			//}
			//entropy_to_mnemonic(entropy, mnemonic);
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

			//printf("END block %d - thread  %d - EffectiveId:%d - curDigits:%d-%d-%d-%d-%d-%d %s\r\n", blockId, threadId, effective_idx
			//	, curDigits[0], curDigits[1], curDigits[2], curDigits[3], curDigits[4], curDigits[5] , mnemonic);


			key_to_hash160((extended_private_key_t*)&ipad[128 / 4], tables_legacy, tables_segwit, tables_native_segwit, (uint32_t*)mnemonic, ret);
			
		}
	} 

	__syncthreads(); // Synchronize to ensure all data is loaded
	if (threadIdx.x == 0) {
		atomicAdd(nProcessedInstances, ourBlockProcNormal);
	}

}//DICTIONARY ATTACK
