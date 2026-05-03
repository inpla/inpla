#include <stdio.h>
#include <stdlib.h>

#include "config.h"
#include "mytype.h"
#include "name_table.h"

#include "heap.h"

#ifdef EXPANDABLE_HEAP

HoopList *HoopList_new_forName(void) {
  int i;
  HoopList *hp_list;

  hp_list = (HoopList *)malloc(sizeof(HoopList));
  if (hp_list == NULL) {
    printf("[HoopList]Malloc error\n");
    exit(-1);
  }

  // Name Heap
  hp_list->hoop = (VALUE *)malloc(sizeof(Name) * HOOP_SIZE);
  if (hp_list->hoop == (VALUE *)NULL) {
    printf("[HoopList->Hoop (name)]Malloc error\n");
    exit(-1);
  }
  for (i = 0; i < HOOP_SIZE; i++) {
    //    ((Name *)(hp_list->hoop))[i].basic.id = ID_NAME;
    RESET_HOOPFLAG_READYFORUSE_NAME(((Name *)(hp_list->hoop))[i].basic.id);
  }

  // hp->next = NULL;   // this should be executed only for the first creation.
  return hp_list;
}

HoopList *HoopList_new_forAgent(void) {
  int i;
  HoopList *hp_list;

  hp_list = (HoopList *)malloc(sizeof(HoopList));
  if (hp_list == NULL) {
    printf("[HoopList]Malloc error\n");
    exit(-1);
  }

  // Agent Heap
  hp_list->hoop = (VALUE *)malloc(sizeof(Agent) * HOOP_SIZE);
  if (hp_list->hoop == (VALUE *)NULL) {
    printf("[HoopList->Hoop]Malloc error\n");
    exit(-1);
  }
  for (i = 0; i < HOOP_SIZE; i++) {
    RESET_HOOPFLAG_READYFORUSE_AGENT(((Agent *)(hp_list->hoop))[i].basic.id);
  }

  // hp->next = NULL;   // this should be executed only for the first creation.
  return hp_list;
}

unsigned long Heap_GetNum_Usage_forAgent(Heap *hp) {

  unsigned long count = 0;
  HoopList *hoop_list = hp->last_alloc_list;

  Agent *hoop;

  do {

    hoop = (Agent *)(hoop_list->hoop);
    for (int i = 0; i < HOOP_SIZE; i++) {
      if (!IS_READYFORUSE(hoop[i].basic.id)) {
        count++;
      }
    }
    hoop_list = hoop_list->next;
  } while (hoop_list != hp->last_alloc_list);

  return count;
}

unsigned long Heap_GetNum_Usage_forName(Heap *hp) {

  unsigned long count = 0;
  HoopList *hoop_list = hp->last_alloc_list;

  Name *hoop;

  do {

    hoop = (Name *)(hoop_list->hoop);
    for (int i = 0; i < HOOP_SIZE; i++) {
      if (!IS_READYFORUSE(hoop[i].basic.id)) {
        count++;
      }
    }
    hoop_list = hoop_list->next;
  } while (hoop_list != hp->last_alloc_list);

  return count;
}

