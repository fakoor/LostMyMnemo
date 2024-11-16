#include "cuda_runtime.h"

// Define debug level names
#define DBG_ERROR 0
#define DBG_WARN  1
#define DBG_INFO  2
#define DBG_DEBUG 3

// Set the current debug level
#define DEBUGLEVEL DBG_ERROR  // Change this to control debug output

// Define the DBGPRINTF macro
#define DBGPRINTF(level, fmt, ...) \
    do { \
        if (level <= DEBUGLEVEL) { \
            printf(fmt, ##__VA_ARGS__); \
        } \
    } while (0)
