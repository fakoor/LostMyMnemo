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



  /* Two of six logical functions used in SHA-1, SHA-256, SHA-384, and SHA-512: */
#define SHAF1(x,y,z)	(((x) & (y)) ^ ((~(x)) & (z)))
#define SHAF0(x,y,z)	(((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))



#define mod(x,y) ((x)-((x)/(y)*(y)))
#define shr32(x,n) ((x) >> (n))
#define rotl32(n,d) (((n) << (d)) | ((n) >> (32 - (d))))
#define rotl64(n,d) (((n) << (d)) | ((n) >> (64 - (d))))
#define rotr64(n,d) (((n) >> (d)) | ((n) << (64 - (d))))
#define S0(x) (rotl32 ((x), 25u) ^ rotl32 ((x), 14u) ^ shr32 ((x),  3u))
#define S1(x) (rotl32 ((x), 15u) ^ rotl32 ((x), 13u) ^ shr32 ((x), 10u))
#define S2(x) (rotl32 ((x), 30u) ^ rotl32 ((x), 19u) ^ rotl32 ((x), 10u))
#define S3(x) (rotl32 ((x), 26u) ^ rotl32 ((x), 21u) ^ rotl32 ((x),  7u))




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
void GetWordFromBipIndex(int16_t  index, uint8_t word[10]);

__device__
void entropy_to_mnemonic(const uint64_t* gl_entropy, uint8_t* mnemonic_phrase);

__device__
void entropy_to_mnemonic_with_offset(const uint64_t* gl_entropy, uint8_t* mnemonic_phrase, uint32_t idx, int16_t  local_static_words_indices[12]);

//__inline__
//__device__
//void IndicesToMnemonic(int16_t  indices[12], uint8_t* mnemonic_phrase);

__inline__
__device__
uint64_t SWAP512(uint64_t val) {
	uint64_t tmp;
	uint64_t ret;
	tmp = (rotr64((uint64_t)((val) & (uint64_t)0x0000FFFF0000FFFFUL), 16) | rotl64((uint64_t)((val) & (uint64_t)0xFFFF0000FFFF0000UL), 16));
	ret = (rotr64((uint64_t)((tmp) & (uint64_t)0xFF00FF00FF00FF00UL), 8) | rotl64((uint64_t)((tmp) & (uint64_t)0x00FF00FF00FF00FFUL), 8));
	return ret;
}

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