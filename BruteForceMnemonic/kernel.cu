﻿/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V1.2.0
  * @date		16-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#include <stdafx.h>

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
//#include <synchapi.h>

#include <Dispatcher.h>
#include <thread>

int main()
{
    
    Generate_Mnemonic();


    while (1) {
        std::this_thread::sleep_for(std::chrono::seconds(100));
    }

    return 0;
}

