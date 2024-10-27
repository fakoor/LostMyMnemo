#include "stdafx.h"
#include "cuda_runtime.h"
#include "GPU.h"

__device__
int LookupHash(const uint32_t* hash, uint32_t* hash_from_table, const uint32_t* mnemonic, foundStruct* fnd_ret, uint32_t path, uint32_t child)
{
	int found = 0;
	bool search_state = true;
	uint32_t line_cnt = 1;
	uint32_t point = 0;
	uint32_t point_last = 0;
	uint32_t interval = line_cnt / 3;
	//uint32_t* hash_from_table;
	while (point < line_cnt) {
		point_last = point;
		if (interval == 0) {
			search_state = false;
		}
		if (search_state) {
			point += interval;

			if (point >= line_cnt) {
				point = point_last;
				interval = (line_cnt - point) / 2;
				continue;
			}
			//hash_from_table = &table.table[point * (20 / 4)];
		}
		else {
			//hash_from_table = &table.table[point * (20 / 4)];
			point += 1;
		}

		int cmp = 0;
		if (hash[0] < hash_from_table[0])
		{
			cmp = -1;
		}
		else if (hash[0] > hash_from_table[0])
		{
			cmp = 1;
		}
		else if (hash[1] < hash_from_table[1])
		{
			cmp = -2;
		}
		else if (hash[1] > hash_from_table[1])
		{
			cmp = 2;
		}
		else if (hash[2] < hash_from_table[2])
		{
			cmp = -3;
		}
		else if (hash[2] > hash_from_table[2])
		{
			cmp = 3;
		}
		else if (hash[3] < hash_from_table[3])
		{
			cmp = -4;
		}
		else if (hash[3] > hash_from_table[3])
		{
			cmp = 4;
		}
		else if (hash[4] < hash_from_table[4])
		{
			cmp = -5;
		}
		else if (hash[4] > hash_from_table[4])
		{
			cmp = 5;
		}

		if (search_state) {
			if (cmp < 0) {
				if (interval < 20) {
					search_state = false;
				}
				else
				{
					interval = interval / 2;
				}
				point = point_last;
				continue;
			}
			else if (cmp == 0) {
				search_state = false;
			}
			else {
				continue;
			}
		}

		if (cmp <= 0) {
			if (cmp == 0)
			{
				found = 1;
				uint32_t cnt = fnd_ret->count_found;
				fnd_ret->count_found++;
				if (cnt < MAX_FOUND_ADDRESSES)
				{
					for (int i = 0; i < 5; i++) fnd_ret->found_info[cnt].hash160[i] = hash[i];
					for (int i = 0; i < SIZE32_MNEMONIC_FRAME; i++) fnd_ret->found_info[cnt].mnemonic[i] = mnemonic[i];
					fnd_ret->found_info[cnt].path = path;
					fnd_ret->found_info[cnt].child = child;
				}
			}
			break;
		}

		if (cmp > 1) {
			if (dev_num_bytes_find[0] == 8) {
				if (hash[1] == hash_from_table[1]) found = 2;
			}
#ifdef TEST_MODE
			else if (dev_num_bytes_find[0] == 7) {
				if ((hash[1] & 0x00FFFFFF) == (hash_from_table[1] & 0x00FFFFFF)) found = 2;
			}
			else if (dev_num_bytes_find[0] == 6) {
				if ((hash[1] & 0x0000FFFF) == (hash_from_table[1] & 0x0000FFFF)) found = 2;
			}
			else if (dev_num_bytes_find[0] == 5) {
				if ((hash[1] & 0x000000FF) == (hash_from_table[1] & 0x000000FF)) found = 2;
			}
#endif //TEST_MODE
		}


		if (found == 2) {
			uint32_t cnt = fnd_ret->count_found_bytes;
			fnd_ret->count_found_bytes++;
			if (cnt < MAX_FOUND_ADDRESSES)
			{
				for (int i = 0; i < 5; i++)
				{
					fnd_ret->found_bytes_info[cnt].hash160_from_table[i] = hash_from_table[i];
					fnd_ret->found_bytes_info[cnt].hash160[i] = hash[i];
				}
				for (int i = 0; i < SIZE32_MNEMONIC_FRAME; i++) fnd_ret->found_bytes_info[cnt].mnemonic[i] = mnemonic[i];
				fnd_ret->found_bytes_info[cnt].path = path;
				fnd_ret->found_bytes_info[cnt].child = child;
			}
			break;
		}

	}

	return found;
}
