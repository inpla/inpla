#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "name_table.h"

static NameList *NameHashTable[NAME_HASHSIZE];  // HashTable for name strings

/*
  NameTable[] <-- hashtable
    NameTable[hash] <-- NameList (linear list)
*/


NameList *NameList_new() {
  NameList *alist;
  alist = malloc(sizeof(NameList));
  if (alist == NULL) {
    printf("Malloc error\n");
    exit(-1);
  }
  return alist;
}


// It should be called at first, and must be never called after that.
void NameTable_init() {
  int i;
  for (i=0; i<NAME_HASHSIZE; i++) {
    NameHashTable[i] = NULL;
  }
}

int getHash(char *key) 
{
  int len;
  int ret;
  
  // Make the hash number by addition among char nums of
  // the first, middle, the last letters of the key
  len = strlen(key);
  ret  = key[0];
  ret += key[len-1];
  ret += key[(len-1)/2];
  
  // Make the hash number as the modulo of the size of the Hash Table.
  return ret % NAME_HASHSIZE;
}







void NameTable_erase_id(char *key) {
  // Delete the entry for the key
  
  int hash;
  
  if (key == NULL) return;
  
  hash = getHash(key);
  
  if (NameHashTable[hash] == NULL) {
    // No entries

    // Nothing to do
    return;
  }


  // linear search
  NameList *at = NameHashTable[hash];
  while (at != NULL) {
    if (strcmp(at->name, key) == 0) {
      // already exists

      at->id = -1;
      return;
      
    }
    at = at->next;
  }
  
  return;  
}



int NameTable_get_id(char *key) {
  int hash;
  
  hash = getHash(key);
  
  if (NameHashTable[hash] == NULL) {
    return -1;
  }

  NameList *at = NameHashTable[hash];
  while (at != NULL) {
    if (strcmp(at->name, key) == 0) {
      // already exists
      return at->id;
    }
    
    at = at->next;
  }
  
  // There is no entry for the key
  return -1;
  
}


IDTYPE NameTable_get_set_id_with_IdTable_forAgent(char *key) {
  int hash;
  NameList *add;

  hash = getHash(key);
  
  if (NameHashTable[hash] == NULL) {
    
    add = NameList_new();
    add->name = key;
    add->id = IdTable_new_agentid();
    IdTable_set_name(add->id, add->name);
    add->next = NULL;
    NameHashTable[hash] = add;
    return (add->id);

  }
  
  NameList *at = NameHashTable[hash];
  while (at != NULL) {
    if (strcmp(at->name, key) == 0) {      
      return (at->id);      
    }
    at = at->next;
  }
  

  add = NameList_new();
  add->name = key;  
  add->id = IdTable_new_agentid();
  IdTable_set_name(add->id, add->name);
  
  add->next = NameHashTable[hash];
  NameHashTable[hash] = add;

  return (add->id);
}



void NameTable_set_id(char *key, IDTYPE id) {
  int hash;
  NameList *add;


  hash = getHash(key);
  
  if (NameHashTable[hash] == NULL) {

    add = NameList_new();
    add->name = key;
    add->id = id;
    add->next = NULL;
    NameHashTable[hash] = add;
    return;

  }
  
  NameList *at = NameHashTable[hash];
  while (at != NULL) {
    if (strcmp(at->name, key) == 0) {
      at->id = id;
      return;
      
    }
    at = at->next;
  }
  

  add = NameList_new();
  add->name = key;  
  add->id = id;
  
  add->next = NameHashTable[hash];
  NameHashTable[hash] = add;

  return;
}








