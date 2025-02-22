/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V2.0.0
  * @date		28-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#include "Config.hpp"
#include <tao/config.hpp>

int check_config(ConfigClass& config)
{
	int num_paths = 0;
	if (config.path_m0_x == "yes") {
		num_paths++;
		config.generate_path[0] = 1;
	}
	else if (config.path_m0_x != "no") {
		std::cerr << "Error parse path_m0_x. Please write \"yes\" or \"no\"" << std::endl;
		throw std::logic_error("error parse config.cfg file");
	}
	if (config.path_m1_x == "yes") {
		num_paths++;
		config.generate_path[1] = 1;
	}
	else if (config.path_m1_x != "no") {
		std::cerr << "Error parse path_m1_x. Please write \"yes\" or \"no\"" << std::endl;
		throw std::logic_error("error parse config.cfg file");
	}
	if (config.path_m0_0_x == "yes") {
		num_paths++;
		config.generate_path[2] = 1;
	}
	else if (config.path_m0_0_x != "no") {
		std::cerr << "Error parse path_m0_0_x. Please write \"yes\" or \"no\"" << std::endl;
		throw std::logic_error("error parse config.cfg file");
	}
	if (config.path_m0_1_x == "yes") {
		num_paths++;
		config.generate_path[3] = 1;
	}
	else if (config.path_m0_1_x != "no") {
		std::cerr << "Error parse path_m0_1_x. Please write \"yes\" or \"no\"" << std::endl;
		throw std::logic_error("error parse config.cfg file");
	}
	if (config.path_m44h_0h_0h_0_x == "yes") {
		num_paths++;
		config.generate_path[4] = 1;
	}
	else if (config.path_m44h_0h_0h_0_x != "no") {
		std::cerr << "Error parse path_m44h_0h_0h_0_x. Please write \"yes\" or \"no\"" << std::endl;
		throw std::logic_error("error parse config.cfg file");
	}
	if (config.path_m44h_0h_0h_1_x == "yes") {
		num_paths++;
		config.generate_path[5] = 1;
	}
	else if (config.path_m44h_0h_0h_1_x != "no") {
		std::cerr << "Error parse path_m44h_0h_0h_1_x. Please write \"yes\" or \"no\"" << std::endl;
		throw std::logic_error("error parse config.cfg file");
	}
	if (config.path_m49h_0h_0h_0_x == "yes") {
		num_paths++;
		config.generate_path[6] = 1;
	}
	else if (config.path_m49h_0h_0h_0_x != "no") {
		std::cerr << "Error parse path_m49h_0h_0h_0_x. Please write \"yes\" or \"no\"" << std::endl;
		throw std::logic_error("error parse config.cfg file");
	}
	if (config.path_m49h_0h_0h_1_x == "yes") {
		num_paths++;
		config.generate_path[7] = 1;
	}
	else if (config.path_m49h_0h_0h_1_x != "no") {
		std::cerr << "Error parse path_m49h_0h_0h_1_x. Please write \"yes\" or \"no\"" << std::endl;
		throw std::logic_error("error parse config.cfg file");
	}
	if (config.path_m84h_0h_0h_0_x == "yes") {
		num_paths++;
		config.generate_path[8] = 1;
	}
	else if (config.path_m84h_0h_0h_0_x != "no") {
		std::cerr << "Error parse path_m84h_0h_0h_0_x. Please write \"yes\" or \"no\"" << std::endl;
		throw std::logic_error("error parse config.cfg file");
	}
	if (config.path_m84h_0h_0h_1_x == "yes") {
		num_paths++;
		config.generate_path[9] = 1;
	}
	else if (config.path_m84h_0h_0h_1_x != "no") {
		std::cerr << "Error parse path_m84h_0h_0h_1_x. Please write \"yes\" or \"no\"" << std::endl;
		throw std::logic_error("error parse config.cfg file");
	}

	if (config.chech_equal_bytes_in_adresses == "yes") {
	}
	else if (config.chech_equal_bytes_in_adresses != "no") {
		std::cerr << "Error parse chech_equal_bytes_in_adresses. Please write \"yes\" or \"no\"" << std::endl;
		throw std::logic_error("error parse config.cfg file");
	}
	if (config.save_generation_result_in_file == "yes") {
	}
	else if (config.save_generation_result_in_file != "no") {
		std::cerr << "Error parse save_generation_result_in_file. Please write \"yes\" or \"no\"" << std::endl;
		throw std::logic_error("error parse config.cfg file");
	}
	if (config.use_old_random_method == "yes") {
	}
	else if (config.use_old_random_method != "no") {
		std::cerr << "Error parse use_old_random_method. Please write \"yes\" or \"no\"" << std::endl;
		throw std::logic_error("error parse config.cfg file");
	}


	if (config.num_child_addresses > 0xFFFF)
	{
		std::cerr << "Error num_child. Please enter a number less than 65,535" << std::endl;
		throw std::logic_error("error parse config.cfg file");
	}
	if (config.number_of_generated_mnemonics > 18000000000000000000)
	{
		std::cerr << "Error number_of_generated_mnemonics. Please enter a number less than 18,000,000,000,000,000,000" << std::endl;
		throw std::logic_error("error parse config.cfg file");
	}

	config.num_paths = num_paths;

	return 0;
}



