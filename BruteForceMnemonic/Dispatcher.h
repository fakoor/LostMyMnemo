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
#include "consts.h"
int Generate_Mnemonic(void);


void PrintNextMnemo(uint64_t batchMnemo[2], uint64_t nHowMuch, int16_t carry[MAX_ADAPTIVE_BASE_POSITIONS]
	, int16_t initDigits[MAX_ADAPTIVE_BASE_POSITIONS]
	, int16_t digitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION]
);

//__host__ __device__ void AdaptiveUpdateMnemonicLow64(uint64_t* low64
//	, int16_t digitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION]
//	, int16_t curDigits[MAX_ADAPTIVE_BASE_POSITIONS]);

bool NewTrunkPrefix();

