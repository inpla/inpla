//https://github.com/zuqqhi2/numerical_simulation/blob/master/multithread/laytrace/timer.h

#ifndef _H_TIMER
#define _H_TIMER

#include <stdio.h>
#include <sys/time.h>

static inline
unsigned long long gettimeval(void) {
  struct timeval tv;
  struct timezone tz;
  gettimeofday(&tv, &tz);
  return ((unsigned long long)tv.tv_sec)*1000000+tv.tv_usec;
}

static inline
void start_timer(unsigned long long *startt) {
  *startt = gettimeval();
  return;
}

static inline
unsigned long long stop_timer(unsigned long long *startt) {
  unsigned long long stopt = gettimeval();
  return (stopt>=*startt)?(stopt-*startt):(stopt);
}

#define print_timer(te) {printf("time of %s:%f[sec]\n", #te, (te*1.0e-3)/1000);}

#endif