VALUE Expand_heap_alloc_Agent(Heap *hp) {

  int idx;
  HoopList *hoop_list;
  Agent *hoop;

  idx = hp->last_alloc_idx;
  hoop_list = hp->last_alloc_list;

  while (1) {
    hoop = (Agent *)(hoop_list->hoop);

    while (idx < HOOP_SIZE) {

      if (IS_READYFORUSE(hoop[idx].basic.id)) {
        TOGGLE_HOOPFLAG_READYFORUSE(hoop[idx].basic.id);

        hp->last_alloc_idx = idx;
        // hp->last_alloc_idx = (idx-1+HOOP_SIZE)%HOOP_SIZE_MASK;

        hp->last_alloc_list = hoop_list;

        //    printf("hit[%d]\n", idx);
        return (VALUE) & (hoop[idx]);
      }
      idx++;
    }

    // No nodes are available in this hoop.

    if (hoop_list->next != hp->last_alloc_list) {
      // There is another hoop.
      hoop_list = hoop_list->next;
      idx = 0;

    } else {
      // There are no other hoops. A new hoop should be created.

      //          v when come again here
      //    current    last_alloc
      // -->|......|-->|......|-->
      //
      // ==>
      //             new current
      //               new        last_alloc
      // -->|......|-->|oooooo|-->|......|--

#ifdef VERBOSE_HOOP_EXPANSION
      puts("(Agent hoop is BEING expanded)");
      fflush(stdout)
#endif

          HoopList *new_hoop_list;
      new_hoop_list = HoopList_new_forAgent();

#ifdef VERBOSE_HOOP_EXPANSION
      puts("(Agent hoop has been expanded!)");
      fflush(stdout)
#endif

          HoopList *last_alloc = hoop_list->next;
      hoop_list->next = new_hoop_list;
      new_hoop_list->next = last_alloc;

      /*
      // Another way: insert new_hoop into the next of the top.
      // But, it does not work so well.

      HoopList *next_from_top = hp->hoop_list->next;
      hp->hoop_list = new_hoop_list;
      new_hoop_list->next = next_from_top;
      */

      hoop_list = new_hoop_list;
      idx = 0;
    }
  }
}

VALUE Expand_heap_alloc_Name(Heap *hp) {

  int idx;
  HoopList *hoop_list;
  Name *hoop;

  idx = hp->last_alloc_idx;
  hoop_list = hp->last_alloc_list;

  while (1) {
    hoop = (Name *)(hoop_list->hoop);

    while (idx < HOOP_SIZE) {

      if (IS_READYFORUSE(hoop[idx].basic.id)) {
        TOGGLE_HOOPFLAG_READYFORUSE(hoop[idx].basic.id);

        // hp->last_alloc_idx = idx;
        hp->last_alloc_idx = (idx - 1 + HOOP_SIZE) & HOOP_SIZE_MASK;

        hp->last_alloc_list = hoop_list;

        //    printf("hit[%d]\n", idx);
        return (VALUE) & (hoop[idx]);
      }
      idx++;
    }

    // No nodes are available in this hoop.

    if (hoop_list->next != hp->last_alloc_list) {
      // There is another hoop.
      hoop_list = hoop_list->next;
      idx = 0;

    } else {

      // There are no other hoops. A new hoop should be created.

      //          v when come again here
      //    current    last_alloc
      // -->|......|-->|xxxxxx|-->
      //
      // ==>
      //             new current
      //               new        last_alloc
      // -->|......|-->|oooooo|-->|xxxxxx|--

#ifdef VERBOSE_HOOP_EXPANSION
      puts("(Name hoop is BEING expanded)");
      fflush(stdout);
#endif

      HoopList *new_hoop_list;
      new_hoop_list = HoopList_new_forName();

#ifdef VERBOSE_HOOP_EXPANSION
      puts("(Name hoop has been expanded!)");
      fflush(stdout);
#endif

      HoopList *last_alloc = hoop_list->next;
      hoop_list->next = new_hoop_list;
      new_hoop_list->next = last_alloc;

      hoop_list = new_hoop_list;
      idx = 0;
    }
  }
}

void sweep_AgentHeap(Heap *hp) {

  HoopList *hoop_list = hp->last_alloc_list;
  Agent *hoop;

  do {
    hoop = (Agent *)(hoop_list->hoop);
    for (int i = 0; i < HOOP_SIZE; i++) {

      if (!IS_FLAG_MARKED(hoop[i].basic.id)) {
        SET_HOOPFLAG_READYFORUSE(hoop[i].basic.id);
      } else {
        TOGGLE_FLAG_MARKED(hoop[i].basic.id);
      }
    }
    hoop_list = hoop_list->next;
  } while (hoop_list != hp->last_alloc_list);
}

void sweep_NameHeap(Heap *hp) {
  HoopList *hoop_list = hp->last_alloc_list;
  Name *hoop;

  do {
    hoop = (Name *)(hoop_list->hoop);
    for (int i = 0; i < HOOP_SIZE; i++) {

      if (!IS_FLAG_MARKED(hoop[i].basic.id)) {
        SET_HOOPFLAG_READYFORUSE(hoop[i].basic.id);
      } else {
        TOGGLE_FLAG_MARKED(hoop[i].basic.id);
      }
    }
    hoop_list = hoop_list->next;
  } while (hoop_list != hp->last_alloc_list);
}

