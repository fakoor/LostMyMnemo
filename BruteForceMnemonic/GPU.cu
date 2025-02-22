﻿/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V2.0.0
  * @date		28-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#include <stdafx.h>
#include <stdio.h>


#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <GPU.h>
#include <cuda.h>

#include "EntropyTools.cuh"
#include "MemConfig.cuh"
#include "Bip39Tools.cuh"
#include "BuildConfig.cuh"



 /* Shift-right (used in SHA-256, SHA-384, and SHA-512): */
#define SHR(b,x) 		((x) >> (b))
/* 32-bit Rotate-right (used in SHA-256): */
#define ROTR32(b,x)	(((x) >> (b)) | ((x) << (32 - (b))))
 /* 64-bit Rotate-right (used in SHA-384 and SHA-512): */
#define ROTR64(b,x)	(((x) >> (b)) | ((x) << (64 - (b))))
 /* Four of six logical functions used in SHA-384 and SHA-512: */
#define REVERSE32(w,x)	{ \
	uint32_t tmp = (w); \
	tmp = (tmp >> 16) | (tmp << 16); \
	(x) = ((tmp & 0xff00ff00UL) >> 8) | ((tmp & 0x00ff00ffUL) << 8); \
}
#define REVERSE64(w,x)	{ \
	uint64_t tmp = (w); \
	tmp = (tmp >> 32) | (tmp << 32); \
	tmp = ((tmp & 0xff00ff00ff00ff00UL) >> 8) | \
	      ((tmp & 0x00ff00ff00ff00ffUL) << 8); \
	(x) = ((tmp & 0xffff0000ffff0000UL) >> 16) | \
	      ((tmp & 0x0000ffff0000ffffUL) << 16); \
}
/* Four of six logical functions used in SHA-384 and SHA-512: */
#define SHA512_S0(x)	(ROTR64(28, (x)) ^ ROTR64(34, (x)) ^ ROTR64(39, (x)))
#define SHA512_S1(x)	(ROTR64(14, (x)) ^ ROTR64(18, (x)) ^ ROTR64(41, (x)))
#define little_s0(x)	(ROTR64( 1, (x)) ^ ROTR64( 8, (x)) ^ SHR( 7,   (x)))
#define little_s1(x)	(ROTR64(19, (x)) ^ ROTR64(61, (x)) ^ SHR( 6,   (x)))


#define highBit(i) (0x0000000000000001ULL << (8*(i) + 7))
#define fBytes(i)  (0xFFFFFFFFFFFFFFFFULL >> (8 * (8-(i))))
#define SHA256C00 0x428a2f98u
#define SHA256C01 0x71374491u
#define SHA256C02 0xb5c0fbcfu
#define SHA256C03 0xe9b5dba5u
#define SHA256C04 0x3956c25bu
#define SHA256C05 0x59f111f1u
#define SHA256C06 0x923f82a4u
#define SHA256C07 0xab1c5ed5u
#define SHA256C08 0xd807aa98u
#define SHA256C09 0x12835b01u
#define SHA256C0a 0x243185beu
#define SHA256C0b 0x550c7dc3u
#define SHA256C0c 0x72be5d74u
#define SHA256C0d 0x80deb1feu
#define SHA256C0e 0x9bdc06a7u
#define SHA256C0f 0xc19bf174u
#define SHA256C10 0xe49b69c1u
#define SHA256C11 0xefbe4786u
#define SHA256C12 0x0fc19dc6u
#define SHA256C13 0x240ca1ccu
#define SHA256C14 0x2de92c6fu
#define SHA256C15 0x4a7484aau
#define SHA256C16 0x5cb0a9dcu
#define SHA256C17 0x76f988dau
#define SHA256C18 0x983e5152u
#define SHA256C19 0xa831c66du
#define SHA256C1a 0xb00327c8u
#define SHA256C1b 0xbf597fc7u
#define SHA256C1c 0xc6e00bf3u
#define SHA256C1d 0xd5a79147u
#define SHA256C1e 0x06ca6351u
#define SHA256C1f 0x14292967u
#define SHA256C20 0x27b70a85u
#define SHA256C21 0x2e1b2138u
#define SHA256C22 0x4d2c6dfcu
#define SHA256C23 0x53380d13u
#define SHA256C24 0x650a7354u
#define SHA256C25 0x766a0abbu
#define SHA256C26 0x81c2c92eu
#define SHA256C27 0x92722c85u
#define SHA256C28 0xa2bfe8a1u
#define SHA256C29 0xa81a664bu
#define SHA256C2a 0xc24b8b70u
#define SHA256C2b 0xc76c51a3u
#define SHA256C2c 0xd192e819u
#define SHA256C2d 0xd6990624u
#define SHA256C2e 0xf40e3585u
#define SHA256C2f 0x106aa070u
#define SHA256C30 0x19a4c116u
#define SHA256C31 0x1e376c08u
#define SHA256C32 0x2748774cu
#define SHA256C33 0x34b0bcb5u
#define SHA256C34 0x391c0cb3u
#define SHA256C35 0x4ed8aa4au
#define SHA256C36 0x5b9cca4fu
#define SHA256C37 0x682e6ff3u
#define SHA256C38 0x748f82eeu
#define SHA256C39 0x78a5636fu
#define SHA256C3a 0x84c87814u
#define SHA256C3b 0x8cc70208u
#define SHA256C3c 0x90befffau
#define SHA256C3d 0xa4506cebu
#define SHA256C3e 0xbef9a3f7u
#define SHA256C3f 0xc67178f2u 

// 512 bytes
__constant__ uint64_t padLong[8] = { highBit(0), highBit(1), highBit(2), highBit(3), highBit(4), highBit(5), highBit(6), highBit(7) };

// 512 bytes
__constant__ uint64_t maskLong[8] = { 0, fBytes(1), fBytes(2), fBytes(3), fBytes(4), fBytes(5), fBytes(6), fBytes(7) };

__inline__
__device__
static uint32_t SWAP256(uint32_t val) {
	return (rotl32(((val) & (uint32_t)0x00FF00FF), (uint32_t)24U) | rotl32(((val) & (uint32_t)0xFF00FF00), (uint32_t)8U));
}





// 1, 383 0's, 128 bit length BE
// uint64_t is 64 bits => 8 bytes so msg[0] is bytes 1->8  msg[1] is bytes 9->16
// msg[24] is bytes 193->200 but our message is only 192 bytes
__device__
static void md_pad_128(uint64_t* msg, const long msgLen_bytes) {
	uint32_t padLongIndex, overhang;
	padLongIndex = ((uint32_t)msgLen_bytes) / 8; // 24
	overhang = (((uint32_t)msgLen_bytes) - padLongIndex * 8); // 0
	msg[padLongIndex] &= maskLong[overhang]; // msg[24] = msg[24] & 0 -> 0's out this byte
	msg[padLongIndex] |= padLong[overhang]; // msg[24] = msg[24] | 0x1UL << 7 -> sets it to 0x1UL << 7
	msg[padLongIndex + 1] = 0; // msg[25] = 0
	msg[padLongIndex + 2] = 0; // msg[26] = 0
	uint32_t i = 0;

	// 27, 28, 29, 30, 31 = 0
	for (i = padLongIndex + 3; i < 32; i++) {
		msg[i] = 0;
	}
	// i = 32
	// int nBlocks = i / 16; // nBlocks = 2
	msg[i - 2] = 0; // msg[30] = 0; already did this in loop..
	msg[i - 1] = SWAP512(msgLen_bytes * 8); // msg[31] = SWAP512(1536)
	//return nBlocks; // 2
	//return 2; // 2
};


// 256 bytes
__constant__ static uint32_t k_sha256[64] =
{
  SHA256C00, SHA256C01, SHA256C02, SHA256C03,
  SHA256C04, SHA256C05, SHA256C06, SHA256C07,
  SHA256C08, SHA256C09, SHA256C0a, SHA256C0b,
  SHA256C0c, SHA256C0d, SHA256C0e, SHA256C0f,
  SHA256C10, SHA256C11, SHA256C12, SHA256C13,
  SHA256C14, SHA256C15, SHA256C16, SHA256C17,
  SHA256C18, SHA256C19, SHA256C1a, SHA256C1b,
  SHA256C1c, SHA256C1d, SHA256C1e, SHA256C1f,
  SHA256C20, SHA256C21, SHA256C22, SHA256C23,
  SHA256C24, SHA256C25, SHA256C26, SHA256C27,
  SHA256C28, SHA256C29, SHA256C2a, SHA256C2b,
  SHA256C2c, SHA256C2d, SHA256C2e, SHA256C2f,
  SHA256C30, SHA256C31, SHA256C32, SHA256C33,
  SHA256C34, SHA256C35, SHA256C36, SHA256C37,
  SHA256C38, SHA256C39, SHA256C3a, SHA256C3b,
  SHA256C3c, SHA256C3d, SHA256C3e, SHA256C3f,
};

// 5kB
__constant__ static uint64_t k_sha512[80] =
{
	0x428a2f98d728ae22UL, 0x7137449123ef65cdUL, 0xb5c0fbcfec4d3b2fUL, 0xe9b5dba58189dbbcUL, 0x3956c25bf348b538UL,
	0x59f111f1b605d019UL, 0x923f82a4af194f9bUL, 0xab1c5ed5da6d8118UL, 0xd807aa98a3030242UL, 0x12835b0145706fbeUL,
	0x243185be4ee4b28cUL, 0x550c7dc3d5ffb4e2UL, 0x72be5d74f27b896fUL, 0x80deb1fe3b1696b1UL, 0x9bdc06a725c71235UL,
	0xc19bf174cf692694UL, 0xe49b69c19ef14ad2UL, 0xefbe4786384f25e3UL, 0x0fc19dc68b8cd5b5UL, 0x240ca1cc77ac9c65UL,
	0x2de92c6f592b0275UL, 0x4a7484aa6ea6e483UL, 0x5cb0a9dcbd41fbd4UL, 0x76f988da831153b5UL, 0x983e5152ee66dfabUL,
	0xa831c66d2db43210UL, 0xb00327c898fb213fUL, 0xbf597fc7beef0ee4UL, 0xc6e00bf33da88fc2UL, 0xd5a79147930aa725UL,
	0x06ca6351e003826fUL, 0x142929670a0e6e70UL, 0x27b70a8546d22ffcUL, 0x2e1b21385c26c926UL, 0x4d2c6dfc5ac42aedUL,
	0x53380d139d95b3dfUL, 0x650a73548baf63deUL, 0x766a0abb3c77b2a8UL, 0x81c2c92e47edaee6UL, 0x92722c851482353bUL,
	0xa2bfe8a14cf10364UL, 0xa81a664bbc423001UL, 0xc24b8b70d0f89791UL, 0xc76c51a30654be30UL, 0xd192e819d6ef5218UL,
	0xd69906245565a910UL, 0xf40e35855771202aUL, 0x106aa07032bbd1b8UL, 0x19a4c116b8d2d0c8UL, 0x1e376c085141ab53UL,
	0x2748774cdf8eeb99UL, 0x34b0bcb5e19b48a8UL, 0x391c0cb3c5c95a63UL, 0x4ed8aa4ae3418acbUL, 0x5b9cca4f7763e373UL,
	0x682e6ff3d6b2b8a3UL, 0x748f82ee5defb2fcUL, 0x78a5636f43172f60UL, 0x84c87814a1f0ab72UL, 0x8cc702081a6439ecUL,
	0x90befffa23631e28UL, 0xa4506cebde82bde9UL, 0xbef9a3f7b2c67915UL, 0xc67178f2e372532bUL, 0xca273eceea26619cUL,
	0xd186b8c721c0c207UL, 0xeada7dd6cde0eb1eUL, 0xf57d4f7fee6ed178UL, 0x06f067aa72176fbaUL, 0x0a637dc5a2c898a6UL,
	0x113f9804bef90daeUL, 0x1b710b35131c471bUL, 0x28db77f523047d84UL, 0x32caab7b40c72493UL, 0x3c9ebe0a15c9bebcUL,
	0x431d67c49c100d4cUL, 0x4cc5d4becb3e42b6UL, 0x597f299cfc657e2aUL, 0x5fcb6fab3ad6faecUL, 0x6c44198c4a475817UL
};

#define SHA256_STEP(F0a,F1a,a,b,c,d,e,f,g,h,x,K) { h += K; h += x; h += S3 (e); h += F1a (e,f,g); d += h; h += S2 (a); h += F0a (a,b,c); }
#define SHA512_STEP(a,b,c,d,e,f,g,h,x,K) { h += K + SHA512_S1(e) + SHAF1(e, f, g) + x; d += h; h += SHA512_S0(a) + SHAF0(a, b, c);}
#define ROUND_STEP_SHA512(i) { SHA512_STEP(a, b, c, d, e, f, g, h, W[i + 0], k_sha512[i +  0]); SHA512_STEP(h, a, b, c, d, e, f, g, W[i + 1], k_sha512[i +  1]); SHA512_STEP(g, h, a, b, c, d, e, f, W[i + 2], k_sha512[i +  2]); SHA512_STEP(f, g, h, a, b, c, d, e, W[i + 3], k_sha512[i +  3]); SHA512_STEP(e, f, g, h, a, b, c, d, W[i + 4], k_sha512[i +  4]); SHA512_STEP(d, e, f, g, h, a, b, c, W[i + 5], k_sha512[i +  5]); SHA512_STEP(c, d, e, f, g, h, a, b, W[i + 6], k_sha512[i +  6]); SHA512_STEP(b, c, d, e, f, g, h, a, W[i + 7], k_sha512[i +  7]); SHA512_STEP(a, b, c, d, e, f, g, h, W[i + 8], k_sha512[i +  8]); SHA512_STEP(h, a, b, c, d, e, f, g, W[i + 9], k_sha512[i +  9]); SHA512_STEP(g, h, a, b, c, d, e, f, W[i + 10], k_sha512[i + 10]); SHA512_STEP(f, g, h, a, b, c, d, e, W[i + 11], k_sha512[i + 11]); SHA512_STEP(e, f, g, h, a, b, c, d, W[i + 12], k_sha512[i + 12]); SHA512_STEP(d, e, f, g, h, a, b, c, W[i + 13], k_sha512[i + 13]); SHA512_STEP(c, d, e, f, g, h, a, b, W[i + 14], k_sha512[i + 14]); SHA512_STEP(b, c, d, e, f, g, h, a, W[i + 15], k_sha512[i + 15]); }
#define SHA256_EXPAND(x,y,z,w) (S1 (x) + y + S0 (z) + w) 
#define ROUND_STEP_SHA512_SHARED(i) { \
SHA512_STEP(a, b, c, d, e, f, g, h, W_data[i + 0], k_sha512[i +  0]); \
SHA512_STEP(h, a, b, c, d, e, f, g, W_data[i + 1], k_sha512[i +  1]); \
SHA512_STEP(g, h, a, b, c, d, e, f, W_data[i + 2], k_sha512[i +  2]); \
SHA512_STEP(f, g, h, a, b, c, d, e, W_data[i + 3], k_sha512[i +  3]); \
SHA512_STEP(e, f, g, h, a, b, c, d, W_data[i + 4], k_sha512[i +  4]); \
SHA512_STEP(d, e, f, g, h, a, b, c, W_data[i + 5], k_sha512[i +  5]); \
SHA512_STEP(c, d, e, f, g, h, a, b, W_data[i + 6], k_sha512[i +  6]); \
SHA512_STEP(b, c, d, e, f, g, h, a, W_data[i + 7], k_sha512[i +  7]); \
SHA512_STEP(a, b, c, d, e, f, g, h, W_data[i + 8], k_sha512[i +  8]); \
SHA512_STEP(h, a, b, c, d, e, f, g, W_data[i + 9], k_sha512[i +  9]); \
SHA512_STEP(g, h, a, b, c, d, e, f, W_data[i + 10], k_sha512[i + 10]); \
SHA512_STEP(f, g, h, a, b, c, d, e, W_data[i + 11], k_sha512[i + 11]); \
SHA512_STEP(e, f, g, h, a, b, c, d, W_data[i + 12], k_sha512[i + 12]); \
SHA512_STEP(d, e, f, g, h, a, b, c, W_data[i + 13], k_sha512[i + 13]); \
SHA512_STEP(c, d, e, f, g, h, a, b, W_data[i + 14], k_sha512[i + 14]); \
SHA512_STEP(b, c, d, e, f, g, h, a, W_data[i + 15], k_sha512[i + 15]);} 


__device__
static void sha256_process2(const uint32_t* W, uint32_t* digest) {
	uint32_t a = digest[0];
	uint32_t b = digest[1];
	uint32_t c = digest[2];
	uint32_t d = digest[3];
	uint32_t e = digest[4];
	uint32_t f = digest[5];
	uint32_t g = digest[6];
	uint32_t h = digest[7];

	uint32_t w0_t = W[0];
	uint32_t w1_t = W[1];
	uint32_t w2_t = W[2];
	uint32_t w3_t = W[3];
	uint32_t w4_t = W[4];
	uint32_t w5_t = W[5];
	uint32_t w6_t = W[6];
	uint32_t w7_t = W[7];
	uint32_t w8_t = W[8];
	uint32_t w9_t = W[9];
	uint32_t wa_t = W[10];
	uint32_t wb_t = W[11];
	uint32_t wc_t = W[12];
	uint32_t wd_t = W[13];
	uint32_t we_t = W[14];
	uint32_t wf_t = W[15];

#define ROUND_EXPAND() { w0_t = SHA256_EXPAND (we_t, w9_t, w1_t, w0_t); w1_t = SHA256_EXPAND (wf_t, wa_t, w2_t, w1_t); w2_t = SHA256_EXPAND (w0_t, wb_t, w3_t, w2_t); w3_t = SHA256_EXPAND (w1_t, wc_t, w4_t, w3_t); w4_t = SHA256_EXPAND (w2_t, wd_t, w5_t, w4_t); w5_t = SHA256_EXPAND (w3_t, we_t, w6_t, w5_t); w6_t = SHA256_EXPAND (w4_t, wf_t, w7_t, w6_t); w7_t = SHA256_EXPAND (w5_t, w0_t, w8_t, w7_t); w8_t = SHA256_EXPAND (w6_t, w1_t, w9_t, w8_t); w9_t = SHA256_EXPAND (w7_t, w2_t, wa_t, w9_t); wa_t = SHA256_EXPAND (w8_t, w3_t, wb_t, wa_t); wb_t = SHA256_EXPAND (w9_t, w4_t, wc_t, wb_t); wc_t = SHA256_EXPAND (wa_t, w5_t, wd_t, wc_t); wd_t = SHA256_EXPAND (wb_t, w6_t, we_t, wd_t); we_t = SHA256_EXPAND (wc_t, w7_t, wf_t, we_t); wf_t = SHA256_EXPAND (wd_t, w8_t, w0_t, wf_t); }
#define ROUND_STEP(i) { SHA256_STEP (SHAF0, SHAF1, a, b, c, d, e, f, g, h, w0_t, k_sha256[i +  0]); SHA256_STEP (SHAF0, SHAF1, h, a, b, c, d, e, f, g, w1_t, k_sha256[i +  1]); SHA256_STEP (SHAF0, SHAF1, g, h, a, b, c, d, e, f, w2_t, k_sha256[i +  2]); SHA256_STEP (SHAF0, SHAF1, f, g, h, a, b, c, d, e, w3_t, k_sha256[i +  3]); SHA256_STEP (SHAF0, SHAF1, e, f, g, h, a, b, c, d, w4_t, k_sha256[i +  4]); SHA256_STEP (SHAF0, SHAF1, d, e, f, g, h, a, b, c, w5_t, k_sha256[i +  5]); SHA256_STEP (SHAF0, SHAF1, c, d, e, f, g, h, a, b, w6_t, k_sha256[i +  6]); SHA256_STEP (SHAF0, SHAF1, b, c, d, e, f, g, h, a, w7_t, k_sha256[i +  7]); SHA256_STEP (SHAF0, SHAF1, a, b, c, d, e, f, g, h, w8_t, k_sha256[i +  8]); SHA256_STEP (SHAF0, SHAF1, h, a, b, c, d, e, f, g, w9_t, k_sha256[i +  9]); SHA256_STEP (SHAF0, SHAF1, g, h, a, b, c, d, e, f, wa_t, k_sha256[i + 10]); SHA256_STEP (SHAF0, SHAF1, f, g, h, a, b, c, d, e, wb_t, k_sha256[i + 11]); SHA256_STEP (SHAF0, SHAF1, e, f, g, h, a, b, c, d, wc_t, k_sha256[i + 12]); SHA256_STEP (SHAF0, SHAF1, d, e, f, g, h, a, b, c, wd_t, k_sha256[i + 13]); SHA256_STEP (SHAF0, SHAF1, c, d, e, f, g, h, a, b, we_t, k_sha256[i + 14]); SHA256_STEP (SHAF0, SHAF1, b, c, d, e, f, g, h, a, wf_t, k_sha256[i + 15]); }

	ROUND_STEP(0);
	ROUND_EXPAND();
	ROUND_STEP(16);
	ROUND_EXPAND();
	ROUND_STEP(32);
	ROUND_EXPAND();
	ROUND_STEP(48);

	digest[0] += a;
	digest[1] += b;
	digest[2] += c;
	digest[3] += d;
	digest[4] += e;
	digest[5] += f;
	digest[6] += g;
	digest[7] += h;
}

__device__
static void sha512(uint64_t* input, const uint32_t length, uint64_t* hash) {
	md_pad_128(input, (const uint64_t)length);
	uint64_t W[80];
	uint64_t State[8];
	//for (int i = 16; i < 80; i++) {
	//	W[i] = 0;
	//}
	State[0] = 0x6a09e667f3bcc908UL;
	State[1] = 0xbb67ae8584caa73bUL;
	State[2] = 0x3c6ef372fe94f82bUL;
	State[3] = 0xa54ff53a5f1d36f1UL;
	State[4] = 0x510e527fade682d1UL;
	State[5] = 0x9b05688c2b3e6c1fUL;
	State[6] = 0x1f83d9abfb41bd6bUL;
	State[7] = 0x5be0cd19137e2179UL;
	uint64_t a, b, c, d, e, f, g, h;
	for (int block_i = 0; block_i < 2; block_i++) {

		W[0] = SWAP512(input[0]);
		W[1] = SWAP512(input[1]);
		W[2] = SWAP512(input[2]);
		W[3] = SWAP512(input[3]);
		W[4] = SWAP512(input[4]);
		W[5] = SWAP512(input[5]);
		W[6] = SWAP512(input[6]);
		W[7] = SWAP512(input[7]);
		W[8] = SWAP512(input[8]);
		W[9] = SWAP512(input[9]);
		W[10] = SWAP512(input[10]);
		W[11] = SWAP512(input[11]);
		W[12] = SWAP512(input[12]);
		W[13] = SWAP512(input[13]);
		W[14] = SWAP512(input[14]);
		W[15] = SWAP512(input[15]);

		//SWAP512_16D(input, W);

		for (int i = 16; i < 80; i++) {
			W[i] = W[i - 16] + little_s0(W[i - 15]) + W[i - 7] + little_s1(W[i - 2]);
		}
		a = State[0];
		b = State[1];
		c = State[2];
		d = State[3];
		e = State[4];
		f = State[5];
		g = State[6];
		h = State[7];
		for (int i = 0; i < 80; i += 16) {
			ROUND_STEP_SHA512(i)
		}
		State[0] += a;
		State[1] += b;
		State[2] += c;
		State[3] += d;
		State[4] += e;
		State[5] += f;
		State[6] += g;
		State[7] += h;
		input += 16;
	}
	hash[0] = SWAP512(State[0]);
	hash[1] = SWAP512(State[1]);
	hash[2] = SWAP512(State[2]);
	hash[3] = SWAP512(State[3]);
	hash[4] = SWAP512(State[4]);
	hash[5] = SWAP512(State[5]);
	hash[6] = SWAP512(State[6]);
	hash[7] = SWAP512(State[7]);
	return;
}

__device__
static void md_pad_128_swap(uint64_t* msg, const long msgLen_bytes) {
	uint32_t padLongIndex, overhang;
	padLongIndex = ((uint32_t)msgLen_bytes) / 8; // 24
	overhang = (((uint32_t)msgLen_bytes) - padLongIndex * 8); // 0
	msg[padLongIndex] &= SWAP512(maskLong[overhang]); // msg[24] = msg[24] & 0 -> 0's out this byte
	msg[padLongIndex] |= SWAP512(padLong[overhang]); // msg[24] = msg[24] | 0x1UL << 7 -> sets it to 0x1UL << 7
	msg[padLongIndex + 1] = 0; // msg[25] = 0
	msg[padLongIndex + 2] = 0; // msg[26] = 0
	uint32_t i = 0;

	// 27, 28, 29, 30, 31 = 0
	for (i = padLongIndex + 3; i < 32; i++) {
		msg[i] = 0;
	}
	// i = 32
	// int nBlocks = i / 16; // nBlocks = 2
	msg[i - 2] = 0; // msg[30] = 0; already did this in loop..
	msg[i - 1] = msgLen_bytes * 8; // msg[31] = SWAP512(1536)
	//return nBlocks; // 2
	//return 2; // 2
};

__device__
 void sha512_swap(uint64_t* input, const uint32_t length, uint64_t* hash) {
	md_pad_128_swap(input, (const uint64_t)length);
	uint64_t W[80];
	uint64_t State[8];
	//for (int i = 16; i < 80; i++) {
	//	W[i] = 0;
	//}
	State[0] = 0x6a09e667f3bcc908UL;
	State[1] = 0xbb67ae8584caa73bUL;
	State[2] = 0x3c6ef372fe94f82bUL;
	State[3] = 0xa54ff53a5f1d36f1UL;
	State[4] = 0x510e527fade682d1UL;
	State[5] = 0x9b05688c2b3e6c1fUL;
	State[6] = 0x1f83d9abfb41bd6bUL;
	State[7] = 0x5be0cd19137e2179UL;
	uint64_t a, b, c, d, e, f, g, h;
	for (int block_i = 0; block_i < 2; block_i++) {

		W[0] = input[0];
		W[1] = input[1];
		W[2] = input[2];
		W[3] = input[3];
		W[4] = input[4];
		W[5] = input[5];
		W[6] = input[6];
		W[7] = input[7];
		W[8] = input[8];
		W[9] = input[9];
		W[10] = input[10];
		W[11] = input[11];
		W[12] = input[12];
		W[13] = input[13];
		W[14] = input[14];
		W[15] = input[15];

		//SWAP512_16D(input, W);
#pragma unroll
		for (int i = 16; i < 80; i++) {
			W[i] = W[i - 16] + little_s0(W[i - 15]) + W[i - 7] + little_s1(W[i - 2]);
		}
		a = State[0];
		b = State[1];
		c = State[2];
		d = State[3];
		e = State[4];
		f = State[5];
		g = State[6];
		h = State[7];
#pragma unroll
		for (int i = 0; i < 80; i += 16) {
			ROUND_STEP_SHA512(i)
		}
		State[0] += a;
		State[1] += b;
		State[2] += c;
		State[3] += d;
		State[4] += e;
		State[5] += f;
		State[6] += g;
		State[7] += h;
		input += 16;
	}
	hash[0] = State[0];
	hash[1] = State[1];
	hash[2] = State[2];
	hash[3] = State[3];
	hash[4] = State[4];
	hash[5] = State[5];
	hash[6] = State[6];
	hash[7] = State[7];
	return;
}

__device__
static void sha512_swap_3(uint64_t* input, const uint32_t length, uint64_t* hash) {
	md_pad_128_swap(input, (const uint64_t)length);
	uint64_t W[80];
	uint64_t State[8];
	//for (int i = 16; i < 80; i++) {
	//	W[i] = 0;
	//}
	State[0] = 0x6a09e667f3bcc908UL;
	State[1] = 0xbb67ae8584caa73bUL;
	State[2] = 0x3c6ef372fe94f82bUL;
	State[3] = 0xa54ff53a5f1d36f1UL;
	State[4] = 0x510e527fade682d1UL;
	State[5] = 0x9b05688c2b3e6c1fUL;
	State[6] = 0x1f83d9abfb41bd6bUL;
	State[7] = 0x5be0cd19137e2179UL;
	uint64_t a, b, c, d, e, f, g, h;
	for (int block_i = 0; block_i < 4; block_i++) {

		W[0] = input[0];
		W[1] = input[1];
		W[2] = input[2];
		W[3] = input[3];
		W[4] = input[4];
		W[5] = input[5];
		W[6] = input[6];
		W[7] = input[7];
		W[8] = input[8];
		W[9] = input[9];
		W[10] = input[10];
		W[11] = input[11];
		W[12] = input[12];
		W[13] = input[13];
		W[14] = input[14];
		W[15] = input[15];

		//SWAP512_16D(input, W);
#pragma unroll
		for (int i = 16; i < 80; i++) {
			W[i] = W[i - 16] + little_s0(W[i - 15]) + W[i - 7] + little_s1(W[i - 2]);
		}
		a = State[0];
		b = State[1];
		c = State[2];
		d = State[3];
		e = State[4];
		f = State[5];
		g = State[6];
		h = State[7];
#pragma unroll
		for (int i = 0; i < 80; i += 16) {
			ROUND_STEP_SHA512(i)
		}
		State[0] += a;
		State[1] += b;
		State[2] += c;
		State[3] += d;
		State[4] += e;
		State[5] += f;
		State[6] += g;
		State[7] += h;
		input += 16;
	}
	hash[0] = State[0];
	hash[1] = State[1];
	hash[2] = State[2];
	hash[3] = State[3];
	hash[4] = State[4];
	hash[5] = State[5];
	hash[6] = State[6];
	hash[7] = State[7];
	return;
}


__device__
 void sha256(const uint32_t* pass, int pass_len, uint32_t* hash) {
	int plen = pass_len / 4;
	if (mod(pass_len, 4)) plen++;
	uint32_t* p = hash;
	uint32_t W[0x10];
	int loops = plen;
	int curloop = 0;
	uint32_t State[8];
	State[0] = 0x6a09e667;
	State[1] = 0xbb67ae85;
	State[2] = 0x3c6ef372;
	State[3] = 0xa54ff53a;
	State[4] = 0x510e527f;
	State[5] = 0x9b05688c;
	State[6] = 0x1f83d9ab;
	State[7] = 0x5be0cd19;
	while (loops > 0) {
		W[0x0] = 0x0;
		W[0x1] = 0x0;
		W[0x2] = 0x0;
		W[0x3] = 0x0;
		W[0x4] = 0x0;
		W[0x5] = 0x0;
		W[0x6] = 0x0;
		W[0x7] = 0x0;
		W[0x8] = 0x0;
		W[0x9] = 0x0;
		W[0xA] = 0x0;
		W[0xB] = 0x0;
		W[0xC] = 0x0;
		W[0xD] = 0x0;
		W[0xE] = 0x0;
		W[0xF] = 0x0;
		for (int m = 0; loops != 0 && m < 16; m++) {
			W[m] ^= SWAP256(pass[m + (curloop * 16)]);
			loops--;
		}
		if (loops == 0 && mod(pass_len, 64) != 0) {
			uint32_t padding = 0x80 << (((pass_len + 4) - ((pass_len + 4) / 4 * 4)) * 8);
			int v = mod(pass_len, 64);
			W[v / 4] |= SWAP256(padding);
			if ((pass_len & 0x3B) != 0x3B) {
				W[0x0F] = pass_len * 8;
			}
		}
		sha256_process2(W, State);
		curloop++;
	}
	if (mod(plen, 16) == 0) {
		W[0x0] = 0x0;
		W[0x1] = 0x0;
		W[0x2] = 0x0;
		W[0x3] = 0x0;
		W[0x4] = 0x0;
		W[0x5] = 0x0;
		W[0x6] = 0x0;
		W[0x7] = 0x0;
		W[0x8] = 0x0;
		W[0x9] = 0x0;
		W[0xA] = 0x0;
		W[0xB] = 0x0;
		W[0xC] = 0x0;
		W[0xD] = 0x0;
		W[0xE] = 0x0;
		W[0xF] = 0x0;
		if ((pass_len & 0x3B) != 0x3B) {
			uint32_t padding = 0x80 << (((pass_len + 4) - ((pass_len + 4) / 4 * 4)) * 8);
			W[0] |= SWAP256(padding);
		}
		W[0x0F] = pass_len * 8;
		sha256_process2(W, State);
	}
	p[0] = SWAP256(State[0]);
	p[1] = SWAP256(State[1]);
	p[2] = SWAP256(State[2]);
	p[3] = SWAP256(State[3]);
	p[4] = SWAP256(State[4]);
	p[5] = SWAP256(State[5]);
	p[6] = SWAP256(State[6]);
	p[7] = SWAP256(State[7]);
	return;
}

#undef F0
#undef F1
#undef S0
#undef S1
#undef S2
#undef S3

#undef mod
#undef shr32
#undef rotl32



#define XOR_SEED_WITH_ROUND(seed, round)	{ \
	for (int x = 0; x < 64; x++) { \
		seed[x] = seed[x] ^ round[x]; \
	} \
}

#define XOR_SEED_WITH_ROUND_32(seed, round)	{ \
	for (int x = 0; x < 64 / 4; x++) { \
		seed[x] = seed[x] ^ round[x]; \
	} \
}


#define ECMULT_GEN_PREC_BITS 2
#define ECMULT_GEN_PREC_B ECMULT_GEN_PREC_BITS
#define ECMULT_GEN_PREC_G (1 << ECMULT_GEN_PREC_B)
#define ECMULT_GEN_PREC_N (256 / ECMULT_GEN_PREC_B)
#define ECMULT_WINDOW_SIZE 15
#define WINDOW_A 5
#define WINDOW_G ECMULT_WINDOW_SIZE
#define ECMULT_TABLE_SIZE(w) (1 << ((w)-2))
#define RIPEMD160_BLOCK_LENGTH 64
#define RIPEMD160_DIGEST_LENGTH 20
#define SECP256K1_FLAGS_TYPE_MASK ((1 << 8) - 1)
#define SECP256K1_FLAGS_TYPE_CONTEXT (1 << 0)
#define SECP256K1_FLAGS_TYPE_COMPRESSION (1 << 1)
#define SECP256K1_FLAGS_BIT_CONTEXT_VERIFY (1 << 8)
#define SECP256K1_FLAGS_BIT_CONTEXT_SIGN (1 << 9)
#define SECP256K1_FLAGS_BIT_CONTEXT_DECLASSIFY (1 << 10)
#define SECP256K1_FLAGS_BIT_COMPRESSION (1 << 8)
#define SECP256K1_EC_COMPRESSED (SECP256K1_FLAGS_TYPE_COMPRESSION | SECP256K1_FLAGS_BIT_COMPRESSION)
#define SECP256K1_EC_UNCOMPRESSED (SECP256K1_FLAGS_TYPE_COMPRESSION)
#define SECP256K1_TAG_PUBKEY_EVEN 0x02
#define SECP256K1_TAG_PUBKEY_ODD 0x03
#define SECP256K1_TAG_PUBKEY_UNCOMPRESSED 0x04
#define SECP256K1_TAG_PUBKEY_HYBRID_EVEN 0x06
#define SECP256K1_TAG_PUBKEY_HYBRID_ODD 0x07
#define SECP256K1_FE_CONST_INNER(d7, d6, d5, d4, d3, d2, d1, d0) { (d0) & 0x3FFFFFFUL, (((uint32_t)d0) >> 26) | (((uint32_t)(d1) & 0xFFFFFUL) << 6), (((uint32_t)d1) >> 20) | (((uint32_t)(d2) & 0x3FFFUL) << 12), (((uint32_t)d2) >> 14) | (((uint32_t)(d3) & 0xFFUL) << 18), (((uint32_t)d3) >> 8) | (((uint32_t)(d4) & 0x3UL) << 24), (((uint32_t)d4) >> 2) & 0x3FFFFFFUL,(((uint32_t)d4) >> 28) | (((uint32_t)(d5) & 0x3FFFFFUL) << 4), (((uint32_t)d5) >> 22) | (((uint32_t)(d6) & 0xFFFFUL) << 10), (((uint32_t)d6) >> 16) | (((uint32_t)(d7) & 0x3FFUL) << 16), (((uint32_t)d7) >> 10) }
#define SECP256K1_SCALAR_CONST(d7, d6, d5, d4, d3, d2, d1, d0) {{(d0), (d1), (d2), (d3), (d4), (d5), (d6), (d7)}}
#define SECP256K1_FE_CONST(d7, d6, d5, d4, d3, d2, d1, d0) {SECP256K1_FE_CONST_INNER((d7), (d6), (d5), (d4), (d3), (d2), (d1), (d0))}
#define SECP256K1_GE_CONST(a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p) {SECP256K1_FE_CONST((a),(b),(c),(d),(e),(f),(g),(h)), SECP256K1_FE_CONST((i),(j),(k),(l),(m),(n),(o),(p)), 0}
#define SECP256K1_GE_CONST_INFINITY {SECP256K1_FE_CONST(0, 0, 0, 0, 0, 0, 0, 0), SECP256K1_FE_CONST(0, 0, 0, 0, 0, 0, 0, 0), 1}
#define SECP256K1_N_0 ((uint32_t)0xD0364141UL)
#define SECP256K1_N_1 ((uint32_t)0xBFD25E8CUL)
#define SECP256K1_N_2 ((uint32_t)0xAF48A03BUL)
#define SECP256K1_N_3 ((uint32_t)0xBAAEDCE6UL)
#define SECP256K1_N_4 ((uint32_t)0xFFFFFFFEUL)
#define SECP256K1_N_5 ((uint32_t)0xFFFFFFFFUL)
#define SECP256K1_N_6 ((uint32_t)0xFFFFFFFFUL)
#define SECP256K1_N_7 ((uint32_t)0xFFFFFFFFUL)
#define SECP256K1_N_C_0 (~SECP256K1_N_0 + 1)
#define SECP256K1_N_C_1 (~SECP256K1_N_1)
#define SECP256K1_N_C_2 (~SECP256K1_N_2)
#define SECP256K1_N_C_3 (~SECP256K1_N_3)
#define SECP256K1_N_C_4 (1)

