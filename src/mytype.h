#ifndef _TYPE_
#define _TYPE_

#include "config.h"

typedef unsigned int IDTYPE;
typedef unsigned long VALUE;


typedef struct {
  IDTYPE id;
} Basic;


//#define MAX_PORT 5

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



// Equation
typedef struct EQ_tag {
  VALUE l, r;
} EQ;

typedef struct EQList_tag {  
  EQ eq;
  struct EQList_tag *next;
} EQList;




#define FIXNUM_FLAG 0x01
#define INT2FIX(i) ((VALUE)(((long)(i) << 1) | FIXNUM_FLAG))
#define FIX2INT(i) ((long)(i) >> 1)
#define IS_FIXNUM(i) ((VALUE)(i) & FIXNUM_FLAG)


#define AGENT(a) ((Agent *)(a))
#define BASIC(a) ((Basic *)(a))
#define NAME(a) ((Name *)(a))

#endif
