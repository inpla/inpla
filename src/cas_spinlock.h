#ifndef _CAS_SPINLOCK_
#define _CAS_SPINLOCK_

//#define CAS_LOCK_USLEEP 4
#define CAS_LOCK_USLEEP 200

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include "unlikely.h"

static inline void lock(pthread_spinlock_t *__lock) {
 int ret = pthread_spin_lock(__lock);

 if(unlikely(ret)) {
   printf("Error: pthread_spin_lock() == %d\n", ret);
   abort();
 }
}

static inline void unlock(pthread_spinlock_t *__lock) {
 int ret = pthread_spin_unlock(__lock);

 if(unlikely(ret)) {
   printf("Error: pthread_spin_unlock() == %d\n", ret);
   abort();
 }
}

#endif
