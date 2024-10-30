#include "vars.cuh"

__device__ uint64_t dev_retEntropy[2];
uint64_t host_retEntropy[2];

/* The found account and path */
__device__ uint8_t dev_retAccntPath[2];
uint8_t host_retAccntPath[2];

/* Account numbers. BlockChain's start from 1 all other standard from zero */
GPU_ACCNT_MIN_MAX_LOCATION uint8_t dev_accntMinMax[2];
uint8_t host_accntMinMax[2];



GPU_ACCNT_MIN_MAX_LOCATION uint8_t dev_childrenMinMax[2];
uint8_t host_childrenMinMax[2];


__constant__ uint8_t dev_uniqueTargetAddressBytes[20];
uint8_t host_uniqueTargetAddressBytes[20];


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
