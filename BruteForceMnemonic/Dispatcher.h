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
#ifndef __DISPATCHER_H__
#define __DISPATCHER_H__

#include "consts.h"
#include "../config/Config.hpp"

int Generate_Mnemonic(void);

bool ApplyConfig(ConfigClass& Config);


#endif /* __DISPATCHER_H__ */

