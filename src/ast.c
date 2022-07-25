//----------------------------------------
// for AST
//----------------------------------------
//http://www.hpcs.cs.tsukuba.ac.jp/~msato/lecture-note/comp-lecture/tiny-c-note2.html

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"

#define MAX_SYMBOLS 256
typedef struct {
  char* sym[MAX_SYMBOLS];
  long val[MAX_SYMBOLS];
  int nth;
} SymbolTable;

static SymbolTable SymTable, ConstTable;


void SymTable_init(SymbolTable *table) {
  int i;
  table->nth = 0;
  for (i=0; i<MAX_SYMBOLS; i++) {
    table->sym[i] = NULL;
  }
}

char *recordSymbol(SymbolTable *table, char *name) {
  int i;
  char *result;

  for (i=0; i< table->nth; i++) {
    if (strcmp(table->sym[i], name) == 0) {

      // The `name' has existed already,
      // and table->sym[i] is used instead of that,
      // so starduped memory for the `name' should be freed here.
      // free(name);
      
      return table->sym[i];
    }
  }

  // inpla.l で strdup されているので、
  // ここでは stardup せずに、単に ポインタを格納するだけ。
  table->sym[table->nth]=name; 
  result = table->sym[table->nth];
  table->nth++;
  if (table->nth > MAX_SYMBOLS) {
    puts("ERROR: The SymbolTable in AST library is too small.");
    exit(-1);
  }

  return result;
}

int lookupEntry(SymbolTable *table, char *name) {
  int i;

  for (i=0; i< table->nth; i++) {
    if (strcmp(table->sym[i], name) == 0) {
      return i;
    }
  }
  return -1;
}

int ast_getRecordedVal(int entry) {
  return ConstTable.val[entry];
}


void recordVal(SymbolTable *table, char *name, long val) {
  int i;
  
  for (i=0; i< table->nth; i++) {
    if (strcmp(table->sym[i], name) == 0) {

      // The `name' has existed already,
      // and table->sym[i] is used instead of that,
      // so starduped memory for the `name' should be freed here.
      free(name);
      
      table->val[i] = val;
      return;
    }
  }
  //table->sym[table->nth]=strdup(name);
  table->sym[table->nth]=name;
  table->val[table->nth]=val;
  table->nth++;
  if (table->nth > MAX_SYMBOLS) {
    puts("ERROR: The SymbolTable in AST library is too small.");
    exit(-1);
  }

}


static Ast *AstHeap;
static int NextPtr_AstHeap;
#define MAX_AST_HEAP 10000

void ast_heapInit(void) {
  
  NextPtr_AstHeap = 0;
  AstHeap = malloc(sizeof(Ast)*MAX_AST_HEAP);
  if (AstHeap == NULL) {
    printf("Malloc error [AstHeap]\n");
    exit(-1);
  }

  SymTable_init(&SymTable);
  SymTable_init(&ConstTable);
}

void ast_heapReInit(void) {
  NextPtr_AstHeap = 0;
}  

static Ast *ast_myalloc(void) {
  Ast *ptr;
  
  if (NextPtr_AstHeap < MAX_AST_HEAP) {
    ptr=&AstHeap[NextPtr_AstHeap];
    NextPtr_AstHeap++;
  } else {
    printf("[Error] All memory for AST was run out.\n");
    exit(-1);
  }

  return ptr;
}


Ast *ast_makeSymbol(char *name) {
  Ast *ptr;
  ptr = ast_myalloc();
  ptr->id = AST_SYM;
  ptr->sym = recordSymbol(&SymTable, name);
  return ptr;
}

Ast *ast_makeInt(long num) {
  Ast *ptr;
  ptr = ast_myalloc();
  ptr->id = AST_INT;
  ptr->longval = num;
  return ptr;
}

int ast_recordConst(char *name, int val) {
  if (lookupEntry(&ConstTable, name) == -1) {
    recordVal(&ConstTable, name, val);
    return 1;
  } else {
    return 0;
  }
}



Ast *ast_makeAST(AST_ID id, Ast *left, Ast *right) {
  Ast *ptr;
  if ((id == AST_AGENT) && (right == NULL)) {
    int entry = lookupEntry(&ConstTable, left->sym);
    if (entry != -1) {
      
      ptr = ast_myalloc();
      ptr->id = AST_INT;
      ptr->longval = ConstTable.val[entry];
      return ptr;
    }
  }
  
  ptr = ast_myalloc();
  ptr->id = id;
  ptr->right = right;
  ptr->left = left;
  return ptr;
}

int count_elem(Ast *p) {
  int count=0;
  while (p!=NULL) {
    p = ast_getTail(p);
    count++;
  }
  return count;
}

Ast *ast_makeTuple(Ast *tuple) {
    Ast *ptr;
    ptr = ast_myalloc();
    ptr->id = AST_TUPLE;
    ptr->right = tuple;
    ptr->intval = count_elem(tuple);
    return ptr;
}

Ast *ast_paramToCons(Ast *ast) { 
  // Suppose that ast has the following form:
  //   LIST(a, LIST(b, NULL)).
  // This function makes it an agent form like:
  //   AST_OPCONS(NULL, List(a, AST_OPCONS(NULL, List(b, NIL())))

  if (ast == NULL) {
    return ast_makeAST(AST_NIL, NULL, NULL);
  }

  Ast *head = ast->left;
  Ast *tail = ast->right;
  Ast *ret = ast_makeAST(AST_OPCONS, NULL,
			 ast_makeList2(head, ast_paramToCons(tail)));
  return ret;
  
}



