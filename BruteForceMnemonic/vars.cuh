#pragma once
#ifndef __VARS_CUH__
#define __VARS_CUH__
#include "cuda_runtime.h"
#include "consts.h"
#include "Memconfig.cuh"

extern __device__ uint64_t dev_retEntropy[2];
extern uint64_t host_retEntropy[2];

extern __device__ uint8_t dev_retAccntPath[2];
extern uint8_t host_retAccntPath[2];

extern GPU_ACCNT_MIN_MAX_LOCATION uint8_t dev_accntMinMax[2];
extern uint8_t host_accntMinMax[2];

extern GPU_ACCNT_MIN_MAX_LOCATION uint8_t dev_childrenMinMax[2];
extern uint8_t host_childrenMinMax[2];


extern __constant__ uint8_t dev_uniqueTargetAddressBytes[20];
extern uint8_t host_uniqueTargetAddressBytes[20];


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




#endif