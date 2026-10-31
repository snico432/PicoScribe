#ifndef DEBUG_LOG_H
#define DEBUG_LOG_H

#include <stdio.h>

/*
 * DEBUG_LOGGING is defined for Debug builds (CMAKE_BUILD_TYPE=Debug).
 * Release, MinSizeRel, and RelWithDebInfo compile these calls out.
 */
#ifdef DEBUG_LOGGING
#define DEBUG_LOG(...) fprintf(stderr, __VA_ARGS__)
#else
#define DEBUG_LOG(...) ((void)0)
#endif

#endif /* DEBUG_LOG_H */
