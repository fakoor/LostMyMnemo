﻿/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V2.0.0
  * @date		28-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#include <stdafx.h>
#include <stdio.h>
#include <stdint.h>


#include "KernelStride.hpp"
#include "Helper.h"
#include <GPU.h>
#include "AdaptiveBase.h"
#include "DictionaryScanner.cuh"

#include "../Tools/utils.h"
#include "EntropyTools.cuh"
#include "BuildConfig.cuh"

int stride_class::DictionaryAttack(uint64_t grid, uint64_t block) {
	gl_DictionaryScanner << <(uint32_t)grid, (uint32_t)block, 0, dt->stream1 >> > ();
	cudaError_t err = cudaGetLastError();
	if (err != cudaSuccess) {
		std::cerr << "Kernel launch failed: " << cudaGetErrorString(err) << std::endl;
	}
	return 0;
}

#if STILL_BUILD_OLD_METHOD
int stride_class::bruteforce_mnemonic(uint64_t grid, uint64_t block) {
	gl_bruteforce_mnemonic << <(uint32_t)grid, (uint32_t)block, 0, dt->stream1 >> > (dt->dev.entropy, dt->dev.dev_tables_legacy, dt->dev.dev_tables_segwit, dt->dev.dev_tables_native_segwit, dt->dev.ret);
	return 0;
}

int stride_class::bruteforce_mnemonic_for_save(uint64_t grid, uint64_t block) {
	gl_bruteforce_mnemonic_for_save << <(uint32_t)grid, (uint32_t)block, 0, dt->stream1 >> > (dt->dev.entropy, dt->dev.dev_tables_legacy, dt->dev.dev_tables_segwit, dt->dev.dev_tables_native_segwit, dt->dev.ret, dt->dev.mnemonic, dt->dev.hash160);
	return 0;
}
int stride_class::memsetGlobalMnemonic()
{
	//if (DeviceSynchronize("cudaMemcpy table") != cudaSuccess) return -1;
	if (cudaMemcpyAsync(dt->dev.entropy, dt->host.entropy, dt->size_entropy_buf, cudaMemcpyHostToDevice, dt->stream1) != cudaSuccess) { fprintf(stderr, "cudaMemcpyAsync to Board->dev.entropy failed!"); return -1; }
	if (cudaMemsetAsync(dt->dev.ret, 0, sizeof(retStruct), dt->stream1) != cudaSuccess) { fprintf(stderr, "cudaMemset Board->dev.ret failed!"); return -1; }
	return 0;
}

int stride_class::memsetGlobalMnemonicSave()
{
	if (cudaMemcpyAsync(dt->dev.entropy, dt->host.entropy, dt->size_entropy_buf, cudaMemcpyHostToDevice, dt->stream1) != cudaSuccess) { fprintf(stderr, "cudaMemcpyAsync to Board->dev.entropy failed!"); return -1; }
	if (cudaMemsetAsync(dt->dev.ret, 0, sizeof(retStruct), dt->stream1) != cudaSuccess) { fprintf(stderr, "cudaMemset Board->dev.ret failed!"); return -1; }
	return 0;
}
#endif /*dev_tables_legacy*/

