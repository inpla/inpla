//#define CAS_LOCK_USLEEP 4
#define CAS_LOCK_USLEEP 200

static inline void lock(volatile int *aexclusion) {
  while (__sync_lock_test_and_set(aexclusion, 1))
    while (*aexclusion)
      usleep(CAS_LOCK_USLEEP);
}
static inline void unlock(volatile int *aexclusion) {
  __sync_lock_release(aexclusion); 
}
