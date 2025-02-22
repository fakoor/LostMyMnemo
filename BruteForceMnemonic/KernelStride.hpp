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
#include "stdafx.h"
#include <stdint.h>


#include "Helper.h"
#include "EntropyTools.cuh"
#include "BuildConfig.cuh"

class stride_class
{
public:
	data_class* dt;
public:

	stride_class(data_class* data)
	{
		dt = data;
	}

private:

public:
	
	int DictionaryAttack(uint64_t grid, uint64_t block);
	int startDictionaryAttack(uint64_t grid, uint64_t block);
	int endDictionaryAttack();

	int init();
#if STILL_BUILD_OLD_METHOD

	int start(uint64_t grid, uint64_t block);
	int end();

	int memsetGlobalMnemonic();
	int bruteforce_mnemonic_for_save(uint64_t grid, uint64_t block);
	int memsetGlobalMnemonicSave();
	int end_for_save();
	int bruteforce_mnemonic(uint64_t grid, uint64_t block);
	int start_for_save(uint64_t grid, uint64_t block);
#endif
};

