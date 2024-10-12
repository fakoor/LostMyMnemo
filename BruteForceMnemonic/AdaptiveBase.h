#pragma once
#include "consts.h"


extern __constant__ uint64_t dev_EntropyAbsolutePrefix64[1];
extern uint64_t host_EntropyAbsolutePrefix64[1];


extern __constant__ int16_t dev_AdaptiveBaseDigitCarryTrigger[MAX_ADAPTIVE_BASE_POSITIONS];
extern __constant__ int16_t dev_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION];
extern __constant__ int16_t dev_AdaptiveBaseCurrentBatchInitialDigits[MAX_ADAPTIVE_BASE_POSITIONS];
extern __constant__ uint64_t dev_EntropyNextPrefix2[1]; //Per-Batch Const

extern int16_t host_AdaptiveBaseDigitCarryTrigger[MAX_ADAPTIVE_BASE_POSITIONS];
extern int16_t host_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION];
extern int16_t host_AdaptiveBaseCurrentBatchInitialDigits[MAX_ADAPTIVE_BASE_POSITIONS];
extern uint64_t host_EntropyNextPrefix2[1]; //Per-Batch Const


//extern /*__device__*/ uint64_t* dev_nProcessedFromBatch;
//
//extern /*__device__*/ uint64_t* dev_nProcessedMoreThanBatch;
//
//extern uint64_t* host_nProcessedFromBatch;
//
//extern uint64_t* host_nProcessedMoreThanBatch;
__host__ __device__
void PrintNextMnemo(uint64_t entrop[2], uint64_t nHowMuch, int16_t carry[MAX_ADAPTIVE_BASE_POSITIONS]
	, int16_t initDigits[MAX_ADAPTIVE_BASE_POSITIONS]
	, int16_t digitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION]
);


__host__ /*and */ __device__
void AdaptiveUpdateMnemonicLow64(uint64_t* low64
	, int16_t digitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION]
	, int16_t curDigits[MAX_ADAPTIVE_BASE_POSITIONS]
);


__host__ /* __and__ */ __device__  bool IncrementAdaptiveDigits(int16_t* local_AdaptiveBaseDigitCarryTrigger, int16_t* inDigits, uint64_t howMuch, int16_t* outDigits);

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

__global__ void gl_DictionaryAttack(
	 uint64_t*  nBatchPlannedProc,
	 uint64_t*  nBatchMoreProc,
	const tableStruct* __restrict__ tables_legacy,
	const tableStruct* __restrict__ tables_segwit,
	const tableStruct* __restrict__ tables_native_segwit,
	retStruct* __restrict__ ret
);

