#pragma once

#ifndef __DICTINARYSCANNER_CUH__
#define __DICTINARYSCANNER_CUH__

#include "EntropyTools.cuh"

__global__ void gl_DictionaryScanner(
	uint64_t* nBatchPlannedProc,
	uint64_t* nBatchMoreProc,
	const tableStruct* __restrict__ tables_legacy,
	const tableStruct* __restrict__ tables_segwit,
	const tableStruct* __restrict__ tables_native_segwit,
	retStruct* __restrict__ ret
);



#endif  /*__DICTINARYSCANNER_CUH__*/