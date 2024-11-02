#include <stdafx.h>

#include <iostream>
#include <thread>

#include "cuda_runtime.h"

#include "DispatchDictionaryScan.cuh"
#include "DictionaryScanner.cuh"

#include "consts.h"
#include "AdaptiveBase.h"


#include "../Tools/tools.h"
#include "../Tools/utils.h"
#include "Helper.h"

#include <windows.h> //some beeping fancey
#include <mmsystem.h>

#define _USE_MATH_DEFINES
#include <cmath>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

#include "EntropyTools.cuh"









//// A simple 1-second sine wave sound (440 Hz)
//const unsigned char soundDataSimple[] = {
//	0x52, 0x49, 0x46, 0x46, 0x24, 0x08, 0x00, 0x00, // RIFF header
//	0x57, 0x41, 0x56, 0x45, 0x66, 0x6d, 0x74, 0x20, // WAVE header
//	0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, // Format chunk
//	0x44, 0xac, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00, // 44.1kHz, 16-bit
//	0x64, 0x61, 0x74, 0x61, 0x00, 0x08, 0x00, 0x00, // Data chunk header
//	// Actual audio data (440 Hz sine wave)
//	0x00, 0x00, 0x1d, 0x00, 0x38, 0x00, 0x4f, 0x00,
//	0x5e, 0x00, 0x64, 0x00, 0x68, 0x00, 0x6a, 0x00,
//	0x68, 0x00, 0x64, 0x00, 0x5e, 0x00, 0x4f, 0x00,
//	0x38, 0x00, 0x1d, 0x00, 0x00, 0x00, 0xe3, 0xff,
//	0xc8, 0xff, 0xa0, 0xff, 0x8f, 0xff, 0x7c, 0xff,
//	0x6f, 0xff, 0x68, 0xff, 0x68, 0xff, 0x70, 0xff,
//	0x7c, 0xff, 0x8f, 0xff, 0xa0, 0xff, 0xc8, 0xff,
//	0xe3, 0xff, 0x00, 0x00, 0x1d, 0x00, 0x38, 0x00,
//};

//void playWavFromMemory(const unsigned char* data, size_t size) {
//	HWAVEOUT hWaveOut;
//	WAVEFORMATEX wfx;
//
//	// Set up the WAVEFORMATEX structure
//	wfx.wFormatTag = WAVE_FORMAT_PCM;
//	wfx.nChannels = 1; // Mono
//	wfx.nSamplesPerSec = 44100; // Sample rate
//	wfx.wBitsPerSample = 16; // Bits per sample
//	wfx.nBlockAlign = (wfx.nChannels * wfx.wBitsPerSample) / 8;
//	wfx.nAvgBytesPerSec = wfx.nSamplesPerSec * wfx.nBlockAlign;
//
//	// Open the wave output device
//	waveOutOpen(&hWaveOut, WAVE_MAPPER, &wfx, 0, 0, CALLBACK_NULL);
//
//	// Prepare the wave header
//	WAVEHDR whdr;
//	whdr.lpData = (LPSTR)data; // Pointer to the data
//	whdr.dwBufferLength = (DWORD)size; // Size of the data
//	whdr.dwFlags = 0;
//
//	// Prepare and write the header
//	waveOutPrepareHeader(hWaveOut, &whdr, sizeof(WAVEHDR));
//	waveOutWrite(hWaveOut, &whdr, sizeof(WAVEHDR));
//
//	// Wait for the sound to finish playing
//	while (!(whdr.dwFlags & WHDR_DONE)) {
//		Sleep(100);
//	}
//
//	// Clean up
//	waveOutUnprepareHeader(hWaveOut, &whdr, sizeof(WAVEHDR));
//	waveOutClose(hWaveOut);
//}



const int SAMPLE_RATE = 44100;
const int DURATION = 1; // 1 second
const int FREQUENCY = 440; // Frequency of the sine wave (A4 note)

const int NUM_SAMPLES = SAMPLE_RATE * DURATION;
const int BYTE_RATE = SAMPLE_RATE * 2; // 16 bits = 2 bytes per sample

// Generating stereo sine wave data
unsigned char soundDataSine[NUM_SAMPLES * 4]; // 2 channels (stereo), 2 bytes per sample


