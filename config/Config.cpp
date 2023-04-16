/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V1.2.0
  * @date		16-April-2023
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
	if (config.num_child_addresses > 0xFFFF)
	{
		std::cerr << "Error num_child. Please enter a number less than 65,535" << std::endl;
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


