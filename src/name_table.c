#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "name_table.h"

NameList *NameList_new() {
  NameList *alist;
  alist = malloc(sizeof(NameList));
  if (alist == NULL) {
    printf("Malloc error\n");
    exit(-1);
  }
  return alist;
}


// It should be called at first, and never called after that.
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
  
  // 0文字目、最後の文字、真中の文字の数値を加算し
  len = strlen(key);
  ret  = key[0];
  ret += key[len-1];
  ret += key[(len-1)/2];
  
  // ハッシュテーブルのサイズ（山の数）で modulo する
  return ret % NAME_HASHSIZE;
}





void NameTable_set_heap_id(char *key, VALUE heap, IDTYPE id) {
  int hash;
  NameList *add;
  hash = getHash(key);
    
  if (NameHashTable[hash] == NULL) {  // もしハッシュテーブルが空ならば
    add = NameList_new();             // データノードを作成

    add->name = key;
    add->id = id;
    IdTable_set_name(id, key);
    add->heap = heap;
    add->next = NULL;
    
    NameHashTable[hash] = add;        /* 単にセット */
  }

  
  /* 線形探査 */
  NameList *at = NameHashTable[hash];  /* 先頭をセット */
  while (at != NULL) {
    if(strcmp( at->name, key ) == 0) {  /* すでにあれば... */	
      at->id = id;
      IdTable_set_name(at->id, key);
      at->heap = heap;
      return;

    }
    at = at->next;  /* 次のチェーンを辿る */
  }

  
  /* key がなかったら、 先頭に追加 */
  add = NameList_new();

  add->name = key;  
  add->id = id;
  IdTable_set_name(add->id, key);
  add->heap = heap;

  add->next = NameHashTable[hash];  // 以前の先頭を自分の次にする
  NameHashTable[hash] = add;        // add を先頭とする
  
  return;
}




// NameHashTable から key のエントリーを削除
void NameTable_erase(char *key) {
  int hash;
  //int heap;
  //NameList *add;
  
  if (key == NULL) return;
  
  hash = getHash(key);
  
  if (NameHashTable[hash] == NULL) {  // ハッシュテーブルが空ならば何もしない
    return;
  }

  /* 線形探査 */
  NameList *at = NameHashTable[hash];  /* 先頭をセット */
  while (at != NULL) {
    if (strcmp(at->name, key) == 0) {  /* すでにあれば... */	
      at->heap = (VALUE)NULL;
      at->id = -1;                  // 登録削除したら ID を -1 にする
                                    // これを削ると、10%の速度低下。なぜ？

      return;
      
    }
    at = at->next;  /* 次のチェーンを辿る */
  }
  
  return;  
}



VALUE NameTable_get_heap(char *key) {
  int hash;
  //int heap;
  //NameList *add;
  hash = getHash(key);
  
  if (NameHashTable[hash] == NULL) {
    // ハッシュテーブルが空
    return (VALUE)NULL;
  }

  // 線形探査
  NameList *at = NameHashTable[hash];  // 先頭をセット
  while (at != NULL) {
    if (strcmp( at->name, key ) == 0) {  // すでにあれば
      
      if (at->heap != (VALUE)NULL) {
	// NULLP でなければ、既に存在している変数 
	return at->heap;
	
      } else {
	return (VALUE)NULL;
	
      }
    }
    at = at->next;  // 次のチェーンを辿る
  }
  
  // key がなかった
  return (VALUE)NULL;
  
}


IDTYPE NameTable_get_set_id(char *key) {
  int hash;
  NameList *add;


  hash = getHash(key);
  
  if (NameHashTable[hash] == NULL) {
    // ハッシュテーブルが空
    add = NameList_new();             // データノードを作成
    add->name = key;
    add->id = IdTable_new_agentid();
    IdTable_set_name(add->id, add->name);
    add->heap = (VALUE)NULL;
    add->next = NULL;
    NameHashTable[hash] = add;        // 単にセット
    return (add->id);

  }
  
  // 線形探査
  NameList *at = NameHashTable[hash];  // 先頭をセット
  while (at != NULL) {
    if (strcmp(at->name, key) == 0) {  // すでにあれば
      return (at->id);
      
    }
    at = at->next;  // 次のチェーンを辿る
  }
  
  // key がなかったら→ 先頭に追加
  add = NameList_new();
  add->name = key;  
  add->id = IdTable_new_agentid();
  IdTable_set_name(add->id, add->name);
  add->heap = (VALUE)NULL;
  add->next = NameHashTable[hash];  // 以前の先頭を自分の次にする
  NameHashTable[hash] = add;        // 先頭に追加

  return (add->id);
}



// Whether the given 'term' has a name node 'keynode'.
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
  // It returns how many occurs in terms connected from global names.
  // Also, the one of the terms is stored in the 'connected_from'.
  int i, result=0;
  NameList *at;

  for (i=0; i<NAME_HASHSIZE; i++) {
    at = NameHashTable[i];
    while (at != NULL) {
      if (at->heap != (VALUE)NULL) {
	if (at->heap != keynode)  {
	  if (term_has_keynode(keynode, at->heap)) {
	    result++;
	    if (connected_from != NULL) {
	      *connected_from = at->heap;
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
      if (at->heap != (VALUE)NULL) {
	if (at->heap != keynode)  {
	  
	  if (term_has_keynode(keynode, at->heap)) {

	    VALUE replaced = replace_keynode(keynode, term, at->heap);
	    at->heap = replaced;
	    
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
      if (at->heap != (VALUE)NULL) {
	if (IS_NAMEID(BASIC(at->heap)->id))  {
	  printf("%s ", IdTable_get_name(BASIC(at->heap)->id));
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
      if (at->heap != (VALUE)NULL) {
	if (IS_NAMEID(BASIC(at->heap)->id))  {
	  printf("%s ->", IdTable_get_name(BASIC(at->heap)->id));
	  puts_name_port0(at->heap);
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
      if (at->heap != (VALUE)NULL) {
	if (IS_NAMEID(BASIC(at->heap)->id))  {
	  flush_name_port0(at->heap);
	}
      }
      at = at->next;
    }
  }
}


int NameTable_ckech_if_term_has_gname(VALUE term) {
  int i;
  NameList *at;
  VALUE ptr;
  
  for (i=0; i<NAME_HASHSIZE; i++) {
    at = NameHashTable[i];
    while (at != NULL) {
      if (at->heap != (VALUE)NULL) {
	ptr = at->heap;
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

