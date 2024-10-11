#include <stdafx.h>

//#include "device_launch_parameters.h"
//#include <device_functions.h>

#include <cuda.h>
#include "cuda_runtime.h"
#include <GPU.h>
#include "AdaptiveBase.h"



//#include <cooperative_groups.h>
//#include <sm_60_atomic_functions.h>
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



__device__ int dev_checkResult(retStruct* ret) {

	if (ret->f[0].count_found >= MAX_FOUND_ADDRESSES)
	{
		ret->f[0].count_found = MAX_FOUND_ADDRESSES;
	}
	if (ret->f[1].count_found >= MAX_FOUND_ADDRESSES)
	{
		ret->f[1].count_found = MAX_FOUND_ADDRESSES;
	}
	if (ret->f[2].count_found >= MAX_FOUND_ADDRESSES)
	{
		ret->f[2].count_found = MAX_FOUND_ADDRESSES;
	}
	if (ret->f[0].count_found_bytes >= MAX_FOUND_ADDRESSES)
	{
		ret->f[0].count_found_bytes = MAX_FOUND_ADDRESSES;
	}
	if (ret->f[1].count_found_bytes >= MAX_FOUND_ADDRESSES)
	{
		ret->f[1].count_found_bytes = MAX_FOUND_ADDRESSES;
	}
	if (ret->f[2].count_found_bytes >= MAX_FOUND_ADDRESSES)
	{
		ret->f[2].count_found_bytes = MAX_FOUND_ADDRESSES;

	}

	if (ret->f[0].count_found != 0)
	{
		for (uint32_t i = 0; i < ret->f[0].count_found; i++)
		{
			//foundInfoStruct* info = &ret->f[0].found_info[i];
			//std::string mnemonic_str = (const char*)info->mnemonic;
			//std::string addr;
			//std::string path = getPath(info->path, info->child);
			//tools::encodeAddressBase58((const uint8_t*)info->hash160, addr);
			//tools::addFoundMnemonicInFile(path, mnemonic_str, addr);
			//std::cout << "!!!FOUND!!!\n!!!FOUND!!!\n!!!FOUND!!!\n!!!FOUND!!!\n";
			//std::cout << "!!!FOUND ADDRESS (" << path << "): " << mnemonic_str << ", " << addr << std::endl;
			//std::cout << "!!!FOUND!!!\n!!!FOUND!!!\n!!!FOUND!!!\n!!!FOUND!!!\n";
			return 1;
		}
	}
	if (ret->f[1].count_found != 0)
	{
		for (uint32_t i = 0; i < ret->f[1].count_found; i++)
		{
			//foundInfoStruct* info = &ret->f[1].found_info[i];
			//std::string mnemonic_str = (const char*)info->mnemonic;
			//std::string addr;
			//std::string path = getPath(info->path, info->child);
			//tools::encodeAddressBIP49((const uint8_t*)info->hash160, addr);
			//tools::addFoundMnemonicInFile(path, mnemonic_str, addr);
			//std::cout << "!!!FOUND!!!\n!!!FOUND!!!\n!!!FOUND!!!\n!!!FOUND!!!\n";
			//std::cout << "!!!FOUND ADDRESS (" << path << "): " << mnemonic_str << ", " << addr << std::endl;
			//std::cout << "!!!FOUND!!!\n!!!FOUND!!!\n!!!FOUND!!!\n!!!FOUND!!!\n
			return 1;
		}
	}
	if (ret->f[2].count_found != 0)
	{
		for (uint32_t i = 0; i < ret->f[2].count_found; i++)
		{
			//foundInfoStruct* info = &ret->f[2].found_info[i];
			//std::string mnemonic_str = (const char*)info->mnemonic;
			//std::string addr;
			//std::string path = getPath(info->path, info->child);
			//tools::encodeAddressBase32((const uint8_t*)info->hash160, addr);
			//tools::addFoundMnemonicInFile(path, mnemonic_str, addr);
			//std::cout << "!!!FOUND!!!\n!!!FOUND!!!\n!!!FOUND!!!\n!!!FOUND!!!\n";
			//std::cout << "!!!FOUND ADDRESS (" << path << "): " << mnemonic_str << ", " << addr << std::endl;
			//std::cout << "!!!FOUND!!!\n!!!FOUND!!!\n!!!FOUND!!!\n!!!FOUND!!!\n";
			return 1;
		}
	}

	//if (ret->f[0].count_found_bytes != 0)
	//{
	//	for (uint32_t i = 0; i < ret->f[0].count_found_bytes; i++)
	//	{
	//		foundBytesInfoStruct* info = &ret->f[0].found_bytes_info[i];
	//		int num_bytes = 0;
	//		for (int i = 0; i < 20; i++)
	//		{
	//			if (*(uint8_t*)((uint8_t*)info->hash160 + i) != *(uint8_t*)((uint8_t*)info->hash160_from_table + i)) break;
	//			num_bytes++;
	//		}

	//		std::string mnemonic_str = (const char*)info->mnemonic;
	//		std::string hash160 = tools::bytesToHexString((const uint8_t*)info->hash160, 20);
	//		std::string hash160_in_table = tools::bytesToHexString((const uint8_t*)info->hash160_from_table, 20);
	//		std::string addr;
	//		std::string addr_in_table;
	//		std::string path = getPath(info->path, info->child);
	//		tools::encodeAddressBase58((const uint8_t*)info->hash160, addr);
	//		tools::encodeAddressBase58((const uint8_t*)info->hash160_from_table, addr_in_table);
	//		std::cout << "\n!!!FOUND IN ADDRESS(HASH160) (" << path << ") EQUAL " << num_bytes << " BYTES: " << mnemonic_str << "," << addr << "," << addr_in_table << "," << hash160 << "," << hash160_in_table << " \n";
	//		tools::addInFileTest(num_bytes, path, mnemonic_str, hash160, hash160_in_table, addr, addr_in_table);
	//	}
	//}
	//if (ret->f[1].count_found_bytes != 0)
	//{
	//	for (uint32_t i = 0; i < ret->f[1].count_found_bytes; i++)
	//	{
	//		foundBytesInfoStruct* info = &ret->f[1].found_bytes_info[i];
	//		int num_bytes = 0;
	//		for (int i = 0; i < 20; i++)
	//		{
	//			if (*(uint8_t*)((uint8_t*)info->hash160 + i) != *(uint8_t*)((uint8_t*)info->hash160_from_table + i)) break;
	//			num_bytes++;
	//		}

	//		std::string mnemonic_str = (const char*)info->mnemonic;
	//		std::string hash160 = tools::bytesToHexString((const uint8_t*)info->hash160, 20);
	//		std::string hash160_in_table = tools::bytesToHexString((const uint8_t*)info->hash160_from_table, 20);
	//		std::string addr;
	//		std::string addr_in_table;
	//		std::string path = getPath(info->path, info->child);
	//		tools::encodeAddressBIP49((const uint8_t*)info->hash160, addr);
	//		tools::encodeAddressBIP49((const uint8_t*)info->hash160_from_table, addr_in_table);
	//		std::cout << "\n!!!FOUND IN ADDRESS(HASH160) (" << path << ") EQUAL " << num_bytes << " BYTES: " << mnemonic_str << "," << addr << "," << addr_in_table << "," << hash160 << "," << hash160_in_table << " \n";
	//		tools::addInFileTest(num_bytes, path, mnemonic_str, hash160, hash160_in_table, addr, addr_in_table);
	//	}
	//}
	//if (ret->f[2].count_found_bytes != 0)
	//{
	//	for (uint32_t i = 0; i < ret->f[2].count_found_bytes; i++)
	//	{
	//		foundBytesInfoStruct* info = &ret->f[2].found_bytes_info[i];
	//		int num_bytes = 0;
	//		for (int i = 0; i < 20; i++)
	//		{
	//			if (*(uint8_t*)((uint8_t*)info->hash160 + i) != *(uint8_t*)((uint8_t*)info->hash160_from_table + i)) break;
	//			num_bytes++;
	//		}

	//		std::string mnemonic_str = (const char*)info->mnemonic;
	//		std::string hash160 = tools::bytesToHexString((const uint8_t*)info->hash160, 20);
	//		std::string hash160_in_table = tools::bytesToHexString((const uint8_t*)info->hash160_from_table, 20);
	//		std::string addr;
	//		std::string addr_in_table;
	//		std::string path = getPath(info->path, info->child);
	//		tools::encodeAddressBase32((const uint8_t*)info->hash160, addr);
	//		tools::encodeAddressBase32((const uint8_t*)info->hash160_from_table, addr_in_table);
	//		std::cout << "\n!!!FOUND IN ADDRESS(HASH160) (" << path << ") EQUAL " << num_bytes << " BYTES: " << mnemonic_str << "," << addr << "," << addr_in_table << "," << hash160 << "," << hash160_in_table << " \n";
	//		tools::addInFileTest(num_bytes, path, mnemonic_str, hash160, hash160_in_table, addr, addr_in_table);
	//	}
	//}
	return 0;
}



