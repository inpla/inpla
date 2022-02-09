#ifndef _NAME_TABLE_
#define _NAME_TABLE_

#include "mytype.h"
#include "id_table.h"
#include "inpla.h"

/**************************************
 NAME TABLE
**************************************/
/*
  NameTable[] <-- hashtable
    NameTable[hash] <-- NameList(linear list)
*/


typedef struct NameList {
  char *name;          // KEY
  int id;              // -1: no entry

  struct NameList *next;
} NameList;

#define NAME_HASHSIZE  127
//static NameList *NameHashTable[NAME_HASHSIZE];  // HashTable for name strings

// It should be called at first, and never called after that.
void NameTable_init();


void NameTable_set_heap_id(char *key, VALUE heap, IDTYPE id);


// Set id at key entry to -1
void NameTable_erase_id(char *key);


int NameTable_get_id(char *key);
void NameTable_set_id(char *key, IDTYPE id);


IDTYPE NameTable_get_set_id_with_IdTable_forAgent(char *key);


void NameTable_puts_all();
void NameTable_free_all();

int NameTable_check_if_term_has_gname(VALUE term);

int term_has_keynode(VALUE keynode, VALUE term);
int keynode_exists_in_another_term(VALUE keynode, VALUE *connected_from);
void global_replace_keynode_in_another_term(VALUE keynode, VALUE term);


#ifndef THREAD
//  Mark and Sweep for error recovery

/* 30bit目が 1 ならば、Garbage Collection の Mark&Sweep にて、
   Mark されたことを意味する*/
#define FLAG_MARKED 0x01 << 30
#define IS_FLAG_MARKED(a) ((a) & FLAG_MARKED)
#define SET_FLAG_MARKED(a) ((a) = ((a) | FLAG_MARKED))
#define TOGGLE_FLAG_MARKED(a) ((a) = ((a) ^ FLAG_MARKED))

void mark_allHash(void);
#endif


#endif