// Whether the given 'term' has a node 'keynode'.
int term_has_keynode(VALUE keynode, VALUE term) {
  int i;

  if ((term == (VALUE)NULL) || (IS_FIXNUM(term))) return 0;

  //puts_term(term);
  //puts("");
  
  if (IS_NAMEID(BASIC(term)->id)) {
          
    if (term == keynode) {
      return 1;
    } else {
      if (NAME(term)->port == (VALUE)NULL) {
	return 0;
      } else {
	return term_has_keynode(keynode, NAME(term)->port);
      }
    }
      
  } else {
    // general term
    int arity;
    arity = IdTable_get_arity(AGENT(term)->basic.id);
    for (i=0; i < arity; i++) {
      if (term_has_keynode(keynode, AGENT(term)->port[i]) ) {
	return 1;
      }
    }
    return 0;
  }
}


int keynode_exists_in_another_term(VALUE keynode, VALUE *connected_from) {
  // It returns how times the keynode occurs in
  // terms connected from global names.
  // When there are such connected terms, 
  // one of these will be stored in the 'connected_from' as the result.
  int i, result=0;
  NameList *at;

  for (i=0; i<NAME_HASHSIZE; i++) {
    at = NameHashTable[i];
    while (at != NULL) {
      if (IS_GNAMEID(at->id)) {
	VALUE heap = IdTable_get_heap(at->id);
	if (heap != keynode)  {
	  if (term_has_keynode(keynode, heap)) {
	    result++;
	    if (connected_from != NULL) {
	      *connected_from = heap;
	    }
	    /*
	    PutIndirection=1;
	    puts_name(at->heap);
	    puts("");
	    PutIndirection=0;
	    */
	  }
	}
      }
      at = at->next;
    }
  }
  return result;
}




VALUE replace_keynode(VALUE keynode, VALUE term, VALUE heap) {
  // heap[term/keynode]
  
  if ((heap == (VALUE)NULL) || (IS_FIXNUM(heap))) {
    return heap;
  }

  if (IS_GNAMEID(BASIC(heap)->id)) {
    if (keynode == heap) {
      return term;
    }
  }
  
  if (IS_NAMEID(BASIC(heap)->id)) {
    if (NAME(heap)->port == (VALUE)NULL) {
      return heap;
    } else {
      NAME(heap)->port = replace_keynode(keynode, term, NAME(heap)->port);
      return heap;
    }
  }
      
  // general heap
  int i, arity;
  arity = IdTable_get_arity(AGENT(heap)->basic.id);
  for (i=0; i < arity; i++) {
    AGENT(heap)->port[i] = replace_keynode(keynode, term, AGENT(heap)->port[i]);
  }
  return heap;  
}



void global_replace_keynode_in_another_term(VALUE keynode, VALUE term) {
  // Replace keynode in Global environment with term.
  int i;
  NameList *at;

  for (i=0; i<NAME_HASHSIZE; i++) {
    at = NameHashTable[i];
    while (at != NULL) {
      if (IS_GNAMEID(at->id)) {
	VALUE heap = IdTable_get_heap(at->id);

	if (heap != keynode)  {
	  
	  if (term_has_keynode(keynode, heap)) {

	    // replaced <- heap[term/keynode]
	    VALUE replaced = replace_keynode(keynode, term, heap);
	    IdTable_set_heap(at->id, replaced);

	    //freeName(keynode); <-- this is called at the calling function.

	    return;
	  }
	}
      }
      at = at->next;
    }
  }
}




void NameTable_puts_all() {
  int i;
  NameList *at;
  int count=0;

  for (i=0; i<NAME_HASHSIZE; i++) {
    at = NameHashTable[i];
    while (at != NULL) {
      if (IS_GNAMEID(at->id)) {
	VALUE heap = IdTable_get_heap(at->id);
	if (IS_NAMEID(BASIC(heap)->id))  {
	  printf("%s ", IdTable_get_name(BASIC(heap)->id));
	  count++;
	}
      }
      at = at->next;
    }
  }
  if (count == 0) {
    printf("<NO-INTERFACE>\n");
    return;
  }

  printf("\n\nConnections:\n");
    
  for (i=0; i<NAME_HASHSIZE; i++) {
    at = NameHashTable[i];
    while (at != NULL) {
      if (IS_GNAMEID(at->id)) {
	VALUE heap = IdTable_get_heap(at->id);	
	if (IS_NAMEID(BASIC(heap)->id))  {
	  printf("%s ->", IdTable_get_name(BASIC(heap)->id));
	  puts_name_port0(heap);
	  printf("\n");
	}
      }
      at = at->next;
    }
  }
  puts("");
}


