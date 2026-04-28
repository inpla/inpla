#ifndef INPLA_UNLIKELY_H_
#define INPLA_UNLIKELY_H_

#if defined(__GNUC__) || defined(__clang__)
// For GCC, Clang
#define likely(x) __builtin_expect(!!(x), 1)
#define unlikely(x) __builtin_expect(!!(x), 0)
#else
// Otherwise
#define likely(x) (x)
#define unlikely(x) (x)
#endif

#endif