/* ------------------------------------------------------------
   FLEX EXPANDABLE HEAP
 ------------------------------------------------------------ */
#elif defined(FLEX_EXPANDABLE_HEAP)

HoopList *HoopList_new_forName(unsigned int size) {
  HoopList *hp_list;

  if (size > MAX_HOOP_SIZE) {
    fprintf(stderr, "\n[Inpla VM Fatal Error] Memory limit exceeded!\n");
    fprintf(stderr,
            "Requested size for Name Hoop (%u) exceeds the maximum limit "
            "MAX_HOOP_SIZE (%u).\n",
            size, MAX_HOOP_SIZE);
    fprintf(stderr, "Possible infinite loop detected in Interaction Rules!\n");
    exit(-1); // Exit safely with an error code
  }

  hp_list = (HoopList *)malloc(sizeof(HoopList));
  if (hp_list == NULL) {
    printf("[HoopList]Malloc error\n");
    fflush(stdout);
    exit(-1);
  }

  // Name Heap
  hp_list->hoop = (VALUE *)malloc(size * sizeof(Name));
  if (hp_list->hoop == (VALUE *)NULL) {
    printf("[HoopList->Hoop (name)]Malloc error\n");
    fflush(stdout);
    exit(-1);
  }

  for (unsigned int i = 0; i < size; i++) {
    RESET_HOOPFLAG_READYFORUSE_NAME(((Name *)(hp_list->hoop))[i].basic.id);
  }
  hp_list->size = size;

  // hp->next = NULL;   // this should be executed only for the first creation.
  return hp_list;
}

HoopList *HoopList_new_forAgent(unsigned int size) {
  HoopList *hp_list;

  //  #define PUT_NEW_AGENTHOOP_TIME
#ifdef PUT_NEW_AGENTHOOP_TIME
  unsigned long long t, time;
  start_timer(&t);
#endif

  if (size > MAX_HOOP_SIZE) {
    fprintf(stderr, "\n[Inpla VM Fatal Error] Memory limit exceeded!\n");
    fprintf(stderr,
            "Requested size for Agent Hoop (%u) exceeds the maximum limit "
            "MAX_HOOP_SIZE (%u).\n",
            size, MAX_HOOP_SIZE);
    fprintf(stderr, "Possible infinite loop detected in Interaction Rules!\n");
    exit(-1); // Exit safely with an error code
  }

  hp_list = (HoopList *)malloc(sizeof(HoopList));
  if (hp_list == NULL) {
    printf("[HoopList]Malloc error\n");
    exit(-1);
  }

  // Agent Heap
  hp_list->hoop = (VALUE *)malloc(size * sizeof(Agent));
  if (hp_list->hoop == (VALUE *)NULL) {
    printf("[HoopList->Hoop]Malloc error\n");
    exit(-1);
  }
  for (unsigned int i = 0; i < size; i++) {
    RESET_HOOPFLAG_READYFORUSE_AGENT(((Agent *)(hp_list->hoop))[i].basic.id);
  }
  hp_list->size = size;

#ifdef PUT_NEW_AGENTHOOP_TIME
  time = stop_timer(&t);
  printf("(%.6f sec)\n", (double)(time) / 1000000.0);
#endif

  // hp->next = NULL;   // this should be executed only for the first creation.
  return hp_list;
}

unsigned long Heap_GetNum_Usage_forAgent(Heap *hp) {
  unsigned long count = 0;
  HoopList *hoop_list = hp->last_alloc_list;

  Agent *hoop;

  do {
    hoop = (Agent *)(hoop_list->hoop);
    for (unsigned int i = 0; i < hoop_list->size; i++) {
      if (!IS_READYFORUSE(hoop[i].basic.id)) {
        count++;
      }
    }
    hoop_list = hoop_list->next;
  } while (hoop_list != hp->last_alloc_list);

  return count;
}