void NameTable_free_all() {
  int i;
  NameList *at;

  for (i=0; i<NAME_HASHSIZE; i++) {
    at = NameHashTable[i];
    while (at != NULL) {
      if (IS_GNAMEID(at->id)) {
	VALUE heap = IdTable_get_heap(at->id);	
	if (IS_NAMEID(BASIC(heap)->id))  {
	  flush_name_port0(heap);
	}
      }
      at = at->next;
    }
  }
}


int NameTable_check_if_term_has_gname(VALUE term) {
  int i;
  NameList *at;
  
  for (i=0; i<NAME_HASHSIZE; i++) {
    at = NameHashTable[i];
    while (at != NULL) {
      if (IS_GNAMEID(at->id)) {
	VALUE ptr = IdTable_get_heap(at->id);	
	
	while ((ptr != (VALUE)NULL) &&
	       (! IS_FIXNUM(ptr)) &&
	       (IS_NAMEID(BASIC(ptr)->id))) {

	  
	  if (term_has_keynode(ptr, term)) {
	      return 1;
	  }
	  
	  ptr = NAME(ptr)->port;
	  
	}
	
      }
      at = at->next;
    }
  }

  return 0;
}



/******************************************
 Mark and Sweep for error recovery
******************************************/
#ifndef THREAD
static VALUE CyclicNameHeap=(VALUE)NULL;

void markHeapRec(VALUE ptr) {
 loop:  
  if ((ptr == (VALUE)NULL) || (IS_FIXNUM(ptr))) {
    return;
  } else if (IS_NAMEID(BASIC(ptr)->id)) {
    if (ptr == CyclicNameHeap) return;

    SET_FLAG_MARKED(BASIC(ptr)->id);
    if (NAME(ptr)->port != (VALUE)NULL) {
      ptr = NAME(ptr)->port;
      goto loop;
    }
  } else {
    if (BASIC(ptr)->id == ID_CONS) {
      if (IS_FIXNUM(AGENT(ptr)->port[0])) {
	SET_FLAG_MARKED(BASIC(ptr)->id);
	ptr = AGENT(ptr)->port[1];
	goto loop;
      }
    }      

    int arity = IdTable_get_arity(BASIC(ptr)->id);
    SET_FLAG_MARKED(BASIC(ptr)->id);
    if (arity == 1) {
      ptr = AGENT(ptr)->port[0];
      goto loop;
    } else { // it also contains the case that arity = 0.
      int i;
      for(i=0; i<arity; i++) {
	markHeapRec(AGENT(ptr)->port[i]);
      }
    }
  }
}


void mark_name_port0(VALUE ptr) {
  if (ptr != (VALUE)NULL) {

    SET_FLAG_MARKED(BASIC(ptr)->id);
    if (NAME(ptr)->port != (VALUE)NULL) {
      CyclicNameHeap=ptr;
      markHeapRec(NAME(ptr)->port);
      CyclicNameHeap=(VALUE)NULL;
    }      
  }
}


void mark_allHash(void) {
  int i;
  NameList *at;

  for (i=0; i<NAME_HASHSIZE; i++) {
    at = NameHashTable[i];
    while (at != NULL) {
      if (IS_GNAMEID(at->id)) {
	VALUE heap = IdTable_get_heap(at->id);	

	if (IS_NAMEID(BASIC(heap)->id))  {
	  mark_name_port0(heap);
	}
      }
      at = at->next;
    }
  }
}
#endif
