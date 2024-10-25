#include <stdafx.h>
#include <stdio.h>


#include <cuda.h>
#include "cuda_runtime.h"

#include "GPU.h"
#include "AdaptiveBase.h"

#include "EntropyTools.cuh"
#include "DictionaryScanner.cuh"


static inline __device__ int device_hashcmp(const  uint32_t* p1, const uint32_t* p2) {
#pragma unroll
	for (auto i = 0; i < 20/4; ++i) {
		if (p1[i] != p2[i]) {
			return p1[i] < p2[i] ? -1 : 1; // Return -1 if p1 < p2, 1 if p1 > p2
		}
	}
	return 0; // Memory regions are equal
}


__device__
bool CheckSumValidate(uint8_t checkSumInputBlock[16], uint64_t entropy[2], uint8_t reqChecksum) {
	uint8_t entropy_hash[32];
	//uint64_t* entropy = curEntropy;

	checkSumInputBlock[15] = entropy[1] & 0xFF;
	checkSumInputBlock[14] = (entropy[1] >> 8) & 0xFF;
	checkSumInputBlock[13] = (entropy[1] >> 16) & 0xFF;
	checkSumInputBlock[12] = (entropy[1] >> 24) & 0xFF;
	checkSumInputBlock[11] = (entropy[1] >> 32) & 0xFF;
	checkSumInputBlock[10] = (entropy[1] >> 40) & 0xFF;
	checkSumInputBlock[9] = (entropy[1] >> 48) & 0xFF;
	checkSumInputBlock[8] = (entropy[1] >> 56) & 0xFF;


	sha256((uint32_t*)checkSumInputBlock, 16, (uint32_t*)entropy_hash);
	uint8_t achievedChecksum = (entropy_hash[0] >> 4) & 0x0F;

	bool bChkMatched = (achievedChecksum == reqChecksum);
	return bChkMatched;
}

