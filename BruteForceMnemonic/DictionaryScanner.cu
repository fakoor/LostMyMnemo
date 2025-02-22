#include <stdafx.h>
#include <stdio.h>


#include <cuda.h>
#include "cuda_runtime.h"

#include "GPU.h"
#include "AdaptiveBase.h"

#include "EntropyTools.cuh"
#include "DictionaryScanner.cuh"
#include "Bip39Tools.cuh"

#include "DbgPrint.cuh"

#if 1
#define device_hashcmp(p1, p2) \
    ( (((uint64_t*)p1)[0] == ((uint64_t*)p2)[0] && ((uint64_t*)p1)[1] == ((uint64_t*)p2)[1] && ((p1)[4] == ((uint32_t*)p2)[4]) )? (0) : (1) )
#else
static inline __device__ int device_hashcmp(const  uint64_t* p1, const uint64_t* p2) {
	return ( ((p1)[0] == (p2)[0] && (p1)[1] == (p2)[1] && *(uint32_t*)(&(p1)[2]) == *(uint32_t*)(&(p2)[2]) )? (0) : (-1) );
}
#endif

__global__ void gl_DictionaryScanner()
{
	unsigned int effective_idx = blockIdx.x * blockDim.x + threadIdx.x;

	uint32_t nTotalThreads = blockDim.x * gridDim.x;

	__shared__ uint64_t ourBlockProcNormal;
	__shared__ uint64_t nGridJobCap;
	__shared__ int32_t bContinueRunning;
	__shared__ uint64_t nThisBlockAddrs;
	int16_t local_static_word_index[12];

	__syncthreads(); // Synchronize to ensure the initialization is complete
	// Initialize the shared variable (first thread of each block)
	if (threadIdx.x == 0) {
		ourBlockProcNormal = 0;
		nGridJobCap = ULLONG_MAX;
		nThisBlockAddrs = 0;
		atomicExch(&bContinueRunning, 1);
	}
	__syncthreads(); // Synchronize to ensure the initialization is complete

	DBGPRINTF(DBG_INFO, "\r\n --- Thread START (Block:%u, Thread:%u) --- \r\n"
		, blockIdx.x, threadIdx.x);


	for (int i = 0; i < 6; i++) {
		local_static_word_index[i] = dev_static_words_indices[i];
	}

	//int4 m128retEntropy = { 0,0,0,0 };

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

	for (uint64_t nManagedIter = dev_nManagedIterationsMinMax[0]; nManagedIter < dev_nManagedIterationsMinMax[1]; nManagedIter++) {
		DBGPRINTF(DBG_INFO,"\r\n --- Iterate BEGIN (Block:%u, Thread:%u, Iterate:%llu) --- \r\n"
			, blockIdx.x, threadIdx.x, nManagedIter);

		//atomicMin(&nManagedIterationsMaxCurrent[1], nManagedIter);
		if (b_globalContinueRunning == 0) {
			DBGPRINTF(DBG_INFO,"\r\n --- Iterate GLOBAL STOP (Block:%u, Thread:%u, Iterate:%llu) --- \r\n"
				, blockIdx.x, threadIdx.x, nManagedIter);
			__syncthreads();
			atomicExch(&bContinueRunning, 0);
			__syncthreads();
			return;
		}


		uint8_t mnemonic_phrase[SIZE_MNEMONIC_FRAME] = { 0 };
		uint8_t* mnemonic = mnemonic_phrase;
		uint64_t nLoopMasterOffset = effective_idx * nPosElevenCarryTrig * nPosTenCarryTrig
			+ nManagedIter * (nTotalThreads * nPosElevenCarryTrig * nPosTenCarryTrig);

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
			DBGPRINTF(DBG_INFO,"\r\n --- Iterate W10 BEGIN %u (Block:%u, Thread:%u, Iterate:%llu) --- \r\n"
				, nWordTenOffset, blockIdx.x, threadIdx.x, nManagedIter);

			for (int16_t nWordElevenOffset = 0; nWordElevenOffset < nPosElevenCarryTrig; nWordElevenOffset++) {
				DBGPRINTF(DBG_INFO,"\r\n --- Iterate W11 START %u (Block:%u, Thread:%u, Iterate:%llu) --- \r\n"
					, nWordElevenOffset, blockIdx.x, threadIdx.x, nManagedIter);

				uint64_t nInstanceOffset =
					nLoopMasterOffset
					+ nWordTenOffset * nPosElevenCarryTrig
					+ nWordElevenOffset
					;

				if (nInstanceOffset > nGridJobCap) {
					DBGPRINTF(DBG_INFO,"\r\n --- Iterate CAP REACHED (Block:%u, Thread:%u, Iterate:%llu) --- \r\n"
						, blockIdx.x, threadIdx.x, nManagedIter);

					break;
				}
				{//loacl block
					int32_t bCouldIncrement = 1;
					IncrementAdaptiveDigits(
						dev_AdaptiveBaseDigitCarryTrigger
						, dev_AdaptiveBaseCurrentBatchInitialDigits
						, nInstanceOffset, curDigits, &bCouldIncrement);


					if (bCouldIncrement <= 0) {
						DBGPRINTF(DBG_INFO,"\r\n --- Iterate CAPPED at %llu (Block:%u, Thread:%u, Iterate:%llu) --- \r\n"
							, nInstanceOffset , blockIdx.x, threadIdx.x, nManagedIter);

						atomicMin(&nGridJobCap, nInstanceOffset);
						break;
					}
				}//loacl block
				atomicAdd(&ourBlockProcNormal, 1);


				SyncBipIndexFromAdaptiveDigits(local_static_word_index, dev_AdaptiveBaseDigitSet, curDigits);

				curEntropy[1] = dev_EntropyNextPrefix2[PTR_AVOIDER];
				AdaptiveUpdateMnemonicLow64(&curEntropy[1], dev_AdaptiveBaseDigitSet, curDigits);
				int16_t wordElevenBipVal = local_static_word_index[11];


				uint8_t reqChecksum = wordElevenBipVal & 0x000F;
				int8_t bChkMatched;

				CheckSumValidate(checkSumInputBlock, curEntropy, reqChecksum, &bChkMatched);


				if (bChkMatched <= 0) {
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

				{//code-block
					const extended_private_key_t* master_private = (extended_private_key_t*)&ipad[128 / 4];

					uint32_t hash[(20 / 4)];
					extended_private_key_t target_key;
					extended_private_key_t target_key_fo_pub;
					extended_private_key_t master_private_fo_extint;
					extended_public_key_t target_public_key;

					for (uint8_t nBlockchainInfoLegacyAddrGen = 0; nBlockchainInfoLegacyAddrGen <= 1; nBlockchainInfoLegacyAddrGen++) {
						/*
						* NOTE: for blockchain.info aka blockchain.com, this is the bip-32 path for purpose 44
						* m/44'/0'/2'/0
						* So we have similar begining of three hardened keys that their last one is account number
						* and the final part of path starts from zero and is child address so here we do not have
						* the notion of extension and its place is used by the child in this context. Note that we
						* derive one item less than the standard since the child place is the last
						*/

						for (uint8_t accNo = dev_accntMinMax[0]; accNo <= dev_accntMinMax[1]; accNo++) {
							DBGPRINTF(DBG_INFO, "\r\n --- Iterate ACC START %u (Block:%u, Thread:%u, Iterate:%llu) --- \r\n"
								, accNo, blockIdx.x, threadIdx.x, nManagedIter);

							hardened_private_child_from_private(master_private, &target_key, 44);
							hardened_private_child_from_private(&target_key, &target_key, 0);
							hardened_private_child_from_private(&target_key, &master_private_fo_extint, accNo); //acount-number
							if (nBlockchainInfoLegacyAddrGen == 0) {
								//only perform when we are not generating blockchain.info custom path
								normal_private_child_from_private(&master_private_fo_extint, &target_key, 0); //extension-0-internal-external
							}
							//m/44'/0'/acc'/0/child (Zeros: first 0=Bitcoin , penultimate 0 = Extension)
	//#pragma unroll
							for (int x = dev_childrenMinMax[0]; x <= dev_childrenMinMax[1]; x++) {
								DBGPRINTF(DBG_INFO, "\r\n --- Iterate CHL START %u (Block:%u, Thread:%u, Iterate:%llu) --- \r\n"
									, x, blockIdx.x, threadIdx.x, nManagedIter);

								DBGPRINTF(DBG_INFO, "\r\n --- CHECKING Instance:%llu, (Itertion:%llu, Block:%u, Thread:%u, W10=%u, W11=%u, acc=%u, child=%u) --- \r\n"
									, nInstanceOffset, nManagedIter, blockIdx.x, threadIdx.x, nWordTenOffset, nWordElevenOffset, accNo, x);
								if (nBlockchainInfoLegacyAddrGen == 0) {
									//when we are not on blockchain.info format, the previous output has been chained to target key
									normal_private_child_from_private(&target_key, &target_key_fo_pub, x); //child x
								}
								else {
									//but when we are on blockchain.info format we directly derive from private key
									normal_private_child_from_private(&master_private_fo_extint, &target_key_fo_pub, x); //child x
								}
								calc_public(&target_key_fo_pub, &target_public_key);
								calc_hash160(&target_public_key, hash);


								atomicAdd(&nThisBlockAddrs, 1);

								if (device_hashcmp(hash, dev_uniqueTargetAddressBytes) <= 0) {
									DBGPRINTF(DBG_ERROR, "\r\n --- Hash found by Instance:%llu, (Itertion:%llu, Block:%u, Thread:%u, W10=%u, W11=%u) --- \r\n"
										, nInstanceOffset, nManagedIter, blockIdx.x, threadIdx.x, nWordTenOffset, nWordElevenOffset);
									dev_retEntropy[0] = curEntropy[0];
									dev_retEntropy[1] = curEntropy[1];
									dev_retAccntPath[0] = accNo;
									dev_retAccntPath[1] = x;
									atomicExch(&bContinueRunning, 0);
									atomicExch(&b_globalContinueRunning, 0);
									atomicAdd(&dev_nComboEachThread[blockIdx.x][threadIdx.x], 1);
									DBGPRINTF(DBG_INFO, "\r\n --- returning ---\r\n");
									return;
								}
								else {
									DBGPRINTF(DBG_INFO, "\r\n --- Tried Instance:%llu, (Itertion:%llu, Block:%u, Thread:%u, W10=%u, W11=%u, acc=%u, child=%u) --- \r\n"
										, nInstanceOffset, nManagedIter, blockIdx.x, threadIdx.x, nWordTenOffset, nWordElevenOffset, accNo, x);

								}
								if (bContinueRunning <= 0) {
									DBGPRINTF(DBG_INFO, "\r\n --- Iterate BREAK CHLD (Block:%u, Thread:%u, Iterate:%llu) --- \r\n"
										, blockIdx.x, threadIdx.x, nManagedIter);

									break;
								}
								DBGPRINTF(DBG_INFO, "\r\n --- Iterate CHL END %u (Block:%u, Thread:%u, Iterate:%llu) --- \r\n"
									, x, blockIdx.x, threadIdx.x, nManagedIter);

							}
							if (bContinueRunning <= 0) {
								DBGPRINTF(DBG_INFO, "\r\n --- Iterate BREAK ACC (Block:%u, Thread:%u, Iterate:%llu) --- \r\n"
									, blockIdx.x, threadIdx.x, nManagedIter);

								break;
							}
							DBGPRINTF(DBG_INFO, "\r\n --- Iterate ACC END %u (Block:%u, Thread:%u, Iterate:%llu) --- \r\n"
								, accNo, blockIdx.x, threadIdx.x, nManagedIter);

						}//accNo
						if (bContinueRunning <= 0) {
							DBGPRINTF(DBG_INFO, "\r\n --- Iterate BREAK CODE-BLOCK (Block:%u, Thread:%u, Iterate:%llu) --- \r\n"
								, blockIdx.x, threadIdx.x, nManagedIter);

							break;
						}
					}//legacy format iterator
				}////code-block
				if (bContinueRunning <= 0) {
					DBGPRINTF(DBG_INFO,"\r\n --- Iterate W11 BREAK %u (Block:%u, Thread:%u, Iterate:%llu) --- \r\n"
						, nWordElevenOffset, blockIdx.x, threadIdx.x, nManagedIter);

					break;
				}
				DBGPRINTF(DBG_INFO,"\r\n --- Iterate W11 END %u (Block:%u, Thread:%u, Iterate:%llu) --- \r\n"
					, nWordElevenOffset, blockIdx.x, threadIdx.x, nManagedIter);

			}//for word 11 
			if (bContinueRunning <= 0) {
				DBGPRINTF(DBG_INFO,"\r\n --- Iterate W10 BREAK %u (Block:%u, Thread:%u, Iterate:%llu) --- \r\n"
					, nWordTenOffset, blockIdx.x, threadIdx.x, nManagedIter);

				break;
			}
			DBGPRINTF(DBG_INFO,"\r\n --- Iterate W10 END %u (Block:%u, Thread:%u, Iterate:%llu) --- \r\n"
				,nWordTenOffset,  blockIdx.x, threadIdx.x, nManagedIter);

		}//word 10
		if (bContinueRunning <= 0) {
			DBGPRINTF(DBG_INFO,"\r\n --- Iterate BREAK itr (Block:%u, Thread:%u, Iterate:%llu) --- \r\n"
				, blockIdx.x, threadIdx.x, nManagedIter);

			break;
		}
		DBGPRINTF(DBG_INFO,"\r\n --- Iterate END (Block:%u, Thread:%u, Iterate:%llu) --- \r\n"
			, blockIdx.x, threadIdx.x, nManagedIter);

	}//managed iteration
	__syncthreads(); // Synchronize to ensure all data is loaded
	if (threadIdx.x == 0) {
		//			atomicAdd(nProcessedInstances, ourBlockProcNormal);
		//atomicAdd(&nManagedIterationsPerBlock[blockIdx.x], 1);
		atomicAdd(dev_universalCount, nThisBlockAddrs);

	}

	DBGPRINTF(DBG_INFO,"\r\n --- Thread END (Block:%u, Thread:%u) --- \r\n"
		, blockIdx.x, threadIdx.x);

}//DICTIONARY ATTACK