unsigned long Heap_GetNum_Usage_forName(Heap *hp) {
  unsigned long count = 0;
  HoopList *hoop_list = hp->last_alloc_list;

  Name *hoop;

  do {

    hoop = (Name *)(hoop_list->hoop);
    for (unsigned int i = 0; i < hoop_list->size; i++) {
      if (!IS_READYFORUSE(hoop[i].basic.id)) {
        count++;
      }
    }
    hoop_list = hoop_list->next;
  } while (hoop_list != hp->last_alloc_list);

  return count;
}

VALUE Flex_expand_heap_alloc_Agent(Heap *hp, unsigned int Hoop_inc_magnitude) {

  unsigned int idx;
  HoopList *hoop_list;
  Agent *hoop;

  idx = hp->last_alloc_idx;
  hoop_list = hp->last_alloc_list;

  while (1) {
    hoop = (Agent *)(hoop_list->hoop);

    while (idx < hoop_list->size) {

      if (IS_READYFORUSE(hoop[idx].basic.id)) {
        //	TOGGLE_HOOPFLAG_READYFORUSE(hoop[idx].basic.id);

        hp->last_alloc_idx = idx;
        // hp->last_alloc_idx = (idx-1+HOOP_SIZE)%HOOP_SIZE_MASK;

        hp->last_alloc_list = hoop_list;

        //    printf("hit[%d]\n", idx);
        return (VALUE) & (hoop[idx]);
      }
      idx++;
    }

    // No nodes are available in this hoop.

    if (hoop_list->next != hp->last_alloc_list) {
      // There is another hoop.
      hoop_list = hoop_list->next;
      idx = 0;

    } else {
      // There are no other hoops. A new hoop should be created.

      //          v when come again here
      //    current    last_alloc
      // -->|......|-->|......|-->
      //
      // ==>
      //             new current
      //               new        last_alloc
      // -->|......|-->|oooooo|-->|......|--

      //      printf("(Agent hoop is expanded [%d])\n", hoop_list->size);
#ifdef VERBOSE_HOOP_EXPANSION
      puts("(Agent hoop is BEING expanded...)");
      fflush(stdout);
#endif

      // puts("!");
      /*
      {
        Agent *last = (Agent *)(hp->last_alloc_list->hoop);
        unsigned long size = hp->last_alloc_list->size;
        unsigned long count = 0;
        for (unsigned long i = 0; i<size; i++) {
          if (!IS_READYFORUSE(last[i].basic.id)) {
            count++;
          }
        }
        printf("%lu is occupied in %lu size.\n\n", count, size);
      }
      */
      //            printf("%lu is occupied.\n",
      //      	     Heap_GetNum_Usage_forAgent(hp));

      HoopList *new_hoop_list;
      // unsigned int new_size_p2 = hoop_list->size * Hoop_inc_magnitude;
      unsigned int new_size_p2 =
          (hp->last_alloc_list->size) * Hoop_inc_magnitude;
      new_hoop_list = HoopList_new_forAgent(new_size_p2);

      HoopList *last_alloc = hoop_list->next;
      hoop_list->next = new_hoop_list;
      new_hoop_list->next = last_alloc;

      /*
      // Another way: insert new_hoop into the next of the top.
      // But, it does not work so well.

      HoopList *next_from_top = hp->hoop_list->next;
      hp->hoop_list = new_hoop_list;
      new_hoop_list->next = next_from_top;
      */

      hoop_list = new_hoop_list;
      idx = 0;

#ifdef VERBOSE_HOOP_EXPANSION
      puts("(Agent hoop has been expanded!)");
      fflush(stdout);
#endif
    }
  }
}

