#pragma once

#ifndef __DICTINARYSCANNER_CUH__
#define __DICTINARYSCANNER_CUH__

#include "EntropyTools.cuh"

__global__ void gl_DictionaryScanner(
	const uint64_t* __restrict__ nProcessedIterations,
	uint64_t* nProcessedInstances,
	const tableStruct* __restrict__ tables_legacy,
	const tableStruct* __restrict__ tables_segwit,
	const tableStruct* __restrict__ tables_native_segwit,
	retStruct* __restrict__ ret
);

inline __device__ __host__ int DictionaryCheckFound(retStruct* ret) {

	//if (ret->f[0].count_found >= MAX_FOUND_ADDRESSES)
	//{
	//	ret->f[0].count_found = MAX_FOUND_ADDRESSES;
	//}
	//if (ret->f[1].count_found >= MAX_FOUND_ADDRESSES)
	//{
	//	ret->f[1].count_found = MAX_FOUND_ADDRESSES;
	//}
	//if (ret->f[2].count_found >= MAX_FOUND_ADDRESSES)
	//{
	//	ret->f[2].count_found = MAX_FOUND_ADDRESSES;
	//}
	//if (ret->f[0].count_found_bytes >= MAX_FOUND_ADDRESSES)
	//{
	//	ret->f[0].count_found_bytes = MAX_FOUND_ADDRESSES;
	//}
	//if (ret->f[1].count_found_bytes >= MAX_FOUND_ADDRESSES)
	//{
	//	ret->f[1].count_found_bytes = MAX_FOUND_ADDRESSES;
	//}
	//if (ret->f[2].count_found_bytes >= MAX_FOUND_ADDRESSES)
	//{
	//	ret->f[2].count_found_bytes = MAX_FOUND_ADDRESSES;

	//}

	if (ret->f[0].count_found != 0)
	{
		//for (uint32_t i = 0; i < ret->f[0].count_found; i++)
		//{
			return 1;
		//}
	}
	if (ret->f[1].count_found != 0)
	{
		//for (uint32_t i = 0; i < ret->f[1].count_found; i++)
		//{
			return 1;
		//}
	}
	if (ret->f[2].count_found != 0)
	{
		//for (uint32_t i = 0; i < ret->f[2].count_found; i++)
		//{
			return 1;
		//}
	}

	return 0;
}


#endif  /*__DICTINARYSCANNER_CUH__*/