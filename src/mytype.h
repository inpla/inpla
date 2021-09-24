#ifndef _TYPE_
#define _TYPE_

typedef unsigned int IDTYPE;
typedef unsigned long VALUE;


typedef struct {
  IDTYPE id;
} Basic;


#define MAX_PORT 5

#ifndef THREAD
typedef struct {
  Basic basic;
  VALUE port;
} Name;

typedef struct {
  Basic basic;
  VALUE port[MAX_PORT];
} Agent;

#else
typedef struct {
  Basic basic;
  volatile VALUE port;
} Name;

typedef struct {
  Basic basic;
  volatile VALUE port[MAX_PORT];
} Agent;
#endif


#define FIXNUM_FLAG 0x01
#define INT2FIX(i) ((VALUE)(((long)(i) << 1) | FIXNUM_FLAG))
#define FIX2INT(i) ((int)(i) >> 1)
#define IS_FIXNUM(i) ((VALUE)(i) & FIXNUM_FLAG)


#define AGENT(a) ((Agent *)(a))
#define BASIC(a) ((Basic *)(a))
#define NAME(a) ((Name *)(a))

#endif
