#include <stdafx.h>
#include <stdio.h>


#include <cuda.h>
#include "cuda_runtime.h"

#include <GPU.h>
#include "AdaptiveBase.h"
#include "EntropyTools.cuh"



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