typedef struct {
	uint32_t n[10];
} secp256k1_fe;

typedef struct {
	uint32_t n[8];
} secp256k1_fe_storage;

typedef struct {
	uint32_t d[8];
} secp256k1_scalar;

typedef struct {
	secp256k1_fe x;
	secp256k1_fe y;
	int infinity;
} secp256k1_ge;

typedef struct {
	secp256k1_fe x;
	secp256k1_fe y;
	secp256k1_fe z;
	int infinity;
} secp256k1_gej;

typedef struct {
	secp256k1_fe_storage x;
	secp256k1_fe_storage y;
} secp256k1_ge_storage;

//typedef struct {
//	unsigned char data[64];
//} secp256k1_pubkey;

#define SECP256K1_FE_STORAGE_CONST(d7, d6, d5, d4, d3, d2, d1, d0) {{ (d0), (d1), (d2), (d3), (d4), (d5), (d6), (d7) }}
#define SECP256K1_GE_STORAGE_CONST(a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p) {SECP256K1_FE_STORAGE_CONST((a),(b),(c),(d),(e),(f),(g),(h)), SECP256K1_FE_STORAGE_CONST((i),(j),(k),(l),(m),(n),(o),(p))}
#define SC SECP256K1_GE_STORAGE_CONST

#define BITCOIN_MAINNET 0
#define BITCOIN_TESTNET 1

//typedef struct {
//	secp256k1_pubkey key;
//} public_key_t;



__device__
static void hmac_sha512_const(const uint32_t* key, const uint32_t* message, uint32_t* output) {
	uint32_t ipad_key[128 / 4];
	uint32_t opad_key[128 / 4];

	for (int x = 0; x < 32 / 4; x++) {
		ipad_key[x] = 0x36363636 ^ *(uint32_t*)((uint32_t*)key + x);
		opad_key[x] = 0x5C5C5C5C ^ *(uint32_t*)((uint32_t*)key + x);
	}

	for (int x = 32 / 4; x < 128 / 4; x++) {
		ipad_key[x] = 0x36363636;
		opad_key[x] = 0x5C5C5C5C;
	}

	uint32_t inner_concat[256 / 4];
	for (int x = 0; x < 256 / 4; x++) {
		inner_concat[x] = 0;
	}

	for (int x = 0; x < 128 / 4; x++) {
		inner_concat[x] = *(uint32_t*)((uint32_t*)&ipad_key + x);
	}
	for (int x = 0; x < 36 / 4; x++) {
		inner_concat[128 / 4 + x] = message[x];
	}
	*(uint8_t*)((uint8_t*)&inner_concat + 128 + (37 - 1)) = *(uint8_t*)((uint8_t*)message + 36);

	sha512((uint64_t*)&inner_concat, 128 + 37, (uint64_t*)output);

	for (int x = 0; x < (128 / 4); x++) {
		*(uint32_t*)((uint32_t*)&inner_concat + x) = *(uint32_t*)((uint32_t*)&opad_key + x);
	}
	for (int x = 0; x < (64 / 4); x++) {
		*(uint32_t*)((uint32_t*)&inner_concat + 128 / 4 + x) = *(uint32_t*)((uint32_t*)output + x);
	}

	sha512((uint64_t*)&inner_concat, 192, (uint64_t*)output);
}



__device__
static void memcpy(uint8_t* dest, const uint8_t* src, uint32_t n) {
	for (int i = 0; i < n; i++) {
		dest[i] = src[i];
	}
}
__device__
static void memcpy_offset(uint8_t* dest, const uint8_t* src, int offset, uint8_t bytes_to_copy) {
	for (int i = 0; i < bytes_to_copy; i++) {
		dest[i] = src[offset + i];
	}
}
__device__
static void memset(uint8_t* str, int c, uint32_t n) {
	for (int i = 0; i < n; i++) {
		str[i] = c;
	}
}

