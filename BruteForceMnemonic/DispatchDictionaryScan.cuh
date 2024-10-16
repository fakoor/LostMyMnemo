#pragma once

#ifndef __DICTIONARY_SCAN_H__
#define __DICTIONARY_SCAN_H__

#include "../config/Config.hpp"

#include "KernelStride.hpp"
#include "EntropyTools.cuh"


bool SyncTrunkVariables();
bool  DispatchDictionaryScan(ConfigClass* Config, data_class* Data, stride_class* Stride);

#endif /*__DICTIONARY_SCAN_H__*/