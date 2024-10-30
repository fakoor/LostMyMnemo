#pragma once
#ifndef __ADAPTIVEBASE_H__
#define __ADAPTIVEBASE_H__
#include "cuda_runtime.h"
#include "consts.h"
#include "EntropyTools.cuh"
#include "vars.cuh"




//extern /*__device__*/ uint64_t* dev_nProcessedFromBatch;
//
//extern /*__device__*/ uint64_t* dev_nProcessedMoreThanBatch;
//
//extern uint64_t* host_nProcessedFromBatch;
//
//extern uint64_t* host_nProcessedMoreThanBatch;
#if 0
__host__ __device__
void PrintNextMnemo(uint64_t entrop[2], uint64_t nHowMuch, int16_t carry[MAX_ADAPTIVE_BASE_POSITIONS]
	, int16_t initDigits[MAX_ADAPTIVE_BASE_POSITIONS]
	, int16_t digitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION]
);
#endif

//#if 1
//#else
//inline __host__ /* __and__ */ __device__   void IncrementAdaptiveDigits(int16_t* local_AdaptiveBaseDigitCarryTrigger, int16_t* inDigits, uint64_t howMuch, int16_t* outDigits, int16_t* bCanContinue) 
//#endif
#define IncrementAdaptiveDigits(local_AdaptiveBaseDigitCarryTrigger, inDigits, howMuch, outDigits, bCanContinue) \
{ \
	uint64_t nYetToAdd = howMuch; \
	uint64_t nCarryValue = 0; \
	int16_t tmpResult[MAX_ADAPTIVE_BASE_POSITIONS]; \
	\
	for (char i = MAX_ADAPTIVE_BASE_POSITIONS - 1; i >= 0; i--) { \
		if (nYetToAdd == 0 && nCarryValue == 0) { \
			tmpResult[i] = inDigits[i]; \
			\
		}\
		else {\
			\
			int16_t beforeIncDigit = inDigits[i]; \
			int16_t nCarryAt = local_AdaptiveBaseDigitCarryTrigger[i];\
\
			uint64_t nThisIdeal = nYetToAdd + beforeIncDigit + nCarryValue; \
			int16_t nThisNewDigit = nThisIdeal % nCarryAt; \
\
			tmpResult[i] = nThisNewDigit; \
			nCarryValue = nThisIdeal / nCarryAt; \
			nYetToAdd = 0; /*all active in carry if any*/ \
		} \
	}/* for */ \
	if (nYetToAdd != 0 || nCarryValue != 0) \
		*bCanContinue = 0; \
\
		outDigits[0] = (*bCanContinue<=0)? local_AdaptiveBaseDigitCarryTrigger[0]-1 : tmpResult[0]; \
		outDigits[1] = (*bCanContinue<=0)? local_AdaptiveBaseDigitCarryTrigger[1]-1 : tmpResult[1]; \
		outDigits[2] = (*bCanContinue<=0)? local_AdaptiveBaseDigitCarryTrigger[2]-1 : tmpResult[2]; \
		outDigits[3] = (*bCanContinue<=0)? local_AdaptiveBaseDigitCarryTrigger[3]-1 : tmpResult[3]; \
		outDigits[4] = (*bCanContinue<=0)? local_AdaptiveBaseDigitCarryTrigger[4]-1 : tmpResult[4]; \
		outDigits[5] = (*bCanContinue<=0)? local_AdaptiveBaseDigitCarryTrigger[5]-1 : tmpResult[5]; \
} 

__host__ /* __and__ */ __device__ void GetBipForAdaptiveDigit(
	int16_t* local_AdaptiveBaseCurrentBatchInitialDigits
	, int16_t* local_AdaptiveBaseDigitCarryTrigger
	, int16_t local_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION]
	, int16_t* inDigits, uint8_t pos, uint64_t* outBip);

__host__ /* __and__ */ __device__ void AdaptiveDigitsToEntropy(
	int16_t* local_AdaptiveBaseCurrentBatchInitialDigits
	, int16_t local_AdaptiveBaseDigitCarryTrigger[MAX_ADAPTIVE_BASE_POSITIONS]
	, int16_t local_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION],
	uint64_t* local_EntropyAbsolutePrefix64,
	uint64_t* local_EntropyBatchNext24,
	int16_t* inDigits, uint64_t* outEntropy, uint8_t* checkSum);



#endif /* __ADAPTIVEBASE_H__ */