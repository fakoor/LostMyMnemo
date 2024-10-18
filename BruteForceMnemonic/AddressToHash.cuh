#include <iostream>
#include "../Tools/utils.h"

inline int ValidateAndConvertAddress(std::string& addr_str, std::string& hash160hex) {
	int ret = 0;
	if (
		(((addr_str.size() == 33) || (addr_str.size() == 34))
			&& (addr_str[0] == '1'))
		)
	{
		ret = tools::decodeAddressBase58(addr_str, hash160hex);


		if (ret) {
			ret = -1;
		}
	}

	return ret;
}
