#ifndef INPLA_UNLIKELY_H
#define INPLA_UNLIKELY_H

#if defined(__GNUC__) || defined(__clang__)
    // GCC と Clang の場合は、極限まで最適化！
    #define likely(x)   __builtin_expect(!!(x), 1)
    #define unlikely(x) __builtin_expect(!!(x), 0)
#else
    // それ以外のコンパイラ（MSVCなど）では、ただの素通り（無害化）
    #define likely(x)   (x)
    #define unlikely(x) (x)
#endif

#endif
