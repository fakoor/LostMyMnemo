#pragma once

#ifndef __DICTINARYSCANNER_CUH__
#define __DICTINARYSCANNER_CUH__

#include "GPU.h"
#include "EntropyTools.cuh"

__global__ void gl_DictionaryScanner(
	const uint64_t* __restrict__ nProcessedIterations,
	uint64_t* nProcessedInstances
);


__device__
void hardened_private_child_from_private(const extended_private_key_t* parent, extended_private_key_t* child, uint16_t hardened_child_number);

__device__
void normal_private_child_from_private(const extended_private_key_t* parent, extended_private_key_t* child, uint16_t normal_child_number, uint8_t h33 = 0, uint8_t h34 = 0);

__device__
void calc_public(const extended_private_key_t* priv, extended_public_key_t* pub);

__device__
void calc_hash160(extended_public_key_t* pub, uint32_t* hash160_bytes);

__device__
int find_hash_in_table(const uint32_t* hash, const tableStruct table, const uint32_t* mnemonic, foundStruct* fnd_ret, uint32_t path, uint32_t child);

#endif  /*__DICTINARYSCANNER_CUH__*/