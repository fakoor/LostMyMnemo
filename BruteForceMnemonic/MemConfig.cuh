#pragma once

#ifndef __MEMCONFIG_CUH__
#define __MEMCONFIG_CUH__

#include "cuda_runtime.h"

/*	
 * 
 *  either use:
 *  __constant__ 
 *  or;
 *  __device__
 * 
 */
#define GPU_BIP_WORDS_TEXT_LOCATION			__device__
#define GPU_BIP_WORDS_LENGTH_LOCATION		__device__

#endif /*__MEMCONFIG_CUH__*/