void generateSineWave() {
	for (int i = 0; i < NUM_SAMPLES; i++) {
		// Calculate the sample value
		int16_t sample = static_cast<int16_t>(32767 * sin((2.0 * M_PI * FREQUENCY * i) / SAMPLE_RATE));

		// Fill left channel
		soundDataSine[i * 4] = (sample & 0xFF);          // Low byte
		soundDataSine[i * 4 + 1] = (sample >> 8) & 0xFF; // High byte

		// Fill right channel (same value for stereo effect)
		soundDataSine[i * 4 + 2] = (sample & 0xFF);      // Low byte
		soundDataSine[i * 4 + 3] = (sample >> 8) & 0xFF; // High byte
	}
}

void playSineWavFromMemory(const unsigned char* data, size_t size) {
	HWAVEOUT hWaveOut;
	WAVEFORMATEX wfx;

	// Set up the WAVEFORMATEX structure
	wfx.wFormatTag = WAVE_FORMAT_PCM;
	wfx.nChannels = 2; // Stereo
	wfx.nSamplesPerSec = SAMPLE_RATE; // Sample rate
	wfx.wBitsPerSample = 16; // Bits per sample
	wfx.nBlockAlign = (wfx.nChannels * wfx.wBitsPerSample) / 8;
	wfx.nAvgBytesPerSec = wfx.nSamplesPerSec * wfx.nBlockAlign;

	// Open the wave output device
	waveOutOpen(&hWaveOut, WAVE_MAPPER, &wfx, 0, 0, CALLBACK_NULL);

	// Prepare the wave header
	WAVEHDR whdr;
	whdr.lpData = (LPSTR)data; // Pointer to the data
	whdr.dwBufferLength = (DWORD)size; // Size of the data
	whdr.dwFlags = 0;

	// Prepare and write the header
	waveOutPrepareHeader(hWaveOut, &whdr, sizeof(WAVEHDR));
	waveOutWrite(hWaveOut, &whdr, sizeof(WAVEHDR));

	// Wait for the sound to finish playing
	while (!(whdr.dwFlags & WHDR_DONE)) {
		Sleep(100);
	}

	// Clean up
	waveOutUnprepareHeader(hWaveOut, &whdr, sizeof(WAVEHDR));
	waveOutClose(hWaveOut);
}


void playAlert() {
	//printf("Playing sound...\r\n");
	//Beep(2000, 1000);

	generateSineWave(); // Fill soundData with sine wave
	playSineWavFromMemory(soundDataSine, sizeof(soundDataSine));

	//playWavFromMemory(soundDataSimple, sizeof(soundDataSimple));
	//int frequencies[] = { 800, 1000, 1200, 1000 }; // Frequencies in Hz
	//int durations[] = { 300, 300, 300, 400 }; // Durations in milliseconds

	//for (int i = 0; i < sizeof(frequencies) / sizeof(frequencies[0]); ++i) {
	//	Beep(frequencies[i], durations[i]);
	//	Sleep(50);
	//}
}

