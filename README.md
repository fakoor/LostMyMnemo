# Introduction
Lost some words of your 12-word mnemonic but remember some? dont panic, this tool is here to help!

## Config
***"account_min_max": "0 5"*** - The acount range to scan for
***"child_min_max": "0 5"*** - The child range to scan for
***"static_btc_legacy_public_wallet_address": "1EDYbAWpNm1orMCbp8APohXMLguRjTs5LD"*** - The legacy address is diretly entered into configuration file and no need to use another tool for hash conversion 

***"static_words_position_00": "fabric"***  -- In this edition the words from place 00
***"static_words_position_01": "canoe"***   -- down to place 05, name the first six
***"static_words_position_02": "hello"***   -- words are considered to be statically known
***"static_words_position_03": "soon"***    -- for the program execution
***"static_words_position_04": "afraid"***  -- all the dynamic dictionary scan would take place
***"static_words_position_05": "robust"***  -- from pisition 06 to 11 
***"static_words_position_06": "abandon able about acid add again airport always amount scrub"*** -- example configuration for dynamic portion 
***"static_words_position_07": "abandon able about acid add again airport bar base basket"*** -- follows below. eah line can hold up to 261 
***"static_words_position_08": "abandon able about acid add again airport car cash cradle"*** -- words separated by spaces
***"static_words_position_09": "abandon able about acid add again airport dance deposit climb"*** -- for this specific problem
***"static_words_position_10": "abandon able about acid add again airport endless energy push"*** -- you may change it in the source code 
***"static_words_position_11": "can zoo"*** --before compiling

***"static_words_starting_point": "fabric canoe hello soon afraid robust 0 0 0 0 0 0"*** -- This indicates the starting position to scan from. Apparently the first 6 words ought be static and also the last two position must be 0 0 due to the algorithm
   
The following paths are enabled by default
* Default (Standard) Bitcoin Legay Address Scheme 
* Blockchain.Info Address Sheme.  
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
This is an special purpose edition based on  Brute-force Mnemonic Bitcoin on GPU(CUDA) Version 2.0.0 work of houzich and further customization might be required to match your specific usecase.
For the momentm you still need to create legacy address table [using this tool](https://github.com/Houzich/Convert-Addresses-To-Hash160-For-Brute-Force), separately however integration is planned
If you need support regarding the original version, please contact the original author following the fork parent.
