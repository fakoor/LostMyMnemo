/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V2.0.0
  * @date		28-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#pragma once

#include <stdint.h>
#include "stdafx.h"
#include "cuda_runtime.h"
#include "device_launch_parameters.h"


#define MAX_ADAPTIVE_BASE_POSITIONS 6
#define MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION 262

extern __constant__ int16_t dev_AdaptiveBaseDigitCarryTrigger[MAX_ADAPTIVE_BASE_POSITIONS];
extern __constant__ int16_t dev_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION];
extern __constant__ int16_t dev_AdaptiveBaseCurrentBatchInitialDigits[MAX_ADAPTIVE_BASE_POSITIONS];

extern __device__ uint64_t dev_largestBatchIncrementProcessed;
extern __device__ int16_t dev_largestBatchDigitsAchieved[MAX_ADAPTIVE_BASE_POSITIONS];

extern __constant__ uint64_t dev_EntropyAbsolutePrefix64;
extern __constant__ uint64_t dev_EntropyBatchNext24; //Per-Batch Const

extern __device__ uint64_t dev_CompletedBatches0;



__global__ void gl_bruteforce_mnemonic(
	const uint64_t* __restrict__ entropy,
	const tableStruct* __restrict__ tables_legacy,
	const tableStruct* __restrict__ tables_segwit,
	const tableStruct* __restrict__ tables_native_segwit,
	retStruct* __restrict__ ret
);

__global__ void gl_bruteforce_mnemonic_for_save(
	const uint64_t* __restrict__ entropy,
	const tableStruct* __restrict__ tables_legacy,
	const tableStruct* __restrict__ tables_segwit,
	const tableStruct* __restrict__ tables_native_segwit,
	retStruct* __restrict__ ret,
	uint8_t* __restrict__ mnemonic_ret,
	uint32_t* __restrict__ hash160_ret
);


extern __constant__ uint32_t dev_num_bytes_find[];
extern __constant__ uint32_t dev_generate_path[];
extern __constant__ uint32_t dev_num_childs[];
extern __constant__ uint32_t dev_num_paths[];
extern __constant__ int16_t dev_static_words_indices[];