__constant__ secp256k1_ge_storage prec[128][4] = { {
	SC(983487347u, 1861041900u, 2599115456u, 565528146u, 1451326239u, 148794576u, 4224640328u, 3120843701u, 2076989736u, 3184115747u, 3754320824u, 2656004457u, 2876577688u, 2388659905u, 3527541004u, 1170708298u),
	SC(3830281845u, 3284871255u, 1309883393u, 2806991612u, 1558611192u, 1249416977u, 1614773327u, 1353445208u, 633124399u, 4264439010u, 426432620u, 167800352u, 2355417627u, 2991792291u, 3042397084u, 505150283u),
	SC(1792710820u, 2165839471u, 3876070801u, 3603801374u, 2437636273u, 1231643248u, 860890267u, 4002236272u, 3258245037u, 4085545079u, 2695347418u, 288209541u, 484302592u, 139267079u, 14621978u, 2750167787u),
	SC(11094760u, 1663454715u, 3104893589u, 1290390142u, 1334245677u, 2671416785u, 3982578986u, 2050971459u, 2136209393u, 1792200847u, 367473428u, 114820199u, 1096121039u, 425028623u, 3983611854u, 923011107u)
},
{
	SC(461660907u, 483260338u, 3090624303u, 3468817529u, 2869411999u, 3408320195u, 157674611u, 1298485121u, 103769941u, 3030878493u, 1440637991u, 4223892787u, 3840844824u, 2730509202u, 2748389383u, 214732837u),
	SC(3283443609u, 2631471420u, 264982313u, 3187722117u, 3429945793u, 4056928493u, 1497022093u, 638309051u, 2303031563u, 1452679770u, 476716869u, 493553758u, 3454202674u, 3741745777u, 4129790071u, 1829770666u),
	SC(2763266881u, 438653250u, 3999405133u, 158126044u, 2748183974u, 2939338200u, 3519271531u, 3601510585u, 987660138u, 698279276u, 698337965u, 1923172050u, 1658527181u, 782345045u, 3605004948u, 15611075u),
	SC(3568265158u, 1979285296u, 1247944677u, 876477019u, 3828537841u, 1131777357u, 1658789385u, 3080372200u, 3506349824u, 713366149u, 865246815u, 524407977u, 1757013280u, 1813640112u, 902731429u, 313923873u)
},
{
	SC(1793692126u, 406948681u, 23075151u, 2805328754u, 3264854407u, 427926777u, 2859563730u, 198037267u, 2129133850u, 1089701106u, 3842694445u, 2533380467u, 663211132u, 2312829798u, 807127373u, 38506815u),
	SC(3263300518u, 3774427737u, 2005654986u, 284791998u, 1741605027u, 278724609u, 3627067623u, 3025303883u, 417282626u, 3961829139u, 717534956u, 3715499492u, 379232378u, 1104631198u, 3186100441u, 3153840916u),
	SC(1212722614u, 2956266711u, 3074799107u, 3489045995u, 2346779929u, 3422717980u, 1268253015u, 1446357559u, 2055290998u, 410965945u, 2228272741u, 3002612624u, 844382671u, 1412583811u, 3199209782u, 3592866396u),
	SC(1365068159u, 4067744317u, 2612651255u, 3786899082u, 2944769362u, 3195829907u, 253325927u, 3611092398u, 3664021332u, 173986934u, 1068324321u, 3913258631u, 757066081u, 3024665023u, 742574213u, 3024517360u)
},
{
	SC(1686440452u, 1988561476u, 754604000u, 1313277943u, 3972816537u, 316394247u, 994407191u, 1904170630u, 2086644946u, 2443632379u, 2709748921u, 1003213045u, 3157743406u, 1758245536u, 3227689301u, 1181052876u),
	SC(3282977068u, 2749755947u, 1149647537u, 3051767577u, 2567408320u, 223888601u, 1782024607u, 1040598133u, 3834763422u, 3012232259u, 1356426753u, 2074929973u, 262201927u, 2358783269u, 1512715052u, 597559892u),
	SC(3878434820u, 2809459675u, 1110739075u, 695947317u, 3386718576u, 2117846541u, 31792705u, 3621315477u, 3821755067u, 3284294059u, 182757u, 4194671632u, 4268712763u, 1335482921u, 1639518590u, 1643885655u),
	SC(1786486241u, 2367070434u, 456182625u, 898034630u, 2025195032u, 3803471405u, 2358553865u, 908230516u, 2887759669u, 2518324u, 3952697231u, 2446050105u, 258193126u, 3175909872u, 3613423880u, 1973719439u)
},
{
	SC(2450731413u, 2768047193u, 2114778718u, 2363611449u, 3811833768u, 1142236074u, 836975073u, 719658637u, 89564040u, 2055034782u, 2279505737u, 2354364196u, 748992674u, 2341838369u, 3471590741u, 3103440079u),
	SC(457107339u, 234212267u, 2808385829u, 1082467153u, 1613477208u, 3837699379u, 3685781168u, 698018196u, 2584486245u, 1427273599u, 4207275348u, 3102061774u, 3618025853u, 1681886269u, 3491183254u, 61130666u),
	SC(1810095661u, 485189292u, 516764725u, 1059330697u, 3450816756u, 2832552490u, 493813891u, 1011558969u, 2296450464u, 3845885786u, 2913000318u, 3788404162u, 143232350u, 359561087u, 2060204960u, 2683204223u),
	SC(3012330212u, 1040538075u, 1731389562u, 2092033766u, 1634006770u, 629989472u, 1831049270u, 1526328333u, 2651817972u, 2636385075u, 3694287824u, 1240070853u, 1803183336u, 1475508921u, 2910213636u, 803501651u)
},
{
	SC(2925506593u, 3911544000u, 1647760999u, 3077282783u, 810174083u, 3532746750u, 1218244633u, 1800164995u, 3882366571u, 1552758454u, 417617232u, 3581187042u, 1107218813u, 308444727u, 2996521844u, 3546298006u),
	SC(3841529585u, 2842543837u, 2288494105u, 4277587815u, 351020610u, 316127787u, 347470810u, 3045389113u, 3024639459u, 1038031284u, 837880241u, 3673071900u, 873110232u, 3246094570u, 3382157003u, 2031890941u),
	SC(1269604407u, 1685288902u, 4078202316u, 3610423837u, 843356019u, 4116145876u, 3730514843u, 788045418u, 1354018886u, 3118713525u, 234872570u, 4197470289u, 2077961707u, 10213883u, 2638019744u, 883368488u),
	SC(2256371012u, 1933806057u, 1899377954u, 2639211579u, 3217452631u, 1151725597u, 479445505u, 2647913315u, 3921232647u, 3013405541u, 1698636294u, 4291348568u, 929386421u, 2431356191u, 615106606u, 3635728912u)
},
{
	SC(2016238746u, 3648008750u, 3741265531u, 1468285316u, 3314132186u, 3225615603u, 2260838904u, 650230459u, 666608997u, 1079817106u, 1685466519u, 3417306450u, 465799968u, 1454367507u, 1432699603u, 4060146438u),
	SC(218622838u, 3144062173u, 1298227431u, 1296710013u, 2520686898u, 259313849u, 3925040134u, 8587584u, 45611266u, 1657172483u, 3606314124u, 759386889u, 2140045562u, 3265737381u, 3755961838u, 2873618455u),
	SC(917499604u, 3075502984u, 677364865u, 199957985u, 3163427900u, 3464203846u, 2082349760u, 962588488u, 1394141129u, 1751216552u, 3471834965u, 1070173761u, 3655391113u, 2733146365u, 1686618869u, 1417767575u),
	SC(3485619732u, 4237744401u, 38484852u, 2062357581u, 2253809979u, 2726578484u, 3538837931u, 2876850528u, 4204679835u, 3188932578u, 2204025751u, 2972778279u, 410709981u, 3746713296u, 2682061958u, 1559674900u)
},
{
	SC(3955300819u, 2390314746u, 8780989u, 1526705205u, 4147934248u, 1494146575u, 1667625450u, 2277923659u, 406493586u, 957460913u, 3449491434u, 912766689u, 1387230361u, 2368913075u, 3538729245u, 2943257094u),
	SC(1164835523u, 3258525964u, 862788422u, 3915615186u, 1495565500u, 4151116061u, 273476183u, 3708703079u, 1646675285u, 2380697417u, 386566820u, 303735559u, 931759265u, 1991815164u, 605297126u, 2505048137u),
	SC(1896909316u, 2768974072u, 703676943u, 194614458u, 944517104u, 2321028722u, 3813034930u, 2482042710u, 4285153324u, 3947936591u, 2061596288u, 1167021054u, 224557835u, 3701623985u, 2956197594u, 4068261876u),
	SC(4163247502u, 3935767334u, 4212387073u, 3469038512u, 2742333502u, 3242681324u, 333877241u, 186752825u, 1022261243u, 1852327832u, 1749655104u, 4248042849u, 3829051933u, 2527510392u, 903534280u, 803873799u)
},
{
	SC(3159079334u, 690659487u, 1550245019u, 1719420482u, 1795694879u, 2846363486u, 15987067u, 569538014u, 1561199762u, 967336684u, 3110376818u, 1863433225u, 3468533545u, 3644881587u, 369296717u, 3652676359u),
	SC(3438533039u, 1129158329u, 4254995182u, 1172977752u, 1348513792u, 2305760743u, 2805600929u, 1063476339u, 2130605077u, 2318963631u, 222333708u, 4242117337u, 3488879344u, 4152191644u, 1566216757u, 3511639585u),
	SC(414049395u, 518193567u, 2908103152u, 3485521646u, 3127487288u, 4257875118u, 4275953437u, 4190818731u, 514254035u, 1676790779u, 3922795604u, 3266003876u, 1240031503u, 615951860u, 1147425993u, 3283995888u),
	SC(2344637795u, 454276177u, 1520037565u, 2206099433u, 3893016787u, 1492026382u, 826322062u, 320651796u, 3470670522u, 2971363985u, 1324478262u, 817963303u, 3145830089u, 3033771320u, 2850457153u, 175864218u)
},
{
	SC(3370489298u, 1718569235u, 523721575u, 2176389434u, 218587365u, 2490878487u, 2288222859u, 812943600u, 2821517993u, 3626217235u, 1545838667u, 3155352961u, 741681736u, 669093936u, 2382929309u, 2620482966u),
	SC(3516186683u, 4285635092u, 112960057u, 4231926357u, 1983367601u, 811638777u, 352425005u, 881406190u, 1586726870u, 1270641374u, 969572673u, 3334919462u, 5443202u, 1202991457u, 1920039784u, 684835265u),
	SC(3487926112u, 1421368619u, 3777105084u, 683300340u, 1372273739u, 519164830u, 3090058277u, 1966650929u, 2808179530u, 4082516040u, 3050161853u, 2955217595u, 2870730035u, 2812368983u, 823237926u, 2499759082u),
	SC(420116030u, 1479628345u, 1468919607u, 1408524558u, 1518349049u, 3834068286u, 2352056000u, 3827608642u, 2975259269u, 3091607462u, 2214091902u, 1601277655u, 882989506u, 1528352914u, 408941671u, 2340962541u)
},
{
	SC(1239892635u, 3772349433u, 1058531752u, 1409211242u, 2847698653u, 2391143499u, 2637108329u, 3000217976u, 4288568828u, 658925470u, 2552628125u, 1468771377u, 3230644908u, 2692030796u, 7587087u, 1951830015u),
	SC(736995476u, 1747351270u, 1163114u, 2026562345u, 3261810630u, 595398226u, 1638337436u, 913924615u, 272242905u, 2792905424u, 556386843u, 2525187487u, 4052079772u, 3989946451u, 2527644148u, 3709255190u),
	SC(2516714890u, 4242544138u, 1891445298u, 1825827611u, 3858741928u, 3764110043u, 4223255299u, 2068094187u, 33167132u, 1747162056u, 723745040u, 45767848u, 2130314563u, 3100468655u, 3727838996u, 3428029531u),
	SC(294456146u, 4095270098u, 3062253927u, 2761923976u, 2157913192u, 2344315975u, 3331272375u, 3152522033u, 820771632u, 3121327106u, 1472157325u, 1201372141u, 722801401u, 866820160u, 1231468285u, 6166136u)
},
{
	SC(2585638847u, 1394876113u, 3750575776u, 4144761638u, 1991524028u, 3165938218u, 158354186u, 812072970u, 3814951634u, 2507408645u, 1163603486u, 3566585210u, 1424854671u, 3326584505u, 3332079056u, 1901915986u),
	SC(3049477029u, 3362467146u, 2600501326u, 4030960217u, 861735902u, 2447190956u, 2775043422u, 676062106u, 1538957086u, 2273140237u, 35534925u, 1390310379u, 2599406245u, 320935889u, 769230025u, 1241866977u),
	SC(863633986u, 1656356192u, 687209691u, 3257947459u, 944771286u, 2566595978u, 3586284316u, 1249271789u, 3782853115u, 3597787480u, 906300809u, 1224395132u, 1470876390u, 2044968575u, 384666520u, 2229055507u),
	SC(3972015306u, 1678690614u, 4158796299u, 1477735526u, 1751460077u, 1469605328u, 4128666344u, 1047203608u, 2704497527u, 3719371097u, 617877068u, 2166818425u, 655329252u, 361395292u, 2368569612u, 4000326891u)
},
{
	SC(1355623958u, 2575138117u, 2562403739u, 1638722303u, 1523970956u, 2189861089u, 3498071469u, 1919711232u, 231840827u, 3230371223u, 143629793u, 1497495034u, 1677900731u, 1608282251u, 3485501508u, 3944969019u),
	SC(886482870u, 1933309417u, 2926226694u, 1591769403u, 1331567529u, 2547948025u, 2272381527u, 2180719490u, 586729206u, 3698459560u, 1407601905u, 3690098029u, 3797283007u, 3185415432u, 2807683983u, 743820249u),
	SC(2220406124u, 2553072517u, 2268184905u, 3807611008u, 962123447u, 1442022786u, 3119831387u, 2245144291u, 3048799325u, 765814649u, 2779802501u, 3050337097u, 2600783793u, 763045554u, 3651452740u, 1057016581u),
	SC(3451851559u, 864607561u, 3244543542u, 2370117179u, 1371306276u, 390003720u, 929868877u, 1869850698u, 3531949911u, 419075495u, 427342596u, 1585514844u, 4047650117u, 3845372526u, 2912023567u, 2794855722u)
},
{
	SC(1272080061u, 1249052793u, 3406223580u, 3180222548u, 3305857569u, 3627944464u, 989639337u, 2790050407u, 2758101533u, 2203734512u, 1518825984u, 392742217u, 2425492197u, 2028188113u, 3750975833u, 2472872035u),
	SC(1718022296u, 3226292642u, 1620876982u, 1500366440u, 376656245u, 341364049u, 1509276702u, 747008556u, 1290140362u, 1157790902u, 2242566110u, 3911630441u, 2511480601u, 3638098785u, 638568919u, 1655301243u),
	SC(2276743600u, 1849567056u, 822640453u, 2045065240u, 4229957379u, 1506967879u, 2910446490u, 1217165739u, 643217741u, 3543926561u, 3104741404u, 3028146784u, 375929280u, 475833070u, 1989644595u, 2186093704u),
	SC(2198523688u, 3232341965u, 253572105u, 3392169722u, 4019005050u, 128871332u, 90164917u, 2138503228u, 2857287832u, 1362500931u, 2738484248u, 2727207447u, 2851366108u, 651094618u, 2926884083u, 423254183u)
},
{
	SC(35118683u, 172484830u, 3416100291u, 3700412376u, 540823883u, 3117923166u, 4211300427u, 2853939967u, 3346783680u, 988896867u, 2435731911u, 431849862u, 1744411117u, 2614624696u, 297543835u, 4045956333u),
	SC(3853250884u, 2621927678u, 3061260391u, 2978860545u, 4020966302u, 4037334842u, 4009723534u, 1680189348u, 3127049287u, 1501424269u, 1271732744u, 2004026132u, 2179623312u, 2037000629u, 2495416023u, 3576889736u),
	SC(1771970765u, 993135396u, 2274060952u, 1278425303u, 1173961441u, 2812998499u, 3792378081u, 2339180374u, 1711421197u, 1710211379u, 2213420101u, 3131984485u, 4023294968u, 11317443u, 3488462274u, 156186322u),
	SC(1828023928u, 3606416364u, 840451334u, 2670120381u, 133606952u, 3979411971u, 3756265636u, 3090434524u, 1277480081u, 4153236500u, 1762321014u, 2309317937u, 888707593u, 3246269083u, 985085852u, 1839210952u)
},
{
	SC(1981590337u, 957784565u, 3778147127u, 3909235993u, 1637480329u, 2280601867u, 1059949562u, 2968107974u, 4043469535u, 4159249472u, 895867525u, 402468881u, 3186079639u, 86430659u, 4027560590u, 4067278225u),
	SC(3963997938u, 839996031u, 571331525u, 776702142u, 2399863185u, 3655810429u, 1738528605u, 2929574574u, 2886156335u, 3352266884u, 2399200150u, 1119216390u, 2001330442u, 1142692018u, 1684746191u, 1064710302u),
	SC(1881361970u, 1643307161u, 2706528897u, 2595735846u, 3177654277u, 15545698u, 1429642476u, 2237750939u, 2019191955u, 4066851471u, 3438523186u, 56173305u, 546163438u, 1764934268u, 3101952782u, 3383780192u),
	SC(2815008973u, 3278450586u, 1220182791u, 3732977113u, 2153332463u, 2653121522u, 1237936443u, 204190827u, 3561117875u, 2030804130u, 157509268u, 1855899717u, 1044294897u, 2837786770u, 2814153431u, 1654668604u)
},
{
	SC(1622151271u, 634353693u, 3884689189u, 1079019159u, 1060108012u, 22091029u, 115446660u, 534633082u, 1649201031u, 4042006969u, 137296836u, 1833810040u, 1562442638u, 3756418044u, 1181092791u, 160208619u),
	SC(1562663069u, 1589588588u, 2484720953u, 4033553041u, 1119890702u, 1146448444u, 124974212u, 1823967544u, 800515771u, 1973272503u, 1462074657u, 1124483621u, 3203313474u, 1285141542u, 2854738281u, 3562644896u),
	SC(1138023289u, 2038391829u, 2468643683u, 949488564u, 1016086543u, 2795023162u, 3124274336u, 2612082433u, 3803893695u, 3091535834u, 4021346615u, 1737416887u, 3153001828u, 1918263949u, 2128561912u, 952524797u),
	SC(3943586865u, 3646894885u, 2019127100u, 2315419208u, 1161518116u, 1292249075u, 3489387539u, 4173675954u, 691560448u, 2084345818u, 3423296048u, 444365932u, 2317205473u, 1398327084u, 1604520210u, 1666009611u)
},
{
	SC(2802315204u, 2299944053u, 2128407100u, 3463617348u, 2448441666u, 1070000794u, 1884246751u, 210372176u, 4075251068u, 1818330260u, 3223083664u, 3496698459u, 3376508259u, 4156094473u, 3718580079u, 1962552466u),
	SC(194186124u, 2794320749u, 2159380922u, 1927129131u, 1345048290u, 3415779817u, 2512593755u, 1165677766u, 2073034551u, 2574315956u, 437435054u, 4150429800u, 4248768515u, 3178144834u, 1180015424u, 975080438u),
	SC(174928435u, 4158717980u, 4003608508u, 3561506628u, 2852686007u, 2729724802u, 1504002726u, 3235296594u, 221206386u, 29543360u, 1903809106u, 1019269350u, 2488604738u, 2948288996u, 833023923u, 2449909516u),
	SC(3252518325u, 3856416592u, 721985911u, 2562399482u, 2949653074u, 467584997u, 4100275835u, 855886762u, 1434875587u, 14835128u, 3295402243u, 782094626u, 2843868240u, 3417958407u, 360641371u, 1444533180u)
},
{
	SC(1862109024u, 2933191225u, 198801920u, 104305860u, 4011109577u, 4122560610u, 1283427153u, 1072910968u, 1957473321u, 1766609671u, 2854361911u, 4075423370u, 2724854995u, 3336067759u, 2831739585u, 400030103u),
	SC(3453383733u, 3388805506u, 2297889713u, 531949640u, 2594355026u, 842506873u, 3392184606u, 3495815509u, 345903420u, 1239109165u, 3176194045u, 3176389873u, 2777114661u, 3657799448u, 3763821885u, 4086593267u),
	SC(2969423736u, 2622529529u, 2343792056u, 3686453319u, 918349654u, 3813685053u, 195351634u, 2215651341u, 2089448784u, 2444413637u, 2876364832u, 2226337257u, 3056652007u, 707231250u, 3702539781u, 561282206u),
	SC(3049935789u, 2012305053u, 2921080511u, 2225835633u, 2565015038u, 3793044966u, 4088579892u, 2862703090u, 248082141u, 2196577601u, 3431211987u, 196767056u, 1180294796u, 2924949673u, 2696237025u, 632085300u)
},
{
	SC(770670183u, 2030489407u, 913827766u, 28354808u, 2556411291u, 589717159u, 413516142u, 20574376u, 1695189435u, 3750527782u, 3546610407u, 1435363367u, 2770958348u, 2608593137u, 3331479090u, 2086258508u),
	SC(2222779586u, 4077859027u, 1090454134u, 2439504603u, 2544922883u, 2183064830u, 1678763169u, 3019219083u, 240763984u, 1050801371u, 206241990u, 3854111478u, 2108674322u, 1500986470u, 222791553u, 3140762944u),
	SC(1096246859u, 1269433403u, 2629392854u, 2527728897u, 1446363080u, 2718672644u, 3058137775u, 2846858917u, 65293585u, 1126911579u, 2537719558u, 1249408641u, 5386238u, 686469873u, 367377622u, 3559877098u),
	SC(1733527990u, 843256705u, 3149977067u, 552818346u, 826377225u, 245961995u, 2860489859u, 1102123594u, 2576762322u, 2048301596u, 3733352267u, 2926653552u, 3115547804u, 2744342141u, 2395800773u, 2243429789u)
},
{
	SC(2533741935u, 4150033708u, 3133949860u, 2798619408u, 806119564u, 266064305u, 1385120185u, 1697466874u, 3309272849u, 2305765083u, 4237655511u, 751372374u, 3319766406u, 1139025033u, 1880631363u, 2216696728u),
	SC(3979749264u, 1427446648u, 1315917960u, 3919278201u, 3527447043u, 3230304145u, 1984210489u, 2055954841u, 2226125452u, 1654657180u, 2952993132u, 623472013u, 1564350724u, 3251441858u, 510917329u, 977717921u),
	SC(555905577u, 3101608559u, 3271774689u, 1980231577u, 37536760u, 162179656u, 2522957948u, 2067517667u, 168118855u, 4239087243u, 4173152820u, 2782395372u, 2971506401u, 2855982516u, 2298196997u, 2806218529u),
	SC(1509040764u, 850370852u, 2577061459u, 2207507581u, 3595322161u, 2000554477u, 4031870545u, 814805117u, 323551199u, 3635260690u, 1131475336u, 3484712926u, 2821291631u, 245369191u, 1885454182u, 3761964146u)
},
{
	SC(1529327297u, 3326406825u, 3128910982u, 2593525414u, 42156971u, 3661621938u, 1244490461u, 1967679138u, 1025455708u, 720268318u, 2871990393u, 1117479541u, 1562094725u, 697888549u, 2324777980u, 3391621955u),
	SC(670055855u, 2742056506u, 3803464832u, 2073978745u, 2472669135u, 3453468195u, 1816736658u, 4052898812u, 4008573063u, 3448716784u, 2635548869u, 1651653718u, 831875200u, 3437956895u, 3239576879u, 2353313279u),
	SC(3540113602u, 2373194703u, 848875413u, 528313402u, 781027054u, 3320052693u, 3893252952u, 1213587531u, 1750521841u, 1586788154u, 1180481180u, 2340391265u, 2727907152u, 4257315287u, 1672030901u, 3645579941u),
	SC(2340972299u, 1929183944u, 1603744771u, 1385803033u, 1212945255u, 3358157939u, 304971975u, 2614002695u, 3381353004u, 990731332u, 848780301u, 852035476u, 1672340734u, 2462927940u, 1317954734u, 2047198676u)
},
{
	SC(1397828129u, 1248172308u, 2194412927u, 3657598991u, 2085616102u, 1202270518u, 3253032741u, 2632389423u, 1019922267u, 332153082u, 1521672215u, 2163564334u, 3102124007u, 582149809u, 329417494u, 188520915u),
	SC(706617574u, 2365306746u, 3961476710u, 3754018908u, 3298852314u, 1319966498u, 2373924403u, 1735507527u, 2985653547u, 1063670015u, 639146151u, 2831556465u, 1223226703u, 2745053007u, 2392123951u, 3006439562u),
	SC(1443727067u, 894328718u, 3897696342u, 2862419807u, 1663696040u, 737221545u, 4230565983u, 2037671469u, 3218417760u, 4096761229u, 2223583194u, 192457337u, 2437148391u, 40877205u, 3051452502u, 1404123256u),
	SC(616809483u, 3741612436u, 3493946169u, 3863830933u, 661534585u, 1753652070u, 1053684102u, 1191387261u, 1681590552u, 3369920130u, 1353333435u, 3681089999u, 4172047522u, 46648183u, 4019180114u, 919466652u)
},
{
	SC(87353816u, 3198238907u, 1232123158u, 3291424375u, 3695263554u, 2608617182u, 3798070797u, 3966302680u, 3847946128u, 278442153u, 3929504461u, 3056452729u, 3658519828u, 643043450u, 684101279u, 121314490u),
	SC(686618621u, 168961360u, 2197925237u, 1613292190u, 333084038u, 3635587819u, 4032948519u, 3707964851u, 3158182099u, 234103179u, 2284298045u, 3480607911u, 1251956347u, 1974274694u, 4181171310u, 929438050u),
	SC(2233115583u, 938378192u, 2199409274u, 1598252782u, 2330561833u, 3726791894u, 776218875u, 3411939105u, 1110676451u, 2474120935u, 2913066780u, 3957172359u, 1578191540u, 587569717u, 2523302528u, 125962068u),
	SC(2121069653u, 2640792943u, 2787524602u, 1775169550u, 4137636069u, 1247634947u, 1593538354u, 2981021719u, 1013779675u, 3349939747u, 474464324u, 3800807983u, 274339632u, 2094850473u, 3469944008u, 4151365282u)
},
{
	SC(3715433378u, 171840999u, 971741983u, 2238541363u, 3192426674u, 4094492328u, 467620204u, 194258737u, 3399274574u, 3279461044u, 1351137305u, 2503870624u, 193649547u, 2998335432u, 1712991547u, 2208648311u),
	SC(2555428913u, 869421506u, 166778442u, 4153679692u, 1197236377u, 241935878u, 2637786338u, 1999265363u, 2897031456u, 2998251513u, 547086286u, 886498720u, 2308742633u, 352858212u, 3092243839u, 773593819u),
	SC(337200504u, 1399030404u, 72828705u, 213399136u, 3202170111u, 3062657059u, 1061055118u, 494458775u, 156072464u, 4108660682u, 3361078208u, 2090300294u, 2971539355u, 3681445000u, 1744779607u, 686761302u),
	SC(3277492425u, 3522618864u, 643530617u, 3964076639u, 1978509205u, 665325373u, 696169182u, 2592458243u, 2486397933u, 223447012u, 1604979091u, 2271093793u, 3084922545u, 3302858388u, 3031087250u, 1063516216u)
},
{
	SC(3356584800u, 529363654u, 613773845u, 1186481398u, 3211505163u, 123165303u, 4059481794u, 1428486699u, 3074915494u, 3726640351u, 881339493u, 977699355u, 1396125459u, 3984731327u, 1086458841u, 3721516733u),
	SC(269451735u, 989948209u, 311519596u, 3229759219u, 101715278u, 276003801u, 727203188u, 454624220u, 2155088951u, 2793076258u, 3170555468u, 952002920u, 2121796311u, 830563326u, 1562604453u, 3066628470u),
	SC(399762888u, 2323422917u, 2321550379u, 207422836u, 1226652697u, 1825201637u, 528558453u, 3875352914u, 1719057328u, 2666562229u, 4176209563u, 583366985u, 1138701109u, 758289953u, 52662073u, 918293402u),
	SC(4157388463u, 1842676713u, 2794772257u, 2114208937u, 1680405111u, 753984785u, 3430137608u, 1493849205u, 2172497743u, 3830022u, 4063929091u, 1999254948u, 153962958u, 491583925u, 4259603773u, 682388728u)
},
{
	SC(3892284764u, 2210224198u, 97085365u, 934022966u, 3120556498u, 264721182u, 4011343025u, 1936310374u, 2593930315u, 3833725723u, 4141640186u, 2218699022u, 3726005369u, 649732123u, 1594208266u, 3687592104u),
	SC(3661305541u, 3709834743u, 1851009402u, 3602780986u, 250666799u, 1173441109u, 3734473218u, 1804296154u, 1729282666u, 3439817738u, 1884765971u, 4096666384u, 3988665003u, 4256503802u, 2053222254u, 2853986610u),
	SC(417666479u, 4268520051u, 3802974299u, 1841513928u, 4041007675u, 563789114u, 3533043334u, 1308819221u, 866092174u, 4038179869u, 4201939600u, 4066261022u, 1758380018u, 4091837615u, 4284827913u, 1677514005u),
	SC(1723722734u, 2349413871u, 846419238u, 3229076191u, 3150004227u, 2361299214u, 1712354056u, 2351882123u, 2445958079u, 957461918u, 225210341u, 803052180u, 1590990979u, 660311212u, 2145699387u, 1393326672u)
},
{
	SC(3639643416u, 3974502485u, 1527161781u, 180938703u, 2788643910u, 3418867931u, 2912046968u, 1776807950u, 1185488163u, 2433308651u, 3682797092u, 1938004308u, 753534320u, 795320477u, 3620835863u, 105275502u),
	SC(989224491u, 3070290035u, 3989786823u, 2436788149u, 1397633359u, 2733484183u, 704304527u, 3349453652u, 3674136808u, 2104551350u, 4212497903u, 2460411350u, 3486955763u, 1761471520u, 1998184581u, 2495319592u),
	SC(282793969u, 2332069888u, 1712291268u, 3517222842u, 20522682u, 1740053556u, 1372738943u, 2800828874u, 794545204u, 1363434049u, 3589633248u, 663242196u, 2153743019u, 3968122652u, 2744863688u, 2596121676u),
	SC(2870523585u, 1439405869u, 2438119706u, 914848314u, 2262774649u, 404517167u, 1916976607u, 2681794713u, 3099128859u, 3707542208u, 4228984251u, 6546639u, 1922067157u, 500889948u, 714001381u, 3135300137u)
},
{
	SC(3392929934u, 3483303263u, 1976307765u, 4193102460u, 1186037029u, 2559946979u, 3008510830u, 4008303279u, 2792795817u, 3991995u, 311426100u, 3736693519u, 1914150184u, 2000710916u, 1829538652u, 896726226u),
	SC(3473142724u, 297762785u, 1185673220u, 3972225082u, 621899093u, 1819279104u, 1900431376u, 2221994154u, 2852913559u, 3581768407u, 3207817907u, 1428681774u, 3343330191u, 2165549552u, 211415337u, 1262086079u),
	SC(1568159518u, 3414645127u, 3387315030u, 3545383094u, 3307092119u, 1871203699u, 3356344528u, 2208205606u, 1984240456u, 1553822824u, 1996586455u, 1093535414u, 751818141u, 2709522277u, 834332325u, 2996879219u),
	SC(3252620262u, 1610725935u, 709542825u, 1181660454u, 4084478688u, 1130923555u, 2413678545u, 3248667340u, 2830530261u, 725536582u, 3850673996u, 2088519335u, 868155176u, 223946842u, 1968507343u, 1549963360u)
},
{
	SC(2320406161u, 892569437u, 3092616448u, 1707673477u, 2810327980u, 4012118332u, 4142748730u, 3869507620u, 92116036u, 2366184953u, 1613655167u, 3287845172u, 3562699894u, 416962379u, 1296831910u, 1764080884u),
	SC(45078160u, 3147040521u, 3977924485u, 1097174861u, 625925083u, 2053439479u, 3228340300u, 75304135u, 3524751472u, 1003341068u, 3156318916u, 1655110323u, 1486337360u, 3495426543u, 2205859914u, 4129504303u),
	SC(179136070u, 2215032909u, 947400282u, 1721490941u, 3257375703u, 3746065879u, 2481020802u, 1203477754u, 1544186038u, 543550381u, 4085618153u, 1601848574u, 738032808u, 1321970306u, 2906258391u, 3047272421u),
	SC(1249716000u, 458263861u, 2828755974u, 1760140511u, 1514147100u, 3407967019u, 3844060237u, 102517947u, 225529033u, 2639856492u, 1300412008u, 3897740626u, 3570441124u, 4093670214u, 3351362455u, 590024637u)
},
{
	SC(1167035839u, 2632944828u, 1562396359u, 1120559767u, 244303722u, 181546963u, 2941229710u, 561240151u, 1460096143u, 346254175u, 110249239u, 1849542582u, 1293066381u, 147850597u, 3876457633u, 1458739232u),
	SC(2533499636u, 3080420164u, 197200931u, 500624683u, 758387417u, 2720398129u, 1407768115u, 1475529124u, 1364265290u, 4069280537u, 1716757546u, 3709805168u, 1357954285u, 3857265562u, 3466627967u, 3830420311u),
	SC(1593643391u, 105228547u, 3712827232u, 1923217888u, 1012568533u, 3355714151u, 528029511u, 3744649120u, 1997200748u, 2604985542u, 1803182035u, 939655107u, 288091786u, 2936799939u, 4234437447u, 4219765747u),
	SC(4293306586u, 716919424u, 760979011u, 3536867423u, 4117027719u, 1461165141u, 807633747u, 3306967909u, 1327104245u, 4288993u, 1708394265u, 2341551077u, 4203016216u, 1355022627u, 2594871517u, 3003370353u)
},
{
	SC(3539989726u, 2664422354u, 3717852078u, 3493347675u, 431408204u, 2534904428u, 166307432u, 1071633271u, 2817060747u, 2307358268u, 3433391820u, 2071844151u, 219511979u, 303896099u, 3062367591u, 2892429963u),
	SC(1521430849u, 1321457442u, 1977165985u, 3332712657u, 3377259048u, 434866482u, 185442588u, 2655667572u, 1565093599u, 3283113197u, 1535104380u, 3878806555u, 2771912862u, 432083506u, 780421961u, 2441979755u),
	SC(91851120u, 228847150u, 3596486782u, 2178535008u, 4219396564u, 341504363u, 1118079131u, 834044504u, 2324675143u, 2964510486u, 1663366491u, 339426068u, 2599455152u, 3701183831u, 1086709651u, 812090397u),
	SC(3028475944u, 4191152422u, 1836925042u, 3223138538u, 685748126u, 646944669u, 4205775633u, 1329728837u, 3990855947u, 2092573299u, 1336025608u, 1375487930u, 2188514371u, 430312768u, 1649233533u, 1162542961u)
},
{
	SC(3015000623u, 325176924u, 3212623969u, 1014540936u, 2686878702u, 3453922035u, 257234635u, 689320672u, 395365200u, 3425465866u, 3351439740u, 3293249321u, 2261203941u, 1504215424u, 2365812346u, 2486464854u),
	SC(875927111u, 1597748031u, 3937158235u, 1433716656u, 3539791089u, 1352702162u, 1146570941u, 1210801675u, 2091841778u, 1252234389u, 1781967815u, 108023679u, 4156463906u, 1849298948u, 3158166728u, 978898853u),
	SC(1342189835u, 1853962572u, 1334929275u, 2688310434u, 1583097217u, 3182342944u, 1463806924u, 1272330490u, 472090228u, 108343030u, 626158941u, 478208262u, 3294264195u, 2684195168u, 3152460770u, 2153166130u),
	SC(3196336832u, 463403692u, 2914369607u, 77355408u, 1950461914u, 2402529709u, 553005914u, 1542102018u, 487903348u, 196020857u, 1813404195u, 4204446770u, 3295634806u, 2206606794u, 494127093u, 846727344u)
},
{
	SC(771871546u, 3238832643u, 2874232693u, 1176661863u, 1772130049u, 1442937700u, 2722327092u, 1148976574u, 4122834849u, 744616687u, 1621674295u, 3475628518u, 2284524224u, 1048213347u, 4058663310u, 153122870u),
	SC(3356509186u, 1884900443u, 4108545327u, 3986583476u, 758524745u, 1588296209u, 723393574u, 2862746860u, 2476163508u, 3679829155u, 1401397106u, 1667387791u, 2555611797u, 1998885507u, 3861616822u, 3016121396u),
	SC(1082144930u, 2812004556u, 4059994359u, 3621635972u, 687684721u, 3983270965u, 3614380944u, 3981328064u, 767324997u, 4104345798u, 4184408595u, 520362170u, 766639361u, 2118637735u, 1480405192u, 3879741370u),
	SC(2400086865u, 1356288676u, 2263936429u, 2831293204u, 528118727u, 762933811u, 1782971542u, 2357556867u, 1020395032u, 35590801u, 2105980457u, 2908398314u, 1176779916u, 965469552u, 4053114186u, 1203094477u)
},
{
	SC(2470971363u, 1622646280u, 3521284388u, 611900249u, 53592433u, 1667691553u, 3986964859u, 3228144262u, 4160240678u, 1357358974u, 796266088u, 2135382104u, 2999113584u, 425466269u, 866665252u, 3795780335u),
	SC(1942107538u, 2061531898u, 486277903u, 2831709377u, 3872945828u, 1947502926u, 3755578321u, 546304669u, 3256189062u, 3873222776u, 979380359u, 3587670204u, 1851918662u, 2435187337u, 1380244930u, 4186681845u),
	SC(3850950458u, 1857044284u, 1191196687u, 401916778u, 1094802678u, 1136464563u, 2120150485u, 325136004u, 974963693u, 585059474u, 2531240419u, 1068453941u, 3498354420u, 4245078651u, 3921542910u, 198121299u),
	SC(2145536262u, 1213879864u, 1118717819u, 3734026403u, 428130114u, 2135123466u, 4045420301u, 3479846205u, 381626330u, 1157860434u, 2785350296u, 637768566u, 2801530882u, 1480517018u, 2538790153u, 4077551317u)
},
{
	SC(2899222640u, 2858879423u, 4023946212u, 3203519621u, 2698675175u, 2895781552u, 3987224702u, 3120457323u, 2482773149u, 4275634169u, 1626305806u, 2497520450u, 1604357181u, 2396667630u, 133501825u, 425754851u),
	SC(1093436137u, 4178194477u, 4093951855u, 3277329686u, 2989824426u, 784494368u, 2625698979u, 525141656u, 833797048u, 1228803093u, 2037224379u, 1506767058u, 2140956084u, 3014084969u, 2249389870u, 2754500395u),
	SC(3234726675u, 1387338169u, 2035693016u, 1580159315u, 2740014444u, 420358668u, 4193254905u, 3166557951u, 3035589053u, 3563526901u, 736535742u, 28001376u, 1900567167u, 1876824307u, 1708886960u, 2448346802u),
	SC(3080860944u, 2883831675u, 924844138u, 165846124u, 403587242u, 2292097283u, 3928197057u, 375892634u, 2252310583u, 4209996391u, 3622004117u, 2707281828u, 2986420019u, 3342106111u, 83951999u, 411887793u)
},
{
	SC(172527491u, 737404283u, 1378219848u, 1967891125u, 3449182151u, 391223470u, 304889116u, 3996348146u, 1311927616u, 1686958697u, 766780722u, 1429807050u, 1546340567u, 1151984543u, 3172111324u, 2189332513u),
	SC(3210880994u, 2807853439u, 4215115106u, 907776530u, 73135694u, 2979353837u, 285477682u, 1377541714u, 546842365u, 1106807941u, 4178267211u, 4178357152u, 2629472682u, 1753007362u, 599552459u, 2136234403u),
	SC(3236743822u, 2429982619u, 1421470122u, 1518357646u, 275483457u, 2785654877u, 405065849u, 3803799408u, 485052728u, 728694599u, 2522926080u, 2396484137u, 2970704111u, 366573577u, 2787456057u, 3096233215u),
	SC(1028153825u, 101097231u, 3719093015u, 1499355615u, 1419801462u, 1110946460u, 271497731u, 588106554u, 1130341153u, 2430884299u, 326125271u, 3541499135u, 1876347220u, 2833401711u, 1027135976u, 641592145u)
},
{
	SC(2759056966u, 2773771898u, 915395955u, 378399267u, 1065424189u, 3786627878u, 2430240867u, 1910948145u, 1268823138u, 2460932406u, 2049702377u, 3729301642u, 2270156417u, 2935515669u, 1488232015u, 333167852u),
	SC(1130030158u, 1325805486u, 1928073773u, 3083689306u, 1906071689u, 2809061745u, 3188612193u, 3317879112u, 3567699092u, 531617155u, 968200745u, 3011814843u, 2232684249u, 3100416438u, 955880884u, 541389696u),
	SC(3245402443u, 2411721740u, 362516442u, 179736723u, 1239928465u, 23431842u, 2304788940u, 1454698033u, 431248900u, 3858938538u, 1887822458u, 1775776127u, 653046597u, 2774049761u, 1414971814u, 1569319314u),
	SC(704920417u, 4125239619u, 430148455u, 3015651212u, 2310935918u, 1678858669u, 3376497865u, 2535125909u, 400017377u, 1812558422u, 3188521745u, 3651390935u, 2345298458u, 3377548855u, 1062840923u, 3297700764u)
},
{
	SC(1198357412u, 890731121u, 697460724u, 351217501u, 1219769569u, 940317437u, 2678867462u, 4175440864u, 2131908090u, 1470497863u, 3243074932u, 494367929u, 1767796005u, 457609517u, 3543955443u, 4149669314u),
	SC(2890647893u, 2867067516u, 2762753699u, 2227974015u, 1022828403u, 2975716284u, 810630306u, 2107801738u, 1766778088u, 1878607300u, 1247804730u, 429284069u, 773180585u, 3038594965u, 2237573847u, 4237662217u),
	SC(1135933156u, 634281942u, 46520021u, 3459499714u, 3745856618u, 2680896277u, 2214246977u, 1778311725u, 3755609700u, 1462691663u, 532464646u, 2021260220u, 3012125251u, 1892990074u, 1736371648u, 2739088972u),
	SC(3804290341u, 2530898158u, 627690883u, 3467192350u, 3816583964u, 3490783256u, 2036783742u, 1974061789u, 4168871160u, 3978339846u, 4173216236u, 732951855u, 1616132185u, 4223609757u, 797743411u, 2206950663u)
},
{
	SC(1331866444u, 3086683411u, 308412705u, 2554456370u, 2967351597u, 1733087234u, 827692265u, 2178921377u, 289799640u, 3318834771u, 2836568844u, 972864473u, 1500041772u, 4280362943u, 2447939655u, 904037199u),
	SC(3391923614u, 2903769192u, 3834144138u, 2204143784u, 3953665264u, 1013613048u, 4275124566u, 2254380009u, 4175595257u, 2392625155u, 3832552958u, 2209848288u, 3564495648u, 2361851297u, 2215206748u, 2634903731u),
	SC(3941037520u, 2365666457u, 1610398325u, 866573713u, 705163077u, 1512109211u, 2390458066u, 1976812875u, 2857084758u, 3708539243u, 854092926u, 2770390554u, 3156364591u, 136447390u, 1039322495u, 3637639253u),
	SC(3679874068u, 3165524081u, 235657258u, 2056673906u, 270355292u, 701332141u, 3374210713u, 4100229496u, 2018939216u, 1505362994u, 989686331u, 2925442307u, 4179636623u, 637307973u, 3518037557u, 4240093409u)
},
{
	SC(286197159u, 1217476806u, 1373931377u, 3573925838u, 1757245025u, 108852419u, 959661087u, 2721509987u, 123823405u, 395119964u, 4128806145u, 3492638840u, 789641269u, 663309689u, 1335091190u, 3909761814u),
	SC(2114197930u, 3273217012u, 1940661926u, 2163906966u, 2123303670u, 414878308u, 233356929u, 871664495u, 3069135830u, 1535289677u, 3883199366u, 1672311108u, 4029021246u, 3634506188u, 2941888534u, 1547199375u),
	SC(3960259180u, 1615091325u, 1620898588u, 3363101089u, 2219794907u, 934039044u, 273251845u, 3349991112u, 536889464u, 1065166606u, 2165591368u, 3968048577u, 3521960647u, 1972440812u, 2996053529u, 3367680654u),
	SC(2485891685u, 1835858186u, 72029953u, 1996135211u, 3815169470u, 4242647100u, 3409890124u, 1431709388u, 3766365750u, 713252238u, 828380183u, 4212677126u, 346703256u, 1754695691u, 4057960681u, 2858172583u)
},
{
	SC(136266275u, 1782161742u, 3530966629u, 586004249u, 4076565170u, 3312577895u, 876489815u, 1337331291u, 888213221u, 1813863938u, 1374206604u, 2668794769u, 1377764865u, 784024905u, 1937217146u, 3627318859u),
	SC(4186161750u, 3049560710u, 1810996291u, 1342717770u, 2124217256u, 1916618560u, 4136670260u, 994193328u, 299707519u, 382044359u, 3598048722u, 3196118917u, 1358315449u, 521912342u, 3156838683u, 4122728661u),
	SC(939267225u, 2510882408u, 2826027661u, 2396536978u, 3106471061u, 742759533u, 13494147u, 684275437u, 3769662715u, 1875002414u, 1146684269u, 3167752575u, 3278332143u, 789595870u, 392640294u, 2752714463u),
	SC(1341948462u, 2439353587u, 4194335954u, 1747913821u, 2444768684u, 3688508118u, 985904958u, 1351917941u, 1073165051u, 1471080717u, 2911301092u, 1526345240u, 3378121335u, 3603759243u, 298408956u, 3700586563u)
},
{
	SC(768143995u, 3015559849u, 803917440u, 4076216623u, 2181646206u, 1394504907u, 4103550766u, 2586780259u, 2146132903u, 2528467950u, 4288774330u, 4277434230u, 4233079764u, 751685015u, 1689565875u, 271910800u),
	SC(3281376452u, 3631727304u, 646324697u, 1606373178u, 3213071634u, 3331180703u, 2195122007u, 3549662455u, 188195908u, 2766615075u, 541563331u, 3750074457u, 2301537882u, 1938050313u, 2637425350u, 930585210u),
	SC(3541324984u, 3025021488u, 961967352u, 2883342260u, 1791115953u, 1760623833u, 3315383837u, 3369251966u, 3315911652u, 1871148493u, 2491604498u, 1271874682u, 350706514u, 1961904735u, 3348178007u, 3810151810u),
	SC(3241391980u, 2699509892u, 2994316388u, 3715979957u, 2191426308u, 2911623554u, 3001094818u, 2672108146u, 1002718225u, 1706079745u, 2478567249u, 1679500649u, 2776278473u, 1632698291u, 2473525446u, 3057863552u)
},
{
	SC(294473811u, 4198428764u, 2165111046u, 977342291u, 950658751u, 1362860671u, 1381568815u, 4165654500u, 2742156443u, 3373802792u, 668387394u, 853861450u, 2637359866u, 2230427693u, 2824878545u, 103849618u),
	SC(703667981u, 341297647u, 1986045687u, 4022611577u, 4119515932u, 502525570u, 864382000u, 408568146u, 1623993579u, 1515217702u, 1701976571u, 1519123656u, 220794715u, 503707450u, 1598098448u, 1792646128u),
	SC(2876602938u, 2062812830u, 592002095u, 964212911u, 1742157290u, 2453152641u, 1920771744u, 3744498389u, 861815181u, 448965745u, 2175363707u, 2098578783u, 4173783874u, 2208989085u, 145625870u, 3688955201u),
	SC(938020790u, 186217808u, 349235829u, 519257124u, 2685242610u, 1590527094u, 2329590692u, 1198678263u, 2429439347u, 1981005487u, 1049116726u, 1349644548u, 193504650u, 2496138058u, 20076180u, 1915403182u)
},
{
	SC(1451965994u, 766802222u, 1324674662u, 350355960u, 2823290314u, 951779387u, 2914020724u, 508533147u, 1932833685u, 1640746212u, 1238908653u, 542788672u, 3642566481u, 2475403216u, 1859773861u, 3791645308u),
	SC(2385975325u, 3901946471u, 1059505820u, 4136894980u, 3371558324u, 2046981257u, 3127837356u, 3095019775u, 2618964688u, 3208744403u, 2271447215u, 3562826422u, 3752327158u, 2498335203u, 250644830u, 2105168329u),
	SC(3475923760u, 323425264u, 3484578422u, 2657477806u, 138246715u, 2224032426u, 1026741249u, 1436653171u, 3097535946u, 3954907075u, 153306250u, 1987577071u, 1136330091u, 1917088242u, 95455667u, 3967280211u),
	SC(2886596919u, 3537263282u, 3871156396u, 1985289080u, 3165778829u, 2180614377u, 1071823085u, 1946857657u, 4115069682u, 302722706u, 1817120536u, 1238106603u, 2202932230u, 3047902548u, 3208297762u, 725675045u)
},
{
	SC(2083716311u, 321936583u, 1157386229u, 758210093u, 3570268096u, 833886820u, 3681471481u, 4249803963u, 2130717687u, 3101800692u, 172642091u, 421697598u, 4220526099u, 1506535732u, 2318522651u, 2076732404u),
	SC(208856640u, 4030733534u, 2480428900u, 575090910u, 2370193275u, 1401235634u, 1396054131u, 3388186107u, 1461125298u, 3044442692u, 1666455609u, 2712178876u, 3699523129u, 175969151u, 2654070857u, 1480298430u),
	SC(1006030828u, 2198412446u, 471722680u, 1651593837u, 2644180195u, 520432186u, 3370897833u, 1224758384u, 905707335u, 3162313659u, 427715965u, 1348036119u, 7970923u, 3914776522u, 1719464048u, 3087746526u),
	SC(873912787u, 1814834283u, 2007356999u, 1342903388u, 2456597479u, 451640963u, 270386192u, 2804676632u, 3347423428u, 1946728624u, 817071823u, 2654597615u, 2075935576u, 4134394912u, 582072193u, 2359391692u)
},
{
	SC(701959589u, 2450082966u, 3801334037u, 1119476651u, 3004037339u, 2895659371u, 1706080091u, 3016377454u, 2829429308u, 3274085782u, 3716849048u, 2275653490u, 4020356712u, 1066046591u, 4286629474u, 835127193u),
	SC(3165586210u, 507538409u, 1576069592u, 2044209233u, 712092282u, 2055526594u, 13545638u, 2637420583u, 2057228124u, 4021333488u, 3231887195u, 3698074935u, 2986196493u, 3191446517u, 1855796754u, 2840543801u),
	SC(2049241981u, 3601384056u, 3450756305u, 1891508453u, 3117006888u, 4292069886u, 1305738264u, 1168325042u, 1885311802u, 3504110100u, 2016985184u, 2881133505u, 1880280254u, 2204317009u, 1399753402u, 3367366171u),
	SC(3277848307u, 2856992413u, 2480712337u, 2842826539u, 2019400062u, 3739668276u, 3783381527u, 2747809175u, 304494821u, 3082618281u, 475713753u, 3181995879u, 103289908u, 3708783250u, 1444805053u, 2524419441u)
},
{
	SC(2022030201u, 622422758u, 4099630680u, 255591669u, 2746707126u, 492890866u, 1170945474u, 626140794u, 2553916130u, 3034177025u, 437361978u, 3530139681u, 3716731527u, 788732176u, 2733886498u, 780490151u),
	SC(3022387205u, 643413342u, 1262913870u, 882426483u, 3783696379u, 2282658896u, 549384772u, 2907119271u, 2965235271u, 258220726u, 2834889991u, 175082611u, 1532630973u, 2641278331u, 873736728u, 2474793598u),
	SC(3436994124u, 1972613506u, 2802593687u, 3277380489u, 4121992441u, 3728497631u, 709132430u, 2822775775u, 2147792195u, 3749335406u, 4209749501u, 3255963905u, 448371535u, 3349728753u, 1134914300u, 2326210644u),
	SC(3579789737u, 857648536u, 3677955192u, 2929905256u, 2925305732u, 396144337u, 2879772175u, 611276653u, 1139725609u, 1640545337u, 2376692224u, 2465623832u, 1774091714u, 3594842769u, 2562599181u, 2913715875u)
},
{
	SC(69398569u, 525452511u, 2938319650u, 1880483009u, 3967907249u, 2829806383u, 1621746321u, 1916983616u, 1370370736u, 248894365u, 3788903479u, 221658457u, 404383926u, 1308961733u, 2635279776u, 2619294254u),
	SC(847745551u, 4043085379u, 2601189120u, 3600040994u, 696074066u, 1966732665u, 2566798633u, 2160875716u, 3937088627u, 223752161u, 1824023635u, 1377996649u, 4082040542u, 1765057927u, 3462559245u, 1605863066u),
	SC(2848864118u, 745552607u, 3815587692u, 2049639609u, 680251550u, 1505718232u, 39628972u, 2226898497u, 513707523u, 2917769605u, 3496480640u, 2593784936u, 590913979u, 1339822749u, 4138230647u, 49928841u),
	SC(2806514274u, 3132555732u, 291777315u, 1351829393u, 2386116447u, 1029032493u, 4242479447u, 4060892676u, 1174959584u, 2813312363u, 4001665503u, 3521645400u, 2629458899u, 2800015182u, 2767567980u, 1450467540u)
},
{
	SC(1137648243u, 3815904636u, 35128896u, 1498158156u, 2482392993u, 1978830034u, 1585381051u, 335710867u, 529205549u, 1286325760u, 863511412u, 283835652u, 936788847u, 101075250u, 116973165u, 2483395918u),
	SC(3811042814u, 1025568765u, 2303929459u, 3941141514u, 909479518u, 1708127829u, 2992362277u, 2201573791u, 823734954u, 2387361592u, 3479939442u, 3649512837u, 1364854u, 1175064965u, 1798998971u, 4010084758u),
	SC(1608551539u, 1659476372u, 3926136551u, 3533578126u, 1457941418u, 4020190424u, 1198729568u, 3336914362u, 4181147510u, 1513359382u, 3454065551u, 1215128659u, 1394347719u, 1306437422u, 671973186u, 802663808u),
	SC(1546843556u, 1958213360u, 3222927312u, 2732547191u, 1075305498u, 4181416960u, 3176341164u, 843613705u, 2496268523u, 1032252253u, 3102939981u, 2488641222u, 354787535u, 3012081304u, 1337099975u, 411906451u)
},
{
	SC(2668669863u, 1518051232u, 591131964u, 3625564717u, 2443152079u, 2589878039u, 747840157u, 1417298109u, 2236109461u, 625624150u, 2276484522u, 3671203634u, 3004642785u, 2519941048u, 286358016u, 3502187361u),
	SC(3043862272u, 290382966u, 559153561u, 3883639409u, 3906304164u, 1541563334u, 3470977197u, 4214898248u, 602703812u, 594285209u, 2528808255u, 3100412656u, 2962818092u, 1713626799u, 716968139u, 3245684477u),
	SC(2849591287u, 2780695223u, 1518691286u, 2959190176u, 132195984u, 1215364670u, 969199256u, 2481548041u, 2367363880u, 2687921445u, 2786812285u, 2680226196u, 1929068126u, 4284277820u, 2652631532u, 1888216766u),
	SC(4221543413u, 941544184u, 3103000498u, 2576480775u, 2799149669u, 1305654192u, 3489282068u, 284158188u, 2392559975u, 3208820720u, 1806838706u, 1068764673u, 3216687520u, 3670357690u, 2977855856u, 2151602676u)
},
{
	SC(3009793609u, 3525092161u, 3245586135u, 574145899u, 4034974232u, 2828949446u, 3457574134u, 1546193476u, 3883480541u, 1976722737u, 3557056370u, 994794948u, 106991499u, 1626704265u, 3534503938u, 3271872260u),
	SC(4111653395u, 3737153809u, 724361214u, 4146801440u, 2864192452u, 2352288978u, 4143003150u, 3927435349u, 959755099u, 2267451506u, 2008749851u, 4197184096u, 608903018u, 331201150u, 171852728u, 3631057598u),
	SC(1040189192u, 3135235581u, 3623291082u, 2461882244u, 2161120847u, 3614159035u, 1308293611u, 3846387110u, 1899566537u, 2082151738u, 1896999495u, 1814244229u, 1384043307u, 510412164u, 3476482520u, 1522244992u),
	SC(3337187848u, 401607407u, 1233709719u, 2407137856u, 4024737998u, 541061391u, 1304919595u, 246716724u, 3564946135u, 4041513396u, 2555398397u, 16604948u, 2211576077u, 2712388351u, 873042891u, 3886941140u)
},
{
	SC(941124125u, 1620226392u, 1431256941u, 3336438938u, 540497787u, 766040889u, 373284400u, 2979905322u, 177008709u, 2625544842u, 1096614388u, 1196846420u, 4186360501u, 3945210662u, 1143943919u, 3412870088u),
	SC(2895190615u, 525902467u, 1367284455u, 2066663630u, 465251607u, 1043189793u, 3148821806u, 3989460909u, 3387524595u, 4067968571u, 1719999600u, 220864914u, 697973681u, 2059667041u, 3220246185u, 695421754u),
	SC(2590577156u, 795774194u, 1904860775u, 4031583685u, 3087922830u, 3668434043u, 1959821395u, 3811394838u, 2785704637u, 1682504742u, 1028254204u, 850730757u, 360229062u, 1954705497u, 3724255123u, 4100070091u),
	SC(2389626852u, 3853851132u, 3195796535u, 1527199924u, 1636717958u, 3735641313u, 2340881444u, 1438175706u, 1296406867u, 1406099139u, 1135839981u, 3285630759u, 2200113083u, 2680217927u, 97279145u, 1781800696u)
},
{
	SC(3638948794u, 3243385178u, 2365114888u, 1084927340u, 2097158816u, 336310452u, 231393062u, 580838002u, 3851653288u, 568877195u, 3846156888u, 2754011062u, 3396743120u, 2639744892u, 1431686029u, 1903473537u),
	SC(672929266u, 4278630514u, 1561041442u, 629394401u, 4070337497u, 2103696271u, 1114356663u, 4084071767u, 3393530368u, 4249550216u, 4113997504u, 1530567080u, 2126274764u, 3676929390u, 2903800270u, 2831711217u),
	SC(1774590259u, 3105493546u, 906525537u, 532177778u, 1023077482u, 1582413022u, 2646097845u, 3428458076u, 414285421u, 1960194778u, 2425645337u, 782659594u, 3724227825u, 4114081279u, 1478362305u, 2537782648u),
	SC(3917166800u, 2613468339u, 1109027751u, 2667491623u, 385647357u, 3040475468u, 470189721u, 715873976u, 1126450033u, 763992434u, 2850815403u, 1253615059u, 3081849614u, 1691888978u, 1354336093u, 3217678760u)
},
{
	SC(4095464112u, 3774124339u, 1954448156u, 2941024780u, 584234335u, 483707475u, 286644251u, 3027719344u, 2257880535u, 651454587u, 3313147574u, 3910046631u, 3169039651u, 2576160449u, 696031594u, 3062648739u),
	SC(3054900837u, 3109053155u, 2935799989u, 304144852u, 3697886700u, 1064553036u, 1195677074u, 3398925561u, 3991559971u, 3873262014u, 2104594364u, 3493235682u, 2872792428u, 3787578901u, 495000705u, 1153422238u),
	SC(4020389332u, 927192013u, 2251972932u, 3404323722u, 3350728280u, 1270028902u, 459737918u, 2709152689u, 3434679250u, 2153846755u, 931264509u, 2126662946u, 3054979751u, 478875445u, 3173181787u, 2136988011u),
	SC(4284049546u, 4227908558u, 367047421u, 3626594909u, 683266175u, 167449575u, 1642758028u, 203888916u, 2541346079u, 2856877101u, 3032791880u, 947365960u, 3274309224u, 1388337804u, 2089622609u, 2510882246u)
},
{
	SC(1740919499u, 3877396933u, 2326751436u, 2985697421u, 1447445291u, 2255966095u, 1611141497u, 1834170313u, 3589822942u, 2703601378u, 299681739u, 3037417379u, 4014970727u, 2126073701u, 3064037855u, 2610138122u),
	SC(612113943u, 1245695464u, 1476531430u, 3079777536u, 1504285401u, 2225606450u, 1678648810u, 943829390u, 446653322u, 1948420681u, 235420476u, 3258122799u, 110378212u, 1165072842u, 821178579u, 1123751364u),
	SC(3547216247u, 1712463318u, 2944825066u, 358566040u, 3226130169u, 3598877722u, 1745994951u, 755648908u, 1640001837u, 618372504u, 3714960843u, 3768940664u, 3050068616u, 3559674055u, 3589358798u, 2839014385u),
	SC(2963615519u, 749556918u, 1703544736u, 3714369503u, 3794250303u, 2736990653u, 3473783325u, 187948579u, 3344991023u, 2615291805u, 3352394273u, 1176851256u, 636324605u, 342413373u, 3601749395u, 1908387121u)
},
{
	SC(1456510740u, 215912204u, 253318863u, 2775298218u, 3073705928u, 3154352632u, 3237812190u, 434409115u, 3593346865u, 3020727994u, 1910411353u, 2325723409u, 1818165255u, 3742118891u, 4111316616u, 4010457359u),
	SC(2691740498u, 3975883270u, 3562065855u, 1744885675u, 1858951364u, 2782293048u, 2737897143u, 1939635664u, 577670420u, 2332511029u, 3680505471u, 1270825205u, 3377980882u, 280451038u, 932639451u, 530901151u),
	SC(2901569236u, 2626505212u, 1775779590u, 378175149u, 2007032171u, 2315048377u, 1708789093u, 1573616959u, 1418282545u, 1543307855u, 3489633010u, 3744345320u, 2558277726u, 1632098179u, 1630179771u, 1410404973u),
	SC(867779817u, 4224370363u, 1242180757u, 377585886u, 4220054352u, 130802516u, 2286612526u, 3690324161u, 168683327u, 2352367282u, 3756724843u, 16820454u, 4121820500u, 774287909u, 3499546464u, 2432203874u)
},
{
	SC(822693957u, 1703644293u, 3960229340u, 2092754577u, 3495958557u, 4288710741u, 4092815138u, 1275224613u, 2592916775u, 472063207u, 2931222331u, 2597044591u, 1261640449u, 1272207288u, 2040245568u, 1417421068u),
	SC(1212624844u, 3724128435u, 2580172104u, 625382842u, 1273692890u, 2224567242u, 4268246350u, 675911881u, 2693399366u, 2212843482u, 3533831779u, 548831153u, 3045738097u, 3033563506u, 2981560259u, 3280282777u),
	SC(583780584u, 3805688551u, 3154056802u, 1265342235u, 2919963666u, 348340950u, 1643957290u, 2937675860u, 531521986u, 2554579484u, 1858445667u, 4045167738u, 32261687u, 71331634u, 108677060u, 3239178045u),
	SC(1344583311u, 144481968u, 4266530071u, 1919888623u, 3530616056u, 405657629u, 550918759u, 2378701874u, 2502453716u, 1249298754u, 2895906070u, 4229345751u, 2698935239u, 1068605837u, 2804235531u, 3419996572u)
},
{
	SC(3660855132u, 3816892380u, 3431508003u, 1440179111u, 768988979u, 3652895254u, 2084463131u, 3991218655u, 323118457u, 3675476946u, 2157306354u, 2684850253u, 1543808805u, 744627428u, 1091926767u, 3538062578u),
	SC(212299625u, 2474466692u, 1704971793u, 3789350230u, 256182388u, 1544421436u, 1581730692u, 1364885237u, 3537961026u, 2803777125u, 3509128589u, 2069072362u, 1096176266u, 640924181u, 3219718394u, 3309717817u),
	SC(2373604216u, 2465825031u, 1037036044u, 2538660397u, 3827328679u, 3459992854u, 2334021373u, 3366566203u, 3392318169u, 190647171u, 2398010849u, 2394404134u, 2171187374u, 2435135993u, 77207937u, 3590739715u),
	SC(3582764810u, 1359502830u, 1025246886u, 329622637u, 584170095u, 1618468670u, 4135269305u, 1632135623u, 3173068118u, 1159468553u, 2477498366u, 2473706416u, 1990379266u, 3619760163u, 3999703172u, 4001561563u)
},
{
	SC(2819478132u, 2629026829u, 2945562911u, 1854605392u, 41922071u, 2531530491u, 2316774439u, 3550381961u, 1180787169u, 3914439365u, 3786421842u, 3441223373u, 494782102u, 2858003292u, 1448968751u, 2940369046u),
	SC(3794875745u, 2254091108u, 118588821u, 3886088825u, 1251278642u, 1219961983u, 2719820348u, 2423061629u, 2599856244u, 220341580u, 4048073849u, 2104530045u, 811981063u, 3760141810u, 1863614748u, 3139122890u),
	SC(3679877447u, 1244259754u, 3066916057u, 2660429719u, 569074139u, 934334703u, 671572554u, 3842972464u, 288530523u, 4182111156u, 1001852850u, 519081958u, 204295960u, 4012888918u, 1945355312u, 1860648163u),
	SC(994404842u, 2682995800u, 29922853u, 1597633752u, 1062800697u, 3306110457u, 520491033u, 3356053075u, 2549792314u, 3477041846u, 3253737096u, 1762450113u, 3375037999u, 2602209592u, 3113557911u, 3720142223u)
},
{
	SC(3017729014u, 3423125690u, 1534829496u, 1346803271u, 888659105u, 1661894766u, 4165031912u, 697485157u, 3575889724u, 1795181757u, 1507549874u, 1480154979u, 3565672142u, 830054113u, 1507719534u, 3652903656u),
	SC(2479103645u, 4018184950u, 2479614475u, 3317764526u, 301828742u, 960498044u, 3094690160u, 3809621811u, 2208635829u, 2224317619u, 3998999734u, 1548883437u, 1441132887u, 3683345599u, 2867687577u, 1233120778u),
	SC(1791101835u, 1817384161u, 1923325009u, 2735725895u, 3675660639u, 3891077763u, 1995919027u, 1905059636u, 1940967335u, 3392681720u, 367988187u, 3612123786u, 3090191283u, 1256462996u, 3912097760u, 2309957363u),
	SC(1966524664u, 3700727165u, 3292074144u, 2147997405u, 2207840483u, 686614845u, 2478395761u, 2099930233u, 1138889901u, 741741915u, 410612689u, 3168582608u, 1480885392u, 2712155566u, 795218052u, 3627485712u)
},
{
	SC(3751554592u, 1759634227u, 4138518211u, 3130599659u, 3881948336u, 669688286u, 3672211577u, 695226401u, 1226786139u, 1855160209u, 905875552u, 2831529665u, 1625185017u, 3130043300u, 3227522138u, 3659203373u),
	SC(3678343731u, 3378294720u, 2783724068u, 44445192u, 1952301657u, 683256120u, 3868461065u, 154627566u, 2492480331u, 688442697u, 2515568703u, 27336037u, 2282124228u, 4010257051u, 1410784834u, 2387531542u),
	SC(2767037774u, 3374543263u, 2353734014u, 740321548u, 1502005361u, 4208562518u, 2317313556u, 1296623898u, 2272488031u, 3877484857u, 979844730u, 2613612689u, 786482265u, 1364244620u, 2033173153u, 3134432953u),
	SC(245516122u, 2889724376u, 1613118230u, 2868868565u, 1013497115u, 3666944940u, 2501541909u, 815141378u, 779235858u, 1902916979u, 3850855895u, 1167093935u, 1168409941u, 3245780852u, 4226945707u, 4280877886u)
},
{
	SC(2950670644u, 1870384244u, 3964091927u, 4110714448u, 298132763u, 3177974896u, 3260855649u, 1258311080u, 2976836646u, 3581267654u, 3094482836u, 80535005u, 2024129606u, 168620678u, 4254285674u, 2577025593u),
	SC(3844732422u, 2230187449u, 1557375911u, 590961129u, 1701027517u, 331713899u, 3363983326u, 1064211679u, 2469744485u, 3844709006u, 554341548u, 2324111146u, 2812323543u, 1435480032u, 4135550045u, 2872067600u),
	SC(2202241595u, 1205836665u, 3131813560u, 1089110772u, 3887508076u, 1233136676u, 3548446202u, 793066767u, 637354793u, 3802923900u, 1174560178u, 382849423u, 962041806u, 1631358036u, 3204426711u, 3944213363u),
	SC(817090639u, 1994913738u, 2648494065u, 4177836343u, 3717672761u, 285814645u, 2423315791u, 4135386952u, 3070326434u, 820456062u, 1683759394u, 1267832048u, 63147800u, 1881205741u, 302905775u, 1485684559u)
},
{
	SC(3370772934u, 1440339939u, 379677041u, 4156026118u, 4200213979u, 1445495145u, 3935749177u, 1783881758u, 1005809262u, 2360538413u, 2323256669u, 457067031u, 3765100747u, 2984166698u, 162921394u, 2668333599u),
	SC(3065468376u, 65466803u, 3784968091u, 3673346023u, 584904352u, 663859712u, 1389234596u, 3496407446u, 890179676u, 1850921398u, 3658025032u, 506692469u, 2138612147u, 3661456633u, 4005648844u, 249742373u),
	SC(1899194536u, 4093520345u, 3415064568u, 1802810398u, 3207570648u, 296545623u, 1204649995u, 2946774221u, 714728700u, 2767849304u, 2356147373u, 157823549u, 3075725764u, 1119360150u, 4211929128u, 3922170227u),
	SC(2659885008u, 598828540u, 2375411681u, 964709383u, 2865976012u, 414712789u, 3082783461u, 6238131u, 3716066600u, 1794924805u, 2313286822u, 946313445u, 2548638721u, 964660560u, 44931074u, 1906436126u)
},
{
	SC(2640868889u, 3250766894u, 1044803536u, 450207928u, 3025775378u, 1680703708u, 276934172u, 2818613080u, 888828802u, 1753154805u, 531715904u, 3273521379u, 341444872u, 2892600615u, 159622930u, 591479697u),
	SC(2952222374u, 1856498301u, 2243569887u, 4213548355u, 4078434310u, 4052372322u, 1416228041u, 2119461034u, 3007622446u, 3050042881u, 2152732646u, 1066024310u, 2582445442u, 682218174u, 2817737782u, 2652201945u),
	SC(3623056786u, 3441458982u, 2160322137u, 2871437811u, 2250704419u, 3170723639u, 4221731738u, 2734636927u, 1185229318u, 4274587310u, 2041058099u, 962960905u, 2061052114u, 1268028907u, 2565378146u, 3631942974u),
	SC(2141595323u, 160210714u, 2228950125u, 92580378u, 988241665u, 445022223u, 566406519u, 3944609260u, 3366528787u, 4002340061u, 961852007u, 3441093957u, 2459277731u, 1024502537u, 1511457730u, 1148963311u)
},
{
	SC(3202237129u, 50883717u, 3598269011u, 1607392277u, 1644299309u, 889527980u, 2825840961u, 2861964676u, 3773279883u, 2790748940u, 801518030u, 2192935882u, 499995327u, 1862737584u, 3413876603u, 616426331u),
	SC(3686793646u, 20428098u, 3969297914u, 913650165u, 2827686478u, 2379892224u, 454312765u, 2897546672u, 3835444382u, 2882659779u, 3321531897u, 74282757u, 3847182670u, 3541719937u, 3150565224u, 3512719354u),
	SC(3784958703u, 2769421682u, 3091517885u, 1991423597u, 3891647149u, 675105671u, 1037706647u, 259233587u, 2569454579u, 2293177837u, 4007742405u, 197079824u, 1273386495u, 3282913176u, 1536053011u, 1223947714u),
	SC(434065071u, 3636373224u, 3991878275u, 1096448533u, 2730731688u, 2513540689u, 113291505u, 371784153u, 1849077614u, 2667695479u, 3752135876u, 2789716514u, 3595582551u, 3031878859u, 2074056379u, 3599743336u)
},
{
	SC(2576095823u, 86681482u, 2327030094u, 1725401015u, 341826214u, 1191297212u, 2343266611u, 1017220807u, 2691244685u, 895382974u, 4111156866u, 2987439990u, 2511968171u, 316177210u, 703101725u, 681437235u),
	SC(1669913590u, 387275198u, 763233018u, 736875927u, 3279145343u, 2513945803u, 102030106u, 2618927150u, 2983227004u, 2212337792u, 2816563243u, 666091160u, 3801431258u, 1348390766u, 1055427564u, 1899913269u),
	SC(1727153737u, 1379698720u, 2039442996u, 2747321025u, 3954121035u, 3301125252u, 2834061869u, 770560392u, 3966591198u, 1961165929u, 105560134u, 30446389u, 183105111u, 3146477434u, 2246060135u, 288949285u),
	SC(1131955257u, 1449655431u, 3518253163u, 4153987991u, 3869923725u, 3198118689u, 1677558296u, 3934028944u, 3706927948u, 1463324750u, 1783261113u, 2788560881u, 3859020908u, 1635416939u, 386489686u, 3874171273u)
},
{
	SC(2353147804u, 1311416906u, 105984912u, 4224529713u, 1353878621u, 1089374941u, 2359121297u, 1681969049u, 35129792u, 742332537u, 258439575u, 2442989035u, 4253756672u, 1596235232u, 3823082318u, 2381448484u),
	SC(1190442982u, 1874855635u, 2229404366u, 3781526169u, 3471201203u, 3683021538u, 2732745990u, 2348452723u, 3499960920u, 3603466370u, 724498153u, 1020423362u, 1277227832u, 1355832959u, 1821604508u, 4167503482u),
	SC(2710790336u, 1725181698u, 1411252199u, 4204440724u, 648339034u, 2322949699u, 3414240870u, 2615287106u, 1037187476u, 2391186172u, 1554369130u, 4112504886u, 2086740002u, 3652684450u, 1249425599u, 3565844824u),
	SC(1408354486u, 4130212172u, 981550913u, 3804435033u, 2516265052u, 3638635807u, 2435893710u, 2985211455u, 2435388317u, 1122223182u, 4045695068u, 4259175893u, 3130782207u, 1516327754u, 222842940u, 3028641973u)
},
{
	SC(1020427295u, 3974659064u, 283755394u, 2698482586u, 3731846525u, 2634119332u, 3930615342u, 605884950u, 2153878216u, 408077371u, 3527644242u, 188880174u, 2969085736u, 1358147467u, 199845647u, 4237400215u),
	SC(3758107081u, 2242188224u, 2662546131u, 1561030959u, 817813866u, 1223534684u, 4230285749u, 2583147456u, 3162765547u, 3250322233u, 2552007157u, 2082705710u, 2014211252u, 3819533721u, 686101552u, 2812413379u),
	SC(2234002525u, 4261429784u, 452225496u, 2303312689u, 1415484610u, 980910758u, 1264265981u, 2116798858u, 2297475165u, 1077069522u, 2336309469u, 1211096986u, 1916895651u, 2716672672u, 195344444u, 4225148444u),
	SC(2384904579u, 639141669u, 3509483302u, 2662576077u, 303835927u, 1836480672u, 2477037280u, 2622449130u, 173493653u, 2124329088u, 1602479127u, 4047873800u, 2535334227u, 2829812834u, 2580882819u, 2222121832u)
},
{
	SC(2119576703u, 2277130384u, 3272897641u, 126602073u, 1915103151u, 123033056u, 3738728306u, 258450927u, 1128202181u, 443393204u, 351769595u, 1486233009u, 4234576346u, 775323398u, 857648792u, 1277112788u),
	SC(2993933961u, 1657088997u, 213007534u, 3535372309u, 2026363619u, 3507155973u, 1176191233u, 3237944387u, 1320866873u, 1924765846u, 4159967257u, 1467377957u, 4047884494u, 1497517194u, 1818016460u, 2744622870u),
	SC(3694140649u, 652746790u, 951189140u, 2098619655u, 1680509345u, 1352655302u, 1544793909u, 2680376337u, 175255713u, 1388931410u, 2800074562u, 3304804431u, 315774843u, 1088993607u, 1406890395u, 1388997459u),
	SC(1251988268u, 2843661694u, 2212874002u, 1534733047u, 1068100174u, 3647918953u, 1789522147u, 3422223776u, 1180289192u, 194862188u, 3422333598u, 3945579082u, 576579849u, 4206528706u, 321834890u, 3661983741u)
},
{
	SC(2441722449u, 2790322712u, 1527675058u, 1338514239u, 2508809510u, 1706782403u, 1349451633u, 1899600596u, 2552002416u, 3067739742u, 4116665780u, 1305299753u, 1475244152u, 1557749124u, 223984632u, 1615437927u),
	SC(2151876908u, 127556265u, 210060943u, 1049978459u, 4151586108u, 2028234025u, 2678412581u, 14644879u, 1565389685u, 3987281138u, 1236497759u, 911479528u, 525893033u, 3024407248u, 3556739040u, 1249730389u),
	SC(3301882220u, 3342072153u, 1895573985u, 1790741734u, 1642968660u, 1858970157u, 2235912890u, 1037870412u, 1813672202u, 4049358910u, 3001339515u, 873617077u, 2873055757u, 3206209966u, 4101837524u, 2624469834u),
	SC(4012899795u, 1411685889u, 1675925042u, 202568246u, 4145924754u, 1399506949u, 1886987672u, 2758768719u, 2971794908u, 2035585462u, 2543963410u, 2573500478u, 1760956179u, 1439621888u, 1566898017u, 1067574233u)
},
{
	SC(3011639073u, 2206317754u, 969819721u, 3738742509u, 1138054282u, 2981140865u, 2802091370u, 2603283830u, 4248836099u, 166302652u, 328639577u, 2188432563u, 4067379185u, 146455516u, 3217830067u, 1729299133u),
	SC(2609432174u, 2327492074u, 3031491512u, 280817824u, 3549986332u, 3308979407u, 2655280939u, 2768967492u, 254774771u, 1876736424u, 2883942286u, 872093970u, 548753956u, 2234019621u, 957665653u, 3478881725u),
	SC(1034467968u, 2792638263u, 3950374324u, 1004331822u, 4143036235u, 3155132214u, 1019409218u, 546983506u, 3592239641u, 3183006100u, 518251172u, 84770439u, 3170919723u, 1246938133u, 2186380724u, 2729251943u),
	SC(2721544689u, 3010554855u, 2194979764u, 1031890814u, 3616460865u, 3262672691u, 1238722150u, 2348608514u, 867532033u, 3287518035u, 3647913083u, 717892616u, 1725828253u, 2539969720u, 3705717374u, 4095834467u)
},
{
	SC(3801315717u, 2112036077u, 3164683094u, 379762771u, 3254176021u, 2342893977u, 1079378879u, 3986955491u, 3221162096u, 2286978182u, 907699080u, 3070638326u, 2125256188u, 2711740807u, 2477965954u, 3570994883u),
	SC(1122525264u, 3591379015u, 3651810742u, 1173125667u, 802651485u, 3322599373u, 2702070556u, 2271315927u, 235540800u, 3051400065u, 2042929625u, 1315436250u, 4279660507u, 1222458841u, 1309738265u, 4260103523u),
	SC(594338363u, 2705306194u, 3994677390u, 2587445452u, 4092458680u, 2550273883u, 1741901457u, 3089932786u, 995531803u, 1552592484u, 185943397u, 1893151579u, 3925084250u, 2731009314u, 2517191571u, 4184090215u),
	SC(2932536533u, 673797799u, 1479658602u, 2730531731u, 1700442209u, 358022048u, 146283469u, 2643625189u, 4024245855u, 4139997168u, 567410177u, 3636916990u, 3268470878u, 314047155u, 1763763844u, 3743541562u)
},
{
	SC(2662528623u, 240757742u, 3179027416u, 3692044327u, 3913846998u, 3528257504u, 3772979290u, 3628427226u, 305430694u, 2987431446u, 794594234u, 1282518312u, 2985258300u, 3333973163u, 4005806037u, 352754457u),
	SC(3782779926u, 4110508606u, 1605467718u, 2642077952u, 458260856u, 2448579418u, 2209203557u, 1968631064u, 3765513190u, 3884784279u, 72532826u, 3248358489u, 3714540198u, 2606678131u, 2904387285u, 2342761321u),
	SC(2569288456u, 1815849164u, 4098684446u, 3349474441u, 1410341352u, 1705004747u, 3665708675u, 381020291u, 2679446175u, 1286312468u, 3575935824u, 279271370u, 1077912003u, 190175010u, 425033099u, 3744325826u),
	SC(3275514338u, 1559161631u, 799309346u, 2839484106u, 305280450u, 3083836149u, 3876776079u, 2156901234u, 2804804991u, 976629240u, 2694392801u, 1790066514u, 2574196749u, 3029867868u, 2629265170u, 4037575284u)
},
{
	SC(1179130413u, 2617888591u, 3899256032u, 1057380664u, 3779344699u, 307335646u, 2770957782u, 4141937651u, 1948539189u, 1358438384u, 1093283021u, 4042006857u, 2791989712u, 3594321177u, 1957065458u, 3124610322u),
	SC(3050699594u, 4280767227u, 290097946u, 3263540548u, 1572664490u, 4270814667u, 52151354u, 1117313135u, 1865289931u, 3010346790u, 3391620705u, 985710674u, 531658779u, 34923524u, 2455194633u, 2374493465u),
	SC(814459970u, 2723917759u, 2477174310u, 3482962885u, 442774037u, 754815613u, 1917888868u, 3158676105u, 2872624459u, 91379209u, 1032043884u, 499991106u, 3778795588u, 3266819779u, 186637454u, 4156664772u),
	SC(3016114145u, 1736461604u, 3205169396u, 474612085u, 1216801222u, 2835641401u, 2918409686u, 3164901799u, 3500254583u, 3667239907u, 1848006585u, 4185934990u, 2478171701u, 1851761984u, 1340662725u, 1559796526u)
},
{
	SC(1360133382u, 1382006343u, 66835972u, 1873466161u, 3876965448u, 3531938445u, 1890798686u, 56472881u, 2533353104u, 4282202369u, 3645923103u, 2705081453u, 1080413790u, 4206709997u, 1506080970u, 1141708053u),
	SC(3155358398u, 990848993u, 2462700614u, 1505675146u, 1247358734u, 2575032972u, 826119084u, 1198127946u, 339679848u, 32954015u, 1727305027u, 2972819958u, 3370367283u, 656266618u, 1005181853u, 530330039u),
	SC(3988823285u, 1731245632u, 1755055403u, 2560356605u, 3730232548u, 2155413514u, 3035164658u, 598434227u, 1475484312u, 3940474610u, 2415265341u, 1405031819u, 3280870431u, 1844631264u, 1610067224u, 1204362218u),
	SC(1269221683u, 2519656157u, 2071625981u, 1090710229u, 3645514314u, 1110844234u, 1924132752u, 892847887u, 4165100719u, 3359788173u, 2008337856u, 938802684u, 991722988u, 4043128230u, 4137074352u, 2561836043u)
},
{
	SC(1832589817u, 2040030464u, 789572087u, 1743772968u, 1938005249u, 998198464u, 2217413253u, 3247653250u, 2992749980u, 3373002764u, 986086387u, 1921971278u, 715241056u, 1828539457u, 550615731u, 178282236u),
	SC(3118922710u, 3133974140u, 3533142743u, 72929286u, 3198298255u, 1502151855u, 108612817u, 3699479089u, 201153487u, 720151169u, 3583408525u, 1210759541u, 1941003258u, 3682465346u, 2883351166u, 3479588638u),
	SC(4075012412u, 2384306778u, 990193452u, 4200939253u, 1216259667u, 1834335958u, 3387821687u, 2234670992u, 2076894060u, 1743544524u, 277514132u, 13313187u, 3071041293u, 760793107u, 2011151740u, 278340182u),
	SC(320316446u, 4109407361u, 3677628424u, 1674877723u, 3753025818u, 4165197242u, 692690716u, 1774953271u, 682266304u, 195625503u, 3298726133u, 1707479636u, 992898575u, 1463223156u, 2482910366u, 300572397u)
},
{
	SC(1520231886u, 1533823723u, 2297723983u, 1744831139u, 3633896082u, 1614546195u, 3609911488u, 597627082u, 3251786608u, 4014292809u, 2038611397u, 3607503000u, 437112807u, 3497657145u, 3940533692u, 3708647540u),
	SC(1465821699u, 3405111997u, 4003997008u, 4183928939u, 3905462877u, 2705297708u, 2238150313u, 742184835u, 1932143234u, 3664530812u, 2046148339u, 2604237599u, 4176974387u, 4184867654u, 4206884099u, 1348617750u),
	SC(3070267841u, 2579987995u, 1969628668u, 3729860143u, 2481075914u, 4102909817u, 3584912684u, 474930687u, 3540071519u, 1029701928u, 1346321162u, 2127250654u, 4129540566u, 3018689710u, 3598109374u, 1767691581u),
	SC(864985299u, 1834850557u, 3109924880u, 1664439774u, 3385518451u, 1913308391u, 3218983195u, 392233970u, 3181268563u, 3784201246u, 2379947300u, 4290722005u, 3528628947u, 1006910471u, 535267399u, 1673418747u)
},
{
	SC(3481601556u, 2233272424u, 379791868u, 257694460u, 1845345200u, 3985799409u, 584988816u, 3412670519u, 3077103055u, 4175161368u, 4242152769u, 288598488u, 1537669756u, 2647153439u, 598939469u, 111034163u),
	SC(3810090684u, 1592169812u, 1940268778u, 338895736u, 497628080u, 4216984708u, 228734525u, 1707793534u, 3500988995u, 3892268537u, 3709814459u, 2481503038u, 4285752394u, 3760502218u, 2308351824u, 2442300374u),
	SC(1463929836u, 1623537503u, 1841529793u, 2601374939u, 443189997u, 1448667259u, 4277352980u, 774378880u, 1726605682u, 711848571u, 609223830u, 3738657676u, 2710655701u, 2088426244u, 1947361269u, 468110171u),
	SC(2120531099u, 3930874976u, 3115446129u, 2510615778u, 1442960918u, 296642718u, 3406147761u, 2917495448u, 3208894642u, 1695107462u, 843596467u, 603763190u, 1560844015u, 355951375u, 3828049563u, 1114999394u)
},
{
	SC(392371846u, 1379814680u, 1363243524u, 3722538090u, 3145592111u, 38816718u, 107491673u, 1676260498u, 3426355262u, 3831639129u, 1301499599u, 611390527u, 78617678u, 1209558708u, 1668351148u, 226581655u),
	SC(1775864961u, 48061652u, 580841005u, 3626988964u, 2557366605u, 3448623530u, 468550727u, 241125115u, 2104687911u, 1089018812u, 1688455712u, 608088120u, 2631681751u, 3937882947u, 2164520114u, 1139400198u),
	SC(1995948241u, 208017732u, 1594842091u, 1452072628u, 164448317u, 3854350135u, 770076275u, 3400678444u, 1409557197u, 2571846673u, 1859309672u, 1573355923u, 4217069526u, 686027826u, 3995935263u, 2273570682u),
	SC(1765332340u, 4134549941u, 3951557595u, 3076127967u, 1338164033u, 2891454422u, 2393384828u, 3559486836u, 1512470972u, 2204654760u, 3549830481u, 442409089u, 2330531785u, 1174852946u, 1644205035u, 4086947411u)
},
{
	SC(101372338u, 2692064245u, 4244055656u, 3410522170u, 4098634818u, 592864064u, 2969397292u, 2927795675u, 1397471704u, 1186809213u, 896853288u, 2272821089u, 1950059720u, 3887661868u, 1484362490u, 3234474008u),
	SC(493258591u, 1121511261u, 1448191541u, 498182176u, 1918511567u, 1960859517u, 2201745473u, 2498339542u, 2151600957u, 562595706u, 3269711078u, 3616189977u, 2368662366u, 2850210764u, 701321748u, 3255466174u),
	SC(3477078337u, 75569968u, 1882477600u, 3795843068u, 3145730975u, 3928889549u, 2226239031u, 2069490233u, 730638780u, 1915612718u, 697919589u, 2467794143u, 374355249u, 3817362210u, 3559591924u, 3708360999u),
	SC(4280685228u, 798565835u, 3447110005u, 2990210928u, 1115710197u, 2405737735u, 682820124u, 1699236188u, 3820769325u, 1615231023u, 2368524531u, 257677290u, 4133610712u, 1592505711u, 3475938680u, 1398379699u)
},
{
	SC(1211755933u, 1247714434u, 1282061171u, 3117211886u, 1838094820u, 562415505u, 2310351523u, 1381183879u, 2707832537u, 117470322u, 2204629759u, 867864819u, 1644915480u, 2820079473u, 134123159u, 540033827u),
	SC(15354647u, 1591670498u, 1190718313u, 1541233542u, 4032967122u, 942685588u, 3365116340u, 2946123057u, 2867864034u, 1431712436u, 3664977314u, 4215252548u, 780940535u, 2664802049u, 3657395174u, 3285444551u),
	SC(1658777725u, 999313419u, 1418469670u, 1566961954u, 3992026007u, 2649729892u, 1047536246u, 2001445947u, 480933675u, 3175009636u, 3359477823u, 2924980702u, 1231329979u, 95058465u, 767731972u, 3917454032u),
	SC(3100292812u, 3884551487u, 4289440287u, 2347826358u, 4211090332u, 670252192u, 3716758936u, 2994228912u, 2525237511u, 3452722491u, 1545378943u, 968437745u, 1479664640u, 1937122359u, 2097556211u, 1258954160u)
},
{
	SC(1673081263u, 3717060688u, 3652383485u, 75555081u, 339104409u, 625664167u, 2957818922u, 3740706216u, 3722123261u, 2164265628u, 41619746u, 878214721u, 3870587649u, 2665027445u, 2987893003u, 808462477u),
	SC(2728711156u, 1086672909u, 2697764898u, 567191765u, 2302742493u, 2005063028u, 2232495503u, 3875528033u, 2914811718u, 3683323689u, 52292746u, 3187471254u, 2532399294u, 4143091019u, 3633190133u, 1590524887u),
	SC(606562011u, 2100995962u, 1839922754u, 532687810u, 3616257173u, 1997694206u, 1335550423u, 2205222605u, 261980003u, 2139354528u, 1841614146u, 2937759052u, 2183075601u, 1723571202u, 1493132360u, 3728582316u),
	SC(3230250852u, 4168344895u, 2679345329u, 3624060879u, 3868167595u, 1865131300u, 1311805479u, 2393247194u, 2139351328u, 3002812369u, 3350833683u, 3969926321u, 2058779916u, 2490793273u, 2159016099u, 496959402u)
},
{
	SC(3999308453u, 3487620652u, 1171382066u, 117957864u, 3636774258u, 986365728u, 3378416914u, 2669903071u, 664895567u, 3538730524u, 166402392u, 3635906958u, 157861605u, 242846507u, 3094051413u, 4038067861u),
	SC(382205097u, 2344781331u, 2937140170u, 1816057341u, 1469220234u, 1940420467u, 398460121u, 3364520375u, 2104328076u, 82674575u, 2140577888u, 852626945u, 3079841577u, 1473577711u, 1465804966u, 3311176475u),
	SC(3267743682u, 1310117768u, 2938225418u, 775374367u, 587863041u, 714539095u, 4061038577u, 3729882348u, 1785496396u, 3211618351u, 2981394335u, 371831223u, 1072350840u, 954419720u, 1959998932u, 2454045566u),
	SC(479494208u, 1987289713u, 601690066u, 2245928090u, 1237926728u, 1978426976u, 1024130488u, 2665301570u, 34745753u, 1736556264u, 1653286844u, 3451912851u, 1138975354u, 4048457251u, 1242843993u, 1054377909u)
},
{
	SC(2738272835u, 2642272027u, 2444253775u, 1913142517u, 529528892u, 363620831u, 2077044016u, 3326463661u, 2845383164u, 2776976386u, 3877921557u, 1199205578u, 3801089501u, 3914384222u, 128907220u, 132434637u),
	SC(555642965u, 1828068553u, 165356918u, 537166884u, 2589769988u, 3893921148u, 735041643u, 904961316u, 4137546439u, 3565210697u, 2338345828u, 3841345944u, 2815585062u, 4082424957u, 394326179u, 52753595u),
	SC(2015072068u, 2250729799u, 1841411011u, 4036188548u, 1854043669u, 2989277393u, 1318251334u, 1142950047u, 3298447599u, 1053616926u, 3428876739u, 2060285001u, 1941488353u, 2614859778u, 4116063961u, 312196617u),
	SC(1645616406u, 2451233446u, 95062652u, 3017612715u, 506657218u, 3839742233u, 3856180001u, 1041180203u, 3937295200u, 1238701953u, 2873597624u, 840250152u, 4243175032u, 930652270u, 1478475816u, 3845467531u)
},
{
	SC(2614321393u, 2590372819u, 1970957616u, 1961333756u, 2325160725u, 2648338335u, 4165709737u, 2339426256u, 3513486801u, 1496810781u, 1669509351u, 258966927u, 2250252751u, 2239710582u, 802055678u, 4015030700u),
	SC(2182037357u, 4101274196u, 1446988332u, 2985927331u, 1146409455u, 3263975303u, 799089634u, 2309382122u, 665330721u, 560691983u, 753778238u, 3562883867u, 3339601863u, 3450049178u, 4100785638u, 1532039755u),
	SC(937987686u, 865492161u, 3272849989u, 1734497423u, 343847785u, 3737085537u, 3368433481u, 2949279024u, 3260496520u, 4153917332u, 3410155564u, 3353468255u, 1739756823u, 4095510864u, 3441948540u, 4106520671u),
	SC(969989902u, 586815344u, 1052565711u, 1966159036u, 1537747586u, 3037234863u, 3719606179u, 3329895927u, 973453015u, 1072637341u, 4177571198u, 599432355u, 4195257378u, 1974046375u, 3591192312u, 1360444203u)
},
{
	SC(1198026164u, 4014048326u, 1230325083u, 2325793602u, 2567156447u, 2557610111u, 1955740227u, 1784651885u, 2575049304u, 3122223295u, 1744960108u, 1453452975u, 793595759u, 384704201u, 949316067u, 1790894944u),
	SC(4018529616u, 2128595084u, 1769902998u, 3875589577u, 1889584730u, 3454870508u, 2548628163u, 1669330066u, 2128608235u, 3281879031u, 2432452508u, 1883985687u, 588999703u, 2324275250u, 901137249u, 3371400173u),
	SC(1200681821u, 3301951048u, 3422623379u, 3571320760u, 874120845u, 3097214442u, 3051103970u, 76968923u, 1387447193u, 2542210132u, 2554494588u, 974855787u, 1477775411u, 3457275362u, 2692305076u, 3235291688u),
	SC(3036583757u, 770121165u, 3053454162u, 522789059u, 2626260097u, 3421082942u, 1104884834u, 4070065260u, 4076311070u, 685795393u, 461218278u, 2168728175u, 3856607167u, 813680045u, 2418442649u, 3951931037u)
},
{
	SC(399941210u, 4052934898u, 1765353186u, 2914831584u, 2330887766u, 5969976u, 1422591474u, 3629530848u, 267437281u, 3214236217u, 4174466044u, 1745439639u, 1864324137u, 3763020267u, 2592531679u, 3537966343u),
	SC(3799373953u, 2724639256u, 2001877812u, 1808948841u, 1593274790u, 3054223609u, 1153023507u, 4239996916u, 1351712236u, 3216557202u, 2535804507u, 845372832u, 3782183452u, 3403957512u, 1416495693u, 3105296601u),
	SC(1498301404u, 4820973u, 153120459u, 2361034920u, 2023699622u, 3245801726u, 2964952371u, 1041760523u, 268911050u, 2634266058u, 2694116227u, 2027567813u, 2373519386u, 269857075u, 30288097u, 2183065286u),
	SC(368526189u, 2559072357u, 1031071164u, 2182129360u, 1944651505u, 636678935u, 1667461006u, 1294621613u, 2608680425u, 3107428868u, 3989419130u, 2232649159u, 2911003556u, 2700112730u, 3650153328u, 3756548335u)
},
{
	SC(3698493999u, 1617091219u, 2641540351u, 630561052u, 1592442355u, 3183940237u, 801174107u, 179980333u, 696230615u, 150351649u, 23935592u, 3859540912u, 468562123u, 923517953u, 805710396u, 4125457547u),
	SC(4165123875u, 2400415189u, 3682055275u, 2069206861u, 3696165550u, 2161642831u, 2037981487u, 1143942884u, 4276433760u, 478865742u, 3086639553u, 1571765198u, 1603084763u, 456679804u, 3651523911u, 1478990563u),
	SC(1379203927u, 3646623795u, 568753294u, 3487537539u, 209654607u, 4212153962u, 3351322045u, 2510527877u, 2242635801u, 2829639500u, 3346970138u, 145495350u, 696632584u, 4044305024u, 3898104982u, 4062174566u),
	SC(3184334172u, 233736710u, 4174791834u, 4097504403u, 3953706740u, 3822932903u, 2814935218u, 358220985u, 3196193396u, 1102715831u, 1098449313u, 2583469858u, 4124598348u, 1123093599u, 2101489793u, 1348316960u)
},
{
	SC(2684573108u, 3558789399u, 3119419718u, 3728836869u, 2947343184u, 1623207311u, 3636415221u, 169916282u, 3184581941u, 3445118881u, 2604468839u, 2706071623u, 2898788331u, 1892631561u, 1665094613u, 3179624796u),
	SC(906269307u, 3944720044u, 1084033100u, 2261306286u, 1213089531u, 3374722818u, 4231098344u, 3721279388u, 1553093275u, 459717074u, 162554025u, 17748698u, 1178068070u, 962016410u, 2213129285u, 1572961619u),
	SC(2793536793u, 1775932955u, 900507119u, 977479138u, 309749318u, 1331949593u, 2418440293u, 531142338u, 4089367200u, 930941048u, 1176503780u, 2036051288u, 3668633163u, 1740102441u, 2194821486u, 1282572570u),
	SC(445096529u, 129462470u, 1884373239u, 3466640820u, 1522309741u, 973848773u, 494935215u, 2424005467u, 3247128628u, 259841527u, 186869565u, 3096718001u, 2477168883u, 367986761u, 2999214109u, 2896323771u)
},
{
	SC(1773026576u, 1379074764u, 3166371072u, 524350604u, 3036223673u, 1696139651u, 617546873u, 4179058200u, 3914872456u, 2598924013u, 3955751324u, 26932306u, 2099484934u, 2862008623u, 768155488u, 1191481499u),
	SC(409212209u, 1052910825u, 3688563284u, 4161847970u, 2245294077u, 897499682u, 456221051u, 2079661589u, 3801089560u, 2078041333u, 3137652751u, 2105451951u, 719093028u, 1468410201u, 1515815488u, 563818410u),
	SC(3286956100u, 2383742683u, 3943355186u, 2993468102u, 3979091318u, 916735409u, 2964268867u, 305123152u, 4128710652u, 2295714888u, 3626542149u, 3583999711u, 4231472159u, 720391481u, 484199833u, 2335936882u),
	SC(538542990u, 4107031584u, 936999250u, 2894531997u, 2884912117u, 1445093734u, 2632468537u, 3748259111u, 2802501861u, 3908527171u, 4249314755u, 2225844668u, 1521902387u, 2622248285u, 2379759782u, 133722185u)
},
{
	SC(2416004768u, 4150485184u, 2866080852u, 2258165843u, 340095341u, 92175320u, 2597374290u, 3087457719u, 3493438419u, 118989751u, 1753361916u, 2495747807u, 639933700u, 3533266873u, 1436534944u, 1404379078u),
	SC(1990073743u, 1730445713u, 289110704u, 2215657403u, 3477688520u, 2065290968u, 1707801924u, 3099400356u, 2323459433u, 2868452324u, 3572002281u, 898120544u, 2341674849u, 1740236652u, 3930315629u, 1721050464u),
	SC(2846769158u, 3226467803u, 3972413633u, 3813187604u, 2977554411u, 3119019066u, 187539422u, 440979155u, 821512909u, 1244234014u, 1904979619u, 299169202u, 3071099705u, 3895808241u, 4109203004u, 1385199880u),
	SC(20905997u, 2435505711u, 3332489889u, 1573385190u, 58777428u, 1157282938u, 2163099427u, 3928469264u, 1842173836u, 315842099u, 505424769u, 3969121644u, 810696578u, 173164137u, 729323247u, 1406869756u)
},
{
	SC(2365567579u, 2649935193u, 2748706770u, 3167941363u, 4184592483u, 348144198u, 2780991619u, 3943215641u, 289217556u, 1966918363u, 1264290193u, 2261335810u, 331626257u, 811495510u, 4241198943u, 2401654548u),
	SC(2748278563u, 1068204456u, 1543821322u, 1360532269u, 3750838841u, 1738925190u, 1060161426u, 1720702106u, 2569490119u, 2592801160u, 2837017084u, 1662592721u, 1922186968u, 2837375648u, 558451644u, 866947791u),
	SC(1192118473u, 405864758u, 2154900285u, 2590455701u, 2443487163u, 774239941u, 1500516041u, 3052959378u, 62497488u, 3655191229u, 1360213674u, 4039219068u, 772399995u, 2523284785u, 1220027510u, 1817586574u),
	SC(3940509119u, 3412105989u, 2952834772u, 2565031146u, 420729718u, 3223325741u, 3799285342u, 2722982144u, 3291273242u, 1970130334u, 1752908455u, 718889499u, 3758072739u, 3367451018u, 3926567909u, 4252203926u)
},
{
	SC(1759002533u, 1487269615u, 2257972014u, 1083840372u, 1641298734u, 2179126519u, 4023242279u, 631576049u, 1738205588u, 618934446u, 2093405187u, 2949307911u, 4007558605u, 1029273367u, 4271100370u, 1039169272u),
	SC(1515566465u, 1552043593u, 3679580696u, 2436820824u, 243951212u, 1100063376u, 3060791820u, 2881381702u, 2255810429u, 2661760029u, 976819642u, 3776497474u, 4249702024u, 2024647373u, 110728762u, 1589245846u),
	SC(1222066781u, 929871833u, 3542816334u, 2450308476u, 3889263811u, 2063341852u, 1713795617u, 1790265502u, 3640640744u, 702438505u, 3752689618u, 861125705u, 2800024898u, 3273280398u, 381422586u, 3458645582u),
	SC(4292194968u, 248883279u, 3851291071u, 2381853448u, 1073433118u, 2354758646u, 509168387u, 1080387022u, 4117133479u, 4274939184u, 1790223702u, 3619550239u, 893146224u, 3535153470u, 2843460502u, 3639480269u)
},
{
	SC(875705436u, 2649940325u, 3671965902u, 2567151996u, 544268373u, 1955202709u, 305754623u, 1141543641u, 990189469u, 3756473672u, 1148700315u, 1129055741u, 1437435407u, 3710411618u, 2889469156u, 1535007815u),
	SC(2884213479u, 1770002877u, 1717656157u, 132095051u, 3410594069u, 2825430154u, 637479405u, 1954348940u, 261832561u, 289175839u, 3006609188u, 2819765533u, 965261546u, 61421601u, 3676726043u, 1762126450u),
	SC(1279868755u, 1028393837u, 402310972u, 1124180052u, 1966420832u, 355916436u, 3164845140u, 1987806920u, 2358723546u, 2333235794u, 547656661u, 741426190u, 3791351751u, 229368670u, 2060024860u, 2496159246u),
	SC(729000302u, 1895693776u, 4291166676u, 165118594u, 4187486015u, 4003769717u, 4173715283u, 1708863275u, 2571981291u, 3314404862u, 2784625143u, 1378770288u, 471970597u, 2471540726u, 885481379u, 30714732u)
},
{
	SC(3178372343u, 819515330u, 1006458744u, 1744046151u, 1335890469u, 3720299130u, 3351999440u, 1610902263u, 1660799402u, 3095620625u, 2313473472u, 1025272967u, 2457745086u, 776820149u, 1991370461u, 2446835994u),
	SC(1010694829u, 3576636721u, 3447938536u, 3020554334u, 2855010652u, 1077306503u, 2519536483u, 1693776468u, 2719234662u, 2809016552u, 352917716u, 496941437u, 2794886318u, 3290871493u, 85090184u, 2720964345u),
	SC(3154596760u, 1177221669u, 1472641897u, 3066862312u, 1973719267u, 3888536326u, 4158066426u, 375731453u, 1194368649u, 504110184u, 3332723499u, 3007941073u, 1703908862u, 2111295124u, 3526651404u, 361981784u),
	SC(1082063268u, 2838135921u, 1074670559u, 1981839722u, 68208200u, 3852545089u, 1874506558u, 34706706u, 1621217725u, 2860154504u, 3598425424u, 186699529u, 2022232276u, 1552131421u, 1256799706u, 1237253344u)
},
{
	SC(4253983049u, 1956128201u, 531971008u, 849224076u, 726267438u, 2775479863u, 1930393199u, 1383823745u, 63229370u, 473494690u, 2189839240u, 2776826045u, 227039104u, 3325879119u, 1283171084u, 96817479u),
	SC(3860217166u, 2940528670u, 506602091u, 3419829981u, 506043244u, 614420425u, 2993710593u, 2920806228u, 1333084534u, 3486829092u, 3082898297u, 2169097101u, 1082170030u, 1470175076u, 1320435311u, 574635396u),
	SC(3258895975u, 4163242637u, 1293464004u, 352297789u, 3644545561u, 3993568180u, 3296091139u, 1095374790u, 2336524066u, 1528884861u, 4268554127u, 1914733099u, 3903840151u, 419762607u, 2887932559u, 497165606u),
	SC(980659287u, 1953455590u, 2112574847u, 735340650u, 1925619502u, 3115495333u, 3627587353u, 1603624354u, 2142860308u, 3379792281u, 1362168334u, 2246175020u, 3677515235u, 2774668056u, 1792230968u, 2199982799u)
},
{
	SC(3323498046u, 1302414577u, 2803546118u, 580488762u, 3428322024u, 682658893u, 4172122357u, 97546814u, 3512743931u, 2961959221u, 4170912416u, 2164991348u, 3081828834u, 1345963536u, 3053610974u, 512267725u),
	SC(4109044470u, 2963061726u, 1107510334u, 767020404u, 632532721u, 4969584u, 2231147626u, 2004993117u, 2229787907u, 2636257111u, 3533633798u, 4022669901u, 2099786750u, 2966651314u, 491396645u, 1164008374u),
	SC(1146578221u, 2435053231u, 2036416135u, 3952141868u, 3838293158u, 979053357u, 2978198077u, 3177553682u, 205027764u, 3304212977u, 4039842386u, 2269838528u, 1189968975u, 1530161763u, 3715730701u, 2440676344u),
	SC(3853141068u, 3126625672u, 870454728u, 2770453842u, 3177858206u, 2718094073u, 853260005u, 1096986102u, 286922389u, 3880860786u, 1776703863u, 829544988u, 2267526544u, 853417458u, 487507949u, 1744159087u)
},
{
	SC(2635257045u, 2400379653u, 4082046555u, 3320840431u, 2185118249u, 1851238012u, 586412780u, 198559223u, 4176104900u, 320695580u, 3648763183u, 469999712u, 4056550133u, 1898353926u, 1621070568u, 336190756u),
	SC(425773252u, 4192919959u, 695637058u, 2825893835u, 1246684379u, 2776039455u, 335155142u, 875351021u, 3737502706u, 2678257435u, 2570009254u, 557800437u, 3620249817u, 906765743u, 3009358775u, 2003811188u),
	SC(3586739762u, 1605178799u, 3207158625u, 2416685060u, 1372280459u, 4291657519u, 3226341120u, 1515806996u, 3830239194u, 2213324751u, 3133089253u, 2615223728u, 3226239280u, 1327007494u, 1747242554u, 1946789201u),
	SC(229748829u, 3453591261u, 3328466049u, 1202432283u, 3704729156u, 417637853u, 2491491096u, 4271840908u, 4186017690u, 2332641048u, 730397211u, 1755124885u, 3913997159u, 1855079991u, 3101480857u, 2716742242u)
},
{
	SC(2131208225u, 203490023u, 3341197434u, 2300918186u, 2246435820u, 116889233u, 936875537u, 1136106357u, 1665211349u, 1592129410u, 3788667018u, 830310025u, 1614112315u, 1756980280u, 1897821395u, 2931105520u),
	SC(936572343u, 3328922681u, 652778152u, 4066731934u, 992030872u, 1684535959u, 670262747u, 3130245314u, 2707904872u, 282017684u, 2219138782u, 4140629492u, 2949064430u, 895598721u, 2387828596u, 215164108u),
	SC(3493973951u, 3052742089u, 1710913345u, 632879547u, 3449905868u, 723462156u, 2752538048u, 1447512672u, 885479393u, 3088711229u, 4251105939u, 134301981u, 3569471580u, 3111378722u, 264654627u, 482772304u),
	SC(3326132753u, 4076881523u, 2748893798u, 2710074042u, 3150043853u, 1630829959u, 2025540868u, 1217571715u, 180553209u, 2317777177u, 1747013269u, 1205226794u, 3222652736u, 1444521786u, 371361777u, 1437728689u)
},
{
	SC(1980393090u, 1471052682u, 2529544041u, 2419695874u, 3416920350u, 2902943265u, 2292472396u, 378161194u, 2894177140u, 3269090944u, 3526211692u, 925904026u, 454381125u, 305110335u, 190601650u, 3202914870u),
	SC(1467005633u, 2266792546u, 3036672011u, 2807172437u, 3596333220u, 2090178779u, 1070591642u, 671033187u, 2186441971u, 1145180231u, 596681715u, 2813955552u, 3463494648u, 1836204490u, 2839238997u, 615421147u),
	SC(2486357277u, 2321737088u, 371691250u, 3253348099u, 241336936u, 1054510245u, 3172626830u, 1843946705u, 1551788124u, 1144782604u, 514598370u, 1218251797u, 4004257982u, 3153901098u, 2725745546u, 563089494u),
	SC(855278129u, 1794192908u, 2589523709u, 3136624000u, 1751139899u, 1931822141u, 4001840960u, 2373683750u, 3112669843u, 1700902707u, 2492103535u, 1398687385u, 1364870191u, 268889761u, 2577131856u, 3537912469u)
},
{
	SC(2401910678u, 375305965u, 1845797827u, 1808370621u, 2384610951u, 2115981945u, 1268013032u, 973702739u, 3477996375u, 3401321764u, 2985206092u, 463194589u, 3843250253u, 1296525826u, 200946437u, 4183167840u),
	SC(3046164623u, 1698475855u, 4011038180u, 876115994u, 1497982689u, 4198027289u, 3324605264u, 2096750914u, 3052485168u, 3278426185u, 2084420855u, 4155537945u, 890002226u, 613397114u, 2729032243u, 1574013457u),
	SC(1904438222u, 1928771619u, 149813336u, 3934581410u, 1242285777u, 1947850577u, 3779741715u, 3156633814u, 827781197u, 3250102070u, 31967352u, 2495163015u, 744720783u, 953132272u, 1221248003u, 3394764122u),
	SC(429325682u, 1724343519u, 2839246837u, 3243811869u, 2918477112u, 2913144266u, 1653710327u, 179459835u, 60361632u, 2169500867u, 1216490983u, 2766565465u, 606947728u, 2025715588u, 685534359u, 4134534728u)
},
{
	SC(4274280104u, 114119435u, 3494981356u, 807288563u, 3579018216u, 2538324541u, 1625485242u, 1907711206u, 3161960219u, 1114518567u, 1717624176u, 786637484u, 3521223946u, 2065514921u, 2344499302u, 2634576753u),
	SC(2629293665u, 123297883u, 574084434u, 3835067290u, 2557454780u, 2321556291u, 3989586587u, 455127277u, 561140419u, 336849834u, 3541875999u, 3505843788u, 1100171101u, 1477969571u, 1787186147u, 152619512u),
	SC(3646569096u, 2625904850u, 4234890597u, 2139521797u, 1000835213u, 3376846654u, 1685875403u, 2197084269u, 3623130940u, 3174867906u, 4226648907u, 3884803677u, 2168476426u, 3982197216u, 3318351026u, 3368793623u),
	SC(2364788399u, 2094495544u, 3600031443u, 52518095u, 3450803164u, 2433684078u, 1127574085u, 3164350498u, 2201911852u, 3482369434u, 3708203090u, 3671504700u, 3052303992u, 3248874335u, 3555217851u, 2846467790u)
},
{
	SC(2723735014u, 236629053u, 1887196519u, 2848632391u, 455156299u, 2273479869u, 1400856890u, 1826270119u, 221549383u, 3908193465u, 302170230u, 1819428813u, 3807297182u, 1656418004u, 178590097u, 1378626567u),
	SC(4132749640u, 115991972u, 785193414u, 2604851835u, 2499003323u, 872920452u, 1114128937u, 3658200701u, 3401955590u, 3496370113u, 3622819064u, 3516038987u, 2562267551u, 1775138324u, 3020878076u, 231617546u),
	SC(4077750691u, 2771835701u, 2957045153u, 1367974584u, 376086022u, 1288251730u, 59162210u, 792982409u, 127585792u, 1095980158u, 3149464510u, 200076985u, 2836796255u, 1120639529u, 1417772957u, 3406945969u),
	SC(1047410039u, 3156369931u, 3920196112u, 1958431722u, 2537004375u, 3156137498u, 864559652u, 811486751u, 4130646394u, 776484898u, 1011672286u, 1356587260u, 293263635u, 3285964634u, 1777118922u, 490814818u)
},
{
	SC(829171875u, 1673500241u, 752481928u, 467629104u, 3690456468u, 3869757428u, 3180928024u, 3535831866u, 1109526652u, 1706204822u, 2082824867u, 1246305295u, 1521867554u, 801312055u, 1276205003u, 1542551361u),
	SC(864331020u, 2674006384u, 46132127u, 1533172170u, 1617035343u, 3023527714u, 572890670u, 2907267638u, 934257589u, 598131077u, 941083478u, 3858267680u, 1599598982u, 1974889698u, 1276949852u, 264135603u),
	SC(839395994u, 1173798234u, 2429488892u, 2352360870u, 1593943673u, 745758510u, 169096299u, 2554493420u, 4227502961u, 2124710128u, 2690424297u, 4138012372u, 1513535824u, 4270029974u, 3102581644u, 450337691u),
	SC(3620750541u, 4243659078u, 2546350744u, 2494917421u, 45295851u, 2411574007u, 261198969u, 765587684u, 1188720760u, 1246321531u, 3896103880u, 281900580u, 1599084165u, 359013339u, 1316512053u, 655643585u)
},
{
	SC(63832981u, 1762179748u, 520016426u, 1020440971u, 236239932u, 2709425734u, 2138406486u, 1393881727u, 4242636743u, 2097184028u, 626362208u, 3610247579u, 581737727u, 1867228809u, 2710068013u, 1594688576u),
	SC(794456914u, 295850194u, 3406979639u, 3267947487u, 3923232296u, 2586941699u, 1511972376u, 3045444584u, 3809039136u, 1058680030u, 3972734621u, 1541958123u, 256144497u, 2675339486u, 4055395548u, 4209367667u),
	SC(3899025122u, 159421581u, 684898980u, 3299122517u, 4294073145u, 1432967880u, 298637016u, 4169308298u, 2184881981u, 549517384u, 1722336827u, 1446107911u, 3097583453u, 2430049850u, 23871552u, 2769316231u),
	SC(454879299u, 2506071180u, 685424913u, 1586115964u, 3739465507u, 1892797750u, 2634261446u, 461271874u, 1602636000u, 1231373405u, 3431819543u, 3678787544u, 826660844u, 1912004887u, 2390177572u, 2745071695u)
},
{
	SC(4276811043u, 1059097804u, 289900404u, 3137716705u, 3430869283u, 853997644u, 2534016377u, 2935805170u, 1207363272u, 1046214590u, 1464072054u, 3859266163u, 2822765506u, 4056252869u, 3234536856u, 2970346892u),
	SC(1107848321u, 3530054002u, 3063728370u, 2411260233u, 2151773796u, 1992367533u, 452845303u, 2000515834u, 2967581171u, 2030577785u, 1361248948u, 320123819u, 1514107806u, 2861220339u, 3414354882u, 3271151930u),
	SC(1603129579u, 1475913977u, 3512753704u, 2558173661u, 3149727230u, 2330111694u, 1224500114u, 15318u, 3353016208u, 194039451u, 2805611551u, 1261479176u, 3558608211u, 4084583046u, 2964990209u, 3717911682u),
	SC(3375017300u, 1835026114u, 1174849844u, 104042981u, 2705057661u, 3824090647u, 989860283u, 312294099u, 680304336u, 766797089u, 3374619394u, 2401643295u, 2657633584u, 750406370u, 1348478381u, 3389751656u)
},
{
	SC(3824059184u, 859274310u, 3575417504u, 2031700058u, 3460053353u, 3845330189u, 2749453433u, 4067197094u, 4149711934u, 2506719565u, 493599601u, 1428768643u, 1342993875u, 1964027032u, 407468978u, 2475215503u),
	SC(2508265589u, 1835337120u, 144393964u, 1686774423u, 3728282933u, 3548855171u, 2816165978u, 448310785u, 3131571614u, 3211253928u, 3249304541u, 1774134863u, 3772421675u, 3798786595u, 3711817145u, 2169824164u),
	SC(32143084u, 2710918433u, 715862337u, 389930087u, 2221145209u, 780694167u, 2803105449u, 3053866952u, 3367190643u, 2356359566u, 3612803918u, 3376924083u, 3128667863u, 1055559333u, 743267127u, 1636229763u),
	SC(942152421u, 924529791u, 3200379335u, 2216473553u, 1518198695u, 1749982867u, 3804310737u, 2901470813u, 2348087597u, 2465905835u, 3356813200u, 565045285u, 1150286792u, 2016334277u, 1623662921u, 1744657596u)
},
{
	SC(1808796868u, 1702566146u, 1375264075u, 2615953000u, 2965950393u, 1695782388u, 2343426588u, 2715536698u, 2228686994u, 3816453121u, 2164987884u, 1041123441u, 667190396u, 2947698065u, 605361351u, 2006737381u),
	SC(2152511832u, 2808902472u, 396766736u, 45163647u, 1176778983u, 2964564331u, 3254967387u, 12684777u, 3346396686u, 2654599951u, 2022589511u, 4223927952u, 3434018260u, 782073481u, 3870179765u, 2412969138u),
	SC(3506766224u, 4215699755u, 3265132994u, 1596694088u, 2568115528u, 862000635u, 3074727028u, 1746671278u, 3598160479u, 3913583347u, 1987267603u, 2939122739u, 2846590159u, 3081159893u, 3590920954u, 124180600u),
	SC(3089031975u, 2914228615u, 3369489731u, 2071754524u, 2422301244u, 3208043074u, 3972514342u, 1324812497u, 1858365131u, 2745510829u, 2851338147u, 1859718474u, 2239378800u, 1627399072u, 2499563783u, 3743438522u)
},
{
	SC(119920204u, 1093195661u, 297072634u, 3953067261u, 2423631007u, 3776093882u, 2235876342u, 1751039492u, 921352707u, 155940113u, 833209844u, 690647815u, 409140151u, 3292524092u, 509521330u, 2142657976u),
	SC(1074172420u, 3956560660u, 2765576142u, 1514152128u, 3815717847u, 4294393136u, 1617070931u, 2372425825u, 3625006267u, 1589460351u, 17469645u, 916374486u, 2628470982u, 4104017283u, 3613829856u, 1296461095u),
	SC(2417628797u, 434113733u, 347322148u, 1973353060u, 1052223694u, 2489772785u, 3069882824u, 1672935871u, 3774929361u, 3779403529u, 727455585u, 506274678u, 1974585690u, 2803500332u, 3880352355u, 2852036869u),
	SC(4042964279u, 972373289u, 2149449957u, 810333657u, 2740269606u, 4294556254u, 3372093488u, 645110813u, 3441665397u, 248553132u, 4165233804u, 2133925580u, 2024582183u, 974116599u, 2559302342u, 907691640u)
},
{
	SC(2404290008u, 551018534u, 3459234433u, 419597992u, 1972345324u, 4156305161u, 3527005711u, 604142749u, 2176391549u, 1937020765u, 466413583u, 445259396u, 430417494u, 1889917985u, 1236273825u, 1610962755u),
	SC(3907300388u, 461727940u, 3469013130u, 2611871544u, 2277585634u, 1202574863u, 1010420602u, 2298806908u, 2311540248u, 1953724441u, 1877058742u, 992514980u, 2254299312u, 2002098425u, 860900005u, 2890218129u),
	SC(3869811984u, 4147212017u, 1313925624u, 3364106784u, 3225286495u, 3842562080u, 4093251003u, 1587351444u, 516793856u, 352093800u, 850522865u, 3087846162u, 2864496532u, 4149152365u, 3698092330u, 2717925551u),
	SC(1965851236u, 3216050915u, 2931553633u, 1063637393u, 3533008444u, 2807533139u, 713786812u, 3944556878u, 536199488u, 106266739u, 3659319211u, 4202747077u, 3579273518u, 211354118u, 1876465071u, 298666300u)
},
{
	SC(2593803771u, 1633427065u, 3267467801u, 875562818u, 1932112370u, 192604181u, 2396580849u, 1484312622u, 970619813u, 4055463243u, 3875191799u, 172341226u, 1555884586u, 3660378812u, 2192229995u, 1183512881u),
	SC(336961210u, 2429966559u, 4280956710u, 2595621898u, 1967179407u, 2810053433u, 2360142687u, 1650644566u, 1150788249u, 666068449u, 900169569u, 3144395892u, 1763238854u, 2046390305u, 2536267795u, 226560486u),
	SC(223166076u, 782629748u, 1159073256u, 431932633u, 197673913u, 4229233268u, 1812772930u, 453158757u, 3042313935u, 1434181308u, 2430243413u, 4137912981u, 1589402008u, 3204585224u, 3993670050u, 343590532u),
	SC(449690994u, 319806074u, 305004892u, 4077917808u, 3624468883u, 2189889725u, 535999042u, 1564399766u, 3100381318u, 880463501u, 2240587453u, 1453850917u, 2098152243u, 187061279u, 2556820292u, 3321055703u)
},
{
	SC(2475105093u, 2199905630u, 2184413732u, 2864493576u, 650198825u, 1690664913u, 194212127u, 1319451903u, 2033204333u, 444617977u, 3597423908u, 2415512974u, 397802954u, 4193928072u, 2600490466u, 22809172u),
	SC(2199507330u, 1506507893u, 579678542u, 2108807958u, 3813449570u, 737470611u, 4033840836u, 824368209u, 97307470u, 3801467614u, 3996740480u, 284558397u, 3641971730u, 3102425622u, 1626983523u, 4002871006u),
	SC(487823224u, 1685221259u, 1997782711u, 1617354589u, 3574687528u, 3580399598u, 3792675119u, 351896957u, 66912916u, 3652873852u, 2047393123u, 3611768414u, 3940203191u, 1609681546u, 2501330281u, 3338397968u),
	SC(2730586736u, 694867425u, 2095124930u, 2308182438u, 661584751u, 3598273149u, 556778443u, 2107619889u, 2963466614u, 1478501027u, 2730899139u, 738789883u, 87276538u, 423592806u, 3864462020u, 3772277406u)
},
{
	SC(615994432u, 968963356u, 3436096730u, 3541857676u, 543371738u, 2275571690u, 1485456246u, 2195380075u, 2236529476u, 2740053810u, 3640697310u, 3685787103u, 378155292u, 1257250263u, 1685202225u, 2735940115u),
	SC(3365723994u, 3233473616u, 4292918727u, 4028548222u, 2315480265u, 1138806130u, 610060892u, 814547079u, 3846780411u, 1860863520u, 2830655398u, 3594327274u, 381873610u, 2466081500u, 2146090037u, 2438568651u),
	SC(626941770u, 734214893u, 2879567852u, 2989408805u, 819182369u, 4154866660u, 3177066349u, 2907236647u, 2043405376u, 148540537u, 1958724781u, 655745771u, 4005742928u, 144708920u, 3195624737u, 3294802440u),
	SC(3779690491u, 2872348419u, 3926351178u, 3183728123u, 2998514707u, 1571508624u, 764287321u, 736460288u, 3810086061u, 1355473395u, 2121349842u, 1538668027u, 1962331070u, 2205688849u, 1705565110u, 3438178218u)
},
{
	SC(3119340081u, 2862892011u, 2581114858u, 2066921503u, 1482724458u, 1516135342u, 3740444348u, 633618335u, 3854505391u, 1040867285u, 312560237u, 3762086043u, 2821402540u, 1874387307u, 1887916767u, 2515566790u),
	SC(1169191436u, 2088376053u, 2651309986u, 3120013004u, 424428695u, 705129470u, 3446022537u, 257013236u, 3098335060u, 2794295542u, 2458891541u, 3575471238u, 3093988139u, 352756305u, 1148465314u, 4065705103u),
	SC(2320246151u, 3441943859u, 2105839446u, 1127380105u, 433302152u, 114604356u, 3570681481u, 97247661u, 1478288627u, 1953610440u, 2660257199u, 3290436596u, 609329493u, 1805724333u, 3736086099u, 2509400120u),
	SC(1290819792u, 4120223469u, 2269129063u, 2015215524u, 702520801u, 846607351u, 2796770526u, 3957217962u, 2455027893u, 1889509516u, 1749703137u, 409248010u, 1011782489u, 3717313435u, 352742190u, 3866665384u)
},
{
	SC(1226869143u, 860995366u, 3844365560u, 2949031580u, 3131198920u, 89546485u, 3550374405u, 2336022295u, 2754047952u, 527781768u, 297652557u, 3519992023u, 2344059967u, 2826364886u, 2503066147u, 48875956u),
	SC(2064223472u, 4170670972u, 3442657693u, 3734351065u, 772127559u, 2976536779u, 3588847655u, 1933986041u, 491681586u, 748272081u, 3711110902u, 3914666890u, 114341382u, 424194151u, 3992044443u, 1638597893u),
	SC(573249158u, 2194313036u, 187907496u, 975125755u, 3785334330u, 2337897707u, 3467368030u, 1913319997u, 1920481035u, 3340935483u, 3640747231u, 1093811620u, 1823978310u, 1007954167u, 643612629u, 1829604661u),
	SC(2547681801u, 2318731186u, 190788363u, 3020256811u, 3486893617u, 3984808880u, 2217400157u, 2719439921u, 1543838447u, 2725838041u, 2732732651u, 2571102426u, 4039140102u, 346400433u, 2040270036u, 3549499716u)
},
{
	SC(643254237u, 2668430230u, 4205134369u, 1241842066u, 1038603126u, 4046940321u, 1356505240u, 2462740951u, 1093623353u, 3682382337u, 1023949856u, 433965863u, 805112331u, 2302754433u, 1998109410u, 4044492715u),
	SC(2441752430u, 2252063997u, 2276842309u, 358030690u, 1357413447u, 4238381388u, 729209311u, 408685106u, 2773818813u, 1551078407u, 2282378375u, 2363627702u, 1986987347u, 2029101139u, 396284872u, 1060515830u),
	SC(1839660827u, 3971561168u, 514020292u, 3393164442u, 2417311433u, 322081286u, 2342249107u, 2921896334u, 2184094080u, 2187706290u, 1072088772u, 1375085125u, 1099278355u, 3824555524u, 3364898024u, 1432019110u),
	SC(3154587866u, 2584103018u, 2570472941u, 190918583u, 2889272609u, 1181711055u, 3770557998u, 1440797289u, 2097141926u, 332350415u, 2127204431u, 2527717853u, 2337594658u, 1228349589u, 2504537490u, 1691859104u)
},
{
	SC(2532748959u, 2217220377u, 1347960721u, 3568791237u, 1006754848u, 1829163834u, 627091706u, 301882799u, 2864915541u, 2898727542u, 4025295836u, 2873293708u, 616372442u, 1615565118u, 3184603530u, 219922979u),
	SC(4065131546u, 2586412172u, 4057568976u, 2145140449u, 4279554467u, 2810257176u, 3904752711u, 2810209588u, 3773052477u, 706904008u, 771163317u, 828641491u, 2792483375u, 54985408u, 1913191207u, 1813844703u),
	SC(287551380u, 3899600367u, 90305680u, 2494240268u, 2574195029u, 3693451256u, 4269169707u, 3564713593u, 970023080u, 3405034180u, 3840495751u, 1855598979u, 1440012839u, 2625512489u, 158736485u, 2942481089u),
	SC(4122519524u, 1833636106u, 1188113836u, 3540572882u, 1065306493u, 3047729005u, 3377954214u, 4036244528u, 2203664835u, 2972626310u, 1822683230u, 3299907923u, 2592781888u, 1044710800u, 933859526u, 2294387247u)
},
{
	SC(254836555u, 3077209039u, 535256453u, 101338212u, 3343430447u, 1218326710u, 385898477u, 576495253u, 4229958338u, 1000586861u, 2857193350u, 3365919835u, 2393902988u, 3956238913u, 1363218498u, 2904039349u),
	SC(3687780594u, 3829065812u, 2247974925u, 3399135869u, 129644861u, 3869455296u, 2030161860u, 1429546345u, 1221870733u, 2363913439u, 220548873u, 402506640u, 3734677759u, 696688039u, 1277503948u, 3712446392u),
	SC(950039042u, 2721916669u, 1715447777u, 2391409321u, 640745758u, 1467158564u, 1047624387u, 2688090232u, 4217395116u, 2857348023u, 3303613131u, 2871754673u, 3840979879u, 1809978871u, 2112001747u, 3983580655u),
	SC(1540614060u, 100163999u, 1572306537u, 4148257097u, 3031410119u, 2513592251u, 4213023149u, 2655393763u, 2598832624u, 3609693006u, 191271323u, 3328628283u, 74170920u, 2359908075u, 773858187u, 611474774u)
},
{
	SC(904169586u, 1349784970u, 2368656274u, 3514365666u, 3838066633u, 109687597u, 1597459461u, 3593971003u, 2501130050u, 2075136091u, 1585406194u, 3646943588u, 4286614395u, 3266140461u, 1754828382u, 3143456377u),
	SC(2249819706u, 3567094453u, 1822006903u, 1179902375u, 1254849123u, 3988150336u, 1995682734u, 2420061561u, 1159004321u, 1034717096u, 2900885070u, 1692164468u, 2305511426u, 1729510378u, 490582645u, 3089583301u),
	SC(2951740380u, 3739114159u, 3700508508u, 269031634u, 4119869919u, 3044364120u, 2737874025u, 408283224u, 3764300973u, 4266881177u, 901644659u, 1028345286u, 1987367331u, 2106662146u, 245692239u, 1801705988u),
	SC(728333338u, 757982977u, 374564642u, 2489206473u, 569389015u, 3639213382u, 2410279257u, 502022771u, 1842785627u, 1146360661u, 2209645375u, 283006625u, 3977692584u, 2010485741u, 624474460u, 3464988143u)
},
{
	SC(3437677747u, 4229741761u, 524305791u, 622165284u, 1832906658u, 616775921u, 3957013250u, 1057153999u, 2543296862u, 2900412000u, 3952324997u, 2137909214u, 756879158u, 2358914795u, 2772117600u, 3012738863u),
	SC(1910987988u, 1495405769u, 1433256375u, 2814952911u, 2007695945u, 2796006810u, 932068957u, 3511718813u, 1309447687u, 3249702510u, 558840032u, 3564477427u, 3012501370u, 893979501u, 1892626021u, 4259908548u),
	SC(3735637403u, 3223465030u, 3328185020u, 2443427380u, 3588194647u, 1453971837u, 1388889265u, 619521084u, 3017762431u, 638951631u, 779878690u, 1672433767u, 189257931u, 3525584370u, 467378482u, 1580414344u),
	SC(1740326806u, 3364799097u, 2280117479u, 3173928606u, 196182123u, 2513688756u, 3785741159u, 105803009u, 720390983u, 1658167586u, 1003552070u, 1237199645u, 2464112010u, 2228138501u, 4072083246u, 3043463824u)
},
{
	SC(2253990976u, 1907759613u, 41826341u, 3394788573u, 3926296920u, 2069488571u, 3008893045u, 2748025494u, 2453161151u, 706313093u, 2989668723u, 690146828u, 2722307524u, 2778540016u, 804500212u, 2943812543u),
	SC(3895076977u, 4227830887u, 2517668608u, 654291094u, 3645938499u, 1853384343u, 3898365875u, 949964733u, 1999811609u, 4040589991u, 2595243943u, 3567588997u, 4239015052u, 3447788988u, 1333073140u, 387434500u),
	SC(2617745338u, 852633742u, 2692915105u, 21507515u, 2150775166u, 3329677124u, 3350253188u, 2714039609u, 722933561u, 2247779386u, 3128104147u, 2263910080u, 3565701987u, 1080206536u, 1065289130u, 1465464486u),
	SC(2028625713u, 490477891u, 3828899870u, 2827333262u, 4025390057u, 645303682u, 1049143069u, 2619529075u, 2503782621u, 2302340403u, 2418140731u, 662489697u, 1299655806u, 2730027583u, 3172277012u, 1555121340u)
},
{
	SC(1227465576u, 4186188055u, 1945445231u, 3713842559u, 2833833375u, 39963563u, 1497935191u, 2039267193u, 648193035u, 862129749u, 2067230680u, 323652936u, 1412172008u, 3268418201u, 92721980u, 1725133862u),
	SC(3142294756u, 3101500095u, 678671070u, 4070328655u, 1646103012u, 2931768355u, 1450052820u, 3036664456u, 3573028674u, 1333234022u, 19353544u, 3903478868u, 1144323239u, 1802745401u, 2689248101u, 2344057903u),
	SC(1878460181u, 398312100u, 3223747754u, 952800941u, 2317571908u, 707058567u, 2692538054u, 3283100410u, 790016661u, 2732292717u, 840073411u, 2772303092u, 1733149205u, 954377558u, 1976383461u, 3555619682u),
	SC(3043073118u, 3988558576u, 3364527277u, 2572525707u, 1984812675u, 907786226u, 2355173463u, 3564356699u, 301368907u, 907108737u, 3534700396u, 4268985476u, 2015423457u, 1408288811u, 350602874u, 3013747006u)
},
{
	SC(3343197847u, 3613988450u, 2923132236u, 2078350840u, 2893073548u, 3806857883u, 2520297714u, 2737040597u, 4270123363u, 842123948u, 1671808972u, 2429482643u, 2795413824u, 3360088499u, 3110760390u, 1756642408u),
	SC(3348613721u, 2513282826u, 2737869756u, 1333756870u, 439462686u, 3688296717u, 836819461u, 1693717511u, 3460982009u, 2927554331u, 2059382164u, 4104562673u, 3343263374u, 2416351582u, 150459153u, 461502558u),
	SC(680144422u, 2411264808u, 700292385u, 1321567755u, 4229879159u, 4094452100u, 2040576289u, 3270817402u, 2202259517u, 1433140964u, 3060573592u, 4110339019u, 2854691778u, 4089664003u, 3994185997u, 3657370450u),
	SC(2057316978u, 2918176633u, 4254682231u, 1769922882u, 3710243176u, 952678560u, 1366865895u, 938684466u, 2690709460u, 2383161641u, 2252474535u, 375919259u, 993593539u, 132684704u, 3890567846u, 1581177230u)
},
{
	SC(882007322u, 2982658177u, 3913668205u, 1626159438u, 4101301130u, 1110794931u, 2512146900u, 3304411937u, 2398674264u, 2920702389u, 2814584762u, 2889942502u, 3492637232u, 576964088u, 1656165114u, 2959402338u),
	SC(733944299u, 161882394u, 2021771232u, 1417913112u, 3386446464u, 3500017204u, 710191602u, 3043314664u, 63929153u, 3215663501u, 3783446324u, 843385535u, 2295995926u, 4256667289u, 3976116578u, 970203859u),
	SC(2549199626u, 1826807182u, 486758651u, 1169437438u, 3194853654u, 887932836u, 3083554620u, 4050010040u, 3352011307u, 2292577732u, 1234112290u, 3467019022u, 464801308u, 2141034547u, 1611897902u, 2547693530u),
	SC(3050366744u, 1645873728u, 3266179914u, 1042179286u, 3148690840u, 3868476470u, 4177032272u, 1465737711u, 776203120u, 2411258528u, 4064942610u, 2055801863u, 226080029u, 1625531009u, 1687878204u, 405625719u)
},
{
	SC(1177583865u, 434951215u, 1497219594u, 758210764u, 1960401198u, 1148135837u, 3193194228u, 594172695u, 711270413u, 3786500469u, 2640082390u, 262588006u, 3125113485u, 876438329u, 1210266513u, 1623280150u),
	SC(1417604899u, 1365791138u, 789974720u, 2014988785u, 343986301u, 638036826u, 2305125524u, 796347226u, 3949929629u, 3999419566u, 3418726146u, 1675235276u, 3812249948u, 2218538546u, 1713312740u, 969208036u),
	SC(2012268962u, 1372883769u, 1660497450u, 1738529228u, 4099469690u, 3992291518u, 3569181768u, 1207513199u, 895436839u, 2970509643u, 1167074347u, 3662966355u, 3688110558u, 488275875u, 546149200u, 882301708u),
	SC(2179335873u, 431419264u, 1099603976u, 2126182867u, 2061496831u, 2820633498u, 388651019u, 667374684u, 3719315532u, 3848344517u, 2475819906u, 1831525042u, 1703982345u, 1166431238u, 3458191958u, 1701126298u)
},
{
	SC(2463394285u, 3767967190u, 2124249905u, 4042720227u, 2546652475u, 3859815214u, 4005065037u, 1683925660u, 614508422u, 2439157748u, 1783875522u, 43662485u, 2163131681u, 55949347u, 4031284320u, 962158034u),
	SC(3842200385u, 1548337741u, 4134709070u, 1320341768u, 1476040826u, 2948923768u, 4290414487u, 1426260079u, 944907873u, 4268239236u, 2070796897u, 2646336635u, 901827051u, 3080412463u, 745252994u, 650876372u),
	SC(3497488416u, 3480077417u, 3473018085u, 3863724772u, 506196246u, 1330544975u, 414956623u, 4100501688u, 2574983523u, 3295085569u, 672847947u, 2836712420u, 3882507441u, 3415261629u, 3973760389u, 1646047398u),
	SC(2283453852u, 119009442u, 906880269u, 1722398293u, 3108347490u, 2158593498u, 3893490354u, 357445754u, 200197489u, 326435615u, 894294620u, 3117954941u, 481597462u, 525104013u, 4139373347u, 261802701u)
},
{
	SC(2877102266u, 2506087082u, 2980100901u, 629427754u, 2637045837u, 4280436104u, 183069761u, 3868254224u, 1308659889u, 3705018819u, 285167655u, 2622703122u, 2230068327u, 2008428921u, 3355911364u, 1120928260u),
	SC(442073827u, 937683792u, 3866751566u, 3276225357u, 452189374u, 2889644694u, 2841596409u, 2844217958u, 3701917204u, 2245351813u, 33407529u, 1458461133u, 4207362153u, 1651911067u, 2711221148u, 2258525340u),
	SC(3168765711u, 2371065012u, 4059251820u, 170257517u, 95734073u, 3046696342u, 2169138650u, 2689907503u, 119339997u, 3517609762u, 2301592548u, 3928878160u, 2177159502u, 1418335940u, 672708461u, 1461844860u),
	SC(3408457434u, 864702600u, 229967322u, 2493308402u, 1948124958u, 932156145u, 3686409998u, 2620533847u, 3649878625u, 3438060863u, 2105857823u, 4170365282u, 1864819030u, 2216504827u, 2058008633u, 1062295811u)
}
};