__device__
int LookupHash(const uint32_t* hash, uint32_t* hash_from_table, const uint32_t* mnemonic, foundStruct* fnd_ret, uint32_t path, uint32_t child)
{
	int found = 0;
	bool search_state = true;
	uint32_t line_cnt = 1;
	uint32_t point = 0;
	uint32_t point_last = 0;
	uint32_t interval = line_cnt / 3;
	//uint32_t* hash_from_table;
	while (point < line_cnt) {
		point_last = point;
		if (interval == 0) {
			search_state = false;
		}
		if (search_state) {
			point += interval;

			if (point >= line_cnt) {
				point = point_last;
				interval = (line_cnt - point) / 2;
				continue;
			}
			//hash_from_table = &table.table[point * (20 / 4)];
		}
		else {
			//hash_from_table = &table.table[point * (20 / 4)];
			point += 1;
		}

		int cmp = 0;
		if (hash[0] < hash_from_table[0])
		{
			cmp = -1;
		}
		else if (hash[0] > hash_from_table[0])
		{
			cmp = 1;
		}
		else if (hash[1] < hash_from_table[1])
		{
			cmp = -2;
		}
		else if (hash[1] > hash_from_table[1])
		{
			cmp = 2;
		}
		else if (hash[2] < hash_from_table[2])
		{
			cmp = -3;
		}
		else if (hash[2] > hash_from_table[2])
		{
			cmp = 3;
		}
		else if (hash[3] < hash_from_table[3])
		{
			cmp = -4;
		}
		else if (hash[3] > hash_from_table[3])
		{
			cmp = 4;
		}
		else if (hash[4] < hash_from_table[4])
		{
			cmp = -5;
		}
		else if (hash[4] > hash_from_table[4])
		{
			cmp = 5;
		}

		if (search_state) {
			if (cmp < 0) {
				if (interval < 20) {
					search_state = false;
				}
				else
				{
					interval = interval / 2;
				}
				point = point_last;
				continue;
			}
			else if (cmp == 0) {
				search_state = false;
			}
			else {
				continue;
			}
		}

		if (cmp <= 0) {
			if (cmp == 0)
			{
				found = 1;
				uint32_t cnt = fnd_ret->count_found;
				fnd_ret->count_found++;
				if (cnt < MAX_FOUND_ADDRESSES)
				{
					for (int i = 0; i < 5; i++) fnd_ret->found_info[cnt].hash160[i] = hash[i];
					for (int i = 0; i < SIZE32_MNEMONIC_FRAME; i++) fnd_ret->found_info[cnt].mnemonic[i] = mnemonic[i];
					fnd_ret->found_info[cnt].path = path;
					fnd_ret->found_info[cnt].child = child;
				}
			}
			break;
		}

		if (cmp > 1) {
			if (dev_num_bytes_find[0] == 8) {
				if (hash[1] == hash_from_table[1]) found = 2;
			}
#ifdef TEST_MODE
			else if (dev_num_bytes_find[0] == 7) {
				if ((hash[1] & 0x00FFFFFF) == (hash_from_table[1] & 0x00FFFFFF)) found = 2;
			}
			else if (dev_num_bytes_find[0] == 6) {
				if ((hash[1] & 0x0000FFFF) == (hash_from_table[1] & 0x0000FFFF)) found = 2;
			}
			else if (dev_num_bytes_find[0] == 5) {
				if ((hash[1] & 0x000000FF) == (hash_from_table[1] & 0x000000FF)) found = 2;
			}
#endif //TEST_MODE
		}


		if (found == 2) {
			uint32_t cnt = fnd_ret->count_found_bytes;
			fnd_ret->count_found_bytes++;
			if (cnt < MAX_FOUND_ADDRESSES)
			{
				for (int i = 0; i < 5; i++)
				{
					fnd_ret->found_bytes_info[cnt].hash160_from_table[i] = hash_from_table[i];
					fnd_ret->found_bytes_info[cnt].hash160[i] = hash[i];
				}
				for (int i = 0; i < SIZE32_MNEMONIC_FRAME; i++) fnd_ret->found_bytes_info[cnt].mnemonic[i] = mnemonic[i];
				fnd_ret->found_bytes_info[cnt].path = path;
				fnd_ret->found_bytes_info[cnt].child = child;
			}
			break;
		}

	}

	return found;
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

	// Initialize the shared variable
	if (threadIdx.x == 0) {
		ourBlockProcNormal = 0; // Only the first thread initializes it

		nGridJobCap = ULLONG_MAX;//0xFFFFFFFFFFFFFFFFull;
		bDone = 0;
	}
	__syncthreads(); // Synchronize to ensure the initialization is complete

	for (int i = 0; i < 6; i++) {
		local_static_word_index[i] = dev_static_words_indices[i];
	}


	uint64_t curEntropy[2];
	curEntropy[0] = dev_EntropyAbsolutePrefix64[PTR_AVOIDER];
	curEntropy[1] = dev_EntropyNextPrefix2[PTR_AVOIDER];


	uint8_t reqChecksum = 0;

	int16_t curDigits[MAX_ADAPTIVE_BASE_POSITIONS] = { 
		 dev_AdaptiveBaseCurrentBatchInitialDigits[0]
		,dev_AdaptiveBaseCurrentBatchInitialDigits[1]
		,dev_AdaptiveBaseCurrentBatchInitialDigits[2]
		,dev_AdaptiveBaseCurrentBatchInitialDigits[3]
		,dev_AdaptiveBaseCurrentBatchInitialDigits[4]
		,dev_AdaptiveBaseCurrentBatchInitialDigits[5] 
	};

	//TODO block: prefix is based on  words 9 and 10 while the last word 11 is iterated inside the thread

	const int16_t lastPos_adaptive = MAX_ADAPTIVE_BASE_POSITIONS - 1;
	const int16_t lastPosCarryTrig = dev_AdaptiveBaseDigitCarryTrigger[lastPos_adaptive];

	//instead of effective_idx, increment so that bypass and leave last word iteration completely to this thread

	SyncBipIndexFromAdaptiveDigits(local_static_word_index , dev_AdaptiveBaseDigitSet , curDigits);

	//Work with Current Entropy
	uint8_t mnemonic_phrase[SIZE_MNEMONIC_FRAME] = { 0 };
	uint8_t* mnemonic = mnemonic_phrase;
	uint64_t nLoopMasterOffset = effective_idx * lastPosCarryTrig + *nProcessingIteration * (nTotalThreads * lastPosCarryTrig);

	uint8_t checkSumInputBlock[16];//with constant portion initalization
	checkSumInputBlock[7] = dev_EntropyAbsolutePrefix64[0] & 0xFF;
	checkSumInputBlock[6] = (dev_EntropyAbsolutePrefix64[0] >> 8) & 0xFF;
	checkSumInputBlock[5] = (dev_EntropyAbsolutePrefix64[0] >> 16) & 0xFF;
	checkSumInputBlock[4] = (dev_EntropyAbsolutePrefix64[0] >> 24) & 0xFF;
	checkSumInputBlock[3] = (dev_EntropyAbsolutePrefix64[0] >> 32) & 0xFF;
	checkSumInputBlock[2] = (dev_EntropyAbsolutePrefix64[0] >> 40) & 0xFF;
	checkSumInputBlock[1] = (dev_EntropyAbsolutePrefix64[0] >> 48) & 0xFF;
	checkSumInputBlock[0] = (dev_EntropyAbsolutePrefix64[0] >> 56) & 0xFF;


#pragma unroll
	for (int16_t nWordElevenOffset = 0; nWordElevenOffset < lastPosCarryTrig; nWordElevenOffset++) {
		//break on nTried < MAX_TRY_PER_THREAD
		uint64_t nInstanceOffset = nLoopMasterOffset + nWordElevenOffset;

		if (nInstanceOffset > nGridJobCap) {
			break;
		}

		if (false== IncrementAdaptiveDigits(
			dev_AdaptiveBaseDigitCarryTrigger
			, dev_AdaptiveBaseCurrentBatchInitialDigits
			, nInstanceOffset, curDigits)){

			atomicMin(&nGridJobCap, nInstanceOffset);
			break;
		}
		atomicAdd(&ourBlockProcNormal, 1);

		if (threadIdx.x == 0) {

		}
		//else {
		//	atomicMax(&nMaxCloudAdd, effective_idx);
		//}

		SyncBipIndexFromAdaptiveDigits(local_static_word_index, dev_AdaptiveBaseDigitSet, curDigits);

		curEntropy[1] = dev_EntropyNextPrefix2[PTR_AVOIDER];
		AdaptiveUpdateMnemonicLow64(&curEntropy[1], dev_AdaptiveBaseDigitSet, curDigits);
		int16_t wordElevenBipVal = local_static_word_index[11];


#if 0 //not required for checksum comparison here
		entropy_to_mnemonic_with_offset(curEntropy, mnemonic, 0, local_static_word_index);
#endif
		reqChecksum = wordElevenBipVal & 0x000F;
		bool bChkMatched = CheckSumValidate (checkSumInputBlock, curEntropy, reqChecksum);


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

		//dev_uniqueTargetAddressBytes;
		{
			const extended_private_key_t* master_private = (extended_private_key_t*)&ipad[128 / 4];

			uint32_t hash[(20 / 4)];
			extended_private_key_t target_key;
			extended_private_key_t target_key_fo_pub;
			extended_private_key_t master_private_fo_extint;
			extended_public_key_t target_public_key;

			for (uint8_t accNo = 0; accNo < 3; accNo++) {
				hardened_private_child_from_private(master_private, &target_key, 44);
				hardened_private_child_from_private(&target_key, &target_key, 0);

				hardened_private_child_from_private(&target_key, &master_private_fo_extint, accNo); //acount-number

				//for (uint8_t h33 = 0; h33 < 3; h33++) {
					normal_private_child_from_private(&master_private_fo_extint, &target_key, 0); //extension-0-internal-external
					//m/44'/0'/0'/0/x
					for (int x = 0; x < dev_num_childs[0]; x++) {

						normal_private_child_from_private(&target_key, &target_key_fo_pub, x); //child x
						calc_public(&target_key_fo_pub, &target_public_key);
						calc_hash160(&target_public_key, hash);

						//find_hash_in_table(hash, tables_legacy[(uint8_t)hash[0]], (uint32_t*) mnemonic, &ret->f[0], 4, 0);
						//LookupHash(hash, (uint32_t*) dev_uniqueTargetAddressBytes, (uint32_t*)mnemonic, &ret->f[0], 4, 0);

						if (device_hashcmp((uint32_t*)hash, (uint32_t*)dev_uniqueTargetAddressBytes) == 0) {
#if 1
							dev_retEntropy[0] = curEntropy[0];
							dev_retEntropy[1] = curEntropy[1];
							dev_retAccntPath[0] = accNo;
							dev_retAccntPath[1] = x;
							bDone = 1;
							break;
#endif
						}
						if (bDone != 0)
							break;

					}
					if (bDone != 0)
						break;

				//}//h33
			}//h34
			if (bDone != 0)
				break;

		}
#if 0
		key_to_hash160((extended_private_key_t*)&ipad[128 / 4], tables_legacy, tables_segwit, tables_native_segwit, (uint32_t*)mnemonic, ret);

		atomicMax(&bDone, DictionaryCheckFound(ret));
		if (bDone ) {
			atomicMin(&nGridJobCap, nInstanceOffset);
			//if (nInstanceOffset == nGridJobCap) {
			//	printf("\r\n\r\n\tBreaking operation at %llu Since Match is Found!\r\n\r\n", nInstanceOffset);
			//}

			break;
		}
#endif
	}//for 

	__syncthreads(); // Synchronize to ensure all data is loaded
	if (threadIdx.x == 0) {
		atomicAdd(nProcessedInstances, ourBlockProcNormal);
	}

}//DICTIONARY ATTACK