VALUE Flex_expand_heap_alloc_Name(Heap *hp, unsigned int Hoop_inc_magnitude) {

  unsigned int idx;
  HoopList *hoop_list;
  Name *hoop;

  idx = hp->last_alloc_idx;
  hoop_list = hp->last_alloc_list;

  while (1) {
    hoop = (Name *)(hoop_list->hoop);
    int size = hoop_list->size;

    while (idx < size) {

      if (IS_READYFORUSE(hoop[idx].basic.id)) {
        //	TOGGLE_HOOPFLAG_READYFORUSE(hoop[idx].basic.id);

        // hp->last_alloc_idx = idx;
        hp->last_alloc_idx = (idx - 1 + size) & (size - 1);

        hp->last_alloc_list = hoop_list;

        //		printf("%d\n", hp->last_alloc_idx); exit(1);
        //    printf("hit[%d]\n", idx);
        return (VALUE) & (hoop[idx]);
      }
      idx++;
    }

    // No nodes are available in this hoop.

    if (hoop_list->next != hp->last_alloc_list) {
      // There is another hoop.
      hoop_list = hoop_list->next;
      idx = 0;

    } else {

      // There are no other hoops. A new hoop should be created.

      //          v when come again here
      //    current    last_alloc
      // -->|......|-->|xxxxxx|-->
      //
      // ==>
      //             new current
      //               new        last_alloc
      // -->|......|-->|oooooo|-->|xxxxxx|--

#ifdef VERBOSE_HOOP_EXPANSION
      puts("(Name hoop is BEING expanded...)");
      fflush(stdout);
#endif

      HoopList *new_hoop_list;
      // unsigned int new_size_p2 = hoop_list->size * Hoop_inc_magnitude;
      unsigned int new_size_p2 =
          (hp->last_alloc_list->size) * Hoop_inc_magnitude;

      new_hoop_list = HoopList_new_forName(new_size_p2);

      HoopList *last_alloc = hoop_list->next;
      hoop_list->next = new_hoop_list;
      new_hoop_list->next = last_alloc;

      hoop_list = new_hoop_list;
      idx = 0;

#ifdef VERBOSE_HOOP_EXPANSION
      puts("(Name hoop has been BEING expanded)");
      fflush(stdout);
#endif
    }
  }
}

void sweep_AgentHeap(Heap *hp) {

  HoopList *hoop_list = hp->last_alloc_list;
  Agent *hoop;

  do {
    hoop = (Agent *)(hoop_list->hoop);
    for (int i = 0; i < hoop_list->size; i++) {

      if (!IS_FLAG_MARKED(hoop[i].basic.id)) {
        SET_HOOPFLAG_READYFORUSE(hoop[i].basic.id);
      } else {
        TOGGLE_FLAG_MARKED(hoop[i].basic.id);
      }
    }
    hoop_list = hoop_list->next;
  } while (hoop_list != hp->last_alloc_list);
}

void sweep_NameHeap(Heap *hp) {
  HoopList *hoop_list = hp->last_alloc_list;
  Name *hoop;

  do {
    hoop = (Name *)(hoop_list->hoop);
    for (int i = 0; i < hoop_list->size; i++) {

      if (!IS_FLAG_MARKED(hoop[i].basic.id)) {
        SET_HOOPFLAG_READYFORUSE(hoop[i].basic.id);
      } else {
        TOGGLE_FLAG_MARKED(hoop[i].basic.id);
      }
    }
    hoop_list = hoop_list->next;
  } while (hoop_list != hp->last_alloc_list);
}

#else
// v0.5.6 -------------------------------------
// Fixed size buffer
// --------------------------------------------

VALUE *MakeAgentHeap(int size) {
  int i;
  VALUE *heap;

  // Agent Heap
  heap = (VALUE *)malloc(sizeof(Agent) * size);
  if (heap == (VALUE *)NULL) {
    printf("[Heap]Malloc error\n");
    exit(-1);
  }
  for (i = 0; i < size; i++) {
    RESET_HEAPFLAG_READYFORUSE_AGENT(((Agent *)(heap))[i].basic.id);
  }

  return heap;
}

VALUE *MakeNameHeap(int size) {
  int i;
  VALUE *heap;

  // Name Heap
  heap = (VALUE *)malloc(sizeof(Name) * size);
  if (heap == (VALUE *)NULL) {
    printf("[Name]Malloc error\n");
    exit(-1);
  }
  for (i = 0; i < size; i++) {
    //    ((Name *)(heap))[i].basic.id = ID_NAME;
    RESET_HEAPFLAG_READYFORUSE_NAME(((Name *)(heap))[i].basic.id);
  }

  return heap;
}

