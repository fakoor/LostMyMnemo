#pragma once

#ifndef __MEMCONFIG_CUH__
#define __MEMCONFIG_CUH__

#include "cuda_runtime.h"

/************************************************************************/
#define GPU_WORD_TO_CONST				0
#define GPU_LENGTH_TO_CONST				0
#define GPU_ACCNT_MIN_MAX_TO_CONST		0 /*Weired : Does Not Work When CONST */
/************************************************************************/
/*	
 * 
 *  either use:
 *  __constant__ 
 *  or;
 *  __device__
 * 
 */
#if GPU_WORD_TO_CONST
#define GPU_BIP_WORDS_TEXT_LOCATION			__constant__
#else
#define GPU_BIP_WORDS_TEXT_LOCATION			__device__
#endif

#if GPU_LENGTH_TO_CONST
#define GPU_BIP_WORDS_LENGTH_LOCATION		__constant__
#else
#define GPU_BIP_WORDS_LENGTH_LOCATION		__device__
#endif

#if GPU_ACCNT_MIN_MAX_TO_CONST
#define GPU_ACCNT_MIN_MAX_LOCATION			__constant__
#else
#define GPU_ACCNT_MIN_MAX_LOCATION			__device__
#endif


#endif /*__MEMCONFIG_CUH__*/