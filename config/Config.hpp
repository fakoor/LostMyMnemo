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
#include <string>

#include "consts.h"

struct ConfigClass
{
public:
	std::string folder_tables_legacy = "";
	std::string folder_tables_segwit = "";
	std::string folder_tables_native_segwit = "";

	uint64_t number_of_generated_mnemonics = 0;
	uint64_t num_child_addresses = 0;

	std::string path_m0_x = "";
	std::string path_m1_x = "";
	std::string path_m0_0_x = "";
	std::string path_m0_1_x = "";
	std::string path_m44h_0h_0h_0_x = "";
	std::string path_m44h_0h_0h_1_x = "";
	std::string path_m49h_0h_0h_0_x = "";
	std::string path_m49h_0h_0h_1_x = "";
	std::string path_m84h_0h_0h_0_x = "";
	std::string path_m84h_0h_0h_1_x = "";

	std::string account_min_max = "0 5";
	std::string children_min_max = "0 5";

	uint32_t generate_path[MAX_PATH_ARRAY_SIZE] = { 0 };
	uint32_t num_paths = 0;


	int16_t words_indicies_mnemonic[12] = { 0 };
	std::string static_btc_legacy_public_wallet_address = "";

	std::string static_words_starting_point = "";
	std::string dynamic_words[12] = { "" };

	std::string chech_equal_bytes_in_adresses = "";
	std::string save_generation_result_in_file = "";
	std::string use_old_random_method = "";

	uint64_t cuda_grid = 0;
	uint64_t cuda_block = 0;
public:
	ConfigClass()
	{
	}
	~ConfigClass()
	{
	}
};


int parse_config(ConfigClass* config, std::string path);

