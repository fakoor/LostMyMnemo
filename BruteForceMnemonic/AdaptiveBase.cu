#include <stdafx.h>

#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include "AdaptiveBase.h"
#include <GPU.h>
#include <cuda.h>


/*
* We onsider Mnemonics a Base - 2048 twelve-digit unsigned integer,
* if we have some information about any of digits, so that we can
* ommit 1 to 2047 digits (words) from a specific position, then that
* digit is adaptively based to Base-2047 down to Base-2 aka binary.
* The only mathematic operation we need for the purpose is increment,
* When we reach the carry for a VariableBase digit, uppon an increment,
* we will rewind that digit and increment the more significant digit
* DUE to less memory usage in constant-memory, we limit such mechanism
* to the 6 least significant mnemonic words in a 262 guessed space
* Hence the dictionary for positions 6 to 12 outght not to include
* more than 262 words. The other structure provides reverse lookup for a value of a digit
*/




__constant__ AdaptiveStructConstType dev_adaptiveConsts;
__device__ AdaptiveStructVarType dev_adaptiveVars;

__host__ /* __and__ */ __device__ void IncrementAdaptiveDigits(int16_t* inDigits, uint64_t howMuch, int16_t* outDigits) {
	uint64_t nYetToAdd = howMuch;
	uint64_t nCarryValue = 0;

	for (int i = MAX_ADAPTIVE_BASE_POSITIONS - 1; i >= 0; i--) {
		if (nYetToAdd == 0 && nCarryValue == 0) {
			outDigits[i] = inDigits[i];
			continue;
		}

		int16_t beforeIncDigit = dev_adaptiveConsts.dev_AdaptiveBaseCurrentBatchInitialDigits[i];
		int nCarryAt = dev_adaptiveConsts.dev_AdaptiveBaseDigitCarryTrigger[i];

		int nThisIdeal = nYetToAdd + beforeIncDigit + nCarryValue;
		int nThisNewDigit = nThisIdeal % nCarryAt;


		outDigits[i] = nThisNewDigit;
		nCarryValue = nThisIdeal / nCarryAt;
		nYetToAdd = 0; //all active in carry if any
	}
	if (nYetToAdd != 0 || nCarryValue != 0) {
		//ASSERT: We have carried out of our space, NOP anyway
	}
}


__host__ /* __and__ */ __device__ void GetBipForAdaptiveDigit(int16_t* inDigits, uint8_t pos, uint64_t* outBip) {
	int16_t curAdapriveDigit = inDigits[pos];
	*outBip = dev_adaptiveConsts.dev_AdaptiveBaseDigitSet[pos][curAdapriveDigit];
}
__host__ /* __and__ */ __device__ void GetPaddedBipForAdaptiveDigit(int16_t* inDigits, uint8_t pos, uint64_t* outPadBip) {
	uint64_t curBipForDigit;
	GetBipForAdaptiveDigit(inDigits, pos, &curBipForDigit);
	uint8_t shiftCount;
	if (pos < MAX_ADAPTIVE_BASE_POSITIONS - 1) {
		shiftCount = (128 - 66 - pos * 11);
		*outPadBip = curBipForDigit << shiftCount;
	}
	else {
		shiftCount = 4;
		*outPadBip = curBipForDigit >> shiftCount;
	}
}
__host__ /* __and__ */ __device__ void AdaptiveDigitsToEntropy(int16_t* inDigits, uint64_t* outEntropy, uint8_t* checkSum) {

	outEntropy[0] = dev_adaptiveConsts.dev_EntropyAbsolutePrefix64;
	outEntropy[1] = dev_adaptiveConsts.dev_EntropyBatchNext24;

	uint64_t digitPaddedBip;
	for (int pos = 0; pos < MAX_ADAPTIVE_BASE_POSITIONS; pos++) {
		GetPaddedBipForAdaptiveDigit(inDigits, pos, &digitPaddedBip);
		outEntropy[1] |= digitPaddedBip;
	}

	uint64_t lastWord;
	GetBipForAdaptiveDigit(inDigits, MAX_ADAPTIVE_BASE_POSITIONS, &lastWord);
	*checkSum = lastWord & 0x000F;
}


