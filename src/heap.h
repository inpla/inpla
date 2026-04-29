#ifndef HEAP_H
#define HEAP_H

#include "config.h"
#include "mytype.h"

#ifdef EXPANDABLE_HEAP

// HOOP_SIZE must be power of two
// #define INIT_HOOP_SIZE (1 << 10)
// #define HOOP_SIZE (1 << 18)
#define HOOP_SIZE_MASK ((HOOP_SIZE) - 1)

typedef struct HoopList_tag {
  VALUE *hoop;
  struct HoopList_tag *next;
} HoopList;

// Nodes with '1' on the 31bit in hoops are ready for use and
// '0' are occupied, that is to say, using now.
#define HOOPFLAG_READYFORUSE 0x01 << 31
#define IS_READYFORUSE(a) ((a) & HOOPFLAG_READYFORUSE)
#define SET_HOOPFLAG_READYFORUSE(a) ((a) = ((a) | HOOPFLAG_READYFORUSE))
#define RESET_HOOPFLAG_READYFORUSE_AGENT(a) ((a) = (HOOPFLAG_READYFORUSE))
#define RESET_HOOPFLAG_READYFORUSE_NAME(a)                                     \
  ((a) = ((ID_NAME) | (HOOPFLAG_READYFORUSE)))
#define TOGGLE_HOOPFLAG_READYFORUSE(a) ((a) = ((a) ^ HOOPFLAG_READYFORUSE))

typedef struct Heap_tag {
  HoopList *last_alloc_list;
  int last_alloc_idx;
} Heap;

HoopList *HoopList_new_forName(void);
HoopList *HoopList_new_forAgent(void);

unsigned long Heap_GetNum_Usage_forAgent(Heap *hp);
unsigned long Heap_GetNum_Usage_forName(Heap *hp);

VALUE Expand_heap_alloc_Agent(Heap *hp);
VALUE Expand_heap_alloc_Name(Heap *hp);

#ifndef THREAD
void sweep_AgentHeap(Heap *hp);
void sweep_NameHeap(Heap *hp);
#endif

static inline void myfree(VALUE ptr) {

  SET_HOOPFLAG_READYFORUSE(BASIC(ptr)->id);
}

static inline void myfree2(VALUE ptr, VALUE ptr2) {

  SET_HOOPFLAG_READYFORUSE(BASIC(ptr)->id);
  SET_HOOPFLAG_READYFORUSE(BASIC(ptr2)->id);
}

/* ------------------------------------------------------------
   FLEX EXPANDABLE HEAP
 ------------------------------------------------------------ */
#elif defined(FLEX_EXPANDABLE_HEAP)

typedef struct HoopList_tag {
  VALUE *hoop;
  struct HoopList_tag *next;
  unsigned int size; // NOTE: Be power of 2!
} HoopList;

#define HOOPFLAG_READYFORUSE 0
#define IS_READYFORUSE(a) ((a) == HOOPFLAG_READYFORUSE)
#define SET_HOOPFLAG_READYFORUSE(a) ((a) = HOOPFLAG_READYFORUSE)
#define RESET_HOOPFLAG_READYFORUSE_AGENT(a) ((a) = HOOPFLAG_READYFORUSE)
#define RESET_HOOPFLAG_READYFORUSE_NAME(a) ((a) = HOOPFLAG_READYFORUSE)

typedef struct Heap_tag {
  HoopList *last_alloc_list;
  unsigned int last_alloc_idx;
} Heap;

// #define MAX_HOOP_SIZE 50000000

HoopList *HoopList_new_forName(unsigned int size);
HoopList *HoopList_new_forAgent(unsigned int size);
unsigned long Heap_GetNum_Usage_forAgent(Heap *hp);
unsigned long Heap_GetNum_Usage_forName(Heap *hp);

VALUE Flex_expand_heap_alloc_Agent(Heap *hp, unsigned int Hoop_inc_magnitude);
VALUE Flex_expand_heap_alloc_Name(Heap *hp, unsigned int Hoop_inc_magnitude);

#ifndef THREAD
void sweep_AgentHeap(Heap *hp);
void sweep_NameHeap(Heap *hp);
#endif

static inline void myfree(VALUE ptr) {

  SET_HOOPFLAG_READYFORUSE(BASIC(ptr)->id);
}

static inline void myfree2(VALUE ptr, VALUE ptr2) {

  SET_HOOPFLAG_READYFORUSE(BASIC(ptr)->id);
  SET_HOOPFLAG_READYFORUSE(BASIC(ptr2)->id);
}

#else
// v0.5.6 -------------------------------------
// Fixed size buffer
// --------------------------------------------
typedef struct Heap_tag {
  VALUE *heap;
  int lastAlloc;
  unsigned int size;
} Heap;

// Heap cells having '1' on the 31bit are ready for use and
// '0' are occupied, that is to say, using now.
#define HEAPFLAG_READYFORUSE 0x01 << 31
#define IS_READYFORUSE(a) ((a) & HEAPFLAG_READYFORUSE)
#define SET_HEAPFLAG_READYFORUSE(a) ((a) = ((a) | HEAPFLAG_READYFORUSE))
#define RESET_HEAPFLAG_READYFORUSE_AGENT(a) ((a) = (HEAPFLAG_READYFORUSE))
#define RESET_HEAPFLAG_READYFORUSE_NAME(a)                                     \
  ((a) = ((ID_NAME) | (HEAPFLAG_READYFORUSE)))
#define TOGGLE_HEAPFLAG_READYFORUSE(a) ((a) = ((a) ^ HEAPFLAG_READYFORUSE))

VALUE *MakeAgentHeap(int size);
VALUE *MakeNameHeap(int size);

unsigned long Heap_GetNum_Usage_forName(Heap *hp);
unsigned long Heap_GetNum_Usage_forAgent(Heap *hp);

VALUE Heap_alloc_Agent(Heap *hp);
VALUE Heap_alloc_Name(Heap *hp);

#ifndef THREAD
void sweep_AgentHeap(Heap *hp);
void sweep_NameHeap(Heap *hp);
#endif

void myfree(VALUE ptr);
void myfree2(VALUE ptr, VALUE ptr2);

//---------------------------------------------

#endif

void puts_memory_usage(Heap *agent_heap, Heap *name_heap);

#endif /* HEAP_H */