bool  DispatchDictionaryScan(ConfigClass* Config, data_class* Data, stride_class* Stride) {

	if (InitalSync(Config) == false)
		return false;



	uint64_t nProblemPower =
		(uint64_t)host_AdaptiveBaseDigitCarryTrigger[0]
		* host_AdaptiveBaseDigitCarryTrigger[1]
		* host_AdaptiveBaseDigitCarryTrigger[2]
		* host_AdaptiveBaseDigitCarryTrigger[3]
		* host_AdaptiveBaseDigitCarryTrigger[4]
		* host_AdaptiveBaseDigitCarryTrigger[5];


	uint64_t nSolverThreads = Config->cuda_block * Config->cuda_grid;
	uint64_t nThreadPower = host_AdaptiveBaseDigitCarryTrigger[4] * host_AdaptiveBaseDigitCarryTrigger[5];
	uint64_t nIterationPower = nSolverThreads * nThreadPower;
	uint64_t nIterationsNeeded = nProblemPower / nIterationPower;
	uint64_t nLastIterationRemainder = nProblemPower - nIterationsNeeded * nIterationPower;
	uint64_t nLastIterationMaxBlockIdx =  nLastIterationRemainder / nThreadPower / Config->cuda_block;
	if (nLastIterationRemainder > 0) {
		nIterationsNeeded++;
	}
	host_nManagedIterationsMaxCurrent[0] = nIterationsNeeded;
	host_nManagedIterationsMaxCurrent[1] = 0ui64;

	for (int i = 0; i < MAX_BLOCKS; i++) {
		nManagedIterationsPerBlock[i] = 0;
	}

	printf("Starting Dictionary Scan...\r\n");
	printf("Looking for Account Range %u to %u.\r\n",host_accntMinMax[0],host_accntMinMax[1]);
	printf("Looking for Children Address from %u to %u.\r\n ", host_childrenMinMax[0], host_childrenMinMax[1]);

	std::cout << " Going to dispatch " << nProblemPower << " total COMBOs" <<std::endl
		<< " {via " << nIterationsNeeded
		<<((nLastIterationRemainder > 0) ? "" : "Perfet")<< " iterations}" << " [Last one with:" <<
		nLastIterationRemainder<<" COMBOs]" <<std::endl
		<<" (each able to process " << nIterationPower << " instances)="<< Config->cuda_grid <<"x" << Config->cuda_block<< "x" << host_AdaptiveBaseDigitCarryTrigger[5] << std::endl;






	
	size_t copySize;
	cudaError cudaResult;

	*Data->host.nProcessedInstances = 0;
	*Data->host.nProcessingIteration = 0;

#if 0

	dev_retEntropy[0] = 0ui64;
	dev_retEntropy[1] = 0ui64;

	dev_retAccntPath[0] = 0;
	dev_retAccntPath[1] = 0;


#else
	host_retEntropy[0] = 0ui64;
	host_retEntropy[1] = 0ui64;

	host_retAccntPath[0] = 0;
	host_retAccntPath[1] = 0;

	if (cudaSuccess != cudaMemcpyToSymbol(dev_retEntropy, host_retEntropy, 16)) {
		std::cout << "Error-Line--" << __LINE__ << std::endl;
	}

	if (cudaSuccess != cudaMemcpyToSymbol(dev_retAccntPath, host_retAccntPath, 2)) {
		std::cout << "Error-Line--" << __LINE__ << std::endl;
	}

#endif
	//host_accntMinMax[0] = 0;
	//host_accntMinMax[1] = 5;
	//printf("Size[0]=%llu , Size_tot=%llu\r\n", sizeof(host_accntMinMax[0]), sizeof(host_accntMinMax));
	if (cudaSuccess != cudaMemcpyToSymbol(dev_accntMinMax, host_accntMinMax, sizeof (host_accntMinMax))) {
		std::cout << "Error-Line--" << __LINE__ << std::endl;
	}

	if (cudaSuccess != cudaMemcpyToSymbol(dev_childrenMinMax, host_childrenMinMax, sizeof(host_childrenMinMax))) {
		std::cout << "Error-Line--" << __LINE__ << std::endl;
	}

	if (cudaSuccess != cudaMemcpyToSymbol(dev_nManagedIterationsMaxCurrent, host_nManagedIterationsMaxCurrent, sizeof(host_nManagedIterationsMaxCurrent))) {
		std::cout << "Error-Line--" << __LINE__ << std::endl;
	}


	if (cudaSuccess != cudaMemcpy(Data->dev.nProcessedInstances, Data->host.nProcessedInstances, 8, cudaMemcpyHostToDevice)) {
		std::cout << "Error-Line--" << __LINE__ << std::endl;
	}
	const int nMnemoShowLen = MAX_ADAPTIVE_BASE_POSITIONS * 9 + MAX_ADAPTIVE_BASE_POSITIONS;
	char strMnemoShow[nMnemoShowLen] = {0};
	int16_t digitShow[MAX_ADAPTIVE_BASE_POSITIONS];
	uint64_t nUniversalProcessed = 0;

		//Set Master Iteration
		if (cudaSuccess != cudaMemcpy(Data->dev.nProcessingIteration, Data->host.nProcessingIteration, 8, cudaMemcpyHostToDevice)) {
			std::cout << "Error-Line--" << __LINE__ << std::endl;
		}

		//Zero Previous Count
		*Data->host.nProcessedInstances = 0;
		if (cudaSuccess != cudaMemcpy( Data->dev.nProcessedInstances, Data->host.nProcessedInstances, 8, cudaMemcpyHostToDevice)) {
			std::cout << "Error-Line--" << __LINE__ << std::endl;
		}

		tools::start_time();
		if (Stride->startDictionaryAttack(Config->cuda_grid, Config->cuda_block) != 0) {
			std::cerr << "Error START!!" << std::endl;
			return false;
		}

		do
		{

		printf("Iteration: %llu started.\r\n", *Data->host.nProcessingIteration + 1);
		int16_t nDummyRet;

		IncrementAdaptiveDigits(host_AdaptiveBaseDigitCarryTrigger, host_AdaptiveBaseCurrentBatchInitialDigits
			, nUniversalProcessed, digitShow, &nDummyRet);

		ShowAdaptiveStr(host_AdaptiveBaseDigitSet,digitShow, arrBipWords,arrBipWordsLengths,strMnemoShow);
		printf("<FROM> * * * * * *\t %s </FROM> (%llu)\r\n", strMnemoShow, nUniversalProcessed+1);


#if 0
		{ //view iteration progress
			uint64_t nVisitCount = 0;
			uint64_t nBlocksToVisit = (nIterationsNeeded == *Data->host.nProcessingIteration + 1) ? nLastIterationMaxBlockIdx + 1 : MAX_BLOCKS;
			printf("\rWaiting for:%llu blocks to complete.", nBlocksToVisit);
			while (nVisitCount < nBlocksToVisit) {
				nVisitCount = 0;
				for (int gb = 0; gb < nBlocksToVisit; gb++) {
					printf("Checking completion....");

					if (nManagedIterationsPerBlock[gb] < *Data->host.nProcessingIteration) {
						printf("Not satisified.\r\n");
						continue;
					}

					nVisitCount++;

					double fPercent = 100.0 * nVisitCount / nBlocksToVisit;
					printf("\r Iteration Progress: %f", fPercent);
				}

				if (nVisitCount < nBlocksToVisit) {
					std:Sleep(1000);
				}
			}//while
		}

#endif
		float delay;
#if 1

		if (Stride->endDictionaryAttack() != 0) {
			std::cerr << "Error END!!" << std::endl;
			return false;
		}
#endif
		tools::stop_time_and_calc_sec(&delay);

#if 0
		if (cudaSuccess != cudaMemcpy(Data->host.nProcessedInstances, Data->dev.nProcessedInstances, 8, cudaMemcpyDeviceToHost)) {
			std::cout << "Error-Line--" << __LINE__ << std::endl;
		}
		
		nUniversalProcessed += *Data->host.nProcessedInstances;
		//printf("\t\t\t.\r\n\t\t\t.\r\n\t\t\t.\r\n");
		//int16_t nDummyRet;
		IncrementAdaptiveDigits(host_AdaptiveBaseDigitCarryTrigger, host_AdaptiveBaseCurrentBatchInitialDigits
			, nUniversalProcessed-1, digitShow, &nDummyRet);

		ShowAdaptiveStr(host_AdaptiveBaseDigitSet, digitShow, arrBipWords, arrBipWordsLengths, strMnemoShow);

		printf("<UPTO> * * * * * * \t %s </UPTO> (%llu)\r\n", strMnemoShow, nUniversalProcessed);

		printf("Checking results of %llu checkups.\r\n", *Data->host.nProcessedInstances);

		uint64_t nSkippedLast = (nIterationPower - *Data->host.nProcessedInstances);

#endif



		* Data->host.nProcessedInstances = nIterationPower;
		std::cout << "Iteration " << *Data->host.nProcessingIteration + 1
			<< " completed we have processed  " << *Data->host.nProcessedInstances << " COMBOs  at " << tools::formatPrefix((double)*Data->host.nProcessedInstances / delay) << " COMBO/Sec" 
			//<<" (Unused:"<<nSkippedLast<<") "
			<< std::endl;
			
#if 1
		if (cudaSuccess != cudaMemcpyFromSymbol (host_retEntropy, dev_retEntropy, 16)) {
			std::cout << "Error-Line--" << __LINE__ << std::endl;
		}

		if (cudaSuccess != cudaMemcpyFromSymbol(host_retAccntPath, dev_retAccntPath, 2)) {
			std::cout << "Error-Line--" << __LINE__ << std::endl;
		}
#endif
		if (host_retEntropy[0] != 0 || host_retEntropy[1] != 0) {
			uint8_t disp[121];
			GetAllWords(host_retEntropy, disp);
			printf("|----------------------------------------------------------------------------------------\r\n");
			// Get the handle to the console
			HANDLE hConsole = GetStdHandle(STD_OUTPUT_HANDLE);

			// Set the text color to green (Green text on black background)
			SetConsoleTextAttribute(hConsole, FOREGROUND_GREEN | FOREGROUND_INTENSITY);
			printf("|    %s \t \r\n", disp);
			// Reset the text color to default (usually white on black)
			SetConsoleTextAttribute(hConsole, FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE);
			printf("|\t---------------------------------------------------------- \t\t\r\n");
			printf("|\t\t Account= %u \t Child= %u  \t\t\t\t\t\r\n", host_retAccntPath[0], host_retAccntPath[1]);
			printf("|\t---------------------------------------------------------- \t\t\r\n");
			printf("|\t\t Entropy : 0x%llX%llX\r\n", host_retEntropy[0], host_retEntropy[1]);
			printf("|----------------------------------------------------------------------------------------\r\n");
			playAlert();
			break;

		}
		else {
			printf("Total Batch Completed.\r\n");
		}

		++*Data->host.nProcessingIteration;
		break;
	} while (*Data->host.nProcessingIteration < nIterationsNeeded);//trunk

	return true;
}