__device__
static int secp256k1_scalar_reduce(secp256k1_scalar* r, uint32_t overflow) {
	uint64_t t;
	t = (uint64_t)r->d[0] + overflow * SECP256K1_N_C_0;
	r->d[0] = t & 0xFFFFFFFFUL; t >>= 32;
	t += (uint64_t)r->d[1] + overflow * SECP256K1_N_C_1;
	r->d[1] = t & 0xFFFFFFFFUL; t >>= 32;
	t += (uint64_t)r->d[2] + overflow * SECP256K1_N_C_2;
	r->d[2] = t & 0xFFFFFFFFUL; t >>= 32;
	t += (uint64_t)r->d[3] + overflow * SECP256K1_N_C_3;
	r->d[3] = t & 0xFFFFFFFFUL; t >>= 32;
	t += (uint64_t)r->d[4] + overflow * SECP256K1_N_C_4;
	r->d[4] = t & 0xFFFFFFFFUL; t >>= 32;
	t += (uint64_t)r->d[5];
	r->d[5] = t & 0xFFFFFFFFUL; t >>= 32;
	t += (uint64_t)r->d[6];
	r->d[6] = t & 0xFFFFFFFFUL; t >>= 32;
	t += (uint64_t)r->d[7];
	r->d[7] = t & 0xFFFFFFFFUL;
	return overflow;
}
__device__
static int secp256k1_scalar_check_overflow(const secp256k1_scalar* a) {
	int yes;
	int no;
	yes = 0; no = 0;
	no |= (a->d[7] < SECP256K1_N_7); /* No need for a > check. */
	no |= (a->d[6] < SECP256K1_N_6); /* No need for a > check. */
	no |= (a->d[5] < SECP256K1_N_5); /* No need for a > check. */
	no |= (a->d[4] < SECP256K1_N_4);
	yes |= (a->d[4] > SECP256K1_N_4) & ~no;
	no |= (a->d[3] < SECP256K1_N_3) & ~yes;
	yes |= (a->d[3] > SECP256K1_N_3) & ~no;
	no |= (a->d[2] < SECP256K1_N_2) & ~yes;
	yes |= (a->d[2] > SECP256K1_N_2) & ~no;
	no |= (a->d[1] < SECP256K1_N_1) & ~yes;
	yes |= (a->d[1] > SECP256K1_N_1) & ~no;
	yes |= (a->d[0] >= SECP256K1_N_0) & ~no;
	return yes;
}
__device__
static void secp256k1_scalar_set_b32(secp256k1_scalar* r, const uint8_t* b32, int* overflow) {
	int over;
	r->d[0] = (uint32_t)b32[31] | (uint32_t)b32[30] << 8 | (uint32_t)b32[29] << 16 | (uint32_t)b32[28] << 24;
	r->d[1] = (uint32_t)b32[27] | (uint32_t)b32[26] << 8 | (uint32_t)b32[25] << 16 | (uint32_t)b32[24] << 24;
	r->d[2] = (uint32_t)b32[23] | (uint32_t)b32[22] << 8 | (uint32_t)b32[21] << 16 | (uint32_t)b32[20] << 24;
	r->d[3] = (uint32_t)b32[19] | (uint32_t)b32[18] << 8 | (uint32_t)b32[17] << 16 | (uint32_t)b32[16] << 24;
	r->d[4] = (uint32_t)b32[15] | (uint32_t)b32[14] << 8 | (uint32_t)b32[13] << 16 | (uint32_t)b32[12] << 24;
	r->d[5] = (uint32_t)b32[11] | (uint32_t)b32[10] << 8 | (uint32_t)b32[9] << 16 | (uint32_t)b32[8] << 24;
	r->d[6] = (uint32_t)b32[7] | (uint32_t)b32[6] << 8 | (uint32_t)b32[5] << 16 | (uint32_t)b32[4] << 24;
	r->d[7] = (uint32_t)b32[3] | (uint32_t)b32[2] << 8 | (uint32_t)b32[1] << 16 | (uint32_t)b32[0] << 24;
	over = secp256k1_scalar_reduce(r, secp256k1_scalar_check_overflow(r));
	if (overflow) {
		*overflow = over;
	}
}
__device__
static int secp256k1_scalar_is_zero(const secp256k1_scalar* a) {
	return (a->d[0] | a->d[1] | a->d[2] | a->d[3] | a->d[4] | a->d[5] | a->d[6] | a->d[7]) == 0;
}
__device__
static int secp256k1_scalar_set_b32_seckey(secp256k1_scalar* r, const uint8_t* bin) {
	int overflow;
	secp256k1_scalar_set_b32(r, bin, &overflow);
	return (!overflow) & (!secp256k1_scalar_is_zero(r));
}
__device__
static void secp256k1_scalar_cmov(secp256k1_scalar* r, const secp256k1_scalar* a, int flag) {
	uint32_t mask0, mask1;
	mask0 = flag + ~((uint32_t)0);
	mask1 = ~mask0;
	r->d[0] = (r->d[0] & mask0) | (a->d[0] & mask1);
	r->d[1] = (r->d[1] & mask0) | (a->d[1] & mask1);
	r->d[2] = (r->d[2] & mask0) | (a->d[2] & mask1);
	r->d[3] = (r->d[3] & mask0) | (a->d[3] & mask1);
	r->d[4] = (r->d[4] & mask0) | (a->d[4] & mask1);
	r->d[5] = (r->d[5] & mask0) | (a->d[5] & mask1);
	r->d[6] = (r->d[6] & mask0) | (a->d[6] & mask1);
	r->d[7] = (r->d[7] & mask0) | (a->d[7] & mask1);
}
__device__
static void secp256k1_fe_clear(secp256k1_fe* a) {
	a->n[0] = 0;
	a->n[1] = 0;
	a->n[2] = 0;
	a->n[3] = 0;
	a->n[4] = 0;
	a->n[5] = 0;
	a->n[6] = 0;
	a->n[7] = 0;
	a->n[8] = 0;
	a->n[9] = 0;
}

