#pragma once
#ifndef __ENTROPYTOOLS_H__
#define __ENTROPYTOOLS_H__

#include "consts.h"
#include <cuda_runtime.h>
#include <cuda_runtime_api.h>
//#include "../Tools/tools.h"
#include "sha256usage.cuh"

extern const uint8_t arrBipWords[2048][9];
extern const uint8_t arrBipWordsLengths[2048];

__host__ /*and */ __device__
void ShowAdaptiveStr(int16_t digitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION]
	, int16_t digs[MAX_ADAPTIVE_BASE_POSITIONS]
	, const uint8_t arrBipWords[2048][9]
	, const uint8_t arrBipWordsLengths[2048]
	, char* str);

__host__ /*and */ __device__
inline void AdaptiveUpdateMnemonicLow64(uint64_t* low64
	, int16_t digitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION]
	, int16_t curDigits[MAX_ADAPTIVE_BASE_POSITIONS]
)

{
	uint64_t tmpHigh = *low64;
	uint64_t tmpAns = tmpHigh;

	tmpAns = tmpHigh >> 62;
	//tmpAns = tmpAns << 2;
#pragma unroll
	for (int i = 0; i < MAX_ADAPTIVE_BASE_POSITIONS - 1; i++) {
		tmpAns = tmpAns << 11;
		tmpAns |= (uint64_t)(digitSet[i][curDigits[i]]);
	}
	tmpAns = tmpAns << 7;
	tmpAns |= ((uint64_t)(digitSet[MAX_ADAPTIVE_BASE_POSITIONS - 1][curDigits[MAX_ADAPTIVE_BASE_POSITIONS - 1]]) >> 4);

	*low64 = tmpAns;
}


//__device__ __host__
//inline void SyncBipIndexFromAdaptiveDigits(int16_t local_static_word_index[12], int16_t dev_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION], int16_t curDigits[MAX_ADAPTIVE_BASE_POSITIONS]) {
#define SyncBipIndexFromAdaptiveDigits(local_static_word_index, dev_AdaptiveBaseDigitSet, curDigits) { \
	local_static_word_index[6] = dev_AdaptiveBaseDigitSet[0][curDigits[0]]; \
	local_static_word_index[7] = dev_AdaptiveBaseDigitSet[1][curDigits[1]]; \
	local_static_word_index[8] = dev_AdaptiveBaseDigitSet[2][curDigits[2]]; \
	local_static_word_index[9] = dev_AdaptiveBaseDigitSet[3][curDigits[3]]; \
	local_static_word_index[10] = dev_AdaptiveBaseDigitSet[4][curDigits[4]]; \
	local_static_word_index[11] = dev_AdaptiveBaseDigitSet[5][curDigits[5]]; \
}

void GetAllWords(uint64_t entropy[2], uint8_t* mnemonic_phrase);



__device__
inline void IndicesToMnemonic(
	  int16_t  indices[12]
	, uint8_t* mnemonic_phrase
	, const uint8_t words[2048][9]
	, const uint8_t word_lengths[2048]
)
{
	int mnemonic_index = 0;
#pragma unroll
	for (int i = 0; i < 12; i++) {
		uint16_t word_index = indices[i];
		uint16_t word_length = word_lengths[word_index];

#pragma unroll
		for (int j = 0; j < word_length; j++) {
			mnemonic_phrase[mnemonic_index] = words[word_index][j];
			mnemonic_index++;
		}
		mnemonic_phrase[mnemonic_index] = 32;
		mnemonic_index++;
	}

	mnemonic_phrase[mnemonic_index - 1] = 0;
}


__device__
inline bool CheckSumValidate(uint8_t checkSumInputBlock[16], uint64_t entropy[2], uint8_t reqChecksum) {
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


#endif /* __ENTROPYTOOLS_H__ */