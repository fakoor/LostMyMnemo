#pragma once


#define MAX_ADAPTIVE_BASE_POSITIONS 6
#define MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION 262

//struct  __align__(8) AdaptiveStructConstType {
//};

struct  __align__(8) AdaptiveStructVarType {
	uint64_t dev_largestBatchIncrementProcessed;
	int16_t dev_largestBatchDigitsAchieved[MAX_ADAPTIVE_BASE_POSITIONS];
	uint64_t dev_CompletedBatches;

};

extern __device__ AdaptiveStructVarType dev_adaptiveVars;
//extern __constant__ AdaptiveStructConstType dev_adaptiveConsts;

//extern AdaptiveStructConstType host_adaptiveConsts;
extern AdaptiveStructVarType host_adaptiveVars;


extern uint64_t dev_EntropyAbsolutePrefix64[1];
extern uint64_t host_EntropyAbsolutePrefix64[1];


extern __constant__ int16_t dev_AdaptiveBaseDigitCarryTrigger[MAX_ADAPTIVE_BASE_POSITIONS];
extern __constant__ int16_t dev_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION];
extern __constant__ int16_t dev_AdaptiveBaseCurrentBatchInitialDigits[MAX_ADAPTIVE_BASE_POSITIONS];
extern __constant__ uint64_t dev_EntropyBatchNext24[1]; //Per-Batch Const

extern int16_t host_AdaptiveBaseDigitCarryTrigger[MAX_ADAPTIVE_BASE_POSITIONS];
extern int16_t host_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION];
extern int16_t host_AdaptiveBaseCurrentBatchInitialDigits[MAX_ADAPTIVE_BASE_POSITIONS];
extern uint64_t host_EntropyBatchNext24[1]; //Per-Batch Const

__host__ /* __and__ */ __device__ void AdaptiveDigitsToEntropy(
	int16_t* local_AdaptiveBaseCurrentBatchInitialDigits
	, int16_t local_AdaptiveBaseDigitCarryTrigger[MAX_ADAPTIVE_BASE_POSITIONS]
	, int16_t local_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION],
	uint64_t* local_EntropyAbsolutePrefix64,
	uint64_t* local_EntropyBatchNext24,
	int16_t* inDigits, uint64_t* outEntropy, uint8_t* checkSum);

__global__ void gl_DictionaryAttack(
	const uint64_t* __restrict__ entropy,
	const tableStruct* __restrict__ tables_legacy,
	const tableStruct* __restrict__ tables_segwit,
	const tableStruct* __restrict__ tables_native_segwit,
	retStruct* __restrict__ ret
);