int parse_config(ConfigClass* config, std::string path)
{
	try {
		const tao::config::value v = tao::config::from_file(path);

		config->folder_tables_legacy = access(v, tao::config::key("folder_tables_legacy")).get_string();
		config->folder_tables_segwit = access(v, tao::config::key("folder_tables_segwit")).get_string();
		config->folder_tables_native_segwit = access(v, tao::config::key("folder_tables_native_segwit")).get_string();

		
		config->number_of_generated_mnemonics = access(v, tao::config::key("number_of_generated_mnemonics")).get_unsigned();
		config->num_child_addresses = access(v, tao::config::key("num_child_addresses")).get_unsigned();

		config->path_m0_x = access(v, tao::config::key("path_m0_x")).get_string();
		config->path_m1_x = access(v, tao::config::key("path_m1_x")).get_string();
		config->path_m0_0_x = access(v, tao::config::key("path_m0_0_x")).get_string();
		config->path_m0_1_x = access(v, tao::config::key("path_m0_1_x")).get_string();
		config->path_m44h_0h_0h_0_x = access(v, tao::config::key("path_m44h_0h_0h_0_x")).get_string();
		config->path_m44h_0h_0h_1_x = access(v, tao::config::key("path_m44h_0h_0h_1_x")).get_string();
		config->path_m49h_0h_0h_0_x = access(v, tao::config::key("path_m49h_0h_0h_0_x")).get_string();
		config->path_m49h_0h_0h_1_x = access(v, tao::config::key("path_m49h_0h_0h_1_x")).get_string();
		config->path_m84h_0h_0h_0_x = access(v, tao::config::key("path_m84h_0h_0h_0_x")).get_string();
		config->path_m84h_0h_0h_1_x = access(v, tao::config::key("path_m84h_0h_0h_1_x")).get_string();

		config->account_min_max = access(v, tao::config::key("account_min_max")).get_string();
		config->children_min_max = access(v, tao::config::key("children_min_max")).get_string();

		config->static_btc_legacy_public_wallet_address = access(v, tao::config::key("static_btc_legacy_public_wallet_address")).get_string();

		config->static_words_starting_point = access(v, tao::config::key("static_words_starting_point")).get_string();


		config->dynamic_words[0] = access(v, tao::config::key("static_words_position_00")).get_string();
		config->dynamic_words[1] = access(v, tao::config::key("static_words_position_01")).get_string();
		config->dynamic_words[2] = access(v, tao::config::key("static_words_position_02")).get_string();
		config->dynamic_words[3] = access(v, tao::config::key("static_words_position_03")).get_string();
		config->dynamic_words[4] = access(v, tao::config::key("static_words_position_04")).get_string();
		config->dynamic_words[5] = access(v, tao::config::key("static_words_position_05")).get_string();
		config->dynamic_words[6] = access(v, tao::config::key("static_words_position_06")).get_string();
		config->dynamic_words[7] = access(v, tao::config::key("static_words_position_07")).get_string();
		config->dynamic_words[8] = access(v, tao::config::key("static_words_position_08")).get_string();
		config->dynamic_words[9] = access(v, tao::config::key("static_words_position_09")).get_string();
		config->dynamic_words[10]= access(v, tao::config::key("static_words_position_10")).get_string();
		config->dynamic_words[11]= access(v, tao::config::key("static_words_position_11")).get_string();


		config->chech_equal_bytes_in_adresses = access(v, tao::config::key("chech_equal_bytes_in_adresses")).get_string();
		config->save_generation_result_in_file = access(v, tao::config::key("save_generation_result_in_file")).get_string();
		config->use_old_random_method = access(v, tao::config::key("use_old_random_method")).get_string();
		
		config->cuda_grid = access(v, tao::config::key("cuda_grid")).get_unsigned();
		config->cuda_block = access(v, tao::config::key("cuda_block")).get_unsigned();

		return check_config(*config);
	}
	catch (std::runtime_error& e) {
		std::cerr << "Error parse config.cfg file " << path << " : " << e.what() << '\n';
		throw std::logic_error("error parse config.cfg file");
	}
	catch (...) {
		std::cerr << "Error parse config.cfg file" << std::endl;
		throw std::logic_error("error parse config.cfg file");
	}
	return 0;
}


