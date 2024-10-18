/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V2.0.0
  * @date		28-April-2023
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
#include "EntropyTools.cuh"

int main()
{
    printf("Compiled on Date ** : %s , time: %s \r\n", __DATE__, __TIME__);
    std::this_thread::sleep_for(std::chrono::seconds(1));

    int ret = Generate_Mnemonic();


    if (ret !=0) {
        printf("Some errors ocurre during program execution, see hints in messages above, fix and re-run the program.\r\n");

        std::this_thread::sleep_for(std::chrono::seconds(2));
    }
    else {

        printf("Program Completed Successfully.\r\n");
    }
    return 0;
}