__device__
static void secp256k1_gej_set_infinity(secp256k1_gej* r) {
	r->infinity = 1;
	secp256k1_fe_clear(&r->x);
	secp256k1_fe_clear(&r->y);
	secp256k1_fe_clear(&r->z);
}
__device__
static uint32_t secp256k1_scalar_get_bits(const secp256k1_scalar* a, uint32_t offset, uint32_t count) {
	return (a->d[offset >> 5] >> (offset & 0x1F)) & ((1 << count) - 1);
}
__device__
static void secp256k1_fe_from_storage(secp256k1_fe* r, const secp256k1_fe_storage* a) {
	r->n[0] = a->n[0] & 0x3FFFFFFUL;
	r->n[1] = a->n[0] >> 26 | ((a->n[1] << 6) & 0x3FFFFFFUL);
	r->n[2] = a->n[1] >> 20 | ((a->n[2] << 12) & 0x3FFFFFFUL);
	r->n[3] = a->n[2] >> 14 | ((a->n[3] << 18) & 0x3FFFFFFUL);
	r->n[4] = a->n[3] >> 8 | ((a->n[4] << 24) & 0x3FFFFFFUL);
	r->n[5] = (a->n[4] >> 2) & 0x3FFFFFFUL;
	r->n[6] = a->n[4] >> 28 | ((a->n[5] << 4) & 0x3FFFFFFUL);
	r->n[7] = a->n[5] >> 22 | ((a->n[6] << 10) & 0x3FFFFFFUL);
	r->n[8] = a->n[6] >> 16 | ((a->n[7] << 16) & 0x3FFFFFFUL);
	r->n[9] = a->n[7] >> 10;
}
__device__
static void secp256k1_ge_from_storage(secp256k1_ge* r, const secp256k1_ge_storage* a) {
	secp256k1_fe_from_storage(&r->x, &a->x);
	secp256k1_fe_from_storage(&r->y, &a->y);
	r->infinity = 0;
}

