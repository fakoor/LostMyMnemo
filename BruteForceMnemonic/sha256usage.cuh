#pragma once
#ifndef __SHA256USAGE_CUH__
#define __SHA256USAGE_CUH__
#include "cuda_runtime.h"

__device__
void sha256(const uint32_t* pass, int pass_len, uint32_t* hash);


#endif /* __SHA256USAGE_CUH__ */