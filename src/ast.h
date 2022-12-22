// http://www.hpcs.cs.tsukuba.ac.jp/~msato/lecture-note/comp-lecture/tiny-c/AST.h

#ifndef _AST_
#define _AST_

typedef enum {
  AST_SYM=0, AST_NAME, AST_INTVAR, AST_AGENT,
  AST_CNCT, AST_CNCT_TCO_INTVAR, AST_CNCT_TCO_CONS, AST_CNCT_TCO,
  AST_RULE, AST_BODY, AST_IF, AST_THEN_ELSE,
  
  // this is for ASTLIST
  AST_LIST,

  // annotation
  AST_ANNOTATION_L, AST_ANNOTATION_R, 

  // builtin tuple
  AST_TUPLE, 

  // operation
  AST_INT, AST_LD, AST_PLUS, AST_SUB, AST_MUL, AST_DIV, AST_MOD,
  AST_LT, AST_LE, AST_EQ, AST_NE, AST_UNM, AST_AND, AST_OR, AST_NOT, 

  // for built-in lists
  AST_OPCONS, AST_NIL,

  // for built-in agents  
  AST_RAND, AST_SRAND,

  // for PERCENT
  AST_PERCENT,
} AST_ID;


typedef struct abstract_syntax_tree {
  AST_ID id;
  int intval;
  long longval;
  char *sym;
  struct abstract_syntax_tree *left,*right;
} Ast;

void ast_heapInit(void);
void ast_heapReInit(void);
Ast *ast_makeSymbol(char *name);
Ast *ast_makeInt(long num);
Ast *ast_makeAST(AST_ID id, Ast *left, Ast *right);
Ast *ast_makeTuple(Ast *tuple);
Ast *ast_addLast(Ast *l, Ast *p);
Ast *ast_getNth(Ast *p,int nth);
Ast *ast_getTail(Ast *p);
void ast_puts(Ast *p);
Ast *ast_paramToCons(Ast *ast);
int ast_recordConst(char *name, int val);
Ast *ast_remove_tuple1(Ast *p);
Ast *ast_unfoldABR(Ast *left_params, char *sym, Ast *paramlist);
int ast_getRecordedVal(int entry);

#define ast_makeCons(x1,x2) ast_makeAST(AST_LIST,x1,x2)
#define ast_makeList1(x1) ast_makeAST(AST_LIST,x1,NULL)
#define ast_makeList2(x1,x2) ast_makeAST(AST_LIST,x1,ast_makeAST(AST_LIST,x2,NULL))
#define ast_makeList3(x1,x2,x3) ast_makeAST(AST_LIST,x1,ast_makeAST(AST_LIST,x2,ast_makeAST(AST_LIST,x3,NULL)))
#define getFirst(p) getNth(p,0)


#endif