__constant__ uint64_t dev_EntropyAbsolutePrefix64[1];
uint64_t host_EntropyAbsolutePrefix64[1];

__constant__ int16_t dev_AdaptiveBaseDigitCarryTrigger[MAX_ADAPTIVE_BASE_POSITIONS];
 int16_t host_AdaptiveBaseDigitCarryTrigger[MAX_ADAPTIVE_BASE_POSITIONS];

__constant__ int16_t dev_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION];
 int16_t host_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION];


__constant__ int16_t dev_AdaptiveBaseCurrentBatchInitialDigits[MAX_ADAPTIVE_BASE_POSITIONS];
 int16_t host_AdaptiveBaseCurrentBatchInitialDigits[MAX_ADAPTIVE_BASE_POSITIONS];


__constant__ uint64_t dev_EntropyBatchNext24[1]; //Per-Batch Const
 uint64_t host_EntropyBatchNext24[1]; //Per-Batch Const

 

__host__ /* __and__ */ __device__ void IncrementAdaptiveDigits( int16_t * local_AdaptiveBaseDigitCarryTrigger, int16_t* inDigits, uint64_t howMuch, int16_t* outDigits) {
	uint64_t nYetToAdd = howMuch;
	uint64_t nCarryValue = 0;

	for (int i = MAX_ADAPTIVE_BASE_POSITIONS - 1; i >= 0; i--) {
		if (nYetToAdd == 0 && nCarryValue == 0) {
			outDigits[i] = inDigits[i];
			continue;
		}

		int16_t beforeIncDigit = inDigits[i];
		int nCarryAt = local_AdaptiveBaseDigitCarryTrigger[i];

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


__host__ /* __and__ */ __device__ void GetBipForAdaptiveDigit(
	  int16_t* local_AdaptiveBaseCurrentBatchInitialDigits
	, int16_t* local_AdaptiveBaseDigitCarryTrigger
	, int16_t local_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION]
	, int16_t* inDigits, uint8_t pos, uint64_t* outBip) {
	int16_t curAdapriveDigit = inDigits[pos];
	*outBip = local_AdaptiveBaseDigitSet[pos][curAdapriveDigit];
}
__host__ /* __and__ */ __device__ void GetPaddedBipForAdaptiveDigit(
	int16_t* local_AdaptiveBaseCurrentBatchInitialDigits
	, int16_t* local_AdaptiveBaseDigitCarryTrigger
	, int16_t local_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION], int16_t* inDigits, uint8_t pos, uint64_t* outPadBip) {
	uint64_t curBipForDigit;

	GetBipForAdaptiveDigit(local_AdaptiveBaseCurrentBatchInitialDigits
		, local_AdaptiveBaseDigitCarryTrigger
		, local_AdaptiveBaseDigitSet, inDigits, pos, &curBipForDigit);

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
__host__ /* __and__ */ __device__ void AdaptiveDigitsToEntropy(
	int16_t* local_AdaptiveBaseCurrentBatchInitialDigits
	, int16_t local_AdaptiveBaseDigitCarryTrigger[MAX_ADAPTIVE_BASE_POSITIONS]
	, int16_t local_AdaptiveBaseDigitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION],
	uint64_t * local_EntropyAbsolutePrefix64,
	uint64_t * local_EntropyBatchNext24, 
	 int16_t* inDigits, uint64_t* outEntropy, uint8_t* checkSum) {

	outEntropy[0] = local_EntropyAbsolutePrefix64[0];
	outEntropy[1] = local_EntropyBatchNext24[0];

	uint64_t digitPaddedBip;
	for (int pos = 0; pos < MAX_ADAPTIVE_BASE_POSITIONS; pos++) {
		GetPaddedBipForAdaptiveDigit(local_AdaptiveBaseCurrentBatchInitialDigits
			, local_AdaptiveBaseDigitCarryTrigger
			,local_AdaptiveBaseDigitSet, inDigits, pos, &digitPaddedBip);
		outEntropy[1] |= digitPaddedBip;
	}

	uint64_t lastWord;
	GetBipForAdaptiveDigit(local_AdaptiveBaseCurrentBatchInitialDigits
		, local_AdaptiveBaseDigitCarryTrigger
		, local_AdaptiveBaseDigitSet, inDigits, MAX_ADAPTIVE_BASE_POSITIONS, &lastWord);
	*checkSum = lastWord & 0x000F;
}


