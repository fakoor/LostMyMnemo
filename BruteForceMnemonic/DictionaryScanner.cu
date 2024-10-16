#include <stdafx.h>
#include <stdio.h>


#include <cuda.h>
#include "cuda_runtime.h"

#include <GPU.h>
#include "AdaptiveBase.h"

#include "EntropyTools.cuh"

__global__ void gl_DictionaryScanner(
	uint64_t* nBatchPlannedProc,
	uint64_t* nBatchMoreProc,
	const tableStruct* __restrict__ tables_legacy,
	const tableStruct* __restrict__ tables_segwit,
	const tableStruct* __restrict__ tables_native_segwit,
	retStruct* __restrict__ ret
)
{
	unsigned int effective_idx = blockIdx.x * blockDim.x + threadIdx.x;

	uint16_t totalPlannedCount = blockDim.x * gridDim.x;

	__shared__ uint64_t ourBlockProcNormal;
	__shared__ uint64_t ourBlockProcExtra;
	__shared__ uint64_t ourBlockBadChkSum;
	__shared__ uint64_t ourBlockGoodChkSum;
	__shared__ uint64_t nMaxCloudAdd;
	__shared__ unsigned int nMoreIterated;
	int16_t local_static_word_index[12];

	// Initialize the shared variable
	if (threadIdx.x == 0) {
		ourBlockProcNormal = 0; // Only the first thread initializes it
		ourBlockProcExtra = 0;
		ourBlockBadChkSum = 0;
		ourBlockGoodChkSum = 0;

		nMaxCloudAdd = 0;
		nMoreIterated = 0;
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
	bool bChkSumFailed = true;

	int16_t curDigits[MAX_ADAPTIVE_BASE_POSITIONS] = { 0,0,0,0,0,0 };

	//TODO block: prefix is based on  words 9 and 10 while the last word 11 is iterated inside the thread

	int nTried = 0;
	bool bCouldAdd = false;
	do {
		bCouldAdd = IncrementAdaptiveDigits(
			dev_AdaptiveBaseDigitCarryTrigger
			, dev_AdaptiveBaseCurrentBatchInitialDigits
			, effective_idx, curDigits);
		if (bCouldAdd == false) {
			if (effective_idx == nMaxCloudAdd + 1) {
				printf("Can not add at %x", effective_idx);
			}

			break;
		}
		else {
			atomicMax(&nMaxCloudAdd, effective_idx);
		}

		AdaptiveUpdateMnemonicLow64(&curEntropy[1], dev_AdaptiveBaseDigitSet, curDigits);
		local_static_word_index[6] = dev_AdaptiveBaseDigitSet[0][curDigits[0]];
		local_static_word_index[7] = dev_AdaptiveBaseDigitSet[1][curDigits[1]];
		local_static_word_index[8] = dev_AdaptiveBaseDigitSet[2][curDigits[2]];
		local_static_word_index[9] = dev_AdaptiveBaseDigitSet[3][curDigits[3]];
		local_static_word_index[10] = dev_AdaptiveBaseDigitSet[4][curDigits[4]];
		local_static_word_index[11] = dev_AdaptiveBaseDigitSet[5][curDigits[5]];



		//Work with Current Entropy
		uint8_t mnemonic_phrase[SIZE_MNEMONIC_FRAME] = { 0 };
		uint8_t* mnemonic = mnemonic_phrase;

		entropy_to_mnemonic_with_offset(curEntropy, mnemonic, 0, local_static_word_index);



		int16_t chkPosIdx = MAX_ADAPTIVE_BASE_POSITIONS - 1;
		int16_t chkWordIdx = curDigits[chkPosIdx];
		uint16_t thisVal = (dev_AdaptiveBaseDigitSet[chkPosIdx][chkWordIdx]);
		uint8_t tmp = (uint8_t)(thisVal & 0x0F);
		reqChecksum = tmp;

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

		bChkSumFailed = (achievedChecksum != reqChecksum);

		nTried++;

		if (bChkSumFailed) {
			atomicAdd(&ourBlockProcExtra, 1);
		}
		else {
			break;
		}
	} while (nTried < MAX_TRY_PER_THREAD); //do

	__syncthreads(); // Synchronize to and check if have a valid checksum to continue with
	if (bCouldAdd/*bChkSumFailed == false*/) { //scrutinize
		atomicAdd(&ourBlockGoodChkSum, 1);

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

		atomicAdd(&ourBlockProcNormal, 1);

		key_to_hash160((extended_private_key_t*)&ipad[128 / 4], tables_legacy, tables_segwit, tables_native_segwit, (uint32_t*)mnemonic, ret);
		//__syncthreads();
	}
	__syncthreads(); // Synchronize to ensure all data is loaded
	if (threadIdx.x == 0) {
		atomicAdd(nBatchPlannedProc, ourBlockProcNormal);
		//atomicAdd(nBatchMoreProc, ourBlockProcExtra);
		*nBatchMoreProc = 0;
	}

}//DICTIONARY ATTACK
