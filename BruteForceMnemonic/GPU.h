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

//use to avoid using pointer and simple use array names as pointer to first and only member
#define PTR_AVOID_ELEMENTS	1
#define PTR_AVOIDER			0

extern __constant__ uint8_t salt_swap[16];
extern __constant__ uint8_t key_swap[16];

typedef struct {
	uint8_t key[32];
	uint8_t chain_code[32];
} extended_private_key_t;

typedef struct {
	uint8_t key[64];
	uint8_t chain_code[32];
} extended_public_key_t;

__device__
void sha256(const uint32_t* pass, int pass_len, uint32_t* hash);


__device__
void entropy_to_mnemonic(const uint64_t* gl_entropy, uint8_t* mnemonic_phrase);

__device__
void entropy_to_mnemonic_with_offset(const uint64_t* gl_entropy, uint8_t* mnemonic_phrase, uint32_t idx, int16_t  local_static_words_indices[12]);

__device__
 uint64_t SWAP512(uint64_t val);

__device__
 void sha512_swap(uint64_t* input, const uint32_t length, uint64_t* hash);

__device__ void key_to_hash160(
	const extended_private_key_t* master_private,
	const tableStruct* tables_legacy,
	const tableStruct* tables_segwit,
	const tableStruct* tables_native_segwit,
	const uint32_t* mnemonic,
	retStruct* ret
);


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