__constant__  uint32_t M = 0x3FFFFFFUL, R0 = 0x3D10UL, R1 = 0x400UL;
__device__
static void secp256k1_fe_sqr_inner(uint32_t* r, const uint32_t* a) {
	uint64_t c, d;
	uint64_t u0, u1, u2, u3, u4, u5, u6, u7, u8;
	uint32_t t9, t0, t1, t2, t3, t4, t5, t6, t7;


	d = (uint64_t)(a[0] * 2) * a[9]
		+ (uint64_t)(a[1] * 2) * a[8]
		+ (uint64_t)(a[2] * 2) * a[7]
		+ (uint64_t)(a[3] * 2) * a[6]
		+ (uint64_t)(a[4] * 2) * a[5];
	t9 = d & M; d >>= 26;
	c = (uint64_t)a[0] * a[0];
	d += (uint64_t)(a[1] * 2) * a[9]
		+ (uint64_t)(a[2] * 2) * a[8]
		+ (uint64_t)(a[3] * 2) * a[7]
		+ (uint64_t)(a[4] * 2) * a[6]
		+ (uint64_t)a[5] * a[5];
	u0 = d & M; d >>= 26; c += u0 * R0;
	t0 = c & M; c >>= 26; c += u0 * R1;
	c += (uint64_t)(a[0] * 2) * a[1];
	d += (uint64_t)(a[2] * 2) * a[9]
		+ (uint64_t)(a[3] * 2) * a[8]
		+ (uint64_t)(a[4] * 2) * a[7]
		+ (uint64_t)(a[5] * 2) * a[6];
	u1 = d & M; d >>= 26; c += u1 * R0;
	t1 = c & M; c >>= 26; c += u1 * R1;
	c += (uint64_t)(a[0] * 2) * a[2]
		+ (uint64_t)a[1] * a[1];
	d += (uint64_t)(a[3] * 2) * a[9]
		+ (uint64_t)(a[4] * 2) * a[8]
		+ (uint64_t)(a[5] * 2) * a[7]
		+ (uint64_t)a[6] * a[6];
	u2 = d & M; d >>= 26; c += u2 * R0;
	t2 = c & M; c >>= 26; c += u2 * R1;
	c += (uint64_t)(a[0] * 2) * a[3]
		+ (uint64_t)(a[1] * 2) * a[2];
	d += (uint64_t)(a[4] * 2) * a[9]
		+ (uint64_t)(a[5] * 2) * a[8]
		+ (uint64_t)(a[6] * 2) * a[7];
	u3 = d & M; d >>= 26; c += u3 * R0;
	t3 = c & M; c >>= 26; c += u3 * R1;
	c += (uint64_t)(a[0] * 2) * a[4]
		+ (uint64_t)(a[1] * 2) * a[3]
		+ (uint64_t)a[2] * a[2];
	d += (uint64_t)(a[5] * 2) * a[9]
		+ (uint64_t)(a[6] * 2) * a[8]
		+ (uint64_t)a[7] * a[7];
	u4 = d & M; d >>= 26; c += u4 * R0;
	t4 = c & M; c >>= 26; c += u4 * R1;
	c += (uint64_t)(a[0] * 2) * a[5]
		+ (uint64_t)(a[1] * 2) * a[4]
		+ (uint64_t)(a[2] * 2) * a[3];
	d += (uint64_t)(a[6] * 2) * a[9]
		+ (uint64_t)(a[7] * 2) * a[8];
	u5 = d & M; d >>= 26; c += u5 * R0;
	t5 = c & M; c >>= 26; c += u5 * R1;
	c += (uint64_t)(a[0] * 2) * a[6]
		+ (uint64_t)(a[1] * 2) * a[5]
		+ (uint64_t)(a[2] * 2) * a[4]
		+ (uint64_t)a[3] * a[3];
	d += (uint64_t)(a[7] * 2) * a[9]
		+ (uint64_t)a[8] * a[8];
	u6 = d & M; d >>= 26; c += u6 * R0;
	t6 = c & M; c >>= 26; c += u6 * R1;
	c += (uint64_t)(a[0] * 2) * a[7]
		+ (uint64_t)(a[1] * 2) * a[6]
		+ (uint64_t)(a[2] * 2) * a[5]
		+ (uint64_t)(a[3] * 2) * a[4];
	d += (uint64_t)(a[8] * 2) * a[9];
	u7 = d & M; d >>= 26; c += u7 * R0;
	t7 = c & M; c >>= 26; c += u7 * R1;
	c += (uint64_t)(a[0] * 2) * a[8]
		+ (uint64_t)(a[1] * 2) * a[7]
		+ (uint64_t)(a[2] * 2) * a[6]
		+ (uint64_t)(a[3] * 2) * a[5]
		+ (uint64_t)a[4] * a[4];
	d += (uint64_t)a[9] * a[9];
	u8 = d & M; d >>= 26; c += u8 * R0;
	r[3] = t3;
	r[4] = t4;
	r[5] = t5;
	r[6] = t6;
	r[7] = t7;
	r[8] = c & M; c >>= 26; c += u8 * R1;
	c += d * R0 + t9;
	r[9] = c & (M >> 4); c >>= 22; c += d * (R1 << 4);
	d = c * (R0 >> 4) + t0;
	r[0] = d & M; d >>= 26;
	d += c * (R1 >> 4) + t1;
	r[1] = d & M; d >>= 26;
	d += t2;
	r[2] = d;
}
__device__
static void secp256k1_fe_sqr(secp256k1_fe* r, const secp256k1_fe* a) {
	secp256k1_fe_sqr_inner(r->n, a->n);
}
__device__
static void secp256k1_fe_normalize_weak(secp256k1_fe* r) {
	uint32_t t0, t1, t2, t3, t4, t5, t6, t7, t8, t9;
	t0 = r->n[0];
	t1 = r->n[1];
	t2 = r->n[2];
	t3 = r->n[3];
	t4 = r->n[4];
	t5 = r->n[5];
	t6 = r->n[6];
	t7 = r->n[7];
	t8 = r->n[8];
	t9 = r->n[9];

	/* Reduce t9 at the start so there will be at most a single carry from the first pass */
	uint32_t x;
	x = t9 >> 22; t9 &= 0x03FFFFFUL;

	/* The first pass ensures the magnitude is 1, ... */
	t0 += x * 0x3D1UL; t1 += (x << 6);
	t1 += (t0 >> 26); t0 &= 0x3FFFFFFUL;
	t2 += (t1 >> 26); t1 &= 0x3FFFFFFUL;
	t3 += (t2 >> 26); t2 &= 0x3FFFFFFUL;
	t4 += (t3 >> 26); t3 &= 0x3FFFFFFUL;
	t5 += (t4 >> 26); t4 &= 0x3FFFFFFUL;
	t6 += (t5 >> 26); t5 &= 0x3FFFFFFUL;
	t7 += (t6 >> 26); t6 &= 0x3FFFFFFUL;
	t8 += (t7 >> 26); t7 &= 0x3FFFFFFUL;
	t9 += (t8 >> 26); t8 &= 0x3FFFFFFUL;

	r->n[0] = t0; r->n[1] = t1; r->n[2] = t2; r->n[3] = t3; r->n[4] = t4;
	r->n[5] = t5; r->n[6] = t6; r->n[7] = t7; r->n[8] = t8; r->n[9] = t9;
}
__device__
static void secp256k1_fe_mul_inner(uint32_t* r, const uint32_t* a, const uint32_t* b) {
	uint64_t c, d;
	uint64_t u0, u1, u2, u3, u4, u5, u6, u7, u8;
	uint32_t t9, t1, t0, t2, t3, t4, t5, t6, t7;
	//const uint32_t M = 0x3FFFFFFUL, R0 = 0x3D10UL, R1 = 0x400UL;
	d = (uint64_t)a[0] * b[9]
		+ (uint64_t)a[1] * b[8]
		+ (uint64_t)a[2] * b[7]
		+ (uint64_t)a[3] * b[6]
		+ (uint64_t)a[4] * b[5]
		+ (uint64_t)a[5] * b[4]
		+ (uint64_t)a[6] * b[3]
		+ (uint64_t)a[7] * b[2]
		+ (uint64_t)a[8] * b[1]
		+ (uint64_t)a[9] * b[0];
	/* VERIFY_BITS(d, 64); */
	/* [d 0 0 0 0 0 0 0 0 0] = [p9 0 0 0 0 0 0 0 0 0] */
	t9 = d & M; d >>= 26;

	/* [d t9 0 0 0 0 0 0 0 0 0] = [p9 0 0 0 0 0 0 0 0 0] */

	c = (uint64_t)a[0] * b[0];

	/* [d t9 0 0 0 0 0 0 0 0 c] = [p9 0 0 0 0 0 0 0 0 p0] */
	d += (uint64_t)a[1] * b[9]
		+ (uint64_t)a[2] * b[8]
		+ (uint64_t)a[3] * b[7]
		+ (uint64_t)a[4] * b[6]
		+ (uint64_t)a[5] * b[5]
		+ (uint64_t)a[6] * b[4]
		+ (uint64_t)a[7] * b[3]
		+ (uint64_t)a[8] * b[2]
		+ (uint64_t)a[9] * b[1];

	/* [d t9 0 0 0 0 0 0 0 0 c] = [p10 p9 0 0 0 0 0 0 0 0 p0] */
	u0 = d & M; d >>= 26; c += u0 * R0;

	/* [d u0 t9 0 0 0 0 0 0 0 0 c-u0*R0] = [p10 p9 0 0 0 0 0 0 0 0 p0] */
	t0 = c & M; c >>= 26; c += u0 * R1;

	/* [d u0 t9 0 0 0 0 0 0 0 c-u0*R1 t0-u0*R0] = [p10 p9 0 0 0 0 0 0 0 0 p0] */
	/* [d 0 t9 0 0 0 0 0 0 0 c t0] = [p10 p9 0 0 0 0 0 0 0 0 p0] */

	c += (uint64_t)a[0] * b[1]
		+ (uint64_t)a[1] * b[0];

	/* [d 0 t9 0 0 0 0 0 0 0 c t0] = [p10 p9 0 0 0 0 0 0 0 p1 p0] */
	d += (uint64_t)a[2] * b[9]
		+ (uint64_t)a[3] * b[8]
		+ (uint64_t)a[4] * b[7]
		+ (uint64_t)a[5] * b[6]
		+ (uint64_t)a[6] * b[5]
		+ (uint64_t)a[7] * b[4]
		+ (uint64_t)a[8] * b[3]
		+ (uint64_t)a[9] * b[2];

	/* [d 0 t9 0 0 0 0 0 0 0 c t0] = [p11 p10 p9 0 0 0 0 0 0 0 p1 p0] */
	u1 = d & M; d >>= 26; c += u1 * R0;

	/* [d u1 0 t9 0 0 0 0 0 0 0 c-u1*R0 t0] = [p11 p10 p9 0 0 0 0 0 0 0 p1 p0] */
	t1 = c & M; c >>= 26; c += u1 * R1;

	/* [d u1 0 t9 0 0 0 0 0 0 c-u1*R1 t1-u1*R0 t0] = [p11 p10 p9 0 0 0 0 0 0 0 p1 p0] */
	/* [d 0 0 t9 0 0 0 0 0 0 c t1 t0] = [p11 p10 p9 0 0 0 0 0 0 0 p1 p0] */

	c += (uint64_t)a[0] * b[2]
		+ (uint64_t)a[1] * b[1]
		+ (uint64_t)a[2] * b[0];

	/* [d 0 0 t9 0 0 0 0 0 0 c t1 t0] = [p11 p10 p9 0 0 0 0 0 0 p2 p1 p0] */
	d += (uint64_t)a[3] * b[9]
		+ (uint64_t)a[4] * b[8]
		+ (uint64_t)a[5] * b[7]
		+ (uint64_t)a[6] * b[6]
		+ (uint64_t)a[7] * b[5]
		+ (uint64_t)a[8] * b[4]
		+ (uint64_t)a[9] * b[3];

	/* [d 0 0 t9 0 0 0 0 0 0 c t1 t0] = [p12 p11 p10 p9 0 0 0 0 0 0 p2 p1 p0] */
	u2 = d & M; d >>= 26; c += u2 * R0;
	/* [d u2 0 0 t9 0 0 0 0 0 0 c-u2*R0 t1 t0] = [p12 p11 p10 p9 0 0 0 0 0 0 p2 p1 p0] */
	t2 = c & M; c >>= 26; c += u2 * R1;

	/* [d u2 0 0 t9 0 0 0 0 0 c-u2*R1 t2-u2*R0 t1 t0] = [p12 p11 p10 p9 0 0 0 0 0 0 p2 p1 p0] */
	/* [d 0 0 0 t9 0 0 0 0 0 c t2 t1 t0] = [p12 p11 p10 p9 0 0 0 0 0 0 p2 p1 p0] */
	c += (uint64_t)a[0] * b[3]
		+ (uint64_t)a[1] * b[2]
		+ (uint64_t)a[2] * b[1]
		+ (uint64_t)a[3] * b[0];

	d += (uint64_t)a[4] * b[9]
		+ (uint64_t)a[5] * b[8]
		+ (uint64_t)a[6] * b[7]
		+ (uint64_t)a[7] * b[6]
		+ (uint64_t)a[8] * b[5]
		+ (uint64_t)a[9] * b[4];
	u3 = d & M; d >>= 26; c += u3 * R0;

	/* VERIFY_BITS(c, 64); */
	/* [d u3 0 0 0 t9 0 0 0 0 0 c-u3*R0 t2 t1 t0] = [p13 p12 p11 p10 p9 0 0 0 0 0 p3 p2 p1 p0] */
	t3 = c & M; c >>= 26; c += u3 * R1;

	c += (uint64_t)a[0] * b[4]
		+ (uint64_t)a[1] * b[3]
		+ (uint64_t)a[2] * b[2]
		+ (uint64_t)a[3] * b[1]
		+ (uint64_t)a[4] * b[0];

	/* [d 0 0 0 0 t9 0 0 0 0 c t3 t2 t1 t0] = [p13 p12 p11 p10 p9 0 0 0 0 p4 p3 p2 p1 p0] */
	d += (uint64_t)a[5] * b[9]
		+ (uint64_t)a[6] * b[8]
		+ (uint64_t)a[7] * b[7]
		+ (uint64_t)a[8] * b[6]
		+ (uint64_t)a[9] * b[5];

	/* [d 0 0 0 0 t9 0 0 0 0 c t3 t2 t1 t0] = [p14 p13 p12 p11 p10 p9 0 0 0 0 p4 p3 p2 p1 p0] */
	u4 = d & M; d >>= 26; c += u4 * R0;

	/* VERIFY_BITS(c, 64); */
	/* [d u4 0 0 0 0 t9 0 0 0 0 c-u4*R0 t3 t2 t1 t0] = [p14 p13 p12 p11 p10 p9 0 0 0 0 p4 p3 p2 p1 p0] */
	t4 = c & M; c >>= 26; c += u4 * R1;

	/* [d u4 0 0 0 0 t9 0 0 0 c-u4*R1 t4-u4*R0 t3 t2 t1 t0] = [p14 p13 p12 p11 p10 p9 0 0 0 0 p4 p3 p2 p1 p0] */
	/* [d 0 0 0 0 0 t9 0 0 0 c t4 t3 t2 t1 t0] = [p14 p13 p12 p11 p10 p9 0 0 0 0 p4 p3 p2 p1 p0] */

	c += (uint64_t)a[0] * b[5]
		+ (uint64_t)a[1] * b[4]
		+ (uint64_t)a[2] * b[3]
		+ (uint64_t)a[3] * b[2]
		+ (uint64_t)a[4] * b[1]
		+ (uint64_t)a[5] * b[0];

	/* [d 0 0 0 0 0 t9 0 0 0 c t4 t3 t2 t1 t0] = [p14 p13 p12 p11 p10 p9 0 0 0 p5 p4 p3 p2 p1 p0] */
	d += (uint64_t)a[6] * b[9]
		+ (uint64_t)a[7] * b[8]
		+ (uint64_t)a[8] * b[7]
		+ (uint64_t)a[9] * b[6];

	/* [d 0 0 0 0 0 t9 0 0 0 c t4 t3 t2 t1 t0] = [p15 p14 p13 p12 p11 p10 p9 0 0 0 p5 p4 p3 p2 p1 p0] */
	u5 = d & M; d >>= 26; c += u5 * R0;

	/* VERIFY_BITS(c, 64); */
	/* [d u5 0 0 0 0 0 t9 0 0 0 c-u5*R0 t4 t3 t2 t1 t0] = [p15 p14 p13 p12 p11 p10 p9 0 0 0 p5 p4 p3 p2 p1 p0] */
	t5 = c & M; c >>= 26; c += u5 * R1;

	/* [d u5 0 0 0 0 0 t9 0 0 c-u5*R1 t5-u5*R0 t4 t3 t2 t1 t0] = [p15 p14 p13 p12 p11 p10 p9 0 0 0 p5 p4 p3 p2 p1 p0] */
	/* [d 0 0 0 0 0 0 t9 0 0 c t5 t4 t3 t2 t1 t0] = [p15 p14 p13 p12 p11 p10 p9 0 0 0 p5 p4 p3 p2 p1 p0] */

	c += (uint64_t)a[0] * b[6]
		+ (uint64_t)a[1] * b[5]
		+ (uint64_t)a[2] * b[4]
		+ (uint64_t)a[3] * b[3]
		+ (uint64_t)a[4] * b[2]
		+ (uint64_t)a[5] * b[1]
		+ (uint64_t)a[6] * b[0];

	/* [d 0 0 0 0 0 0 t9 0 0 c t5 t4 t3 t2 t1 t0] = [p15 p14 p13 p12 p11 p10 p9 0 0 p6 p5 p4 p3 p2 p1 p0] */
	d += (uint64_t)a[7] * b[9]
		+ (uint64_t)a[8] * b[8]
		+ (uint64_t)a[9] * b[7];

	/* [d 0 0 0 0 0 0 t9 0 0 c t5 t4 t3 t2 t1 t0] = [p16 p15 p14 p13 p12 p11 p10 p9 0 0 p6 p5 p4 p3 p2 p1 p0] */
	u6 = d & M; d >>= 26; c += u6 * R0;

	/* VERIFY_BITS(c, 64); */
	/* [d u6 0 0 0 0 0 0 t9 0 0 c-u6*R0 t5 t4 t3 t2 t1 t0] = [p16 p15 p14 p13 p12 p11 p10 p9 0 0 p6 p5 p4 p3 p2 p1 p0] */
	t6 = c & M; c >>= 26; c += u6 * R1;

	/* [d u6 0 0 0 0 0 0 t9 0 c-u6*R1 t6-u6*R0 t5 t4 t3 t2 t1 t0] = [p16 p15 p14 p13 p12 p11 p10 p9 0 0 p6 p5 p4 p3 p2 p1 p0] */
	/* [d 0 0 0 0 0 0 0 t9 0 c t6 t5 t4 t3 t2 t1 t0] = [p16 p15 p14 p13 p12 p11 p10 p9 0 0 p6 p5 p4 p3 p2 p1 p0] */

	c += (uint64_t)a[0] * b[7]
		+ (uint64_t)a[1] * b[6]
		+ (uint64_t)a[2] * b[5]
		+ (uint64_t)a[3] * b[4]
		+ (uint64_t)a[4] * b[3]
		+ (uint64_t)a[5] * b[2]
		+ (uint64_t)a[6] * b[1]
		+ (uint64_t)a[7] * b[0];
	/* VERIFY_BITS(c, 64); */

	/* [d 0 0 0 0 0 0 0 t9 0 c t6 t5 t4 t3 t2 t1 t0] = [p16 p15 p14 p13 p12 p11 p10 p9 0 p7 p6 p5 p4 p3 p2 p1 p0] */
	d += (uint64_t)a[8] * b[9]
		+ (uint64_t)a[9] * b[8];

	/* [d 0 0 0 0 0 0 0 t9 0 c t6 t5 t4 t3 t2 t1 t0] = [p17 p16 p15 p14 p13 p12 p11 p10 p9 0 p7 p6 p5 p4 p3 p2 p1 p0] */
	u7 = d & M; d >>= 26; c += u7 * R0;

	t7 = c & M; c >>= 26; c += u7 * R1;


	c += (uint64_t)a[0] * b[8]
		+ (uint64_t)a[1] * b[7]
		+ (uint64_t)a[2] * b[6]
		+ (uint64_t)a[3] * b[5]
		+ (uint64_t)a[4] * b[4]
		+ (uint64_t)a[5] * b[3]
		+ (uint64_t)a[6] * b[2]
		+ (uint64_t)a[7] * b[1]
		+ (uint64_t)a[8] * b[0];
	/* VERIFY_BITS(c, 64); */

	/* [d 0 0 0 0 0 0 0 0 t9 c t7 t6 t5 t4 t3 t2 t1 t0] = [p17 p16 p15 p14 p13 p12 p11 p10 p9 p8 p7 p6 p5 p4 p3 p2 p1 p0] */
	d += (uint64_t)a[9] * b[9];

	/* [d 0 0 0 0 0 0 0 0 t9 c t7 t6 t5 t4 t3 t2 t1 t0] = [p18 p17 p16 p15 p14 p13 p12 p11 p10 p9 p8 p7 p6 p5 p4 p3 p2 p1 p0] */
	u8 = d & M; d >>= 26; c += u8 * R0;

	/* [d u8 0 0 0 0 0 0 0 0 t9 c-u8*R0 t7 t6 t5 t4 t3 t2 t1 t0] = [p18 p17 p16 p15 p14 p13 p12 p11 p10 p9 p8 p7 p6 p5 p4 p3 p2 p1 p0] */

	r[3] = t3;
	r[4] = t4;
	r[5] = t5;
	r[6] = t6;
	r[7] = t7;
	r[8] = c & M; c >>= 26; c += u8 * R1;
	c += d * R0 + t9;
	r[9] = c & (M >> 4); c >>= 22; c += d * (R1 << 4);
	d = c * (R0 >> 4) + t0;
	r[0] = d & M; d >>= 26;
	d += c * (R1 >> 4) + t1;
	r[1] = d & M; d >>= 26;
	d += t2;
	r[2] = d;
}
__device__
static void secp256k1_fe_mul(secp256k1_fe* r, const secp256k1_fe* a, const secp256k1_fe* b) {
	secp256k1_fe_mul_inner(r->n, a->n, b->n);
}
__device__
static void secp256k1_fe_add(secp256k1_fe* r, const secp256k1_fe* a) {
	r->n[0] += a->n[0];
	r->n[1] += a->n[1];
	r->n[2] += a->n[2];
	r->n[3] += a->n[3];
	r->n[4] += a->n[4];
	r->n[5] += a->n[5];
	r->n[6] += a->n[6];
	r->n[7] += a->n[7];
	r->n[8] += a->n[8];
	r->n[9] += a->n[9];
}
__device__
static void secp256k1_fe_negate(secp256k1_fe* r, const secp256k1_fe* a, int m) {
	r->n[0] = 0x3FFFC2FUL * 2 * (m + 1) - a->n[0];
	r->n[1] = 0x3FFFFBFUL * 2 * (m + 1) - a->n[1];
	r->n[2] = 0x3FFFFFFUL * 2 * (m + 1) - a->n[2];
	r->n[3] = 0x3FFFFFFUL * 2 * (m + 1) - a->n[3];
	r->n[4] = 0x3FFFFFFUL * 2 * (m + 1) - a->n[4];
	r->n[5] = 0x3FFFFFFUL * 2 * (m + 1) - a->n[5];
	r->n[6] = 0x3FFFFFFUL * 2 * (m + 1) - a->n[6];
	r->n[7] = 0x3FFFFFFUL * 2 * (m + 1) - a->n[7];
	r->n[8] = 0x3FFFFFFUL * 2 * (m + 1) - a->n[8];
	r->n[9] = 0x03FFFFFUL * 2 * (m + 1) - a->n[9];
}


__device__
static int secp256k1_fe_normalizes_to_zero(secp256k1_fe* r) {
	uint32_t t0, t1, t2, t3, t4, t5, t6, t7, t8, t9;
	t0 = r->n[0];
	t1 = r->n[1];
	t2 = r->n[2];
	t3 = r->n[3];
	t4 = r->n[4],
		t5 = r->n[5];
	t6 = r->n[6];
	t7 = r->n[7];
	t8 = r->n[8];
	t9 = r->n[9];
	/* z0 tracks a possible raw value of 0, z1 tracks a possible raw value of P */
	uint32_t z0, z1;

	/* Reduce t9 at the start so there will be at most a single carry from the first pass */
	uint32_t x = t9 >> 22; t9 &= 0x03FFFFFUL;

	/* The first pass ensures the magnitude is 1, ... */
	t0 += x * 0x3D1UL; t1 += (x << 6);
	t1 += (t0 >> 26); t0 &= 0x3FFFFFFUL; z0 = t0; z1 = t0 ^ 0x3D0UL;
	t2 += (t1 >> 26); t1 &= 0x3FFFFFFUL; z0 |= t1; z1 &= t1 ^ 0x40UL;
	t3 += (t2 >> 26); t2 &= 0x3FFFFFFUL; z0 |= t2; z1 &= t2;
	t4 += (t3 >> 26); t3 &= 0x3FFFFFFUL; z0 |= t3; z1 &= t3;
	t5 += (t4 >> 26); t4 &= 0x3FFFFFFUL; z0 |= t4; z1 &= t4;
	t6 += (t5 >> 26); t5 &= 0x3FFFFFFUL; z0 |= t5; z1 &= t5;
	t7 += (t6 >> 26); t6 &= 0x3FFFFFFUL; z0 |= t6; z1 &= t6;
	t8 += (t7 >> 26); t7 &= 0x3FFFFFFUL; z0 |= t7; z1 &= t7;
	t9 += (t8 >> 26); t8 &= 0x3FFFFFFUL; z0 |= t8; z1 &= t8;
	z0 |= t9; z1 &= t9 ^ 0x3C00000UL;

	return (z0 == 0) | (z1 == 0x3FFFFFFUL);
}
__device__
static void secp256k1_fe_mul_int(secp256k1_fe* r, int a) {
	r->n[0] *= a;
	r->n[1] *= a;
	r->n[2] *= a;
	r->n[3] *= a;
	r->n[4] *= a;
	r->n[5] *= a;
	r->n[6] *= a;
	r->n[7] *= a;
	r->n[8] *= a;
	r->n[9] *= a;
}
__device__
static void secp256k1_fe_set_int(secp256k1_fe* r, int a) {
	r->n[0] = a;
	r->n[1] = r->n[2] = r->n[3] = r->n[4] = r->n[5] = r->n[6] = r->n[7] = r->n[8] = r->n[9] = 0;
}
__device__
static void secp256k1_fe_cmov(secp256k1_fe* r, const secp256k1_fe* a, int flag) {
	uint32_t mask0, mask1;
	mask0 = flag + ~((uint32_t)0);
	mask1 = ~mask0;
	r->n[0] = (r->n[0] & mask0) | (a->n[0] & mask1);
	r->n[1] = (r->n[1] & mask0) | (a->n[1] & mask1);
	r->n[2] = (r->n[2] & mask0) | (a->n[2] & mask1);
	r->n[3] = (r->n[3] & mask0) | (a->n[3] & mask1);
	r->n[4] = (r->n[4] & mask0) | (a->n[4] & mask1);
	r->n[5] = (r->n[5] & mask0) | (a->n[5] & mask1);
	r->n[6] = (r->n[6] & mask0) | (a->n[6] & mask1);
	r->n[7] = (r->n[7] & mask0) | (a->n[7] & mask1);
	r->n[8] = (r->n[8] & mask0) | (a->n[8] & mask1);
	r->n[9] = (r->n[9] & mask0) | (a->n[9] & mask1);
}

__constant__ secp256k1_fe fe_1 = SECP256K1_FE_CONST(0, 0, 0, 0, 0, 0, 0, 1);

