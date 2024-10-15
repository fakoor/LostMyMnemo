#include <stdafx.h>
#include <stdio.h>


#include <cuda.h>
#include "cuda_runtime.h"

#include <GPU.h>
#include "AdaptiveBase.h"



/*
* We onsider Mnemonics a Base - 2048 twelve-digit unsigned integer,
* if we have some information about any of digits, so that we can
* ommit 1 to 2047 digits (words) from a specific position, then that
* digit is adaptively based to Base-2047 down to Base-2 aka binary.
* The only mathematic operation we need for the purpose is increment,
* When we reach the carry for a VariableBase digit, uppon an increment,
* we will rewind that digit and increment the more significant digit
* DUE to less memory usage in constant-memory, we limit such mechanism
* to the 6 least significant mnemonic words in a 262 guessed space
* Hence the dictionary for positions 6 to 12 outght not to include
* more than 262 words. The other structure provides reverse lookup 
* for a value of a digit
*/



__device__ int dev_checkResult(retStruct* ret) {

	if (ret->f[0].count_found >= MAX_FOUND_ADDRESSES)
	{
		ret->f[0].count_found = MAX_FOUND_ADDRESSES;
	}
	if (ret->f[1].count_found >= MAX_FOUND_ADDRESSES)
	{
		ret->f[1].count_found = MAX_FOUND_ADDRESSES;
	}
	if (ret->f[2].count_found >= MAX_FOUND_ADDRESSES)
	{
		ret->f[2].count_found = MAX_FOUND_ADDRESSES;
	}
	if (ret->f[0].count_found_bytes >= MAX_FOUND_ADDRESSES)
	{
		ret->f[0].count_found_bytes = MAX_FOUND_ADDRESSES;
	}
	if (ret->f[1].count_found_bytes >= MAX_FOUND_ADDRESSES)
	{
		ret->f[1].count_found_bytes = MAX_FOUND_ADDRESSES;
	}
	if (ret->f[2].count_found_bytes >= MAX_FOUND_ADDRESSES)
	{
		ret->f[2].count_found_bytes = MAX_FOUND_ADDRESSES;

	}

	if (ret->f[0].count_found != 0)
	{
		for (uint32_t i = 0; i < ret->f[0].count_found; i++)
		{
			return 1;
		}
	}
	if (ret->f[1].count_found != 0)
	{
		for (uint32_t i = 0; i < ret->f[1].count_found; i++)
		{
			return 1;
		}
	}
	if (ret->f[2].count_found != 0)
	{
		for (uint32_t i = 0; i < ret->f[2].count_found; i++)
		{
			return 1;
		}
	}

	return 0;
}



__constant__ uint64_t dev_EntropyAbsolutePrefix64[1];
uint64_t host_EntropyAbsolutePrefix64[1];

__constant__ int16_t dev_AdaptiveBaseDigitCarryTrigger[MAX_ADAPTIVE_BASE_POSITIONS];
 int16_t host_AdaptiveBaseDigitCarryTrigger[MAX_ADAPTIVE_BASE_POSITIONS];

__constant__ int16_t dev_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION];
 int16_t host_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION];


__constant__ int16_t dev_AdaptiveBaseCurrentBatchInitialDigits[MAX_ADAPTIVE_BASE_POSITIONS];
 int16_t host_AdaptiveBaseCurrentBatchInitialDigits[MAX_ADAPTIVE_BASE_POSITIONS];


__constant__ uint64_t dev_EntropyNextPrefix2[1]; //Per-Batch Const
 uint64_t host_EntropyNextPrefix2[1]; //Per-Batch Const

 
 
 __host__ /* __and__ */ __device__ void GetBipForAdaptiveDigit(
	  int16_t* local_AdaptiveBaseCurrentBatchInitialDigits
	, int16_t* local_AdaptiveBaseDigitCarryTrigger
	, int16_t local_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION]
	, int16_t* inDigits, uint8_t pos, uint64_t* outBip) {
	int16_t curAdapriveDigit = inDigits[pos];
	*outBip = local_AdaptiveBaseDigitSet[pos][curAdapriveDigit];
}
__host__ /* __and__ */ __device__ void GetPaddedBipForAdaptiveDigit(
	int16_t* local_AdaptiveBaseCurrentBatchInitialDigits
	, int16_t* local_AdaptiveBaseDigitCarryTrigger
	, int16_t local_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION], int16_t* inDigits, uint8_t pos, uint64_t* outPadBip) {
	uint64_t curBipForDigit;

	GetBipForAdaptiveDigit(local_AdaptiveBaseCurrentBatchInitialDigits
		, local_AdaptiveBaseDigitCarryTrigger
		, local_AdaptiveBaseDigitSet, inDigits, pos, &curBipForDigit);

	uint8_t shiftCount;
	if (pos < MAX_ADAPTIVE_BASE_POSITIONS - 1) {
		shiftCount = (128 - 66 - pos * 11);
		*outPadBip = curBipForDigit << shiftCount;
	}
	else {
		shiftCount = 4;
		*outPadBip = curBipForDigit >> shiftCount;
	}
}
__host__ /* __and__ */ __device__ void AdaptiveDigitsToEntropy(
	int16_t* local_AdaptiveBaseCurrentBatchInitialDigits
	, int16_t local_AdaptiveBaseDigitCarryTrigger[MAX_ADAPTIVE_BASE_POSITIONS]
	, int16_t local_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION],
	uint64_t * local_EntropyAbsolutePrefix64,
	uint64_t * local_EntropyBatchNext24, 
	 int16_t* inDigits, uint64_t* outEntropy, uint8_t* checkSum) {

	outEntropy[0] = local_EntropyAbsolutePrefix64[0];
	outEntropy[1] = local_EntropyBatchNext24[0];

	uint64_t digitPaddedBip;
	for (int pos = 0; pos < MAX_ADAPTIVE_BASE_POSITIONS; pos++) {
		GetPaddedBipForAdaptiveDigit(local_AdaptiveBaseCurrentBatchInitialDigits
			, local_AdaptiveBaseDigitCarryTrigger
			,local_AdaptiveBaseDigitSet, inDigits, pos, &digitPaddedBip);
		outEntropy[1] |= digitPaddedBip;
	}

	uint64_t lastWord;
	GetBipForAdaptiveDigit(local_AdaptiveBaseCurrentBatchInitialDigits
		, local_AdaptiveBaseDigitCarryTrigger
		, local_AdaptiveBaseDigitSet, inDigits, MAX_ADAPTIVE_BASE_POSITIONS, &lastWord);
	*checkSum = lastWord & 0x000F;
}



__host__ /*and */ __device__
void AdaptiveUpdateMnemonicLow64(uint64_t* low64
	, int16_t digitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION]
	, int16_t curDigits[MAX_ADAPTIVE_BASE_POSITIONS]
)

{
	uint64_t tmpHigh = *low64;
	uint64_t tmpAns = tmpHigh;

	tmpAns = tmpHigh >> 62;
	tmpAns = tmpAns << 2;

	for (int i = 0; i < MAX_ADAPTIVE_BASE_POSITIONS - 1; i++) {
		tmpAns = tmpAns << 11;
		tmpAns & 0xFFFFFFFFFFFFF7F;
		tmpAns |= (uint64_t)(digitSet[i][curDigits[i]]);
	}
	tmpAns = tmpAns << 7;
	tmpAns |= ((uint64_t)(digitSet[MAX_ADAPTIVE_BASE_POSITIONS - 1][curDigits[MAX_ADAPTIVE_BASE_POSITIONS - 1]]) >> 4);

	*low64 = tmpAns;
}


