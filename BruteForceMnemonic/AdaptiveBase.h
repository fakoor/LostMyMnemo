#pragma once


#define MAX_ADAPTIVE_BASE_POSITIONS 6
#define MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION 262

struct AdaptiveStructConstType {
	int16_t dev_AdaptiveBaseDigitCarryTrigger[MAX_ADAPTIVE_BASE_POSITIONS];
	int16_t dev_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION];
	int16_t dev_AdaptiveBaseCurrentBatchInitialDigits[MAX_ADAPTIVE_BASE_POSITIONS];


	uint64_t dev_EntropyAbsolutePrefix64;
	uint64_t dev_EntropyBatchNext24; //Per-Batch Const
};

struct AdaptiveStructVarType {
	uint64_t dev_largestBatchIncrementProcessed;
	int16_t dev_largestBatchDigitsAchieved[MAX_ADAPTIVE_BASE_POSITIONS];
	uint64_t dev_CompletedBatches;

};
//extern __constant__ int16_t dev_AdaptiveBaseDigitCarryTrigger[MAX_ADAPTIVE_BASE_POSITIONS];
//extern __constant__ int16_t dev_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION];
//extern __constant__ int16_t dev_AdaptiveBaseCurrentBatchInitialDigits[MAX_ADAPTIVE_BASE_POSITIONS];
//
//extern __device__ uint64_t dev_largestBatchIncrementProcessed;
//extern __device__ int16_t dev_largestBatchDigitsAchieved[MAX_ADAPTIVE_BASE_POSITIONS];
//
//extern __constant__ uint64_t dev_EntropyAbsolutePrefix64;
//extern __constant__ uint64_t dev_EntropyBatchNext24; //Per-Batch Const
//
//extern __device__ uint64_t dev_CompletedBatches0;

extern __device__ AdaptiveStructVarType dev_adaptiveVars;
extern __constant__ AdaptiveStructConstType dev_adaptiveConsts;


__global__ void gl_DictionaryAttack(
	const uint64_t* __restrict__ entropy,
	const tableStruct* __restrict__ tables_legacy,
	const tableStruct* __restrict__ tables_segwit,
	const tableStruct* __restrict__ tables_native_segwit,
	retStruct* __restrict__ ret
);
