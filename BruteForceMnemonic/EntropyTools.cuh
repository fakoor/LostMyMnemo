#pragma once
#ifndef __ENTROPYTOOLS_H__
#define __ENTROPYTOOLS_H__

#include "consts.h"
#include <cuda_runtime.h>
#include <cuda_runtime_api.h>

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

	for (int i = 0; i < MAX_ADAPTIVE_BASE_POSITIONS - 1; i++) {
		tmpAns = tmpAns << 11;
		//tmpAns &= 0xFFFFFFFFFFFFC00;
		tmpAns |= (uint64_t)(digitSet[i][curDigits[i]]);
	}
	tmpAns = tmpAns << 7;
	tmpAns |= ((uint64_t)(digitSet[MAX_ADAPTIVE_BASE_POSITIONS - 1][curDigits[MAX_ADAPTIVE_BASE_POSITIONS - 1]]) >> 4);

	*low64 = tmpAns;
}


__device__ __host__
inline void SyncBipIndexFromAdaptiveDigits(int16_t local_static_word_index[12], int16_t dev_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION], int16_t curDigits[MAX_ADAPTIVE_BASE_POSITIONS]) {
	local_static_word_index[6] = dev_AdaptiveBaseDigitSet[0][curDigits[0]];
	local_static_word_index[7] = dev_AdaptiveBaseDigitSet[1][curDigits[1]];
	local_static_word_index[8] = dev_AdaptiveBaseDigitSet[2][curDigits[2]];
	local_static_word_index[9] = dev_AdaptiveBaseDigitSet[3][curDigits[3]];
	local_static_word_index[10] = dev_AdaptiveBaseDigitSet[4][curDigits[4]];
	local_static_word_index[11] = dev_AdaptiveBaseDigitSet[5][curDigits[5]];

}
#endif /* __ENTROPYTOOLS_H__ */