VALUE Heap_alloc_Agent(Heap *hp) {

  int i, idx, hp_size;
  Agent *hp_heap;

  hp_size = hp->size;
  hp_heap = (Agent *)(hp->heap);

  idx = hp->lastAlloc - 1;

  for (i = 0; i < hp_size; i++) {
    if (!IS_READYFORUSE(hp_heap[idx].basic.id)) {
      idx++;
      if (idx >= hp_size) {
        idx -= hp_size;
      }
      continue;
    }
    //    TOGGLE_HEAPFLAG_READYFORUSE(hp_heap[idx].basic.id);

    hp->lastAlloc = idx;

    return (VALUE) & (hp_heap[idx]);
  }

  printf("\nCritical ERROR: All %d term cells have been consumed.\n", hp->size);
  printf("You should have more term cells with -c option.\n");
  exit(-1);
}

VALUE Heap_alloc_Name(Heap *hp) {

  int i, idx, hp_size;
  Name *hp_heap;

  hp_size = hp->size;
  hp_heap = (Name *)(hp->heap);

  idx = hp->lastAlloc;

  for (i = 0; i < hp_size; i++) {
    //    if (!IS_READYFORUSE(((Name *)hp->heap)[idx].basic.id)) {
    if (!IS_READYFORUSE(hp_heap[idx].basic.id)) {
      idx++;
      if (idx >= hp_size) {
        idx -= hp_size;
      }
      continue;
    }
    //    TOGGLE_HEAPFLAG_READYFORUSE(((Name *)hp->heap)[idx].basic.id);
    //    TOGGLE_HEAPFLAG_READYFORUSE(hp_heap[idx].basic.id);

    hp->lastAlloc = idx;

    //    return (VALUE)&(((Name *)hp->heap)[idx]);
    return (VALUE) & (hp_heap[idx]);
  }

  printf("\nCritical ERROR: All %d name cells have been consumed.\n", hp->size);
  printf("You should have more term cells with -c option.\n");
  exit(-1);
}

unsigned long Heap_GetNum_Usage_forName(Heap *hp) {
  int i;
  unsigned long total = 0;
  for (i = 0; i < hp->size; i++) {
    if (!IS_READYFORUSE(((Name *)hp->heap)[i].basic.id)) {
      total++;
    }
  }
  return total;
}
unsigned long Heap_GetNum_Usage_forAgent(Heap *hp) {
  int i;
  unsigned long total = 0;
  for (i = 0; i < hp->size; i++) {
    if (!IS_READYFORUSE(((Agent *)hp->heap)[i].basic.id)) {
      total++;
    }
  }
  return total;
}

void myfree(VALUE ptr) {

  //  TOGGLE_HEAPFLAG_READYFORUSE(BASIC(ptr)->id);
  SET_HEAPFLAG_READYFORUSE(BASIC(ptr)->id);
}

void myfree2(VALUE ptr, VALUE ptr2) {

  //  TOGGLE_HEAPFLAG_READYFORUSE(BASIC(ptr)->id);
  SET_HEAPFLAG_READYFORUSE(BASIC(ptr)->id);
  SET_HEAPFLAG_READYFORUSE(BASIC(ptr2)->id);
}

void sweep_AgentHeap(Heap *hp) {
  int i;
  for (i = 0; i < hp->size; i++) {
    if (!IS_FLAG_MARKED(((Agent *)hp->heap)[i].basic.id)) {
      SET_HEAPFLAG_READYFORUSE(((Agent *)hp->heap)[i].basic.id);
    } else {
      TOGGLE_FLAG_MARKED(((Agent *)hp->heap)[i].basic.id);
    }
  }
}

void sweep_NameHeap(Heap *hp) {
  int i;
  for (i = 0; i < hp->size; i++) {
    if (!IS_FLAG_MARKED(((Name *)hp->heap)[i].basic.id)) {
      SET_HEAPFLAG_READYFORUSE(((Name *)hp->heap)[i].basic.id);
    } else {
      TOGGLE_FLAG_MARKED(((Name *)hp->heap)[i].basic.id);
    }
  }
}

//---------------------------------------------

#endif

void puts_memory_usage(Heap *agent_heap, Heap *name_heap) {
  //    printf("Using a total of %lu agent nodes and %lu name nodes.\n\n",
  printf("Using %lu agent nodes and %lu name nodes.\n\n",
         Heap_GetNum_Usage_forAgent(agent_heap),
         Heap_GetNum_Usage_forName(name_heap));
}
