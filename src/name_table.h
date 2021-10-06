#ifndef _NAME_TABLE_
#define _NAME_TABLE_

#include "mytype.h"
#include "id_table.h"


/**************************************
 NAME TABLE
**************************************/
/*
  NameTable[] <-- hashtable
    NameTable[hash] <-- NameList(linear list)
*/


typedef struct NameList {
  char *name;             // KEY
  IDTYPE id;

  // `heap' stores a heap only of a global name,
  // that is, is kept having NULL for other nodes, such as agents.
  VALUE heap;
  
  struct NameList *next;
} NameList;

#define NAME_HASHSIZE  127
static NameList *NameHashTable[NAME_HASHSIZE];  // HashTable for name strings

// It should be called at first, and never called after that.
void NameTable_init();


void NameTable_set_heap_id(char *key, VALUE heap, IDTYPE id);


// Erace key entry from NameHashTable
void NameTable_erase(char *key);


VALUE NameTable_get_heap(char *key);
IDTYPE NameTable_get_set_id(char *key);

void NameTable_puts_all();
void NameTable_free_all();

int NameTable_ckech_if_term_has_gname(VALUE term);

int term_has_keynode(VALUE keynode, VALUE term);
int keynode_exists_in_another_term(VALUE keynode, VALUE *connected_from);
void global_replace_keynode_in_another_term(VALUE keynode, VALUE term);


#endif