__global__ void gl_DictionaryAttack(
	 uint64_t*  nBatchPlannedProc,
	 uint64_t*  nBatchMoreProc,
	const tableStruct* __restrict__ tables_legacy,
	const tableStruct* __restrict__ tables_segwit,
	const tableStruct* __restrict__ tables_native_segwit,
	retStruct* __restrict__ ret
)
{
	__shared__ uint64_t ourBlockProcNormal;
	__shared__ uint64_t ourBlockProcExtra;
	__shared__ uint64_t ourBlockBadChkSum;
	__shared__ uint64_t ourBlockGoodChkSum;
	__shared__ int16_t myDigSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION];


	// Initialize the shared variable
	if (threadIdx.x == 0) {
		ourBlockProcNormal = 0; // Only the first thread initializes it
		ourBlockProcExtra = 0;
		ourBlockBadChkSum = 0;
		ourBlockGoodChkSum = 0;
		
		for (int i = 0; i < MAX_ADAPTIVE_BASE_POSITIONS; i++) {
			for (int j = 0; j < MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION; j++) {
				myDigSet[i][j] = dev_AdaptiveBaseDigitSet[i][j];
			}
		}

	}
	__syncthreads(); // Synchronize to ensure the initialization is complete


	//TODO: Each thread picks is load from Incremental Base!
	int idx = blockIdx.x * blockDim.x + threadIdx.x;

	atomicAdd(&ourBlockProcNormal,1);

	uint8_t reqChecksum=0;
	uint8_t achievedChecksum=1;
	bool bChkSumFailed=true;

	int16_t curDigits[MAX_ADAPTIVE_BASE_POSITIONS] = {0,0,0,0,0,0};
	uint64_t curEntropy[2];
	curEntropy[0] = dev_EntropyAbsolutePrefix64[PTR_AVOIDER];
	curEntropy[1] = dev_EntropyBatchNext24[PTR_AVOIDER];

	int nAlternateCandidateRemaining = MAX_ALTERNATE_CANDIDATE;
	while (nAlternateCandidateRemaining) {

		IncrementAdaptiveDigits(
			 dev_AdaptiveBaseDigitCarryTrigger
			, dev_AdaptiveBaseCurrentBatchInitialDigits
			, idx, curDigits);

		//AdaptiveDigitsToEntropy(curDigits
		//	, dev_AdaptiveBaseDigitCarryTrigger
		//	, dev_AdaptiveBaseDigitSet
		//	, dev_EntropyAbsolutePrefix64
		//	, dev_EntropyBatchNext24
		//	, curDigits, curEntropy, &reqChecksum);

		AdaptiveUpdateMnemonicLow64(&curEntropy[1], myDigSet, curDigits);

		if (idx == 0) {
			PrintNextMnemo(curEntropy, idx, dev_AdaptiveBaseDigitCarryTrigger, curDigits, myDigSet);
		}

		int16_t chkPosIdx = MAX_ADAPTIVE_BASE_POSITIONS - 1;
		int16_t chkWordIdx = curDigits[chkPosIdx];
		uint16_t thisVal = (myDigSet[chkPosIdx][chkWordIdx]);
		uint8_t tmp = (uint8_t)(thisVal & 0x0F);
		reqChecksum = tmp;

		uint8_t entropy_hash[32];
		uint8_t bytes[16];
		uint64_t* entropy = curEntropy;

		bytes[15] = entropy[1] & 0xFF;
		bytes[14] = (entropy[1] >> 8) & 0xFF;
		bytes[13] = (entropy[1] >> 16) & 0xFF;
		bytes[12] = (entropy[1] >> 24) & 0xFF;
		bytes[11] = (entropy[1] >> 32) & 0xFF;
		bytes[10] = (entropy[1] >> 40) & 0xFF;
		bytes[9] = (entropy[1] >> 48) & 0xFF;
		bytes[8] = (entropy[1] >> 56) & 0xFF;

		bytes[7] = entropy[0] & 0xFF;
		bytes[6] = (entropy[0] >> 8) & 0xFF;
		bytes[5] = (entropy[0] >> 16) & 0xFF;
		bytes[4] = (entropy[0] >> 24) & 0xFF;
		bytes[3] = (entropy[0] >> 32) & 0xFF;
		bytes[2] = (entropy[0] >> 40) & 0xFF;
		bytes[1] = (entropy[0] >> 48) & 0xFF;
		bytes[0] = (entropy[0] >> 56) & 0xFF;
		
		sha256((uint32_t*)bytes, 16, (uint32_t*)entropy_hash);
		achievedChecksum = (entropy_hash[0] >> 4) & 0x0F;

		bChkSumFailed = (achievedChecksum != reqChecksum);

		if (bChkSumFailed) {
			atomicAdd(&ourBlockProcExtra,1);
			nAlternateCandidateRemaining--;
		}
		else {
			nAlternateCandidateRemaining = 0; //no need to process more in this thread-batch
		}
	} //do

	__syncthreads(); // Synchronize to and check if have a valid checksum to continue with
	if (bChkSumFailed == false) { //scrutinize
		atomicAdd(&ourBlockGoodChkSum, 1);

		uint8_t mnemonic_phrase[SIZE_MNEMONIC_FRAME] = { 0 };
		uint8_t* mnemonic = mnemonic_phrase;
		uint32_t ipad[256 / 4];
		uint32_t opad[256 / 4];
		uint32_t seed[64 / 4];


		//Work with Current Entropy
		entropy_to_mnemonic_with_offset(curEntropy, mnemonic, 0);
		//entropy_to_mnemonic(entropy, mnemonic);
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
	__syncthreads(); // Synchronize to ensure all data is loaded
	if (threadIdx.x == 0) {
		atomicAdd(nBatchPlannedProc , ourBlockProcNormal);
		atomicAdd(nBatchMoreProc, ourBlockProcExtra);
	}

}//DICTIONARY ATTACK

__host__ /*and */ __device__
void AdaptiveUpdateMnemonicLow64(uint64_t* low64
	, int16_t digitSet[MAX_ADAPTIVE_BASE_POSITIONS][MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION]
	, int16_t curDigits[MAX_ADAPTIVE_BASE_POSITIONS]
)

{
	uint64_t tmpHigh = *low64;
	uint64_t tmpAns = tmpHigh;

	tmpAns = tmpHigh >> 62;
	tmpAns = tmpAns << 2;

	for (int i = 0; i < MAX_ADAPTIVE_BASE_POSITIONS - 1; i++) {
		tmpAns = tmpAns << 11;
		tmpAns & 0xFFFFFFFFFFFFF7F;
		tmpAns |= (uint64_t)(digitSet[i][curDigits[i]]);
	}
	tmpAns = tmpAns << 7;
	tmpAns |= ((uint64_t)(digitSet[MAX_ADAPTIVE_BASE_POSITIONS - 1][curDigits[MAX_ADAPTIVE_BASE_POSITIONS - 1]]) >> 4);

	*low64 = tmpAns;
}