Ast *ast_addLast(Ast *l, Ast *p)
{
    Ast *q;

    if(l == NULL) return ast_makeAST(AST_LIST,p,NULL);
    q = l;
    while(q->right != NULL) q = q->right;
    q->right = ast_makeAST(AST_LIST,p,NULL);
    return l;
}

Ast *ast_getNth(Ast *p,int nth)
{
    if(p->id != AST_LIST){
	fprintf(stderr,"bad access to list\n");
	exit(1);
    }
    if(nth > 0) return(ast_getNth(p->right,nth-1));
    else return p->left;
}

Ast *ast_getTail(Ast *p)
{
    if(p->id != AST_LIST){
	fprintf(stderr,"bad access to list\n");
	exit(1);
    }
    else return p->right;
}

void ast_puts(Ast *p) {
  static char *string_AstID[] = {
    // basic
    "SYM", "NAME", "INTNAME", "AGENT",
    "CNCT", "CNCT_TRO_INT", "CNCT_TRO_CONS", "CNCT_TRO",
    "RULE", "BODY", "IF", "THEN_ELSE", 

    // LIST
    "LIST", 

    // annotation
    "(*L)", "(*R)",

    // extension
    "TUPLE", 
    "INT", "LD", "ADD", "SUB", "MUL", "DIV", "MOD", 
    "LT", "LE",  "EQ", "NE", "UNM", "AND", "OR", "NOT",

    
    "CONS", "NIL", 
    "RAND", "SRAND", 
    "PERCENT",
    
    // default
    "UNDEFINED",
  };

  if (p==NULL) {printf("NULL"); return;}

  switch(p->id) {
  case AST_INT:
    printf("int %d", p->intval);
    break;
  case AST_SYM:
    printf("%s", p->sym);
    break;
  case AST_TUPLE:
    printf("TUPLE(%d)(", p->intval);
    ast_puts(p->right);
    printf(")");
    break;
  case AST_NIL:
    printf("NIL");
    break;
  case AST_ANNOTATION_L:
  case AST_ANNOTATION_R:
    printf("%s", string_AstID[p->id]);
    ast_puts(p->left);
    break;
  default:
    printf("%s(", string_AstID[p->id]);
    ast_puts(p->left);
    printf(",");
    ast_puts(p->right);
    printf(")");

  }
}


Ast *ast_unfoldABR(Ast *left_params, char *sym, Ast *paramlist) {
  // input:
  // left_params << (AST_AGENT, sym, paramlist)

  // output:
  // p1,p2,...,pn << (AST_AGENT, sym, params @ [param])
  // ==> (AST_CNCT left right)
  // where left = (AST_AGENT sym, p1,p2,...,pn,params)
  //       right = (AST_NAME param)

  if (!strcmp(sym, "Merger")) {
    // left << Merger(paramlist)  ==> Merger(left) ~ (paramlist)
    Ast *agent_left = ast_makeAST(AST_AGENT, ast_makeSymbol("Merger"),
				  left_params);
    Ast *agent_right = ast_makeTuple(paramlist);
    Ast *cnct = ast_makeAST(AST_CNCT, agent_left, agent_right);
    return cnct;    
  }

  
  if (!strcmp(sym, "Append")) {
    // paramlist: [a,b] => [b,a]
    if (paramlist->right != NULL) {
      Ast *tmp = paramlist->left;                // tmp for a
      paramlist->left = paramlist->right->left;  // a := b
      paramlist->right->left = tmp;              // b := a
    }
  }

  
  //ast_puts(left);puts("");
  //ast_puts(paramlist);puts("");

  Ast *params, *param, *at;

  // paramlist: (AST_LIST elem next)
  if (paramlist->right == NULL) {
    // [x] => [], x
    param = paramlist->left;
    params = NULL;
  } else {
    params = param = NULL;
    
    // params@[param] => params, param
    at = paramlist;    
    while (at->right != NULL) {
      if (at->right->right == NULL) {
	param = at->right->left; // compoment
	at->right = NULL;        // break the list chain
	params = paramlist;      // params is the list whose last is just broken
	break;
      }
      at = at->right;
    }
  }

  //  ast_puts(params);puts("");
  //  ast_puts(param);puts("");


  // make left_params as left_params @ params
  at = left_params;
  if (at == NULL) {
    at = params;
  } else {
    while (at != NULL) {
      if (at->right == NULL) {
	at->right = params;
	break;
      }
      at = at->right;
    }
  }
  //  ast_puts(left);puts("");

    
  Ast *agent_left = ast_makeAST(AST_AGENT, ast_makeSymbol(sym), left_params);
  Ast *agent_right = param;
  Ast *cnct = ast_makeAST(AST_CNCT, agent_left, agent_right);
  
  //ast_puts(agent_left);puts("");
  //ast_puts(agent_right);puts("");

  //exit(1);
  return cnct;
  
}




Ast *ast_remove_tuple1(Ast *p) {

  if (p==NULL) return p;

  switch(p->id) {
  case AST_INT:
    return p;
    break;
  case AST_SYM:
    return p;
    break;
  case AST_TUPLE:
    if (p->intval == 1) {
      // (AST_TUPLE NULL (LIST left right))
      p = p->right->left;
    }
    p->right = ast_remove_tuple1(p->right);
    return p;
    break;
  case AST_NIL:
    return p;
    break;
  case AST_ANNOTATION_L:
  case AST_ANNOTATION_R:
    p->left = ast_remove_tuple1(p->left);
    return p;
    break;
  default:
    p->left = ast_remove_tuple1(p->left);
    p->right = ast_remove_tuple1(p->right);
    return p;

  }
}