int stride_class::init()
{
#if STILL_BUILD_OLD_METHOD

	size_t memory_size = 0;
	for (int i = 0; i < 256; i++)
	{
		std::string name = "Table " + tools::byteToHexString(i);
		if (dt->dev.cudaMallocDevice((uint8_t**)&dt->dev.tables_legacy[i].table, dt->host.tables_legacy[i].size, &memory_size, name.c_str()) != 0)
		{
			std::cout << "Error cudaMallocDevice(), Board->dev.table_legacy[i]! i = " << i << std::endl;
			return -1;
		}
		dt->dev.tables_legacy[i].size = dt->host.tables_legacy[i].size;
		dt->dev.memory_size += dt->host.tables_legacy[i].size;
	}
	std::cout << "MALLOC MEMORY SIZE (TABLES LEGACY(BIP32, BIP44) GPU): " << std::to_string((float)memory_size / (1024.0f * 1024.0f)) << " MB\n";

	memory_size = 0;
	for (int i = 0; i < 256; i++)
	{
		std::string name = "Table " + tools::byteToHexString(i);
		if (dt->dev.cudaMallocDevice((uint8_t**)&dt->dev.tables_segwit[i].table, dt->host.tables_segwit[i].size, &memory_size, name.c_str()) != 0)
		{
			std::cout << "Error cudaMallocDevice(), Board->dev.tables_segwit[i]! i = " << i << std::endl;
			return -1;
		}
		dt->dev.tables_segwit[i].size = dt->host.tables_segwit[i].size;
		dt->dev.memory_size += dt->host.tables_segwit[i].size;
	}
	std::cout << "MALLOC MEMORY SIZE (TABLES SEGWIT(BIP49) GPU): " << std::to_string((float)memory_size / (1024.0f * 1024.0f)) << " MB\n";

	memory_size = 0;
	for (int i = 0; i < 256; i++)
	{
		std::string name = "Table " + tools::byteToHexString(i);
		if (dt->dev.cudaMallocDevice((uint8_t**)&dt->dev.tables_native_segwit[i].table, dt->host.tables_native_segwit[i].size, &memory_size, name.c_str()) != 0)
		{
			std::cout << "Error cudaMallocDevice(), Board->dev.tables_native_segwit[i]! i = " << i << std::endl;
			return -1;
		}
		dt->dev.tables_native_segwit[i].size = dt->host.tables_native_segwit[i].size;
		dt->dev.memory_size += dt->host.tables_native_segwit[i].size;
	}
	std::cout << "MALLOC MEMORY SIZE (TABLES NATIVE SEGWIT(BIP84) GPU): " << std::to_string((float)memory_size / (1024.0f * 1024.0f)) << " MB\n";


	std::cout << "INIT GPU ... \n";
	for (int i = 0; i < 256; i++)
	{
		if (cudaMemcpy((void*)dt->dev.tables_legacy[i].table, dt->host.tables_legacy[i].table, dt->host.tables_legacy[i].size, cudaMemcpyHostToDevice) != cudaSuccess)
		{
			std::cout << "cudaMemcpy to Board->dev.table_legacy[i] failed! i = " << i << std::endl;
			return -1;
		}
		const size_t percentDone = (i * 100 / 256) / 3;
		std::cout << "  " << percentDone << "%\r";
	}
	if (cudaMemcpy(dt->dev.dev_tables_legacy, dt->dev.tables_legacy, 256 * sizeof(tableStruct), cudaMemcpyHostToDevice) != cudaSuccess) { fprintf(stderr, "cudaMemcpyAsync to Board->dev.table_legacy failed!"); return -1; }

	for (int i = 0; i < 256; i++)
	{
		if (cudaMemcpy((void*)dt->dev.tables_segwit[i].table, dt->host.tables_segwit[i].table, dt->host.tables_segwit[i].size, cudaMemcpyHostToDevice) != cudaSuccess)
		{
			std::cout << "cudaMemcpy to Board->dev.table_segwit[i] failed! i = " << i << std::endl;
			return -1;
		}
		const size_t percentDone = 33 + (i * 100 / 256) / 3;
		std::cout << "  " << percentDone << "%\r";
	}
	if (cudaMemcpy(dt->dev.dev_tables_segwit, dt->dev.tables_segwit, 256 * sizeof(tableStruct), cudaMemcpyHostToDevice) != cudaSuccess) { fprintf(stderr, "cudaMemcpyAsync to Board->dev.table_segwit failed!"); return -1; }


	for (int i = 0; i < 256; i++)
	{
		if (cudaMemcpy((void*)dt->dev.tables_native_segwit[i].table, dt->host.tables_native_segwit[i].table, dt->host.tables_native_segwit[i].size, cudaMemcpyHostToDevice) != cudaSuccess)
		{
			std::cout << "cudaMemcpy to Board->dev.tables_native_segwit[i] failed! i = " << i << std::endl;
			return -1;
		}
		const size_t percentDone = 66 + (i * 100 / 256) / 3;
		std::cout << "  " << percentDone << "%\r";
	}
	std::cout << "  100%\r";
	if (cudaMemcpy(dt->dev.dev_tables_native_segwit, dt->dev.tables_native_segwit, 256 * sizeof(tableStruct), cudaMemcpyHostToDevice) != cudaSuccess) { fprintf(stderr, "cudaMemcpyAsync to Board->dev.tables_native_segwit failed!"); return -1; }
#endif
	if (deviceSynchronize("init") != cudaSuccess) return -1;
	return 0;
}


int stride_class::startDictionaryAttack(uint64_t grid, uint64_t block)
{
	if (DictionaryAttack(grid, block) != 0) return -1;

	return 0;
}

int stride_class::endDictionaryAttack()
{
	cudaError_t cudaStatus = cudaSuccess;
	if (deviceSynchronize("endDictionaryAttack") != cudaSuccess) return -1; //????
	cudaStatus = cudaMemcpy(dt->host.ret, dt->dev.ret, sizeof(retStruct), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy ret failed!");
		return -1;
	}
	cudaStatus = cudaMemcpy(dt->host.nProcessedInstances, dt->dev.nProcessedInstances, 8, cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy host_nProcessedFromBatch failed!");
		return -1;
	}
	cudaStatus = cudaMemcpy(dt->host.nProcessingIteration, dt->dev.nProcessingIteration, 8, cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy host_nProcessedMoreThanBatch failed!");
		return -1;
	}

	return 0;
}

#if STILL_BUILD_OLD_METHOD
int stride_class::start(uint64_t grid, uint64_t block)
{
	if (memsetGlobalMnemonic() != 0) return -1;
	if (bruteforce_mnemonic(grid, block) != 0) return -1;

	return 0;
}

int stride_class::end()
{
	cudaError_t cudaStatus = cudaSuccess;
	if (deviceSynchronize("end") != cudaSuccess) return -1; //????
	cudaStatus = cudaMemcpy(dt->host.ret, dt->dev.ret, sizeof(retStruct), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy ret failed!");
		return -1;
	}

	return 0;
}

int stride_class::start_for_save(uint64_t grid, uint64_t block)
{
	if (memsetGlobalMnemonicSave() != 0) return -1;
	if (bruteforce_mnemonic_for_save(grid, block) != 0) return -1;

	return 0;
}

int stride_class::end_for_save()
{
	cudaError_t cudaStatus = cudaSuccess;


	if (deviceSynchronize("end_for_save") != cudaSuccess) return -1; //????
	cudaStatus = cudaMemcpy(dt->host.mnemonic, dt->dev.mnemonic, dt->size_mnemonic_buf, cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy mnemonic failed!");
		return -1;
	}
	cudaStatus = cudaMemcpy(dt->host.hash160, dt->dev.hash160, dt->size_hash160_buf, cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy hash160 failed!");
		return -1;
	}
	cudaStatus = cudaMemcpy(dt->host.ret, dt->dev.ret, sizeof(retStruct), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy ret failed!");
		return -1;
	}

	return 0;
}
#endif /* STILL_BUILD_OLD_METHOD */