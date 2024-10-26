#pragma once

#ifndef __BIP39TOOLS_CUH__
#define __BIP39TOOLS_CUH__

#include "MemConfig.cuh"

extern GPU_BIP_WORDS_TEXT_LOCATION uint8_t words[2048][9];
// 2kB
extern GPU_BIP_WORDS_LENGTH_LOCATION uint8_t word_lengths[2048];


#endif/*__BIP39TOOLS_CUH__*/