__device__
static void secp256k1_gej_add_ge(secp256k1_gej* r, const secp256k1_gej* a, const secp256k1_ge* b) {
	/* Operations: 7 mul, 5 sqr, 4 normalize, 21 mul_int/add/negate/cmov */
//#define SECP256K1_FE_CONST_INNER(d7, d6, d5, d4, d3, d2, d1, d0) { (d0) & 0x3FFFFFFUL, (((uint32_t)d0) >> 26) | (((uint32_t)(d1) & 0xFFFFFUL) << 6), (((uint32_t)d1) >> 20) | (((uint32_t)(d2) & 0x3FFFUL) << 12), (((uint32_t)d2) >> 14) | (((uint32_t)(d3) & 0xFFUL) << 18), (((uint32_t)d3) >> 8) | (((uint32_t)(d4) & 0x3UL) << 24), (((uint32_t)d4) >> 2) & 0x3FFFFFFUL,(((uint32_t)d4) >> 28) | (((uint32_t)(d5) & 0x3FFFFFUL) << 4), (((uint32_t)d5) >> 22) | (((uint32_t)(d6) & 0xFFFFUL) << 10), (((uint32_t)d6) >> 16) | (((uint32_t)(d7) & 0x3FFUL) << 16), (((uint32_t)d7) >> 10) }
//#define SECP256K1_FE_CONST(d7, d6, d5, d4, d3, d2, d1, d0) {SECP256K1_FE_CONST_INNER((d7), (d6), (d5), (d4), (d3), (d2), (d1), (d0))}
	//
	//secp256k1_fe fe_1;
	//fe_1.n[0] = 1 & 0x3FFFFFFUL;
	//fe_1.n[1] = (((uint32_t)1) >> 26) | (((uint32_t)(0) & 0xFFFFFUL) << 6);
	//fe_1.n[2] = (((uint32_t)0) >> 20) | (((uint32_t)(0) & 0x3FFFUL) << 12);
	//fe_1.n[3] = (((uint32_t)0) >> 14) | (((uint32_t)(0) & 0xFFUL) << 18);
	//fe_1.n[4] = (((uint32_t)0) >> 8) | (((uint32_t)(0) & 0x3UL) << 24);
	//fe_1.n[5] = (((uint32_t)0) >> 2) & 0x3FFFFFFUL, 
	//fe_1.n[6] = (((uint32_t)0) >> 28) | (((uint32_t)(0) & 0x3FFFFFUL) << 4);
	//fe_1.n[7] = (((uint32_t)0) >> 22) | (((uint32_t)(0) & 0xFFFFUL) << 10);

	secp256k1_fe zz, u1, u2, s1, s2, t, tt, m, n, q, rr;
	secp256k1_fe m_alt, rr_alt;
	int infinity, degenerate;

	secp256k1_fe_sqr(&zz, &a->z);                       /* z = Z1^2 */
	u1 = a->x; secp256k1_fe_normalize_weak(&u1);        /* u1 = U1 = X1*Z2^2 (1) */
	secp256k1_fe_mul(&u2, &b->x, &zz);                  /* u2 = U2 = X2*Z1^2 (1) */
	s1 = a->y; secp256k1_fe_normalize_weak(&s1);        /* s1 = S1 = Y1*Z2^3 (1) */
	secp256k1_fe_mul(&s2, &b->y, &zz);                  /* s2 = Y2*Z1^2 (1) */
	secp256k1_fe_mul(&s2, &s2, &a->z);                  /* s2 = S2 = Y2*Z1^3 (1) */
	t = u1; secp256k1_fe_add(&t, &u2);                  /* t = T = U1+U2 (2) */
	m = s1; secp256k1_fe_add(&m, &s2);                  /* m = M = S1+S2 (2) */
	secp256k1_fe_sqr(&rr, &t);                          /* rr = T^2 (1) */
	secp256k1_fe_negate(&m_alt, &u2, 1);                /* Malt = -X2*Z1^2 */
	secp256k1_fe_mul(&tt, &u1, &m_alt);                 /* tt = -U1*U2 (2) */
	secp256k1_fe_add(&rr, &tt);                         /* rr = R = T^2-U1*U2 (3) */
	/** If lambda = R/M = 0/0 we have a problem (except in the "trivial"
	 *  case that Z = z1z2 = 0, and this is special-cased later on). */
	degenerate = secp256k1_fe_normalizes_to_zero(&m) &
		secp256k1_fe_normalizes_to_zero(&rr);
	/* This only occurs when y1 == -y2 and x1^3 == x2^3, but x1 != x2.
	 * This means either x1 == beta*x2 or beta*x1 == x2, where beta is
	 * a nontrivial cube root of one. In either case, an alternate
	 * non-indeterminate expression for lambda is (y1 - y2)/(x1 - x2),
	 * so we set R/M equal to this. */
	rr_alt = s1;
	secp256k1_fe_mul_int(&rr_alt, 2);       /* rr = Y1*Z2^3 - Y2*Z1^3 (2) */
	secp256k1_fe_add(&m_alt, &u1);          /* Malt = X1*Z2^2 - X2*Z1^2 */

	secp256k1_fe_cmov(&rr_alt, &rr, !degenerate);
	secp256k1_fe_cmov(&m_alt, &m, !degenerate);
	/* Now Ralt / Malt = lambda and is guaranteed not to be 0/0.
	 * From here on out Ralt and Malt represent the numerator
	 * and denominator of lambda; R and M represent the explicit
	 * expressions x1^2 + x2^2 + x1x2 and y1 + y2. */
	secp256k1_fe_sqr(&n, &m_alt);                       /* n = Malt^2 (1) */
	secp256k1_fe_mul(&q, &n, &t);                       /* q = Q = T*Malt^2 (1) */
	/* These two lines use the observation that either M == Malt or M == 0,
	 * so M^3 * Malt is either Malt^4 (which is computed by squaring), or
	 * zero (which is "computed" by cmov). So the cost is one squaring
	 * versus two multiplications. */
	secp256k1_fe_sqr(&n, &n);
	secp256k1_fe_cmov(&n, &m, degenerate);              /* n = M^3 * Malt (2) */
	secp256k1_fe_sqr(&t, &rr_alt);                      /* t = Ralt^2 (1) */
	secp256k1_fe_mul(&r->z, &a->z, &m_alt);             /* r->z = Malt*Z (1) */
	infinity = secp256k1_fe_normalizes_to_zero(&r->z) * (1 - a->infinity);
	secp256k1_fe_mul_int(&r->z, 2);                     /* r->z = Z3 = 2*Malt*Z (2) */
	secp256k1_fe_negate(&q, &q, 1);                     /* q = -Q (2) */
	secp256k1_fe_add(&t, &q);                           /* t = Ralt^2-Q (3) */
	secp256k1_fe_normalize_weak(&t);
	r->x = t;                                           /* r->x = Ralt^2-Q (1) */
	secp256k1_fe_mul_int(&t, 2);                        /* t = 2*x3 (2) */
	secp256k1_fe_add(&t, &q);                           /* t = 2*x3 - Q: (4) */
	secp256k1_fe_mul(&t, &t, &rr_alt);                  /* t = Ralt*(2*x3 - Q) (1) */
	secp256k1_fe_add(&t, &n);                           /* t = Ralt*(2*x3 - Q) + M^3*Malt (3) */
	secp256k1_fe_negate(&r->y, &t, 3);                  /* r->y = Ralt*(Q - 2x3) - M^3*Malt (4) */
	secp256k1_fe_normalize_weak(&r->y);
	secp256k1_fe_mul_int(&r->x, 4);                     /* r->x = X3 = 4*(Ralt^2-Q) */
	secp256k1_fe_mul_int(&r->y, 4);                     /* r->y = Y3 = 4*Ralt*(Q - 2x3) - 4*M^3*Malt (4) */

	/** In case a->infinity == 1, replace r with (b->x, b->y, 1). */
	secp256k1_fe_cmov(&r->x, &b->x, a->infinity);
	secp256k1_fe_cmov(&r->y, &b->y, a->infinity);
	secp256k1_fe_cmov(&r->z, &fe_1, a->infinity);
	r->infinity = infinity;
}
__device__
static void secp256k1_ge_clear(secp256k1_ge* r) {
	r->infinity = 0;
	secp256k1_fe_clear(&r->x);
	secp256k1_fe_clear(&r->y);
}
__device__
static void secp256k1_ecmult_gen(secp256k1_gej* r, secp256k1_scalar* gn) {
	secp256k1_ge add;
	secp256k1_ge_storage adds;
	int bits;
	int i, j;

	memset((uint8_t*)&adds, 0, (uint32_t)sizeof(adds));
	secp256k1_gej_set_infinity(r);

	add.infinity = 0;
	for (j = 0; j < ECMULT_GEN_PREC_N; j++) {
		bits = secp256k1_scalar_get_bits(gn, j * ECMULT_GEN_PREC_B, ECMULT_GEN_PREC_B);
		for (i = 0; i < ECMULT_GEN_PREC_G; i++) {
			uint32_t mask0, mask1;
			mask0 = (i == bits) + ~((uint32_t)0);
			mask1 = ~mask0;

			adds.x.n[0] = (adds.x.n[0] & mask0) | (prec[j][i].x.n[0] & mask1);
			adds.x.n[1] = (adds.x.n[1] & mask0) | (prec[j][i].x.n[1] & mask1);
			adds.x.n[2] = (adds.x.n[2] & mask0) | (prec[j][i].x.n[2] & mask1);
			adds.x.n[3] = (adds.x.n[3] & mask0) | (prec[j][i].x.n[3] & mask1);
			adds.x.n[4] = (adds.x.n[4] & mask0) | (prec[j][i].x.n[4] & mask1);
			adds.x.n[5] = (adds.x.n[5] & mask0) | (prec[j][i].x.n[5] & mask1);
			adds.x.n[6] = (adds.x.n[6] & mask0) | (prec[j][i].x.n[6] & mask1);
			adds.x.n[7] = (adds.x.n[7] & mask0) | (prec[j][i].x.n[7] & mask1);

			adds.y.n[0] = (adds.y.n[0] & mask0) | (prec[j][i].y.n[0] & mask1);
			adds.y.n[1] = (adds.y.n[1] & mask0) | (prec[j][i].y.n[1] & mask1);
			adds.y.n[2] = (adds.y.n[2] & mask0) | (prec[j][i].y.n[2] & mask1);
			adds.y.n[3] = (adds.y.n[3] & mask0) | (prec[j][i].y.n[3] & mask1);
			adds.y.n[4] = (adds.y.n[4] & mask0) | (prec[j][i].y.n[4] & mask1);
			adds.y.n[5] = (adds.y.n[5] & mask0) | (prec[j][i].y.n[5] & mask1);
			adds.y.n[6] = (adds.y.n[6] & mask0) | (prec[j][i].y.n[6] & mask1);
			adds.y.n[7] = (adds.y.n[7] & mask0) | (prec[j][i].y.n[7] & mask1);
		}
		secp256k1_ge_from_storage(&add, &adds);
		secp256k1_gej_add_ge(r, r, &add);
	}
	bits = 0;
	secp256k1_ge_clear(&add);
}
__device__
static void secp256k1_fe_inv(secp256k1_fe* r, const secp256k1_fe* a) {
	secp256k1_fe x2, x3, x6, x9, x11, x22, x44, x88, x176, x220, x223, t1;
	int j;

	secp256k1_fe_sqr(&x2, a);
	secp256k1_fe_mul(&x2, &x2, a);

	secp256k1_fe_sqr(&x3, &x2);
	secp256k1_fe_mul(&x3, &x3, a);

	x6 = x3;
	for (j = 0; j < 3; j++) {
		secp256k1_fe_sqr(&x6, &x6);
	}
	secp256k1_fe_mul(&x6, &x6, &x3);

	x9 = x6;
	for (j = 0; j < 3; j++) {
		secp256k1_fe_sqr(&x9, &x9);
	}
	secp256k1_fe_mul(&x9, &x9, &x3);

	x11 = x9;
	for (j = 0; j < 2; j++) {
		secp256k1_fe_sqr(&x11, &x11);
	}
	secp256k1_fe_mul(&x11, &x11, &x2);

	x22 = x11;
	for (j = 0; j < 11; j++) {
		secp256k1_fe_sqr(&x22, &x22);
	}
	secp256k1_fe_mul(&x22, &x22, &x11);

	x44 = x22;
	for (j = 0; j < 22; j++) {
		secp256k1_fe_sqr(&x44, &x44);
	}
	secp256k1_fe_mul(&x44, &x44, &x22);

	x88 = x44;
	for (j = 0; j < 44; j++) {
		secp256k1_fe_sqr(&x88, &x88);
	}
	secp256k1_fe_mul(&x88, &x88, &x44);

	x176 = x88;
	for (j = 0; j < 88; j++) {
		secp256k1_fe_sqr(&x176, &x176);
	}
	secp256k1_fe_mul(&x176, &x176, &x88);

	x220 = x176;
	for (j = 0; j < 44; j++) {
		secp256k1_fe_sqr(&x220, &x220);
	}
	secp256k1_fe_mul(&x220, &x220, &x44);

	x223 = x220;
	for (j = 0; j < 3; j++) {
		secp256k1_fe_sqr(&x223, &x223);
	}
	secp256k1_fe_mul(&x223, &x223, &x3);

	t1 = x223;
	for (j = 0; j < 23; j++) {
		secp256k1_fe_sqr(&t1, &t1);
	}
	secp256k1_fe_mul(&t1, &t1, &x22);
	for (j = 0; j < 5; j++) {
		secp256k1_fe_sqr(&t1, &t1);
	}
	secp256k1_fe_mul(&t1, &t1, a);
	for (j = 0; j < 3; j++) {
		secp256k1_fe_sqr(&t1, &t1);
	}
	secp256k1_fe_mul(&t1, &t1, &x2);
	for (j = 0; j < 2; j++) {
		secp256k1_fe_sqr(&t1, &t1);
	}
	secp256k1_fe_mul(r, a, &t1);
}
__device__
static void secp256k1_ge_set_gej(secp256k1_ge* r, secp256k1_gej* a) {
	secp256k1_fe z2, z3;
	r->infinity = a->infinity;
	secp256k1_fe_inv(&a->z, &a->z);
	secp256k1_fe_sqr(&z2, &a->z);
	secp256k1_fe_mul(&z3, &a->z, &z2);
	secp256k1_fe_mul(&a->x, &a->x, &z2);
	secp256k1_fe_mul(&a->y, &a->y, &z3);
	secp256k1_fe_set_int(&a->z, 1);
	r->x = a->x;
	r->y = a->y;
}
__device__
static void secp256k1_fe_normalize_var(secp256k1_fe* r) {
	uint32_t t0, t1, t2, t3, t4, t5, t6, t7, t8, t9;
	t0 = r->n[0];
	t1 = r->n[1];
	t2 = r->n[2];
	t3 = r->n[3];
	t4 = r->n[4];
	t5 = r->n[5];
	t6 = r->n[6];
	t7 = r->n[7];
	t8 = r->n[8];
	t9 = r->n[9];

	/* Reduce t9 at the start so there will be at most a single carry from the first pass */
	uint32_t m, x;
	x = t9 >> 22; t9 &= 0x03FFFFFUL;

	/* The first pass ensures the magnitude is 1, ... */
	t0 += x * 0x3D1UL; t1 += (x << 6);
	t1 += (t0 >> 26); t0 &= 0x3FFFFFFUL;
	t2 += (t1 >> 26); t1 &= 0x3FFFFFFUL;
	t3 += (t2 >> 26); t2 &= 0x3FFFFFFUL; m = t2;
	t4 += (t3 >> 26); t3 &= 0x3FFFFFFUL; m &= t3;
	t5 += (t4 >> 26); t4 &= 0x3FFFFFFUL; m &= t4;
	t6 += (t5 >> 26); t5 &= 0x3FFFFFFUL; m &= t5;
	t7 += (t6 >> 26); t6 &= 0x3FFFFFFUL; m &= t6;
	t8 += (t7 >> 26); t7 &= 0x3FFFFFFUL; m &= t7;
	t9 += (t8 >> 26); t8 &= 0x3FFFFFFUL; m &= t8;

	/* At most a single final reduction is needed; check if the value is >= the field characteristic */
	x = (t9 >> 22) | ((t9 == 0x03FFFFFUL) & (m == 0x3FFFFFFUL)
		& ((t1 + 0x40UL + ((t0 + 0x3D1UL) >> 26)) > 0x3FFFFFFUL));

	if (x) {
		t0 += 0x3D1UL; t1 += (x << 6);
		t1 += (t0 >> 26); t0 &= 0x3FFFFFFUL;
		t2 += (t1 >> 26); t1 &= 0x3FFFFFFUL;
		t3 += (t2 >> 26); t2 &= 0x3FFFFFFUL;
		t4 += (t3 >> 26); t3 &= 0x3FFFFFFUL;
		t5 += (t4 >> 26); t4 &= 0x3FFFFFFUL;
		t6 += (t5 >> 26); t5 &= 0x3FFFFFFUL;
		t7 += (t6 >> 26); t6 &= 0x3FFFFFFUL;
		t8 += (t7 >> 26); t7 &= 0x3FFFFFFUL;
		t9 += (t8 >> 26); t8 &= 0x3FFFFFFUL;

		t9 &= 0x03FFFFFUL;
	}

	r->n[0] = t0; r->n[1] = t1; r->n[2] = t2; r->n[3] = t3; r->n[4] = t4;
	r->n[5] = t5; r->n[6] = t6; r->n[7] = t7; r->n[8] = t8; r->n[9] = t9;
}
__device__
static void secp256k1_fe_get_b32(uint8_t* r, const secp256k1_fe* a) {
	r[0] = (a->n[9] >> 14) & 0xff;
	r[1] = (a->n[9] >> 6) & 0xff;
	r[2] = ((a->n[9] & 0x3F) << 2) | ((a->n[8] >> 24) & 0x3);
	r[3] = (a->n[8] >> 16) & 0xff;
	r[4] = (a->n[8] >> 8) & 0xff;
	r[5] = a->n[8] & 0xff;
	r[6] = (a->n[7] >> 18) & 0xff;
	r[7] = (a->n[7] >> 10) & 0xff;
	r[8] = (a->n[7] >> 2) & 0xff;
	r[9] = ((a->n[7] & 0x3) << 6) | ((a->n[6] >> 20) & 0x3f);
	r[10] = (a->n[6] >> 12) & 0xff;
	r[11] = (a->n[6] >> 4) & 0xff;
	r[12] = ((a->n[6] & 0xf) << 4) | ((a->n[5] >> 22) & 0xf);
	r[13] = (a->n[5] >> 14) & 0xff;
	r[14] = (a->n[5] >> 6) & 0xff;
	r[15] = ((a->n[5] & 0x3f) << 2) | ((a->n[4] >> 24) & 0x3);
	r[16] = (a->n[4] >> 16) & 0xff;
	r[17] = (a->n[4] >> 8) & 0xff;
	r[18] = a->n[4] & 0xff;
	r[19] = (a->n[3] >> 18) & 0xff;
	r[20] = (a->n[3] >> 10) & 0xff;
	r[21] = (a->n[3] >> 2) & 0xff;
	r[22] = ((a->n[3] & 0x3) << 6) | ((a->n[2] >> 20) & 0x3f);
	r[23] = (a->n[2] >> 12) & 0xff;
	r[24] = (a->n[2] >> 4) & 0xff;
	r[25] = ((a->n[2] & 0xf) << 4) | ((a->n[1] >> 22) & 0xf);
	r[26] = (a->n[1] >> 14) & 0xff;
	r[27] = (a->n[1] >> 6) & 0xff;
	r[28] = ((a->n[1] & 0x3f) << 2) | ((a->n[0] >> 24) & 0x3);
	r[29] = (a->n[0] >> 16) & 0xff;
	r[30] = (a->n[0] >> 8) & 0xff;
	r[31] = a->n[0] & 0xff;
}
__device__
static void secp256k1_pubkey_save(uint8_t* pubkey, secp256k1_ge* ge) {
	secp256k1_fe_normalize_var(&ge->x);
	secp256k1_fe_normalize_var(&ge->y);
	secp256k1_fe_get_b32(pubkey, &ge->x);
	secp256k1_fe_get_b32(pubkey + 32, &ge->y);
}

__device__
int secp256k1_ec_pubkey_create(uint8_t* pubkey, const uint8_t* seckey) {
	secp256k1_gej pj;
	secp256k1_ge p;
	secp256k1_scalar sec;
	//#define SECP256K1_SCALAR_CONST(d7, d6, d5, d4, d3, d2, d1, d0) {{(d0), (d1), (d2), (d3), (d4), (d5), (d6), (d7)}}
	//secp256k1_scalar secp256k1_scalar_one = SECP256K1_SCALAR_CONST(0, 0, 0, 0, 0, 0, 0, 1);
	secp256k1_scalar secp256k1_scalar_one;
	secp256k1_scalar_one.d[0] = 1;
	secp256k1_scalar_one.d[1] = 0;
	secp256k1_scalar_one.d[2] = 0;
	secp256k1_scalar_one.d[3] = 0;
	secp256k1_scalar_one.d[4] = 0;
	secp256k1_scalar_one.d[5] = 0;
	secp256k1_scalar_one.d[6] = 0;
	secp256k1_scalar_one.d[7] = 0;

	int ret;

	ret = secp256k1_scalar_set_b32_seckey(&sec, seckey);

	secp256k1_scalar_cmov(&sec, &secp256k1_scalar_one, !ret);

	secp256k1_ecmult_gen(&pj, &sec);
	secp256k1_ge_set_gej(&p, &pj);
	secp256k1_pubkey_save(pubkey, &p);
	return ret;
}
__device__
void calc_public(const extended_private_key_t* priv, extended_public_key_t* pub) {
	//memcpy((uint8_t*)pub->chain_code, (const uint8_t*)priv->chain_code, 32);
	secp256k1_ec_pubkey_create(pub->key, (const uint8_t*)priv->key);
}
__device__
static int secp256k1_fe_set_b32(secp256k1_fe* r, const uint8_t* a) {
	int ret;
	r->n[0] = (uint32_t)a[31] | ((uint32_t)a[30] << 8) | ((uint32_t)a[29] << 16) | ((uint32_t)(a[28] & 0x3) << 24);
	r->n[1] = (uint32_t)((a[28] >> 2) & 0x3f) | ((uint32_t)a[27] << 6) | ((uint32_t)a[26] << 14) | ((uint32_t)(a[25] & 0xf) << 22);
	r->n[2] = (uint32_t)((a[25] >> 4) & 0xf) | ((uint32_t)a[24] << 4) | ((uint32_t)a[23] << 12) | ((uint32_t)(a[22] & 0x3f) << 20);
	r->n[3] = (uint32_t)((a[22] >> 6) & 0x3) | ((uint32_t)a[21] << 2) | ((uint32_t)a[20] << 10) | ((uint32_t)a[19] << 18);
	r->n[4] = (uint32_t)a[18] | ((uint32_t)a[17] << 8) | ((uint32_t)a[16] << 16) | ((uint32_t)(a[15] & 0x3) << 24);
	r->n[5] = (uint32_t)((a[15] >> 2) & 0x3f) | ((uint32_t)a[14] << 6) | ((uint32_t)a[13] << 14) | ((uint32_t)(a[12] & 0xf) << 22);
	r->n[6] = (uint32_t)((a[12] >> 4) & 0xf) | ((uint32_t)a[11] << 4) | ((uint32_t)a[10] << 12) | ((uint32_t)(a[9] & 0x3f) << 20);
	r->n[7] = (uint32_t)((a[9] >> 6) & 0x3) | ((uint32_t)a[8] << 2) | ((uint32_t)a[7] << 10) | ((uint32_t)a[6] << 18);
	r->n[8] = (uint32_t)a[5] | ((uint32_t)a[4] << 8) | ((uint32_t)a[3] << 16) | ((uint32_t)(a[2] & 0x3) << 24);
	r->n[9] = (uint32_t)((a[2] >> 2) & 0x3f) | ((uint32_t)a[1] << 6) | ((uint32_t)a[0] << 14);

	ret = !((r->n[9] == 0x3FFFFFUL) & ((r->n[8] & r->n[7] & r->n[6] & r->n[5] & r->n[4] & r->n[3] & r->n[2]) == 0x3FFFFFFUL) & ((r->n[1] + 0x40UL + ((r->n[0] + 0x3D1UL) >> 26)) > 0x3FFFFFFUL));
	return ret;
}
__device__
static void secp256k1_ge_set_xy(secp256k1_ge* r, const secp256k1_fe* x, const secp256k1_fe* y) {
	r->infinity = 0;
	r->x = *x;
	r->y = *y;
}
__device__
static int secp256k1_pubkey_load(secp256k1_ge* ge, const uint8_t* pubkey) {
	secp256k1_fe x, y;
	secp256k1_fe_set_b32(&x, pubkey);
	secp256k1_fe_set_b32(&y, pubkey + 32);
	secp256k1_ge_set_xy(ge, &x, &y);

	return 1;
}
__device__
static int secp256k1_ge_is_infinity(const secp256k1_ge* a) {
	return a->infinity;
}
__device__
static int secp256k1_fe_is_odd(const secp256k1_fe* a) {
	return a->n[0] & 1;
}
__device__
static int secp256k1_eckey_pubkey_serialize(secp256k1_ge* elem, uint8_t* pub) {
	if (secp256k1_ge_is_infinity(elem)) {
		return 0;
	}
	secp256k1_fe_normalize_var(&elem->x);
	secp256k1_fe_normalize_var(&elem->y);
	secp256k1_fe_get_b32(&pub[1], &elem->x);

	pub[0] = secp256k1_fe_is_odd(&elem->y) ? SECP256K1_TAG_PUBKEY_ODD : SECP256K1_TAG_PUBKEY_EVEN;

	return 1;
}

__device__
int secp256k1_ec_pubkey_serialize(uint8_t* output, uint32_t outputlen, const uint8_t* pubkey) {
	secp256k1_ge Q = { 0 };
	int ret = 0;
	memset(output, 0, outputlen);
	if (secp256k1_pubkey_load(&Q, pubkey)) {
		ret = secp256k1_eckey_pubkey_serialize(&Q, output);
	}
	return ret;
}
__device__
void serialized_public_key(extended_public_key_t* pub, uint8_t* serialized_key) {
	secp256k1_ec_pubkey_serialize(serialized_key, 33, pub->key);
}
__device__
static int secp256k1_scalar_add(secp256k1_scalar* r, const secp256k1_scalar* a, const secp256k1_scalar* b) {
	int overflow;
	uint64_t t;
	t = (uint64_t)a->d[0] + b->d[0];
	r->d[0] = t & 0xFFFFFFFFUL; t >>= 32;
	t += (uint64_t)a->d[1] + b->d[1];
	r->d[1] = t & 0xFFFFFFFFUL; t >>= 32;
	t += (uint64_t)a->d[2] + b->d[2];
	r->d[2] = t & 0xFFFFFFFFUL; t >>= 32;
	t += (uint64_t)a->d[3] + b->d[3];
	r->d[3] = t & 0xFFFFFFFFUL; t >>= 32;
	t += (uint64_t)a->d[4] + b->d[4];
	r->d[4] = t & 0xFFFFFFFFUL; t >>= 32;
	t += (uint64_t)a->d[5] + b->d[5];
	r->d[5] = t & 0xFFFFFFFFUL; t >>= 32;
	t += (uint64_t)a->d[6] + b->d[6];
	r->d[6] = t & 0xFFFFFFFFUL; t >>= 32;
	t += (uint64_t)a->d[7] + b->d[7];
	r->d[7] = t & 0xFFFFFFFFUL; t >>= 32;
	overflow = t + secp256k1_scalar_check_overflow(r);
	secp256k1_scalar_reduce(r, overflow);
	return overflow;
}
__device__
static int secp256k1_eckey_privkey_tweak_add(secp256k1_scalar* key, const secp256k1_scalar* tweak) {
	secp256k1_scalar_add(key, key, tweak);
	return !secp256k1_scalar_is_zero(key);
}
__device__
static void secp256k1_scalar_get_b32(uint8_t* bin, const secp256k1_scalar* a) {
	bin[0] = a->d[7] >> 24; bin[1] = a->d[7] >> 16; bin[2] = a->d[7] >> 8; bin[3] = a->d[7];
	bin[4] = a->d[6] >> 24; bin[5] = a->d[6] >> 16; bin[6] = a->d[6] >> 8; bin[7] = a->d[6];
	bin[8] = a->d[5] >> 24; bin[9] = a->d[5] >> 16; bin[10] = a->d[5] >> 8; bin[11] = a->d[5];
	bin[12] = a->d[4] >> 24; bin[13] = a->d[4] >> 16; bin[14] = a->d[4] >> 8; bin[15] = a->d[4];
	bin[16] = a->d[3] >> 24; bin[17] = a->d[3] >> 16; bin[18] = a->d[3] >> 8; bin[19] = a->d[3];
	bin[20] = a->d[2] >> 24; bin[21] = a->d[2] >> 16; bin[22] = a->d[2] >> 8; bin[23] = a->d[2];
	bin[24] = a->d[1] >> 24; bin[25] = a->d[1] >> 16; bin[26] = a->d[1] >> 8; bin[27] = a->d[1];
	bin[28] = a->d[0] >> 24; bin[29] = a->d[0] >> 16; bin[30] = a->d[0] >> 8; bin[31] = a->d[0];
}
__device__
int secp256k1_ec_seckey_tweak_add(uint8_t* seckey, const uint8_t* tweak) {
	secp256k1_scalar term;
	secp256k1_scalar sec;
	int ret;
	int overflow;
	overflow = 0;
	secp256k1_scalar_set_b32(&term, tweak, &overflow);
	ret = secp256k1_scalar_set_b32_seckey(&sec, seckey);

	ret &= (!overflow) & secp256k1_eckey_privkey_tweak_add(&sec, &term);

	//secp256k1_scalar secp256k1_scalar_zero = SECP256K1_SCALAR_CONST(0, 0, 0, 0, 0, 0, 0, 0);
	secp256k1_scalar secp256k1_scalar_zero;
	secp256k1_scalar_zero.d[0] = 0;
	secp256k1_scalar_zero.d[1] = 0;
	secp256k1_scalar_zero.d[2] = 0;
	secp256k1_scalar_zero.d[3] = 0;
	secp256k1_scalar_zero.d[4] = 0;
	secp256k1_scalar_zero.d[5] = 0;
	secp256k1_scalar_zero.d[6] = 0;
	secp256k1_scalar_zero.d[7] = 0;
	secp256k1_scalar_cmov(&sec, &secp256k1_scalar_zero, !ret);
	secp256k1_scalar_get_b32(seckey, &sec);

	//secp256k1_scalar_clear(&sec);
	//secp256k1_scalar_clear(&term);
	return ret;
}

__device__
void hardened_private_child_from_private(const extended_private_key_t* parent, extended_private_key_t* child, uint16_t hardened_child_number) {

	uint32_t hmacsha512_result[64 / 4];
	uint8_t hmac_input[40]; //37 bytes
	hmac_input[0] = 0;
#pragma unroll
	for (int x = 0; x < 32; x++) {
		hmac_input[x + 1] = parent->key[x];
	}
	hmac_input[33] = 0x80; //Padding Signature 1 of 2
	hmac_input[34] = 0;    //Padding Signature 2 of 2
	//*(uint16_t*)&hmac_input[35] = hardened_child_number;
	hmac_input[35] = *(uint8_t*)((uint8_t*)&hardened_child_number + 1);
	hmac_input[36] = *(uint8_t*)&hardened_child_number;
	hmac_sha512_const((uint32_t*)parent->chain_code, (uint32_t*)&hmac_input, (uint32_t*)&hmacsha512_result);
	//private_key_t sk;
	uint8_t sk[32];
	memcpy((uint8_t*)&sk, (const uint8_t*)&hmacsha512_result, 32);
	secp256k1_ec_seckey_tweak_add((uint8_t*)&sk, (const uint8_t*)&parent->key);
	for (int x = 0; x < 32; x++) {
		child->key[x] = sk[x];
	}
	memcpy_offset((uint8_t*)&child->chain_code, (const uint8_t*)&hmacsha512_result, 32, 32);


}
__device__
void normal_private_child_from_private(const extended_private_key_t* parent, extended_private_key_t* child, uint16_t normal_child_number, uint8_t h33=0, uint8_t h34=0) {
	uint32_t hmacsha512_result[64 / 4];
	extended_public_key_t pub;
	calc_public(parent, &pub);
	uint8_t hmac_input[40]; //37 bytes
	serialized_public_key(&pub, (uint8_t*)&hmac_input);
	hmac_input[33] = 0; //Zero padding 1 of 2
	hmac_input[34] = 0; //Zero padding 2 of 2
	//*(uint16_t*)&hmac_input[35] = normal_child_number;
	hmac_input[35] = *(uint8_t*)((uint8_t*)&normal_child_number + 1);
	hmac_input[36] = *(uint8_t*)&normal_child_number;
	hmac_sha512_const((uint32_t*)&parent->chain_code, (uint32_t*)&hmac_input, (uint32_t*)&hmacsha512_result);
	uint8_t sk[32];
	memcpy((uint8_t*)&sk, (const uint8_t*)&hmacsha512_result, 32);
	secp256k1_ec_seckey_tweak_add((uint8_t*)&sk, (const uint8_t*)&parent->key);
	for (int x = 0; x < 32; x++) {
		child->key[x] = sk[x];
	}
	memcpy_offset((uint8_t*)&child->chain_code, (const uint8_t*)&hmacsha512_result, 32, 32);
}

typedef struct {
	uint32_t total[2];
	uint32_t state[5];
	uint8_t buffer[64];
} RIPEMD160_CTX;

#define GET_UINT32_LE(n,b,i) { (n) = ( (uint32_t) (b)[(i)])| ( (uint32_t) (b)[(i) + 1] <<  8 )| ( (uint32_t) (b)[(i) + 2] << 16 ) | ( (uint32_t) (b)[(i) + 3] << 24 );}

#define PUT_UINT32_LE(n,b,i) { (b)[(i)    ] = (uint8_t) ( ( (n)       ) & 0xFF ); (b)[(i) + 1] = (uint8_t) ( ( (n) >>  8 ) & 0xFF ); (b)[(i) + 2] = (uint8_t) ( ( (n) >> 16 ) & 0xFF ); (b)[(i) + 3] = (uint8_t) ( ( (n) >> 24 ) & 0xFF ); }
__device__
void ripemd160_Init(RIPEMD160_CTX* ctx)
{
	//memset((uint8_t*)ctx, 0, sizeof(RIPEMD160_CTX));
	for (int i = 0; i < 64 / 4; i++)
	{
		*(uint32_t*)((uint32_t*)ctx->buffer + i) = 0;
	}
	ctx->total[0] = 0;
	ctx->total[1] = 0;
	ctx->state[0] = 0x67452301;
	ctx->state[1] = 0xEFCDAB89;
	ctx->state[2] = 0x98BADCFE;
	ctx->state[3] = 0x10325476;
	ctx->state[4] = 0xC3D2E1F0;
}
__device__
void ripemd160_process(RIPEMD160_CTX* ctx, const uint8_t data[64])
{
	uint32_t A, B, C, D, E, Ap, Bp, Cp, Dp, Ep, X[16];

	GET_UINT32_LE(X[0], data, 0);
	GET_UINT32_LE(X[1], data, 4);
	GET_UINT32_LE(X[2], data, 8);
	GET_UINT32_LE(X[3], data, 12);
	GET_UINT32_LE(X[4], data, 16);
	GET_UINT32_LE(X[5], data, 20);
	GET_UINT32_LE(X[6], data, 24);
	GET_UINT32_LE(X[7], data, 28);
	GET_UINT32_LE(X[8], data, 32);
	GET_UINT32_LE(X[9], data, 36);
	GET_UINT32_LE(X[10], data, 40);
	GET_UINT32_LE(X[11], data, 44);
	GET_UINT32_LE(X[12], data, 48);
	GET_UINT32_LE(X[13], data, 52);
	GET_UINT32_LE(X[14], data, 56);
	GET_UINT32_LE(X[15], data, 60);

	A = Ap = ctx->state[0];
	B = Bp = ctx->state[1];
	C = Cp = ctx->state[2];
	D = Dp = ctx->state[3];
	E = Ep = ctx->state[4];

#define F1( x, y, z )   ( x ^ y ^ z )
#define F2( x, y, z )   ( ( x & y ) | ( ~x & z ) )
#define F3( x, y, z )   ( ( x | ~y ) ^ z )
#define F4( x, y, z )   ( ( x & z ) | ( y & ~z ) )
#define F5( x, y, z )   ( x ^ ( y | ~z ) )

#define S( x, n ) ( ( x << n ) | ( x >> (32 - n) ) )

#define P( a, b, c, d, e, r, s, f, k ) { a += f( b, c, d ) + X[r] + k; a = S( a, s ) + e; c = S( c, 10 ); }
#define P2( a, b, c, d, e, r, s, rp, sp ) { P( a, b, c, d, e, r, s, F, K ); P( a ## p, b ## p, c ## p, d ## p, e ## p, rp, sp, Fp, Kp ); }


#define F   F1
#define K   0x00000000
#define Fp  F5
#define Kp  0x50A28BE6
	P2(A, B, C, D, E, 0, 11, 5, 8);
	P2(E, A, B, C, D, 1, 14, 14, 9);
	P2(D, E, A, B, C, 2, 15, 7, 9);
	P2(C, D, E, A, B, 3, 12, 0, 11);
	P2(B, C, D, E, A, 4, 5, 9, 13);
	P2(A, B, C, D, E, 5, 8, 2, 15);
	P2(E, A, B, C, D, 6, 7, 11, 15);
	P2(D, E, A, B, C, 7, 9, 4, 5);
	P2(C, D, E, A, B, 8, 11, 13, 7);
	P2(B, C, D, E, A, 9, 13, 6, 7);
	P2(A, B, C, D, E, 10, 14, 15, 8);
	P2(E, A, B, C, D, 11, 15, 8, 11);
	P2(D, E, A, B, C, 12, 6, 1, 14);
	P2(C, D, E, A, B, 13, 7, 10, 14);
	P2(B, C, D, E, A, 14, 9, 3, 12);
	P2(A, B, C, D, E, 15, 8, 12, 6);
#undef F
#undef K
#undef Fp
#undef Kp

#define F   F2
#define K   0x5A827999
#define Fp  F4
#define Kp  0x5C4DD124
	P2(E, A, B, C, D, 7, 7, 6, 9);
	P2(D, E, A, B, C, 4, 6, 11, 13);
	P2(C, D, E, A, B, 13, 8, 3, 15);
	P2(B, C, D, E, A, 1, 13, 7, 7);
	P2(A, B, C, D, E, 10, 11, 0, 12);
	P2(E, A, B, C, D, 6, 9, 13, 8);
	P2(D, E, A, B, C, 15, 7, 5, 9);
	P2(C, D, E, A, B, 3, 15, 10, 11);
	P2(B, C, D, E, A, 12, 7, 14, 7);
	P2(A, B, C, D, E, 0, 12, 15, 7);
	P2(E, A, B, C, D, 9, 15, 8, 12);
	P2(D, E, A, B, C, 5, 9, 12, 7);
	P2(C, D, E, A, B, 2, 11, 4, 6);
	P2(B, C, D, E, A, 14, 7, 9, 15);
	P2(A, B, C, D, E, 11, 13, 1, 13);
	P2(E, A, B, C, D, 8, 12, 2, 11);
#undef F
#undef K
#undef Fp
#undef Kp

#define F   F3
#define K   0x6ED9EBA1
#define Fp  F3
#define Kp  0x6D703EF3
	P2(D, E, A, B, C, 3, 11, 15, 9);
	P2(C, D, E, A, B, 10, 13, 5, 7);
	P2(B, C, D, E, A, 14, 6, 1, 15);
	P2(A, B, C, D, E, 4, 7, 3, 11);
	P2(E, A, B, C, D, 9, 14, 7, 8);
	P2(D, E, A, B, C, 15, 9, 14, 6);
	P2(C, D, E, A, B, 8, 13, 6, 6);
	P2(B, C, D, E, A, 1, 15, 9, 14);
	P2(A, B, C, D, E, 2, 14, 11, 12);
	P2(E, A, B, C, D, 7, 8, 8, 13);
	P2(D, E, A, B, C, 0, 13, 12, 5);
	P2(C, D, E, A, B, 6, 6, 2, 14);
	P2(B, C, D, E, A, 13, 5, 10, 13);
	P2(A, B, C, D, E, 11, 12, 0, 13);
	P2(E, A, B, C, D, 5, 7, 4, 7);
	P2(D, E, A, B, C, 12, 5, 13, 5);
#undef F
#undef K
#undef Fp
#undef Kp

#define F   F4
#define K   0x8F1BBCDC
#define Fp  F2
#define Kp  0x7A6D76E9
	P2(C, D, E, A, B, 1, 11, 8, 15);
	P2(B, C, D, E, A, 9, 12, 6, 5);
	P2(A, B, C, D, E, 11, 14, 4, 8);
	P2(E, A, B, C, D, 10, 15, 1, 11);
	P2(D, E, A, B, C, 0, 14, 3, 14);
	P2(C, D, E, A, B, 8, 15, 11, 14);
	P2(B, C, D, E, A, 12, 9, 15, 6);
	P2(A, B, C, D, E, 4, 8, 0, 14);
	P2(E, A, B, C, D, 13, 9, 5, 6);
	P2(D, E, A, B, C, 3, 14, 12, 9);
	P2(C, D, E, A, B, 7, 5, 2, 12);
	P2(B, C, D, E, A, 15, 6, 13, 9);
	P2(A, B, C, D, E, 14, 8, 9, 12);
	P2(E, A, B, C, D, 5, 6, 7, 5);
	P2(D, E, A, B, C, 6, 5, 10, 15);
	P2(C, D, E, A, B, 2, 12, 14, 8);
#undef F
#undef K
#undef Fp
#undef Kp

#define F   F5
#define K   0xA953FD4E
#define Fp  F1
#define Kp  0x00000000
	P2(B, C, D, E, A, 4, 9, 12, 8);
	P2(A, B, C, D, E, 0, 15, 15, 5);
	P2(E, A, B, C, D, 5, 5, 10, 12);
	P2(D, E, A, B, C, 9, 11, 4, 9);
	P2(C, D, E, A, B, 7, 6, 1, 12);
	P2(B, C, D, E, A, 12, 8, 5, 5);
	P2(A, B, C, D, E, 2, 13, 8, 14);
	P2(E, A, B, C, D, 10, 12, 7, 6);
	P2(D, E, A, B, C, 14, 5, 6, 8);
	P2(C, D, E, A, B, 1, 12, 2, 13);
	P2(B, C, D, E, A, 3, 13, 13, 6);
	P2(A, B, C, D, E, 8, 14, 14, 5);
	P2(E, A, B, C, D, 11, 11, 0, 15);
	P2(D, E, A, B, C, 6, 8, 3, 13);
	P2(C, D, E, A, B, 15, 5, 9, 11);
	P2(B, C, D, E, A, 13, 6, 11, 11);
#undef F
#undef K
#undef Fp
#undef Kp

	C = ctx->state[1] + C + Dp;
	ctx->state[1] = ctx->state[2] + D + Ep;
	ctx->state[2] = ctx->state[3] + E + Ap;
	ctx->state[3] = ctx->state[4] + A + Bp;
	ctx->state[4] = ctx->state[0] + B + Cp;
	ctx->state[0] = C;
}



