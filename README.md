# Introduction
Lost some words of your 12-word mnemonic but remember some? dont panic, this tool is here to help!

## Config
* ***"path_m44h_0h_0h_0_x": "yes"*** - The only path focoused in this edition which is defaulted to yes and other paths turned off

### Other default settings
* ***"chech_equal_bytes_in_adresses": "yes"*** 
* ***"save_generation_result_in_file": "no"***
* ***"cuda_grid": 1024*** 
* ***"cuda_block": 256*** 

### Some other changes
* We also here focous on the first child / first account.
* The first CUDA capable device is automatically selected.
* Support for detecting specification of other HW (equal or newer than pascal such as ampere) is added.
* The method to scan addresses is change to dictionary scan so that you can specify individual lists of purified words for last six positions

  
### Notes
This is an special purpose edition based on  Brute-force Mnemonic Bitcoin on GPU(CUDA) Version 2.0.0 work of houzich and further customization might be required to match your specific usecase
The main focous is on Bitcoin Legacy(BIP32, BIP44) addresses (that start with 1)
For the momentm you still need to create legacy address table [using this tool](https://github.com/Houzich/Convert-Addresses-To-Hash160-For-Brute-Force), separately however integration is planned
If you need support regarding the original version, please contact the original author following the fork parent.