__global__ void gl_DictionaryAttack(
	const uint64_t* __restrict__ entropy,
	const tableStruct* __restrict__ tables_legacy,
	const tableStruct* __restrict__ tables_segwit,
	const tableStruct* __restrict__ tables_native_segwit,
	retStruct* __restrict__ ret
)
{

	//TODO: Each thread picks is load from Incremental Base!
	int idx = blockIdx.x * blockDim.x + threadIdx.x;

	int16_t curDigits[MAX_ADAPTIVE_BASE_POSITIONS];
	uint64_t curEntropy[2];
	uint8_t reqChecksum;

	IncrementAdaptiveDigits(dev_adaptiveConsts.dev_AdaptiveBaseCurrentBatchInitialDigits, idx, curDigits);
	AdaptiveDigitsToEntropy(curDigits, curEntropy, &reqChecksum);

	uint8_t mnemonic_phrase[SIZE_MNEMONIC_FRAME] = { 0 };
	uint8_t* mnemonic = mnemonic_phrase;
	uint32_t ipad[256 / 4];
	uint32_t opad[256 / 4];
	uint32_t seed[64 / 4];

	entropy_to_mnemonic(entropy, mnemonic);
#pragma unroll
	for (int x = 0; x < 120 / 8; x++) {
		*(uint64_t*)((uint64_t*)ipad + x) = 0x3636363636363636ULL ^ SWAP512(*(uint64_t*)((uint64_t*)mnemonic + x));
	}
#pragma unroll
	for (int x = 0; x < 120 / 8; x++) {
		*(uint64_t*)((uint64_t*)opad + x) = 0x5C5C5C5C5C5C5C5CULL ^ SWAP512(*(uint64_t*)((uint64_t*)mnemonic + x));
	}
#pragma unroll
	for (int x = 120 / 4; x < 128 / 4; x++) {
		ipad[x] = 0x36363636;
	}
#pragma unroll
	for (int x = 120 / 4; x < 128 / 4; x++) {
		opad[x] = 0x5C5C5C5C;
	}
#pragma unroll
	for (int x = 0; x < 16 / 4; x++) {
		ipad[x + 128 / 4] = *(uint32_t*)((uint32_t*)&salt_swap + x);
	}
	sha512_swap((uint64_t*)ipad, 140, (uint64_t*)&opad[128 / 4]);
	sha512_swap((uint64_t*)opad, 192, (uint64_t*)&ipad[128 / 4]);
#pragma unroll
	for (int x = 0; x < 64 / 4; x++) {
		seed[x] = ipad[128 / 4 + x];
	}
	for (int x = 1; x < 2048; x++) {
		sha512_swap((uint64_t*)ipad, 192, (uint64_t*)&opad[128 / 4]);
		sha512_swap((uint64_t*)opad, 192, (uint64_t*)&ipad[128 / 4]);
#pragma unroll
		for (int x = 0; x < 64 / 4; x++) {
			seed[x] = seed[x] ^ ipad[128 / 4 + x];
		}
	}
#pragma unroll
	for (int x = 0; x < 16 / 4; x++) {
		ipad[x] = 0x36363636 ^ *(uint32_t*)((uint32_t*)&key_swap + x);
	}
#pragma unroll
	for (int x = 0; x < 16 / 4; x++) {
		opad[x] = 0x5C5C5C5C ^ *(uint32_t*)((uint32_t*)&key_swap + x);
	}
#pragma unroll
	for (int x = 16 / 4; x < 128 / 4; x++) {
		ipad[x] = 0x36363636;
	}
#pragma unroll
	for (int x = 16 / 4; x < 128 / 4; x++) {
		opad[x] = 0x5C5C5C5C;
	}
#pragma unroll
	for (int x = 0; x < 64 / 4; x++) {
		ipad[x + 128 / 4] = seed[x];
	}
	//ipad[192 / 4] = 0;
	//opad[192 / 4] = 0;
	sha512_swap((uint64_t*)ipad, 192, (uint64_t*)&opad[128 / 4]);
	sha512_swap((uint64_t*)opad, 192, (uint64_t*)&ipad[128 / 4]);
#pragma unroll
	for (int x = 0; x < 128 / 8; x++) {
		*(uint64_t*)((uint64_t*)&ipad[128 / 4] + x) = SWAP512(*(uint64_t*)((uint64_t*)&ipad[128 / 4] + x));
	}
	key_to_hash160((extended_private_key_t*)&ipad[128 / 4], tables_legacy, tables_segwit, tables_native_segwit, (uint32_t*)mnemonic, ret);
	//__syncthreads();
}

