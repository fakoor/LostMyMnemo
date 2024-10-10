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
#include <vector>
#include <string>
#include "../BruteForceMnemonic/stdafx.h"
namespace tools {

	void generateRandomUint64Buffer(uint64_t* buff, size_t len);
	int pushToMemory(uint8_t* addr_buff, std::vector<std::string>& lines, int max_len);
	int readAllTables(tableStruct* tables, std::string path, std::string prefix, size_t* num_lines);
	void clearFiles(void);
	void saveResult(char* mnemonic, uint8_t* hash160, size_t num_wallets, size_t num_all_childs, size_t num_childs, uint32_t path_generate[10]);
	int checkResult(retStruct* ret);

	void entropyTo12Words(uint64_t entr[2], const int16_t gen_words_indices[12], uint32_t idx, uint8_t* mnemonic_phrase);
	std::string GetMnemoString(int16_t* arr, uint8_t count);

	bool GetSingleWordIndex(std::string singleWord, int16_t* wordIndex);
	std::vector<std::string> SplitWords(std::string str);
	int stringToWordIndices(std::string str, int16_t* gen_words_indices);
}