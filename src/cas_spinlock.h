//#define CAS_LOCK_USLEEP 4
#define CAS_LOCK_USLEEP 200



#define USE_UNLIKELY
#ifdef USE_UNLIKELY
#include "unlikely.h"
static inline void lock(volatile int *aexclusion) {
  if (likely(__sync_lock_test_and_set(aexclusion, 1) == 0)) {
      return; 
  }

  while (__sync_lock_test_and_set(aexclusion, 1)) {
    while (*aexclusion) {
      usleep(CAS_LOCK_USLEEP);
    }
  }
}

#else

static inline void lock(volatile int *aexclusion) {
  while (__sync_lock_test_and_set(aexclusion, 1))
    while (*aexclusion)
      usleep(CAS_LOCK_USLEEP);
}

#endif


static inline void unlock(volatile int *aexclusion) {
  __sync_lock_release(aexclusion); 
}