bool InitalSync(ConfigClass* Config)
{
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] = 0;
	host_EntropyNextPrefix2[PTR_AVOIDER] = 0;

	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[0]) << 53;
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[1]) << 42;
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[2]) << 31;
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[3]) << 20;
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[4]) << 9;

	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[5]) >> 2;
	host_EntropyNextPrefix2[PTR_AVOIDER] = (uint64_t)(Config->words_indicies_mnemonic[5]) << 62; //two bits from main 6 words


	size_t copySize;
	cudaError_t cudaResult;


	copySize = sizeof(uint8_t) * 20;
	cudaResult = cudaMemcpyToSymbol(dev_uniqueTargetAddressBytes, host_uniqueTargetAddressBytes, copySize, 0, cudaMemcpyHostToDevice);
	if (cudaResult != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol copying " << copySize << " bytes to dev_uniqueTargetAddressBytes failed!: " << cudaResult << std::endl;
		return false;
	}


	copySize = sizeof(uint64_t);
	cudaResult = cudaMemcpyToSymbol(dev_EntropyAbsolutePrefix64, host_EntropyAbsolutePrefix64, copySize, 0, cudaMemcpyHostToDevice);
	if (cudaResult != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol copying " << copySize << " bytes to dev_EntropyAbsolutePrefix64 failed!: " << cudaResult << std::endl;
		return false;
	}

	copySize = sizeof(uint64_t);
	cudaResult = cudaMemcpyToSymbol(dev_EntropyNextPrefix2, host_EntropyNextPrefix2, copySize, 0, cudaMemcpyHostToDevice);
	if (cudaResult != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol copying " << copySize << " bytes to dev_EntropyBatchNext24 failed!: " << cudaResult << std::endl;
		return false;
	}


	copySize = sizeof(int16_t) * MAX_ADAPTIVE_BASE_POSITIONS * MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION;
	cudaResult = cudaMemcpyToSymbol(dev_AdaptiveBaseDigitSet, host_AdaptiveBaseDigitSet, copySize, 0, cudaMemcpyHostToDevice);
	if (cudaResult != cudaSuccess)
	{
		std::cerr << "dev_AdaptiveBaseCurrentBatchInitialDigits copying " << copySize << " bytes to dev_AdaptiveBaseDigitSet failed!: " << cudaResult << std::endl;
		return false;
	}

	copySize = sizeof(host_AdaptiveBaseDigitCarryTrigger[0]) * MAX_ADAPTIVE_BASE_POSITIONS;
	cudaResult = cudaMemcpyToSymbol(dev_AdaptiveBaseDigitCarryTrigger, host_AdaptiveBaseDigitCarryTrigger, copySize, 0, cudaMemcpyHostToDevice);
	if (cudaResult != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol copying " << copySize << " bytes to dev_AdaptiveBaseDigitCarryTrigger failed!: " << cudaResult << std::endl;
		return false;
	}

	copySize = sizeof(int16_t) * MAX_ADAPTIVE_BASE_POSITIONS;
	cudaResult = cudaMemcpyToSymbol(dev_AdaptiveBaseCurrentBatchInitialDigits, host_AdaptiveBaseCurrentBatchInitialDigits, copySize, 0, cudaMemcpyHostToDevice);
	if (cudaResult != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol copying " << copySize << " bytes to dev_AdaptiveBaseCurrentBatchInitialDigits failed!: " << cudaResult << std::endl;
		return false;
	}

	return true;
}