__device__
void ripemd160_Update(RIPEMD160_CTX* ctx, const uint8_t* input, uint32_t ilen)
{
	uint32_t fill;
	uint32_t left;

	if (ilen == 0)
		return;

	left = ctx->total[0] & 0x3F;
	fill = 64 - left;

	ctx->total[0] += (uint32_t)ilen;
	ctx->total[0] &= 0xFFFFFFFF;

	if (ctx->total[0] < (uint32_t)ilen)
		ctx->total[1]++;

	if (left && ilen >= fill)
	{
		memcpy((uint8_t*)(ctx->buffer + left), input, fill);

		ripemd160_process(ctx, ctx->buffer);
		input += fill;
		ilen -= fill;
		left = 0;
	}

	while (ilen >= 64)
	{
		ripemd160_process(ctx, input);
		input += 64;
		ilen -= 64;
	}

	if (ilen > 0)
	{
		memcpy((uint8_t*)(ctx->buffer + left), input, ilen);
	}
}

__constant__ uint8_t ripemd160_padding[64] = {
0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};

__device__
void ripemd160_Final(RIPEMD160_CTX* ctx, uint32_t output[5])
{
	uint32_t last, padn;
	uint32_t high, low;
	uint8_t msglen[8];

	high = (ctx->total[0] >> 29)
		| (ctx->total[1] << 3);
	low = (ctx->total[0] << 3);

	PUT_UINT32_LE(low, msglen, 0);
	PUT_UINT32_LE(high, msglen, 4);

	last = ctx->total[0] & 0x3F;
	padn = (last < 56) ? (56 - last) : (120 - last);


	ripemd160_Update(ctx, ripemd160_padding, padn);
	ripemd160_Update(ctx, msglen, 8);

	//PUT_UINT32_LE(ctx->state[0], output, 0);
	//PUT_UINT32_LE(ctx->state[1], output, 4);
	//PUT_UINT32_LE(ctx->state[2], output, 8);
	//PUT_UINT32_LE(ctx->state[3], output, 12);
	//PUT_UINT32_LE(ctx->state[4], output, 16);

	output[0] = ctx->state[0];
	output[1] = ctx->state[1];
	output[2] = ctx->state[2];
	output[3] = ctx->state[3];
	output[4] = ctx->state[4];
	//memzero(ctx, sizeof(RIPEMD160_CTX));
}
__device__
void ripemd160_GPU(const uint8_t* msg, uint32_t msg_len, uint32_t hash[5])
{
	RIPEMD160_CTX ctx;
	ripemd160_Init(&ctx);
	ripemd160_Update(&ctx, msg, msg_len);
	ripemd160_Final(&ctx, hash);
}


__device__
void hash160(const uint8_t* input, int input_len, uint32_t* output) {
	uint8_t sha256_result[32];
	sha256((const uint32_t*)input, input_len, (uint32_t*)&sha256_result);
	ripemd160_GPU((const uint8_t*)&sha256_result, 32, output);
}
__device__
void calc_hash160(extended_public_key_t* pub, uint32_t* hash160_bytes) {
	//вроде если не заполнять нулями, то иногда считает не правильно
	uint8_t serialized_pub_key[36] = { 0 };//36 а не 33, потому что там потом, бля на uint32_t переводиться и лишнии не нулевые байты появляются и все в пизду сыпиться
	serialized_public_key(pub, (uint8_t*)&serialized_pub_key);
	hash160((const uint8_t*)&serialized_pub_key, 33, hash160_bytes);
}

__device__
void calc_hash160_bip49(extended_public_key_t* pub, uint32_t* hash160_bytes) {
	uint8_t serialized_pub_key[36] = { 0 };//36 а не 33, потому что там потом, бля на uint32_t переводиться и лишнии не нулевые байты появляются и все в пизду сыпиться
	serialized_public_key(pub, (uint8_t*)&serialized_pub_key);
	uint8_t sha256_result[32];
	sha256((const uint32_t*)serialized_pub_key, 33, (uint32_t*)&sha256_result);
	RIPEMD160_CTX ctx;
	ripemd160_Init(&ctx);
	ripemd160_Update(&ctx, sha256_result, 32);
	ripemd160_Final(&ctx, (uint32_t*)sha256_result);

	////uint8_t hash[24];
	serialized_pub_key[0] = 0;
	serialized_pub_key[1] = 0x14;
	for (int i = 0; i < 20; i++)
		serialized_pub_key[i + 2] = sha256_result[i];
	serialized_pub_key[22] = 0;
	serialized_pub_key[23] = 0;
	sha256((const uint32_t*)serialized_pub_key, 22, (uint32_t*)&sha256_result);
	ripemd160_Init(&ctx);
	ripemd160_Update(&ctx, sha256_result, 32);
	ripemd160_Final(&ctx, (uint32_t*)hash160_bytes);
}



//#define SHA512_SHARED

__constant__ uint8_t salt[12] = { 109, 110, 101, 109, 111, 110, 105, 99, 0, 0, 0, 1 };
__constant__ uint8_t salt_swap[16] = { 99, 105, 110, 111, 109, 101, 110, 109, 0, 0, 0, 0, 1, 0, 0, 0};
__constant__ uint8_t key[12] = { 0x42, 0x69, 0x74, 0x63, 0x6f, 0x69, 0x6e, 0x20, 0x73, 0x65, 0x65, 0x64 };
__constant__ uint8_t key_swap[16] = { 0x20, 0x6e, 0x69, 0x6f, 0x63, 0x74, 0x69, 0x42, 0, 0, 0, 0, 0x64, 0x65, 0x65, 0x73 };
#define MEMCPY32(x,y,t) for (int i = 0; i < t; i++) *(uint32_t*)((uint32_t*)x + i) = *(uint32_t*)((uint32_t*)y + i);
#define MEMCPY8(x,y,t) for (int i = 0; i < t; i++) *(uint8_t*)((uint8_t*)x + i) = *(uint8_t*)((uint8_t*)y + i);



//#define printf(...)
__constant__ uint32_t dev_num_bytes_find[1];
__constant__ uint32_t dev_generate_path[MAX_PATH_ARRAY_SIZE];
__constant__ uint32_t dev_num_paths[1];
__constant__ uint32_t dev_num_childs[1];
__constant__ int16_t dev_static_words_indices[12];


__device__
void GetWordFromBipIndex(int16_t  index, uint8_t word[10]) {
	word[9] = 0;
	memcpy(word, words[index], 9);
}

__device__
void entropy_to_mnemonic(const uint64_t* gl_entropy, uint8_t* mnemonic_phrase) {
	uint32_t idx = blockIdx.x * blockDim.x + threadIdx.x;
	entropy_to_mnemonic_with_offset(gl_entropy, mnemonic_phrase, idx, dev_static_words_indices);
}

__device__
void entropy_to_mnemonic_with_offset(const uint64_t* gl_entropy, uint8_t* mnemonic_phrase, uint32_t idx, int16_t  local_static_words_indices[12]) {
	int16_t indices[12] = {-1, -1, -1 , -1 , -1 , -1 , -1 , -1 , -1 , -1 , -1 , -1 };
	//uint32_t idx = blockIdx.x * blockDim.x + threadIdx.x;
	uint64_t entropy[2];
	if (idx < NUM_ENTROPY_FRAME) {
		entropy[0] = gl_entropy[0 + idx * 2];
		entropy[1] = gl_entropy[1 + idx * 2];
	}
	else
	{
		entropy[0] = gl_entropy[0 + (idx % NUM_ENTROPY_FRAME) * 2];
		entropy[1] = gl_entropy[1 + (idx % NUM_ENTROPY_FRAME) * 2];
	}


	entropy[1] += idx;
	if (idx > entropy[1]) entropy[0]++;

	for (int i = 0; i < 12; i++) if (local_static_words_indices[i] != -1) indices[i] = local_static_words_indices[i];
	for (int i = 11, pos = 11; i >= 0; i--)
	{
		if (indices[i] == -1)
		{
			int16_t ind = 0;
			switch (pos)
			{
			case 0: indices[i] = (entropy[0] >> 53) & 2047; break;
			case 1: indices[i] = (entropy[0] >> 42) & 2047; break;
			case 2: indices[i] = (entropy[0] >> 31) & 2047; break;
			case 3: indices[i] = (entropy[0] >> 20) & 2047; break;
			case 4: indices[i] = (entropy[0] >> 9) & 2047; break;
			case 5: indices[i] = ((entropy[0] & ((1 << 9) - 1)) << 2) | ((entropy[1] >> 62) & 3); break;
			case 6: indices[i] = (entropy[1] >> 51) & 2047; break;
			case 7: indices[i] = (entropy[1] >> 40) & 2047; break;
			case 8: indices[i] = (entropy[1] >> 29) & 2047; break;
			case 9: indices[i] = (entropy[1] >> 18) & 2047; break;
			case 10: indices[i] = (entropy[1] >> 7) & 2047; break;
			case 11: indices[i] = ((entropy[1] & ((1 << 7) - 1)) << 4);

				break;
			default:
				break;
			}
			pos--;
		}

	}

	entropy[0] = 0; entropy[1] = 0;
	for (int i = 0; i < 12; i++)
	{
		uint64_t temp = indices[i];
		switch (i)
		{
		case 0: entropy[0] |= temp << 53; break;
		case 1: entropy[0] |= temp << 42; break;
		case 2: entropy[0] |= temp << 31; break;
		case 3: entropy[0] |= temp << 20; break;
		case 4: entropy[0] |= temp << 9; break;
		case 5:
			entropy[0] |= temp >> 2;
			entropy[1] |= temp << 62;
			break;
		case 6: entropy[1] |= temp << 51; break;
		case 7: entropy[1] |= temp << 40; break;
		case 8: entropy[1] |= temp << 29; break;
		case 9: entropy[1] |= temp << 18; break;
		case 10: entropy[1] |= temp << 7; break;
		case 11: entropy[1] |= temp >> 4; break;
		default:
			break;
		}
	}

	uint8_t entropy_hash[32];
	uint8_t bytes[16];
	bytes[15] = entropy[1] & 0xFF;
	bytes[14] = (entropy[1] >> 8) & 0xFF;
	bytes[13] = (entropy[1] >> 16) & 0xFF;
	bytes[12] = (entropy[1] >> 24) & 0xFF;
	bytes[11] = (entropy[1] >> 32) & 0xFF;
	bytes[10] = (entropy[1] >> 40) & 0xFF;
	bytes[9] = (entropy[1] >> 48) & 0xFF;
	bytes[8] = (entropy[1] >> 56) & 0xFF;

	bytes[7] = entropy[0] & 0xFF;
	bytes[6] = (entropy[0] >> 8) & 0xFF;
	bytes[5] = (entropy[0] >> 16) & 0xFF;
	bytes[4] = (entropy[0] >> 24) & 0xFF;
	bytes[3] = (entropy[0] >> 32) & 0xFF;
	bytes[2] = (entropy[0] >> 40) & 0xFF;
	bytes[1] = (entropy[0] >> 48) & 0xFF;
	bytes[0] = (entropy[0] >> 56) & 0xFF;
	sha256((uint32_t*)bytes, 16, (uint32_t*)entropy_hash);
	uint8_t checksum = (entropy_hash[0] >> 4) & ((1 << 4) - 1);

	indices[11] |= checksum;

	IndicesToMnemonic(indices, mnemonic_phrase,words, word_lengths);

}




__device__
int find_hash_in_table(const uint32_t* hash, const tableStruct table, const uint32_t* mnemonic, foundStruct* fnd_ret, uint32_t path, uint32_t child)
{
	int found = 0;
	bool search_state = true;
	uint32_t line_cnt = (table.size / 20);
	uint32_t point = 0;
	uint32_t point_last = 0;
	uint32_t interval = line_cnt / 3;
	uint32_t* hash_from_table;
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
			hash_from_table = &table.table[point * (20 / 4)];
		}
		else {
			hash_from_table = &table.table[point * (20 / 4)];
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

#if STILL_BUILD_OLD_METHOD

__device__ void key_to_hash160(
	const extended_private_key_t* master_private,
	const tableStruct* tables_legacy,
	const tableStruct* tables_segwit,
	const tableStruct* tables_native_segwit,
	const uint32_t* mnemonic,
	retStruct* ret
)
{
	uint32_t hash[(20 / 4)];
	extended_private_key_t target_key;
	extended_private_key_t target_key_fo_pub;
	extended_private_key_t master_private_fo_extint;
	extended_public_key_t target_public_key;
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	if (dev_generate_path[0] != 0) {
		normal_private_child_from_private(master_private, &target_key, 0);
		//m/0/x
		for (int i = 0; i < dev_num_childs[0]; i++) {
			normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
			calc_public(&target_key_fo_pub, &target_public_key);
			calc_hash160(&target_public_key, hash);
			find_hash_in_table(hash, tables_legacy[(uint8_t)hash[0]], mnemonic, &ret->f[0], 0, i);
		}
	}

	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	if (dev_generate_path[1] != 0) {
		normal_private_child_from_private(master_private, &target_key, 1);
		//m/1/x
		for (int i = 0; i < dev_num_childs[0]; i++) {
			normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
			calc_public(&target_key_fo_pub, &target_public_key);
			calc_hash160(&target_public_key, hash);
			find_hash_in_table(hash, tables_legacy[(uint8_t)hash[0]], mnemonic, &ret->f[0], 1, i);
		}
	}
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	if ((dev_generate_path[2] != 0) || (dev_generate_path[3] != 0)) {
		//m/0
		normal_private_child_from_private(master_private, &master_private_fo_extint, 0);

		if (dev_generate_path[2] != 0) {
			//m/0/0
			normal_private_child_from_private(&master_private_fo_extint, &target_key, 0);
			//m/0/0/x
			for (int i = 0; i < dev_num_childs[0]; i++) {
				normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
				calc_public(&target_key_fo_pub, &target_public_key);
				calc_hash160(&target_public_key, hash);
				find_hash_in_table(hash, tables_legacy[(uint8_t)hash[0]], mnemonic, &ret->f[0], 2, i);
			}
		}
		if (dev_generate_path[3] != 0) {
			//m/0/1
			normal_private_child_from_private(&master_private_fo_extint, &target_key, 1);
			//m/0/1/x
			for (int i = 0; i < dev_num_childs[0]; i++) {
				normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
				calc_public(&target_key_fo_pub, &target_public_key);
				calc_hash160(&target_public_key, hash);
				find_hash_in_table(hash, tables_legacy[(uint8_t)hash[0]], mnemonic, &ret->f[0], 3, i);
			}
		}
	}
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	if ((dev_generate_path[4] != 0) || (dev_generate_path[5] != 0)) {
		hardened_private_child_from_private(master_private, &target_key, 44);
		hardened_private_child_from_private(&target_key, &target_key, 0);
		hardened_private_child_from_private(&target_key, &master_private_fo_extint, 0);
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		if (dev_generate_path[4] != 0) {
			normal_private_child_from_private(&master_private_fo_extint, &target_key, 0);
			//m/44'/0'/0'/0/x
			for (int i = 0; i < dev_num_childs[0]; i++) {
				normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
				calc_public(&target_key_fo_pub, &target_public_key);
				calc_hash160(&target_public_key, hash);
				find_hash_in_table(hash, tables_legacy[(uint8_t)hash[0]], mnemonic, &ret->f[0], 4, i);
			}
		}
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		if (dev_generate_path[5] != 0) {
			normal_private_child_from_private(&master_private_fo_extint, &target_key, 1);
			//m/44'/0'/0'/1/x
			for (int i = 0; i < dev_num_childs[0]; i++) {
				normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
				calc_public(&target_key_fo_pub, &target_public_key);
				calc_hash160(&target_public_key, hash);
				find_hash_in_table(hash, tables_legacy[(uint8_t)hash[0]], mnemonic, &ret->f[0], 5, i);
			}
		}
	}
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	if ((dev_generate_path[6] != 0) || (dev_generate_path[7] != 0)) {
		hardened_private_child_from_private(master_private, &target_key, 49);
		hardened_private_child_from_private(&target_key, &target_key, 0);
		hardened_private_child_from_private(&target_key, &master_private_fo_extint, 0);
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		if (dev_generate_path[6] != 0) {
			normal_private_child_from_private(&master_private_fo_extint, &target_key, 0);
			//m/49'/0'/0'/0/x
			for (int i = 0; i < dev_num_childs[0]; i++) {
				normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
				calc_public(&target_key_fo_pub, &target_public_key);
				calc_hash160_bip49(&target_public_key, hash);
				find_hash_in_table(hash, tables_segwit[(uint8_t)hash[0]], mnemonic, &ret->f[1], 6, i);
			}
		}
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		if (dev_generate_path[7] != 0) {
			normal_private_child_from_private(&master_private_fo_extint, &target_key, 1);
			//m/49'/0'/0'/1/x
			for (int i = 0; i < dev_num_childs[0]; i++) {
				normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
				calc_public(&target_key_fo_pub, &target_public_key);
				calc_hash160_bip49(&target_public_key, hash);
				find_hash_in_table(hash, tables_segwit[(uint8_t)hash[0]], mnemonic, &ret->f[1], 7, i);
			}
		}
	}
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	if ((dev_generate_path[8] != 0) || (dev_generate_path[9] != 0)) {
		hardened_private_child_from_private(master_private, &target_key, 84);
		hardened_private_child_from_private(&target_key, &target_key, 0);
		hardened_private_child_from_private(&target_key, &master_private_fo_extint, 0);
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		if (dev_generate_path[8] != 0) {
			normal_private_child_from_private(&master_private_fo_extint, &target_key, 0);
			//m/84'/0'/0'/0/x
			for (int i = 0; i < dev_num_childs[0]; i++) {
				normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
				calc_public(&target_key_fo_pub, &target_public_key);
				calc_hash160(&target_public_key, hash);
				find_hash_in_table(hash, tables_native_segwit[(uint8_t)hash[0]], mnemonic, &ret->f[2], 8, i);
			}
		}
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		if (dev_generate_path[9] != 0) {
			normal_private_child_from_private(&master_private_fo_extint, &target_key, 1);
			//m/84'/0'/0'/1/x
			for (int i = 0; i < dev_num_childs[0]; i++) {
				normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
				calc_public(&target_key_fo_pub, &target_public_key);
				calc_hash160(&target_public_key, hash);
				find_hash_in_table(hash, tables_native_segwit[(uint8_t)hash[0]], mnemonic, &ret->f[2], 9, i);
			}
		}
	}
}

__device__ void key_to_hash160_for_save(
	const extended_private_key_t* master_private,
	const tableStruct* tables_legacy,
	const tableStruct* tables_segwit,
	const tableStruct* tables_native_segwit,
	const uint32_t* mnemonic,
	retStruct* ret,
	uint32_t* hash
)
{
	extended_private_key_t target_key;
	extended_private_key_t target_key_fo_pub;
	extended_private_key_t master_private_fo_extint;
	extended_public_key_t target_public_key;
	uint32_t point = 0;
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	if (dev_generate_path[0] != 0) {
		normal_private_child_from_private(master_private, &target_key, 0);
		//m/0/x
		for (int i = 0; i < dev_num_childs[0]; i++) {
			normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
			calc_public(&target_key_fo_pub, &target_public_key);
			uint32_t* phash = &hash[(i + dev_num_childs[0] * point) * 5];
			calc_hash160(&target_public_key, phash);
			find_hash_in_table(phash, tables_legacy[(uint8_t)phash[0]], mnemonic, &ret->f[0], 0, i);
		}
		point++;
	}
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	if (dev_generate_path[1] != 0) {
		normal_private_child_from_private(master_private, &target_key, 1);
		//m/1/x
		for (int i = 0; i < dev_num_childs[0]; i++) {
			normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
			calc_public(&target_key_fo_pub, &target_public_key);
			uint32_t* phash = &hash[(i + dev_num_childs[0] * point) * 5];
			calc_hash160(&target_public_key, phash);
			find_hash_in_table(phash, tables_legacy[(uint8_t)phash[0]], mnemonic, &ret->f[0], 1, i);
		}
		point++;
	}
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	if ((dev_generate_path[2] != 0) || (dev_generate_path[3] != 0)) {
		//m/0
		normal_private_child_from_private(master_private, &master_private_fo_extint, 0);
		if (dev_generate_path[2] != 0) {
			//m/0/0
			normal_private_child_from_private(&master_private_fo_extint, &target_key, 0);
			//m/0/0/x
			for (int i = 0; i < dev_num_childs[0]; i++) {
				normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
				calc_public(&target_key_fo_pub, &target_public_key);
				uint32_t* phash = &hash[(i + dev_num_childs[0] * point) * 5];
				calc_hash160(&target_public_key, phash);
				find_hash_in_table(phash, tables_legacy[(uint8_t)phash[0]], mnemonic, &ret->f[0], 2, i);
			}
			point++;
		}
		if (dev_generate_path[3] != 0) {
			//m/0/1
			normal_private_child_from_private(&master_private_fo_extint, &target_key, 1);
			//m/0/1/x
			for (int i = 0; i < dev_num_childs[0]; i++) {
				normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
				calc_public(&target_key_fo_pub, &target_public_key);
				uint32_t* phash = &hash[(i + dev_num_childs[0] * point) * 5];
				calc_hash160(&target_public_key, phash);
				find_hash_in_table(phash, tables_legacy[(uint8_t)phash[0]], mnemonic, &ret->f[0], 3, i);
			}
			point++;
		}
	}
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	if ((dev_generate_path[4] != 0) || (dev_generate_path[5] != 0)) {
		hardened_private_child_from_private(master_private, &target_key, 44);
		hardened_private_child_from_private(&target_key, &target_key, 0);
		hardened_private_child_from_private(&target_key, &master_private_fo_extint, 0);
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		if (dev_generate_path[4] != 0) {
			normal_private_child_from_private(&master_private_fo_extint, &target_key, 0);
			//m/44'/0'/0'/0/x
			for (int i = 0; i < dev_num_childs[0]; i++) {
				normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
				calc_public(&target_key_fo_pub, &target_public_key);
				uint32_t* phash = &hash[(i + dev_num_childs[0] * point) * 5];
				calc_hash160(&target_public_key, phash);
				find_hash_in_table(phash, tables_legacy[(uint8_t)phash[0]], mnemonic, &ret->f[0], 4, i);
			}
			point++;
		}
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		if (dev_generate_path[5] != 0) {
			normal_private_child_from_private(&master_private_fo_extint, &target_key, 1);
			//m/44'/0'/0'/1/x
			for (int i = 0; i < dev_num_childs[0]; i++) {
				normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
				calc_public(&target_key_fo_pub, &target_public_key);
				uint32_t* phash = &hash[(i + dev_num_childs[0] * point) * 5];
				calc_hash160(&target_public_key, phash);
				find_hash_in_table(phash, tables_legacy[(uint8_t)phash[0]], mnemonic, &ret->f[0], 5, i);
			}
			point++;
		}
	}
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	if ((dev_generate_path[6] != 0) || (dev_generate_path[7] != 0)) {
		hardened_private_child_from_private(master_private, &target_key, 49);
		hardened_private_child_from_private(&target_key, &target_key, 0);
		hardened_private_child_from_private(&target_key, &master_private_fo_extint, 0);
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		if (dev_generate_path[6] != 0) {
			normal_private_child_from_private(&master_private_fo_extint, &target_key, 0);
			//m/49'/0'/0'/0/x
			for (int i = 0; i < dev_num_childs[0]; i++) {
				normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
				calc_public(&target_key_fo_pub, &target_public_key);
				uint32_t* phash = &hash[(i + dev_num_childs[0] * point) * 5];
				calc_hash160_bip49(&target_public_key, phash);
				find_hash_in_table(phash, tables_segwit[(uint8_t)phash[0]], mnemonic, &ret->f[1], 6, i);
			}
			point++;
		}
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		if (dev_generate_path[7] != 0) {
			normal_private_child_from_private(&master_private_fo_extint, &target_key, 1);
			//m/49'/0'/0'/1/x
			for (int i = 0; i < dev_num_childs[0]; i++) {
				normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
				calc_public(&target_key_fo_pub, &target_public_key);
				uint32_t* phash = &hash[(i + dev_num_childs[0] * point) * 5];
				calc_hash160_bip49(&target_public_key, phash);
				find_hash_in_table(phash, tables_segwit[(uint8_t)phash[0]], mnemonic, &ret->f[1], 7, i);
			}
			point++;
		}
	}
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	//______________________________________________________________________________________________________________________
	if ((dev_generate_path[8] != 0) || (dev_generate_path[9] != 0)) {
		hardened_private_child_from_private(master_private, &target_key, 84);
		hardened_private_child_from_private(&target_key, &target_key, 0);
		hardened_private_child_from_private(&target_key, &master_private_fo_extint, 0);
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		if (dev_generate_path[8] != 0) {
			normal_private_child_from_private(&master_private_fo_extint, &target_key, 0);
			//m/84'/0'/0'/0/x
			for (int i = 0; i < dev_num_childs[0]; i++) {
				normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
				calc_public(&target_key_fo_pub, &target_public_key);
				uint32_t* phash = &hash[(i + dev_num_childs[0] * point) * 5];
				calc_hash160(&target_public_key, phash);
				find_hash_in_table(phash, tables_native_segwit[(uint8_t)phash[0]], mnemonic, &ret->f[2], 8, i);
			}
			point++;
		}
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		//______________________________________________________________________________________________________________________
		if (dev_generate_path[9] != 0) {
			normal_private_child_from_private(&master_private_fo_extint, &target_key, 1);
			//m/84'/0'/0'/1/x
			for (int i = 0; i < dev_num_childs[0]; i++) {
				normal_private_child_from_private(&target_key, &target_key_fo_pub, i);
				calc_public(&target_key_fo_pub, &target_public_key);
				uint32_t* phash = &hash[(i + dev_num_childs[0] * point) * 5];
				calc_hash160(&target_public_key, phash);
				find_hash_in_table(phash, tables_native_segwit[(uint8_t)phash[0]], mnemonic, &ret->f[2], 9, i);
			}
		}
	}
}



__global__ void gl_bruteforce_mnemonic(
	const uint64_t* __restrict__ entropy,
	const tableStruct* __restrict__ tables_legacy,
	const tableStruct* __restrict__ tables_segwit,
	const tableStruct* __restrict__ tables_native_segwit,
	retStruct* __restrict__ ret
)
{
	//int idx = blockIdx.x * blockDim.x + threadIdx.x;
	uint8_t mnemonic_phrase[SIZE_MNEMONIC_FRAME] = { 0 };
	uint8_t* mnemonic = mnemonic_phrase;
	uint32_t ipad[256 / 4];
	uint32_t opad[256 / 4];
	uint32_t seed[64 / 4];

	entropy_to_mnemonic(entropy, mnemonic);
#pragma unroll
	for (int x = 0; x < 120 / 8; x++) {
		*(uint64_t*)((uint64_t*)ipad + x) = 0x3636363636363636ULL ^ SWAP512(*(uint64_t*)((uint64_t*)mnemonic + x));
	}
#pragma unroll
	for (int x = 0; x < 120 / 8; x++) {
		*(uint64_t*)((uint64_t*)opad + x) = 0x5C5C5C5C5C5C5C5CULL ^ SWAP512(*(uint64_t*)((uint64_t*)mnemonic + x));
	}
#pragma unroll
	for (int x = 120 / 4; x < 128 / 4; x++) {
		ipad[x] = 0x36363636;
	}
#pragma unroll
	for (int x = 120 / 4; x < 128 / 4; x++) {
		opad[x] = 0x5C5C5C5C;
	}
#pragma unroll
	for (int x = 0; x < 16 / 4; x++) {
		ipad[x + 128 / 4] = *(uint32_t*)((uint32_t*)&salt_swap + x);
	}
	sha512_swap((uint64_t*)ipad, 140, (uint64_t*)&opad[128 / 4]);
	sha512_swap((uint64_t*)opad, 192, (uint64_t*)&ipad[128 / 4]);
#pragma unroll
	for (int x = 0; x < 64 / 4; x++) {
		seed[x] = ipad[128 / 4 + x];
	}
	for (int x = 1; x < 2048; x++) {
		sha512_swap((uint64_t*)ipad, 192, (uint64_t*)&opad[128 / 4]);
		sha512_swap((uint64_t*)opad, 192, (uint64_t*)&ipad[128 / 4]);
#pragma unroll
		for (int x = 0; x < 64 / 4; x++) {
			seed[x] = seed[x] ^ ipad[128 / 4 + x];
		}
	}
#pragma unroll
	for (int x = 0; x < 16 / 4; x++) {
		ipad[x] = 0x36363636 ^ *(uint32_t*)((uint32_t*)&key_swap + x);
	}
#pragma unroll
	for (int x = 0; x < 16 / 4; x++) {
		opad[x] = 0x5C5C5C5C ^ *(uint32_t*)((uint32_t*)&key_swap + x);
	}
#pragma unroll
	for (int x = 16 / 4; x < 128 / 4; x++) {
		ipad[x] = 0x36363636;
	}
#pragma unroll
	for (int x = 16 / 4; x < 128 / 4; x++) {
		opad[x] = 0x5C5C5C5C;
	}
#pragma unroll
	for (int x = 0; x < 64 / 4; x++) {
		ipad[x + 128 / 4] = seed[x];
	}
	//ipad[192 / 4] = 0;
	//opad[192 / 4] = 0;
	sha512_swap((uint64_t*)ipad, 192, (uint64_t*)&opad[128 / 4]);
	sha512_swap((uint64_t*)opad, 192, (uint64_t*)&ipad[128 / 4]);
#pragma unroll
	for (int x = 0; x < 128 / 8; x++) {
		*(uint64_t*)((uint64_t*)&ipad[128 / 4] + x) = SWAP512(*(uint64_t*)((uint64_t*)&ipad[128 / 4] + x));
	}
	key_to_hash160((extended_private_key_t*)&ipad[128 / 4], tables_legacy, tables_segwit, tables_native_segwit, (uint32_t*)mnemonic, ret);
	//__syncthreads();
}


__global__ void gl_bruteforce_mnemonic_for_save(
	const uint64_t* __restrict__ entropy,
	const tableStruct* __restrict__ tables_legacy,
	const tableStruct* __restrict__ tables_segwit,
	const tableStruct* __restrict__ tables_native_segwit,
	retStruct* __restrict__ ret,
	uint8_t* __restrict__ mnemonic_ret,
	uint32_t* __restrict__ hash160_ret
)
{
	int idx = blockIdx.x * blockDim.x + threadIdx.x;
	uint8_t mnemonic[SIZE_MNEMONIC_FRAME] = { 0 };
	uint32_t ipad[512 / 4];
	uint32_t opad[512 / 4];
	uint32_t seed[64 / 4];
	//uint64_t W[80];

	entropy_to_mnemonic(entropy, mnemonic);
#pragma unroll
	for (int x = 0; x < 120 / 8; x++) {
		*(uint64_t*)((uint64_t*)ipad + x) = 0x3636363636363636ULL ^ SWAP512(*(uint64_t*)((uint64_t*)mnemonic + x));
	}
#pragma unroll
	for (int x = 0; x < 120 / 8; x++) {
		*(uint64_t*)((uint64_t*)opad + x) = 0x5C5C5C5C5C5C5C5CULL ^ SWAP512(*(uint64_t*)((uint64_t*)mnemonic + x));
	}
#pragma unroll
	for (int x = 120 / 4; x < 128 / 4; x++) {
		ipad[x] = 0x36363636;
	}
#pragma unroll
	for (int x = 120 / 4; x < 128 / 4; x++) {
		opad[x] = 0x5C5C5C5C;
	}
#pragma unroll
	for (int x = 0; x < 16 / 4; x++) {
		ipad[x + 128 / 4] = *(uint32_t*)((uint32_t*)&salt_swap + x);
	}
	sha512_swap((uint64_t*)ipad, 140, (uint64_t*)&opad[128 / 4]);
	sha512_swap((uint64_t*)opad, 192, (uint64_t*)&ipad[128 / 4]);
#pragma unroll
	for (int x = 0; x < 64 / 4; x++) {
		seed[x] = ipad[128 / 4 + x];
	}
	for (int x = 1; x < 2048; x++) {
		sha512_swap((uint64_t*)ipad, 192, (uint64_t*)&opad[128 / 4]);
		sha512_swap((uint64_t*)opad, 192, (uint64_t*)&ipad[128 / 4]);
#pragma unroll
		for (int x = 0; x < 64 / 4; x++) {
			seed[x] = seed[x] ^ ipad[128 / 4 + x];
		}
	}
#pragma unroll
	for (int x = 0; x < 16 / 4; x++) {
		ipad[x] = 0x36363636 ^ *(uint32_t*)((uint32_t*)&key_swap + x);
	}
#pragma unroll
	for (int x = 0; x < 16 / 4; x++) {
		opad[x] = 0x5C5C5C5C ^ *(uint32_t*)((uint32_t*)&key_swap + x);
	}
#pragma unroll
	for (int x = 16 / 4; x < 128 / 4; x++) {
		ipad[x] = 0x36363636;
	}
#pragma unroll
	for (int x = 16 / 4; x < 128 / 4; x++) {
		opad[x] = 0x5C5C5C5C;
	}
#pragma unroll
	for (int x = 0; x < 64 / 4; x++) {
		ipad[x + 128 / 4] = seed[x];
	}
	//ipad[192 / 4] = 0;
	//opad[192 / 4] = 0;
	sha512_swap((uint64_t*)ipad, 192, (uint64_t*)&opad[128 / 4]);
	sha512_swap((uint64_t*)opad, 192, (uint64_t*)&ipad[128 / 4]);
#pragma unroll
	for (int x = 0; x < 128 / 8; x++) {
		*(uint64_t*)((uint64_t*)&ipad[128 / 4] + x) = SWAP512(*(uint64_t*)((uint64_t*)&ipad[128 / 4] + x));
	}
	key_to_hash160_for_save((extended_private_key_t*)&ipad[128 / 4], tables_legacy, tables_segwit, tables_native_segwit, (uint32_t*)mnemonic, ret, &hash160_ret[idx * (dev_num_paths[0] * dev_num_childs[0] * 5)]);
	for (int i = 0; i < SIZE_MNEMONIC_FRAME; i++)
	{
		mnemonic_ret[idx * SIZE_MNEMONIC_FRAME + i] = mnemonic[i];
	}

	//__syncthreads();
}

#endif /*STILL_BUILD_OLD_METHOD*/


