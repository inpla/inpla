%{
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sched.h>

#include "timer.h" //#include <time.h>
#include "linenoise/linenoise.h"
  
#include "ast.h"
#include "id_table.h"
#include "name_table.h"
#include "name_table.h"
#include "mytype.h"
#include "inpla.h"




  
// Configuration  ---------------------------------------------------
#define COUNT_INTERACTION  // Count interaction.
#define EXPANDABLE_HEAP    // Expandable heaps for agents and names
#define OPTIMISE_IMCODE    // Optimise the intermediate codes

  
//#define VERBOSE_NODE_USE  // Put memory usage of agents and names.
//#define VERBOSE_HOOP_EXPANSION  // Put messages when hoops are expanded.
//#define VERBOSE_EQSTACK_EXPANSION  // Put messages when Eqstacks are expanded.


// ----------------------------------------------
  
//#define DEBUG
  
// For experiments of the tail recursion optimisation.
//#define COUNT_CNCT    // count of execution of JMP_CNCT
//#define COUNT_MKAGENT // count of execution fo mkagent


#define VERSION "0.7.2-1"
#define BUILT_DATE  "12 Feb. 2022"  
// ------------------------------------------------------------------





  
  
// For threads  ---------------------------------
int MaxThreadsNum=1;

#ifdef THREAD
#include <pthread.h>
extern int pthread_setconcurrency(int concurrency); 

int SleepingThreadsNum=0;

// for cas spinlock
#include "cas_spinlock.h"

#endif

// ----------------------------------------------
// For parsing
 
int makeRule(Ast *ast);
void freeAgentRec(VALUE ptr);

//static inline void freeName(VALUE ptr);
void freeName(VALUE ptr);

//static inline void freeAgent(VALUE ptr);
void freeAgent(VALUE ptr);

void puts_names_ast(Ast *ast);
void free_names_ast(Ast *ast);
void puts_name_port0_nat(char *sym);
void puts_term(VALUE ptr);
void puts_aplist(EQList *at);

int exec(Ast *st);
int destroy(void);

 
//#define YYDEBUG 1
extern FILE *yyin;
extern int yylex();
int yyerror();
#define YY_NO_INPUT
extern int yylineno;

// For error message when nested source files are specified.
#define MY_YYLINENO 
#ifdef MY_YYLINENO
 typedef struct InfoLinenoType_tag {
   char *fname;
   int yylineno;
   struct InfoLinenoType_tag *next;
 } InfoLinenoType;
static InfoLinenoType *InfoLineno;

#define InfoLineno_Init() InfoLineno = NULL;

void InfoLineno_Push(char *fname, int lineno) {
  InfoLinenoType *aInfo;
  aInfo = (InfoLinenoType *)malloc(sizeof(InfoLinenoType));
  if (aInfo == NULL) {
    printf("[InfoLineno]Malloc error\n");
    exit(-1);
  }
  aInfo->next = InfoLineno;
  aInfo->yylineno = lineno+1;
  aInfo->fname = strdup(fname);

  InfoLineno = aInfo;
}

void InfoLineno_Free() {
  InfoLinenoType *aInfo;
  free(InfoLineno->fname);
  aInfo = InfoLineno;
  InfoLineno = InfoLineno->next;
  free(aInfo);
}

void InfoLineno_AllDestroy() {
  //  InfoLinenoType *aInfo;
  while (InfoLineno != NULL) {
    InfoLineno_Free();
  }
}

#endif


extern void pushFP(FILE *fp);
extern int popFP();


// Messages from yyerror will be stored here.
// This works to prevent puting the message. 
static char *Errormsg = NULL;


%}
%union{
  int intval;
  char *chval;
  Ast *ast;
}

%token <chval> NAME AGENT
%token <intval> INT_LITERAL
%token <chval> STRING_LITERAL
%token LP RP LC RC LB RB COMMA CROSS DELIMITER ABR
%token COLON
%token TO CNCT

%token ANNOTATE_L ANNOTATE_R

%token PIPE
%token NOT AND OR LD EQUAL NE GT GE LT LE
%token ADD SUB MUL DIV MOD INT LET IN END IF THEN ELSE ANY WHERE RAND DEF
%token INTERFACE IFCE PRNAT FREE EXIT
%token END_OF_FILE USE

%type <ast> body astterm astterm_item nameterm agentterm astparam astparams
val_declare
rule 
ap aplist
stm stmlist_nondelimiter
stmlist 
expr additive_expr equational_expr logical_expr relational_expr unary_expr
multiplicative_expr primary_expr agent_tuple agent_list agent_cons
bodyguard bd_else bd_elif bd_compound
if_sentence if_compound
name_params
 //body 

%nonassoc REDUCE
%nonassoc RP

%right COLON
 //%right LD
 //%right EQ
 //%left NE GE GT LT
 //%left ADD SUB
 //%left MULT DIV

%%
s     
: error DELIMITER { 
  yyclearin;
  yyerrok; 
  puts(Errormsg);
  free(Errormsg);
  ast_heapReInit();
  if (yyin == stdin) yylineno=0;
  //  YYACCEPT;
  YYABORT;
}
| DELIMITER { 
  if (yyin == stdin) yylineno=0;
  YYACCEPT;
}
| body DELIMITER
{
  exec($1); // $1 is a list such as [stmlist, aplist]
  ast_heapReInit(); 
  if (yyin == stdin) yylineno=0;
  YYACCEPT;
}
| rule DELIMITER { 
  if (makeRule($1)) {
    if (yyin == stdin) yylineno=0;
    YYACCEPT;
  } else {
    if (yyin == stdin) yylineno=0;
    YYABORT;
  }
}
| command {
  if (yyin == stdin) yylineno=0;
  YYACCEPT;
}
;



// body is a list such as [stmlist, aplist] 
// ==> changed into (AST_BODY stmlist aplist)
body
: aplist { $$ = ast_makeAST(AST_BODY, NULL, $1); }
| aplist WHERE stmlist_nondelimiter { $$ = ast_makeAST(AST_BODY, $3, $1);}
| aplist WHERE  { $$ = ast_makeAST(AST_BODY, NULL, $1);}
| LET stmlist IN aplist END { $$ = ast_makeAST(AST_BODY, $2, $4);}
| LET stmlist DELIMITER IN aplist END { $$ = ast_makeAST(AST_BODY, $2, $5);}
| LET  IN aplist END { $$ = ast_makeAST(AST_BODY, NULL, $3);}
| LC stmlist RC  aplist { $$ = ast_makeAST(AST_BODY, $2, $4);}
| LC stmlist DELIMITER RC aplist { $$ = ast_makeAST(AST_BODY, $2, $5);}
;

// rule is changed as follows:
//    (ASTRULE (AST_CNCT agentL agentR)
//      <if-sentence>)
//
//      WHERE
//      <if-sentence> ::= (AST_IF guard (AST_BRANCH <then> <else>))
//                      | <body>
//                      | NULL
//      <then> ::= <if-sentence>
//      <else> ::= <if-sentence>


rule
: astterm CROSS astterm TO 
{ $$ = ast_makeAST(AST_RULE, ast_makeAST(AST_CNCT, $1, $3),
                 	     NULL); }

| astterm CROSS astterm TO body
{ $$ = ast_makeAST(AST_RULE, ast_makeAST(AST_CNCT, $1, $3), 
		             $5); }


| astterm CROSS astterm TO if_sentence
{ $$ = ast_makeAST(AST_RULE, ast_makeAST(AST_CNCT, $1, $3),
                 	     $5); } 


| astterm CROSS astterm bodyguard
{ $$ = ast_makeAST(AST_RULE, ast_makeAST(AST_CNCT, $1, $3),
		   $4); }
;


name_params
: NAME
{ $$ = ast_makeList1(ast_makeSymbol($1)); }
| name_params NAME 
{ $$ = ast_addLast($1, ast_makeSymbol($2)); }
;

command:
| FREE name_params DELIMITER
{ 
  free_names_ast($2);
}
| FREE DELIMITER
| FREE IFCE DELIMITER
{
  NameTable_free_all();
}
| FREE INTERFACE DELIMITER
{
  NameTable_free_all();
}
| name_params DELIMITER
{ 
  puts_names_ast($1);
}

| PRNAT NAME DELIMITER
{ 
  puts_name_port0_nat($2); 
}
| INTERFACE DELIMITER
{ 
  NameTable_puts_all(); 
}
| IFCE DELIMITER
{ 
  NameTable_puts_all(); 
}
| EXIT DELIMITER {destroy(); exit(0);}
| USE STRING_LITERAL DELIMITER {
  // http://flex.sourceforge.net/manual/Multiple-Input-Buffers.html
  yyin = fopen($2, "r");
  if (!yyin) {
    printf("Error: The file '%s' does not exist.\n", $2);
    free($2);
    yyin = stdin;

  } else {
#ifdef MY_YYLINENO
    InfoLineno_Push($2, yylineno+1);
    yylineno = 0;
#endif  

    pushFP(yyin);
  }
}
| error END_OF_FILE {}
| END_OF_FILE {
  if (!popFP()) {
    destroy(); exit(-1);
  }
#ifdef MY_YYLINENO
  yylineno = InfoLineno->yylineno;
  InfoLineno_Free();
  destroy();
#endif  


}
| DEF AGENT LD INT_LITERAL DELIMITER {
  int entry=ast_recordConst($2,$4);

  if (!entry) {
    printf("`%s' has been already bound to a value '%d' as immutable.\n\n",
	   $2, ast_getRecordedVal(entry));
    fflush(stdout);
  }
 }
;


bodyguard
: PIPE expr TO bd_compound bd_elif
{ $$ = ast_makeAST(AST_IF, $2, ast_makeAST(AST_THEN_ELSE, $4, $5));}
;

bd_compound
: body
| bodyguard
;

bd_elif
: bd_else
| PIPE expr TO bd_compound bd_elif
{ $$ = ast_makeAST(AST_IF, $2, ast_makeAST(AST_THEN_ELSE, $4, $5));}
;

bd_else
: PIPE ANY TO bd_compound
{ $$ = $4; }
;



// if_sentence
if_sentence
: IF expr THEN if_compound ELSE if_compound
{ $$ = ast_makeAST(AST_IF, $2, ast_makeAST(AST_THEN_ELSE, $4, $6));}
;

if_compound
: if_sentence
| body
;



// AST -----------------
astterm
: LP ANNOTATE_L RP astterm_item
{ $$=ast_makeAST(AST_ANNOTATION_L, $4, NULL); }
| LP ANNOTATE_R RP astterm_item
{ $$=ast_makeAST(AST_ANNOTATION_R, $4, NULL); }
//| astterm_item COLON astterm_item
| astterm_item COLON astterm   // h:t
{$$ = ast_makeAST(AST_OPCONS, NULL, ast_makeList2($1, $3)); }
| astterm_item
;


astterm_item
      : agentterm
      | agent_tuple
      | agent_list
      | agent_cons
      | val_declare
      | expr %prec REDUCE
;

val_declare
: INT NAME { $$ = ast_makeAST(AST_INTVAR, ast_makeSymbol($2), NULL); }
;

agent_cons
: LB astterm PIPE astterm RB
{ $$ = ast_makeAST(AST_OPCONS, NULL, ast_makeList2($2, $4)); }
;

agent_list
: LB RB { $$ = ast_makeAST(AST_NIL, NULL, NULL); }
| LB astparams RB { $$ = ast_paramToCons($2); }
;

agent_tuple
: astparam { $$ = ast_makeTuple($1);}
;

nameterm
: NAME {$$=ast_makeAST(AST_NAME, ast_makeSymbol($1), NULL);}

agentterm
: AGENT astparam
{ $$=ast_makeAST(AST_AGENT, ast_makeSymbol($1), $2); }
| NAME astparam
{ $$=ast_makeAST(AST_AGENT, ast_makeSymbol($1), $2); }
;


astparam
: LP RP { $$ = NULL; }
| LP astparams RP { $$ = $2; }
;

astparams
: astterm { $$ = ast_makeList1($1); }
| astparams COMMA astterm { $$ = ast_addLast($1, $3); }
;

ap
: astterm CNCT astterm { $$ = ast_makeAST(AST_CNCT, $1, $3); }
//
| astparams ABR AGENT LP astparams RP
{ $$ = ast_unfoldABR($1, $3, $5); }
//
| astparams ABR NAME LP astparams RP
{ $$ = ast_unfoldABR($1, $3, $5); }
;



aplist
: ap { $$ = ast_makeList1($1); }
| aplist COMMA ap { $$ = ast_addLast($1, $3); }
;

stm
: nameterm LD expr { $$ = ast_makeAST(AST_LD, $1, $3); }
 
stmlist
: stm { $$ = ast_makeList1($1); }
| stmlist DELIMITER stm { $$ = ast_addLast($1, $3); }

stmlist_nondelimiter
: stm { $$ = ast_makeList1($1); }
| stmlist_nondelimiter stm { $$ = ast_addLast($1, $2); }


expr
: equational_expr
;

equational_expr
: logical_expr
| equational_expr EQUAL logical_expr { $$ = ast_makeAST(AST_EQ, $1, $3); }
| equational_expr NE logical_expr { $$ = ast_makeAST(AST_NE, $1, $3); }

logical_expr
: relational_expr
| NOT relational_expr { $$ = ast_makeAST(AST_NOT, $2, NULL); }
| logical_expr AND relational_expr { $$ = ast_makeAST(AST_AND, $1, $3); }
| logical_expr OR relational_expr { $$ = ast_makeAST(AST_OR, $1, $3); }
;

relational_expr
: additive_expr
| relational_expr LT additive_expr { $$ = ast_makeAST(AST_LT, $1, $3); }
| relational_expr LE additive_expr { $$ = ast_makeAST(AST_LE, $1, $3); }
| relational_expr GT additive_expr { $$ = ast_makeAST(AST_LT, $3, $1); }
| relational_expr GE additive_expr { $$ = ast_makeAST(AST_LE, $3, $1); }
;

additive_expr
: multiplicative_expr
| additive_expr ADD multiplicative_expr { $$ = ast_makeAST(AST_PLUS, $1, $3); }
| additive_expr SUB multiplicative_expr { $$ = ast_makeAST(AST_SUB, $1, $3); }
;

multiplicative_expr
: unary_expr
| multiplicative_expr MUL primary_expr { $$ = ast_makeAST(AST_MUL, $1, $3); }
| multiplicative_expr DIV primary_expr { $$ = ast_makeAST(AST_DIV, $1, $3); }
| multiplicative_expr MOD primary_expr { $$ = ast_makeAST(AST_MOD, $1, $3); }


unary_expr
: primary_expr
| SUB primary_expr { $$ = ast_makeAST(AST_UNM, $2, NULL); }
| RAND LP primary_expr RP { $$ = ast_makeAST(AST_RAND, $3, NULL); }
;

primary_expr
: nameterm { $$ = $1;}
| INT_LITERAL { $$ = ast_makeInt($1); }
| AGENT { $$=ast_makeAST(AST_AGENT, ast_makeSymbol($1), NULL); }
| LP expr RP { $$ = $2; }

;

%%



int yyerror(char *s) {
  extern char *yytext;
  char msg[256];

#ifdef MY_YYLINENO
  if (InfoLineno != NULL) {
    sprintf(msg, "%s:%d: %s near token '%s'.\n", 
	  InfoLineno->fname, yylineno+1, s, yytext);
  } else {
    sprintf(msg, "%d: %s near token '%s'.\n", 
	  yylineno, s, yytext);
  }
#else
  sprintf(msg, "%d: %s near token '%s'.\n", yylineno, s, yytext);
#endif

  Errormsg = strdup(msg);  

  if (yyin != stdin) {
    //    puts(Errormsg);
    destroy(); 
    //    exit(0);
  }

  return 0;
}






/**********************************
 AGENT and NAME Heaps
*********************************/

#ifdef EXPANDABLE_HEAP

// HOOP_SIZE must be power of two
#define HOOP_SIZE (1 << 18)
#define HOOP_SIZE_MASK ((HOOP_SIZE) -1)

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
#define RESET_HOOPFLAG_READYFORUSE_NAME(a) ((a) = ((ID_NAME) | (HOOPFLAG_READYFORUSE)))
#define TOGGLE_HOOPFLAG_READYFORUSE(a) ((a) = ((a) ^ HOOPFLAG_READYFORUSE))


typedef struct Heap_tag {
  HoopList *last_alloc_list;
  int last_alloc_idx;
} Heap;  



HoopList *HoopList_New_forName(void) {
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
  for (i=0; i<HOOP_SIZE; i++) {
    //    ((Name *)(hp_list->hoop))[i].basic.id = ID_NAME;
    RESET_HOOPFLAG_READYFORUSE_NAME(((Name *)(hp_list->hoop))[i].basic.id);
  }

  // hp->next = NULL;   // this should be executed only for the first creation.
  return hp_list;
}




HoopList *HoopList_New_forAgent(void) {
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
  for (i=0; i<HOOP_SIZE; i++) {
    RESET_HOOPFLAG_READYFORUSE_AGENT(((Agent *)(hp_list->hoop))[i].basic.id);

  }

  // hp->next = NULL;   // this should be executed only for the first creation.
  return hp_list;
}






unsigned long Heap_GetNum_Usage_forAgent(Heap *hp) {
  
  unsigned long count=0;
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
  
  unsigned long count=0;
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




//static inline
VALUE myallocAgent(Heap *hp) {

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

	///		hp->last_alloc_idx = idx;
	hp->last_alloc_idx = (idx-1+HOOP_SIZE)%HOOP_SIZE_MASK;  	
	hp->last_alloc_list = hoop_list;

	//    printf("hit[%d]\n", idx);
	return (VALUE)&(hoop[idx]);
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
      puts("(Agent hoop is expanded)");
#endif
      
      HoopList *new_hoop_list;
      new_hoop_list = HoopList_New_forAgent();

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


//static inline
VALUE myallocName(Heap *hp) {

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

	hp->last_alloc_idx = idx;      
	//hp->last_alloc_idx = (idx+1) & HOOP_SIZE_MASK;
	hp->last_alloc_list = hoop_list;

	//    printf("hit[%d]\n", idx);
	return (VALUE)&(hoop[idx]);
      }
      idx++;
    }

    // No nodes are available in this hoop.
  
    if (hoop_list->next != hp->last_alloc_list) {
      // There is another hoop.
      hoop_list = hoop_list->next;
      idx=0;

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
      puts("(Name hoop is expanded)");
#endif
      
      HoopList *new_hoop_list;
      new_hoop_list = HoopList_New_forName();

      HoopList *last_alloc = hoop_list->next;
      hoop_list->next = new_hoop_list;
      new_hoop_list->next = last_alloc;
    
      hoop_list = new_hoop_list;
      idx=0;    
    }

  }


}




static inline
void myfree(VALUE ptr) {

  SET_HOOPFLAG_READYFORUSE(BASIC(ptr)->id);

}


#else
// v0.5.6 -------------------------------------
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
#define RESET_HEAPFLAG_READYFORUSE_NAME(a) ((a) = ((ID_NAME) | (HEAPFLAG_READYFORUSE)))
#define TOGGLE_HEAPFLAG_READYFORUSE(a) ((a) = ((a) ^ HEAPFLAG_READYFORUSE))



VALUE *MakeAgentHeap(int size) {
  int i;
  VALUE *heap;

  // Agent Heap  
  heap = (VALUE *)malloc(sizeof(Agent)*size);
  if (heap == (VALUE *)NULL) {
      printf("[Heap]Malloc error\n");
      exit(-1);
  }
  for (i=0; i<size; i++) {
    RESET_HEAPFLAG_READYFORUSE_AGENT(((Agent *)(heap))[i].basic.id);
  }

  return heap;
}

VALUE *MakeNameHeap(int size) {
  int i;
  VALUE *heap;

  // Name Heap  
  heap = (VALUE *)malloc(sizeof(Name)*size);
  if (heap == (VALUE *)NULL) {
      printf("[Name]Malloc error\n");
      exit(-1);
  }
 for (i=0; i<size; i++) {
   //    ((Name *)(heap))[i].basic.id = ID_NAME;
    RESET_HEAPFLAG_READYFORUSE_NAME(((Name *)(heap))[i].basic.id);
  }

  return heap;
}



//static inline
VALUE myallocAgent(Heap *hp) {

  int i, idx, hp_size;
  Agent *hp_heap;

  hp_size = hp->size;
  hp_heap = (Agent *)(hp->heap);
  
  idx = hp->lastAlloc-1;

  for (i=0; i < hp_size; i++) {
    if (!IS_READYFORUSE(hp_heap[idx].basic.id)) {
      idx++;
      if (idx >= hp_size) {
	idx -= hp_size;
      }
      continue;
    }
    TOGGLE_HEAPFLAG_READYFORUSE(hp_heap[idx].basic.id);
    
    hp->lastAlloc = idx;
    
    return (VALUE)&(hp_heap[idx]);
  }

  printf("\nCritical ERROR: All %d term cells have been consumed.\n", hp->size);
  printf("You should have more term cells with -c option.\n");
  exit(-1);

  
}


//static inline
VALUE myallocName(Heap *hp) {

  int i,idx,hp_size;
  Name *hp_heap;

  hp_size = hp->size;
  hp_heap = (Name *)(hp->heap);
  
  idx = hp->lastAlloc;


  for (i=0; i < hp_size; i++) {
    //    if (!IS_READYFORUSE(((Name *)hp->heap)[idx].basic.id)) {
    if (!IS_READYFORUSE(hp_heap[idx].basic.id)) {
      idx++;
      if (idx >= hp_size) {
	idx -= hp_size;
      }
      continue;
    }
    //    TOGGLE_HEAPFLAG_READYFORUSE(((Name *)hp->heap)[idx].basic.id);
    TOGGLE_HEAPFLAG_READYFORUSE(hp_heap[idx].basic.id);
    
    hp->lastAlloc = idx;
    
    //    return (VALUE)&(((Name *)hp->heap)[idx]);
    return (VALUE)&(hp_heap[idx]);
  }

  printf("\nCritical ERROR: All %d name cells have been consumed.\n", hp->size);
  printf("You should have more term cells with -c option.\n");
  exit(-1);

  
}


unsigned long Heap_GetNum_Usage_forName(Heap *hp) {
  int i;
  unsigned long total=0;
  for (i=0; i < hp->size; i++) {
    if (!IS_READYFORUSE( ((Name *)hp->heap)[i].basic.id)) {
      total++;
    }
  }
  return total;
}
unsigned long Heap_GetNum_Usage_forAgent(Heap *hp) {
  int i;
  unsigned long total=0;
  for (i=0; i < hp->size; i++) {
    if (!IS_READYFORUSE( ((Agent *)hp->heap)[i].basic.id)) {
      total++;
    }
  }
  return total;
}



//static inline
void myfree(VALUE ptr) {

  TOGGLE_HEAPFLAG_READYFORUSE(BASIC(ptr)->id);

}


//---------------------------------------------


#endif


//-----------------------------------------
// Pretty printing for terms
//-----------------------------------------

static VALUE ShowNameHeap=(VALUE)NULL; // showname で表示するときの cyclic 防止
// showname 時に、呼び出し変数の heap num を入れておく。
// showname 呼び出し以外は NULL に。

void puts_name(VALUE ptr) {

  if (ptr == (VALUE)NULL) {
    printf("[NULL]");
    return;
  }

  if (IS_GNAMEID(BASIC(ptr)->id)) {
      printf("%s", IdTable_get_name(BASIC(ptr)->id));
  } else if (BASIC(ptr)->id == ID_NAME) {
      printf("<var%lu>", (unsigned long)(ptr));
  } else {
    puts_term(ptr);
  }

}
  

#define PRETTY_VAR
#ifdef PRETTY_VAR
typedef struct PrettyList_tag {
  VALUE id;
  char *name;
  struct PrettyList_tag *next; 
} PrettyList;

typedef struct {
  PrettyList *list;
  int alphabet;
  int index;
  char namebuf[10];
} PrettyStruct;

PrettyStruct Pretty;

#define MAX_PRETTY_ALPHABET 26
void Pretty_init(void) {
  Pretty.alphabet = -1;
  Pretty.list = NULL;
  Pretty.index = 1;
}

PrettyList *PrettyList_new(void) {
  PrettyList *alist;
  alist = malloc(sizeof(PrettyList));
  if (alist == NULL) {
    printf("[PrettyList] Malloc error\n");
    exit(-1);
  }
  return alist;
}

char *Pretty_newName(void) {
  Pretty.alphabet++;
  if (Pretty.alphabet >= MAX_PRETTY_ALPHABET) {
    Pretty.alphabet = 0;
    Pretty.index++;
  }
  sprintf(Pretty.namebuf, "%c%d", 'a'+Pretty.alphabet, Pretty.index);
  return(Pretty.namebuf);
}

PrettyList *PrettyList_recordName(VALUE a) {
  PrettyList *alist;
  alist = PrettyList_new();
  alist->id = a;
  alist->name = strdup(Pretty_newName());
  alist->next = Pretty.list;
  Pretty.list = alist;
  return (alist);
}

char *Pretty_Name(VALUE a) {
  PrettyList *alist;
  if (Pretty.list == NULL) {
    alist = PrettyList_recordName(a);
    Pretty.list = alist;
    return (alist->name);
  } else {
    PrettyList *at = Pretty.list;
    while (at != NULL) {
      if (at->id == a) {
	return (at->name);
      }
      at = at->next;
    }

    alist = PrettyList_recordName(a);
    Pretty.list = alist;
    return (alist->name);    
  }
}
#endif


//#define PUTS_ELEMENTS_NUM 12
#define PUTS_ELEMENTS_NUM 30
static int Puts_list_element=0;


// put an indirected term t for x such as x->t when `PutIndireaction' is 1
static int PutIndirection = 1;       
void puts_term(VALUE ptr) {
  if (IS_FIXNUM(ptr)) {
    printf("%d", FIX2INT(ptr));
    return;
  } else if (BASIC(ptr) == NULL) {
    printf("<NULL>");
    return;
  }

  if (IS_NAMEID(BASIC(ptr)->id)) {
    if (NAME(ptr)->port == (VALUE)NULL) {
      if (IS_GNAMEID(BASIC(ptr)->id)) {
	//printf("%s", NAME(ptr)->name);
	printf("%s", IdTable_get_name(BASIC(ptr)->id));
      } else {
#ifndef PRETTY_VAR
	printf("<var%lu>", (unsigned long)(ptr));
#else
	printf("<%s>", Pretty_Name(ptr));
#endif
      }
    } else {
      if (ptr == ShowNameHeap) {
	printf("<Warning:%s is cyclic>", IdTable_get_name(BASIC(ptr)->id));
	return;
      }
      
      if ((PutIndirection) &&
	  (IdTable_get_name(BASIC(ptr)->id) != NULL)) {
	  printf("%s", IdTable_get_name(BASIC(ptr)->id));
      } else {
	  puts_term(NAME(ptr)->port);
      }
	
    }

  } else if (IS_TUPLEID(BASIC(ptr)->id)) {
    int i, arity;
    arity = GET_TUPLEARITY(BASIC(ptr)->id);
    printf("(");
    for (i=0; i<arity; i++) {
      puts_term(AGENT(ptr)->port[i]);
      if (i != arity - 1) {
	printf(",");
      }
    }
    printf(")");

  } else if (BASIC(ptr)->id == ID_NIL) {
    printf("[]");

  } else if (BASIC(ptr)->id == ID_CONS) {
    printf("[");

    while (ptr != (VALUE)NULL) {
      puts_term(AGENT(ptr)->port[0]);

      ptr = AGENT(ptr)->port[1];
      while ((IS_NAMEID(BASIC(ptr)->id)) && (NAME(ptr)->port != (VALUE)NULL)) {
	ptr = NAME(ptr)->port;
      }	
      if (BASIC(ptr)->id == ID_NIL) {
	printf("]");
	Puts_list_element=0;
	break;
      }
      
      if ((IS_NAMEID(BASIC(ptr)->id)) && (NAME(ptr)->port == (VALUE)NULL)) {
	// for WHNF
	printf(",");
	puts_term(ptr);
	printf("...");
	break;
      }

      printf(",");

      Puts_list_element++;
      if (Puts_list_element > PUTS_ELEMENTS_NUM) {
	printf("...]");
	Puts_list_element=0;
	break;
      }
      
    }
        
  } else {
    // Agent
    int i, arity;

    arity = IdTable_get_arity(AGENT(ptr)->basic.id);
    printf("%s", IdTable_get_name(AGENT(ptr)->basic.id));
    if (arity != 0) {
      printf("(");
    }
    for (i=0; i<arity; i++) {
      puts_term(AGENT(ptr)->port[i]);
      if (i != arity - 1) {
	printf(",");
      }
    }
    if (arity != 0) {
      printf(")");
    }
  }
}


void puts_name_port0(VALUE ptr) {
  
  if (ptr == (VALUE)NULL) {
    printf("<NON-DEFINED>");

  } else if (IS_NAMEID(BASIC(ptr)->id)) {
    if (NAME(ptr)->port == (VALUE)NULL) {
      printf("<EMPTY>");
    } else {
      ShowNameHeap=ptr;
      puts_term(NAME(ptr)->port);
      ShowNameHeap=(VALUE)NULL;      
    }
  } else {
    puts("ERROR: it is not a name.");
  }
  
}

void puts_names_ast(Ast *ast) {
  Ast *param = ast;

  int preserve = PutIndirection;
  PutIndirection = 0;
  
  while (param != NULL) {
    char *sym = param->left->sym;
    int sym_id = NameTable_get_id(sym);
    if (IS_GNAMEID(sym_id)) {
      puts_name_port0(IdTable_get_heap(sym_id));
    } else {
      puts_name_port0((VALUE)NULL);
    }
      
    param = ast_getTail(param);
    if (param != NULL)
      printf(" ");
    
  }
  puts("");

  PutIndirection = preserve;  
}

//void puts_name_port0_nat(VALUE a1) {
void puts_name_port0_nat(char *sym) {
  int result=0;
  int idS, idZ;

  int sym_id = NameTable_get_id(sym);
  if (!IS_GNAMEID(sym_id)) {
    printf("<NOT-DEFINED>\n");
    fflush(stdout);
    return;
  }

  VALUE a1 = IdTable_get_heap(sym_id);
  
  idS = NameTable_get_set_id_with_IdTable_forAgent("S");
  idZ = NameTable_get_set_id_with_IdTable_forAgent("Z");
  
  if (a1 == (VALUE)NULL) {
    printf("<NUll>");
  } else if (!IS_NAMEID(BASIC(a1)->id)) {
    printf("<NON-NAME>");
  } else {
    if (NAME(a1)->port == (VALUE)NULL) {
      printf("<EMPTY>");
    } else {
      
      a1=NAME(a1)->port;
      while (BASIC(a1)->id != idZ) {
	if (BASIC(a1)->id == idS) {
	  result++;
	  a1=AGENT(a1)->port[0];
	} else if (IS_NAMEID(BASIC(a1)->id)) {
	  a1=NAME(a1)->port;
	} else {
	  puts("ERROR: puts_name_port0_nat");
	  exit(-1);
	}
      }
      printf("%d\n", result);
      fflush(stdout);
    }
  }  
  
}


void puts_eqlist(EQList *at) {
  while (at != NULL) {
    puts_term(at->eq.l);
    printf("~");
    puts_term(at->eq.r);
    printf(",");
    at=at->next;
  }
}




/**********************************
  VIRTUAL MACHINE 
*********************************/
#define VM_REG_SIZE 64

// reg0 is used to store comparison results
// so, others have to be used from reg1
#define VM_OFFSET_R0            (0)
#define VM_OFFSET_METAVAR_L(a)  (1+a)
#define VM_OFFSET_METAVAR_R(a)  (1+MAX_PORT+(a))
#define VM_OFFSET_ANNOTATE_L    (1+MAX_PORT*2)
#define VM_OFFSET_ANNOTATE_R    (1+MAX_PORT*2+1)
#define VM_OFFSET_LOCALVAR      (VM_OFFSET_ANNOTATE_R + 1)



typedef struct {
  // Heaps for agents and names
  Heap agentHeap, nameHeap;
  
  // EQStack
  EQ *eqStack;
  int nextPtr_eqStack;
  int eqStack_size;

#ifdef COUNT_INTERACTION
  unsigned int count_interaction;  
#endif


  // register
  //  VALUE reg[VM_REG_SIZE+(MAX_PORT*2 + 2)];
  //  VALUE reg[VM_REG_SIZE];
  VALUE *reg;


#ifdef THREAD
  unsigned int id;
#endif
  
} VirtualMachine;

#ifdef COUNT_INTERACTION
#define COUNTUP_INTERACTION(vm) vm->count_interaction++
#else
#define COUNTUP_INTERACTION(vm)
#endif


#ifndef THREAD
static VirtualMachine VM;
#endif

#ifdef COUNT_MKAGENT
  unsigned int NumberOfMkAgent;
  //  unsigned int id;
#endif


#ifdef EXPANDABLE_HEAP
void VM_Buffer_Init(VirtualMachine *vm) {
  // Agent Heap
  vm->agentHeap.last_alloc_list = HoopList_New_forAgent();
  vm->agentHeap.last_alloc_list->next = vm->agentHeap.last_alloc_list;
  vm->agentHeap.last_alloc_idx = 0;


  // Name Heap
  vm->nameHeap.last_alloc_list = HoopList_New_forName();
  vm->nameHeap.last_alloc_list->next = vm->nameHeap.last_alloc_list;
  vm->nameHeap.last_alloc_idx = 0;

  // Register
  vm->reg = malloc(sizeof(VALUE) * VM_REG_SIZE);
}  
#else

void VM_InitBuffer(VirtualMachine *vm, int size) {

  // Name Heap
  vm->agentHeap.heap = MakeAgentHeap(size);
  vm->agentHeap.lastAlloc = 0;
  vm->agentHeap.size = size;
  
		    
  //size = size/2;
  vm->nameHeap.heap = MakeNameHeap(size);
  vm->nameHeap.lastAlloc = size-1;
  //vm->nameHeap.lastAlloc = 0;
  vm->nameHeap.size = size;

  
  // Register
  vm->reg = malloc(sizeof(VALUE) * VM_REG_SIZE);
}  

#endif



void VM_EQStack_Init(VirtualMachine *vm, int size) {
  vm->nextPtr_eqStack = -1;  
  vm->eqStack = malloc(sizeof(EQ)*size);
  vm->eqStack_size = size;
  if (vm->eqStack == NULL) {
    printf("Malloc error\n");
    exit(-1);
  }
}


void VM_EQStack_Push(VirtualMachine *vm, VALUE l, VALUE r) {

  vm->nextPtr_eqStack++;

  if (vm->nextPtr_eqStack >= vm->eqStack_size) {
    vm->eqStack_size += vm->eqStack_size;
    vm->eqStack = realloc(vm->eqStack, sizeof(EQ)*vm->eqStack_size);

#ifdef VERBOSE_EQSTACK_EXPANSION    
    puts("(EQStack is expanded)");
#endif
    
  }
  vm->eqStack[vm->nextPtr_eqStack].l = l;
  vm->eqStack[vm->nextPtr_eqStack].r = r;

#ifdef DEBUG
  //DEBUG
  printf(" PUSH:");
  puts_term(l);
  puts("");
  puts("      ><");
  printf("      ");puts_term(r);
  puts("");
  //  printf("VM%d:pushed\n", vm->id);
#endif


}

int VM_EQStack_Pop(VirtualMachine *vm, VALUE *l, VALUE *r) {
  if (vm->nextPtr_eqStack >= 0) {
    *l = vm->eqStack[vm->nextPtr_eqStack].l;
    *r = vm->eqStack[vm->nextPtr_eqStack].r;
    vm->nextPtr_eqStack--;
    return 1;
  }
  return 0;
}


#ifdef EXPANDABLE_HEAP
void VM_Init(VirtualMachine *vm, unsigned int eqStackSize) {
  VM_Buffer_Init(vm);
  VM_EQStack_Init(vm, eqStackSize);
}
#else

// v0.5.6
void VM_Init(VirtualMachine *vm, 
	     unsigned int agentBufferSize, unsigned int eqStackSize) {
  VM_InitBuffer(vm, agentBufferSize);
  VM_EQStack_Init(vm, eqStackSize);
}
#endif





//static inline
VALUE makeAgent(VirtualMachine *vm, int id) {
  VALUE ptr;
  ptr = myallocAgent(&vm->agentHeap);

#ifdef COUNT_MKAGENT
  NumberOfMkAgent++;
#endif
  
  AGENT(ptr)->basic.id = id;
  return ptr;
}



//static inline
VALUE makeName(VirtualMachine *vm) {
  VALUE ptr;
  
  ptr = myallocName(&vm->nameHeap);
  //  AGENT(ptr)->basic.id = ID_NAME;
  NAME(ptr)->port = (VALUE)NULL;

  return ptr;
}



/**********************************
  Counter for Interaction operation
*********************************/
#ifdef COUNT_INTERACTION
int VM_Get_InteractionCount(VirtualMachine *vm) {
  return(vm->count_interaction);
}

void VM_Clear_InteractionCount(VirtualMachine *vm) {
  vm->count_interaction = 0;
}
#endif















/**************************************
 Free node allocation
**************************************/

//static inline
void freeAgent(VALUE ptr) {
  
  if (ptr == (VALUE)NULL) {
    puts("ERROR: NULL is applied to freeAgent.");
    return;
  }

  myfree(ptr);
}

//static inline
void freeName(VALUE ptr) {
  if (ptr == (VALUE)NULL) {
    puts("ERROR: NULL is applied to freeName.");
    return;
  }

  if (IS_LOCAL_NAMEID(BASIC(ptr)->id)) {
    myfree(ptr);
  } else {    
    // Global name

    NameTable_erase_id(IdTable_get_name(BASIC(ptr)->id));
    IdTable_set_heap(BASIC(ptr)->id, (VALUE)NULL);
    
    SET_LOCAL_NAMEID(BASIC(ptr)->id); //    BASIC(ptr)->id = ID_NAME;
    myfree(ptr);
  }

}


void freeAgentRec(VALUE ptr) {
  
 loop:  
  if ((IS_FIXNUM(ptr)) || (ptr == (VALUE)NULL)) {
    return;
  }

  if (IS_READYFORUSE(BASIC(ptr)->id)) {
    return;
  }

  
  if (IS_NAMEID(BASIC(ptr)->id)) {
    if (ptr == ShowNameHeap) return;

    if (NAME(ptr)->port != (VALUE)NULL) {
      VALUE port = NAME(ptr)->port;
      freeName(ptr);
      ptr = port; goto loop;
    } else {

      // The name is kept living if it occurs anywhere as a global.
      if (keynode_exists_in_another_term(ptr, NULL) < 2) {
	freeName(ptr);
      }
    }
  } else {
    if (BASIC(ptr)->id == ID_CONS) {
      if (IS_FIXNUM(AGENT(ptr)->port[0])) {
	VALUE port1 = AGENT(ptr)->port[1];
	freeAgent(ptr);
	ptr = port1; goto loop;
      }
    }


    int arity;
    arity = IdTable_get_arity(AGENT(ptr)->basic.id);
    if (arity == 1) {
      VALUE port1 = AGENT(ptr)->port[0];
      freeAgent(ptr);
      ptr = port1; goto loop;
    } else {
      freeAgent(ptr);
      //      printf(" .");
      int i;
      for(i=0; i<arity; i++) {
	freeAgentRec(AGENT(ptr)->port[i]);
      }
    }
  }
}




void flush_name_port0(VALUE ptr) {
  if (ptr == (VALUE)NULL) {
    return;
  }

  if (IS_FIXNUM(ptr)) {
    return;
  }

  // When the given name nodes (ptr) occurs somewhere also,
  // these are not freed.
  // JAPANESE: ptr の name nodes が他の場所で出現するなら flush しない。
  VALUE connected_from;
  if (keynode_exists_in_another_term(ptr, &connected_from) >= 1) {
    printf("Error: '%s' cannot be freed because it is referred to by '%s'.\n", 
	   IdTable_get_name(BASIC(ptr)->id),
	   IdTable_get_name(BASIC(connected_from)->id));
    
    return;
  }

  
  if (NAME(ptr)->port == (VALUE)NULL) {
    freeName(ptr);
  } else {
    ShowNameHeap=ptr;
    freeAgentRec(NAME(ptr)->port);
    freeName(ptr);
    ShowNameHeap=(VALUE)NULL;
  }      
  

#ifdef VERBOSE_NODE_USE
#ifndef THREAD  
  printf("(%lu agents and %lu names nodes are used.)\n", 
	 Heap_GetNum_Usage_forAgent(&VM.agentHeap),
	 Heap_GetNum_Usage_forName(&VM.nameHeap));
#endif
#endif

}

void free_names_ast(Ast *ast) {
  Ast *param = ast;

  while (param != NULL) {
    int sym_id = NameTable_get_id(param->left->sym);
    if (IS_GNAMEID(sym_id)) {
      flush_name_port0(IdTable_get_heap(sym_id));
    } else {
      flush_name_port0((VALUE)NULL);
    }
    param = ast_getTail(param);		     
  }
}








/*************************************
 Global Exec STACK
**************************************/

#ifdef THREAD
static pthread_cond_t EQStack_not_empty = PTHREAD_COND_INITIALIZER;
static pthread_mutex_t Sleep_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t AllSleep_lock = PTHREAD_MUTEX_INITIALIZER;
#endif



// GlobalEQStack for execution with threads
#ifdef THREAD
typedef struct {
  EQ *stack;
  int nextPtr;
  int size;
  volatile int lock;  // for lightweight spin lock
} EQStack;
static EQStack GlobalEQS;
#endif


#ifdef THREAD
void GlobalEQStack_Init(int size) {
 GlobalEQS.nextPtr = -1;
 GlobalEQS.stack = malloc(sizeof(EQ)*size);
 GlobalEQS.size = size;
  if (GlobalEQS.stack == NULL) {
    printf("Malloc error\n");
    exit(-1);
  }
  // for cas_lock
 GlobalEQS.lock = 0;
}
#endif


#ifdef THREAD
void GlobalEQStack_Push(VALUE l, VALUE r) {

  lock(&GlobalEQS.lock);

  GlobalEQS.nextPtr++;
  if (GlobalEQS.nextPtr >= GlobalEQS.size) {
    GlobalEQS.size += GlobalEQS.size;
    GlobalEQS.stack = realloc(GlobalEQS.stack, sizeof(EQ)*GlobalEQS.size);

#ifdef VERBOSE_EQSTACK_EXPANSION    
    puts("(Global EQStack is expanded)");
#endif
  }
  
  GlobalEQS.stack[GlobalEQS.nextPtr].l = l;
  GlobalEQS.stack[GlobalEQS.nextPtr].r = r;

  unlock(&GlobalEQS.lock);

  if (SleepingThreadsNum > 0) {
    pthread_mutex_lock(&Sleep_lock);
    pthread_cond_signal(&EQStack_not_empty);
    pthread_mutex_unlock(&Sleep_lock);
  }

}
#endif


int EQStack_Pop(VirtualMachine *vm, VALUE *l, VALUE *r) {

  if (vm->nextPtr_eqStack >= 0) {
    *l = vm->eqStack[vm->nextPtr_eqStack].l;
    *r = vm->eqStack[vm->nextPtr_eqStack].r;
    vm->nextPtr_eqStack--;

    /*
#ifdef DEBUG
    puts("");
    puts("====================================");
    puts("POP");
    puts("====================================");
    puts_term(*l);
    puts("");
    puts("><");
    puts_term(*r);
    puts("");
    puts("====================================");
#endif
    */

    return 1;
  }
#ifndef THREAD
  return 0;
#else

  lock(&GlobalEQS.lock);

  if (GlobalEQS.nextPtr  < 0) {
    // When GlobalEQStack is empty
    unlock(&GlobalEQS.lock);
    return 0;    
  } 

  *l = GlobalEQS.stack[GlobalEQS.nextPtr].l;
  *r = GlobalEQS.stack[GlobalEQS.nextPtr].r;
  GlobalEQS.nextPtr--;
  
  unlock(&GlobalEQS.lock);
  return 1;
  
#endif
}


#ifdef DEBUG
void VM_EQStack_allputs(VirtualMachine *vm) {
  int i;
  if (vm->nextPtr_eqStack == -1) return;
  for (i=0; i<=vm->nextPtr_eqStack+1; i++) {
    printf("%02d: ", i); puts_term(vm->eqStack[i].l);
    puts("");
    printf("    ");
    puts_term(vm->eqStack[i].r);
    puts("");
  }
}
#endif




/**************************************
 BYTECODE and Compilation
**************************************/
// *** The occurrence order must be the same in labels in ExecCode. ***
typedef enum {
  OP_PUSH=0, OP_PUSHI, OP_MYPUSH,

  OP_MKNAME, OP_MKGNAME,
  
  OP_MKAGENT0, OP_MKAGENT1, OP_MKAGENT2, OP_MKAGENT3,
  OP_MKAGENT4, OP_MKAGENT5,
  
  OP_REUSEAGENT0, OP_REUSEAGENT1, OP_REUSEAGENT2, OP_REUSEAGENT3,
  OP_REUSEAGENT4, OP_REUSEAGENT5,
  

  OP_RET, OP_RET_FREE_LR, OP_RET_FREE_L, OP_RET_FREE_R,

  OP_LOADI, OP_LOAD, 

  OP_ADD, OP_SUB, OP_ADDI, OP_SUBI, OP_MUL, OP_DIV, OP_MOD,
  OP_LT, OP_LE, OP_EQ, OP_EQI, OP_NE,
  OP_UNM, OP_RAND, OP_INC, OP_DEC,

  OP_LT_R0, OP_LE_R0, OP_EQ_R0, OP_EQI_R0, OP_NE_R0,

  
  OP_JMPEQ0, OP_JMPEQ0_R0, OP_JMP, OP_JMPNEQ0,
  
  OP_JMPCNCT_CONS, OP_JMPCNCT,
  OP_LOOP, OP_LOOP_RREC, OP_LOOP_RREC1, OP_LOOP_RREC2,

  
  // Connection operation for global names of given nets in the interactive mode.
  OP_CNCTGN, OP_SUBSTGN,
  
  // This corresponds to the last code in CodeAddr.
  // So ones after this are not used for execution by virtual machines.
  OP_NOP,

  // These are used for translation from intermediate codes to Bytecodes
  OP_LABEL, OP_DEAD_CODE, OP_BEGIN_BLOCK
} Code;


// The real addresses for the `Code':
static void* CodeAddr[OP_NOP+1];


//void *ExecCode(int arg, VirtualMachine *vm, void **code);
void *ExecCode(int mode, VirtualMachine *restrict vm, void *restrict *code);

void CodeAddr_init(void) {
  // Set CodeAddr
  void **table;
  table = ExecCode(0, NULL, NULL);
  for (int i=0; i<OP_NOP; i++) {
    CodeAddr[i] = table[i];
  }
}





typedef enum {
  NB_NAME=0,
  NB_META,
  NB_INTVAR,
} NB_TYPE;


// NBIND 数は meta数(MAX_PORT*2) + 一つの rule（や eqlist） における
// 最大name出現数(100)
#define MAX_NBIND MAX_PORT*2+100
typedef struct {
  char *name;
  int reg;
  int refnum; //  0: global name (thus created only),
              // >0: local name
              // (for the bind names: should be 1)
              // (for the int names: not paticular)
  NB_TYPE type; // NB_NAME, NB_META or NB_INTVAR
} NameBind;


//http://www.hpcs.cs.tsukuba.ac.jp/~msato/lecture-note/comp-lecture/note10.html
#define MAX_IMCODE 1024
struct IMCode_tag {
  int opcode;
  int operand1, operand2, operand3, operand4, operand5, operand6, operand7;
} IMCode[MAX_IMCODE];

int IMCode_n;

void IMCode_init(void) {
  IMCode_n = 0;
}

#define IMCODE_OVERFLOW_CHECK if(IMCode_n>MAX_IMCODE) {puts("IMCODE overflow");exit(1);}

void IMCode_genCode0(int opcode) {
  IMCode[IMCode_n++].opcode = opcode;
  IMCODE_OVERFLOW_CHECK
}
void IMCode_genCode1(int opcode, int operand1) {
  IMCode[IMCode_n].operand1 = operand1;
  IMCode[IMCode_n++].opcode = opcode;
  IMCODE_OVERFLOW_CHECK
}
void IMCode_genCode2(int opcode, int operand1, int operand2) {
  IMCode[IMCode_n].operand1 = operand1;
  IMCode[IMCode_n].operand2 = operand2;
  IMCode[IMCode_n++].opcode = opcode;  
  IMCODE_OVERFLOW_CHECK
}
void IMCode_genCode3(int opcode, int operand1, int operand2, int operand3) {
  IMCode[IMCode_n].operand1 = operand1;
  IMCode[IMCode_n].operand2 = operand2;
  IMCode[IMCode_n].operand3 = operand3;
  IMCode[IMCode_n++].opcode = opcode;  
  IMCODE_OVERFLOW_CHECK
}
void IMCode_genCode4(int opcode, int operand1, int operand2, int operand3,
		     int operand4) {
  IMCode[IMCode_n].operand1 = operand1;
  IMCode[IMCode_n].operand2 = operand2;
  IMCode[IMCode_n].operand3 = operand3;
  IMCode[IMCode_n].operand4 = operand4;
  IMCode[IMCode_n++].opcode = opcode;  
  IMCODE_OVERFLOW_CHECK
}
void IMCode_genCode5(int opcode, int operand1, int operand2, int operand3,
		     int operand4, int operand5) {
  IMCode[IMCode_n].operand1 = operand1;
  IMCode[IMCode_n].operand2 = operand2;
  IMCode[IMCode_n].operand3 = operand3;
  IMCode[IMCode_n].operand4 = operand4;
  IMCode[IMCode_n].operand5 = operand5;
  IMCode[IMCode_n++].opcode = opcode;  
  IMCODE_OVERFLOW_CHECK
}
void IMCode_genCode6(int opcode, int operand1, int operand2, int operand3,
		     int operand4, int operand5, int operand6) {
  IMCode[IMCode_n].operand1 = operand1;
  IMCode[IMCode_n].operand2 = operand2;
  IMCode[IMCode_n].operand3 = operand3;
  IMCode[IMCode_n].operand4 = operand4;
  IMCode[IMCode_n].operand5 = operand5;
  IMCode[IMCode_n].operand6 = operand6;
  IMCode[IMCode_n++].opcode = opcode;  
  IMCODE_OVERFLOW_CHECK
}
void IMCode_genCode7(int opcode, int operand1, int operand2, int operand3,
		     int operand4, int operand5, int operand6, int operand7) {
  IMCode[IMCode_n].operand1 = operand1;
  IMCode[IMCode_n].operand2 = operand2;
  IMCode[IMCode_n].operand3 = operand3;
  IMCode[IMCode_n].operand4 = operand4;
  IMCode[IMCode_n].operand5 = operand5;
  IMCode[IMCode_n].operand6 = operand6;
  IMCode[IMCode_n].operand7 = operand7;
  IMCode[IMCode_n++].opcode = opcode;  
  IMCODE_OVERFLOW_CHECK
}


#define MAX_CODE_SIZE 1024
typedef struct {
  
  // Management table for local and global names
  NameBind bind[MAX_NBIND];   
  int bindPtr;                // its index
  int bindPtr_metanames;      // The max index that stores info of meta names
                              // (default: -1)

  
  // Index for local and global names in Regs
  int localNamePtr;           // It starts from VM_OFFSET_LOCALVAR
  
  // For rule agents
  int idL, idR;               // ids of ruleAgentL and ruleAgentR
  int reg_agentL, reg_agentR; // Beginning reg nums for args of
                              // ruleAgentL, ruleAgentR
  int annotateL, annotateR;   // `Annotation properties' such as (*L) (*R) (int)


  // for compilation to VMCode
  int label;                    // labels

  int tmpRegState[VM_REG_SIZE]; // register assignments
                                // store localvar numbers. -1 is no assignment.
  
} CmEnvironment;


// The annotation properties
#define ANNOTATE_NOTHING  0     // The rule agent is not reused,
#define ANNOTATE_REUSE 1        // annotation (*L), (*R) is specified,
#define ANNOTATE_AS_INT_AGENT 2 // (int i), therefore it should not be freed.


static CmEnvironment CmEnv;


static inline
void CmEnv_clear_localnamePtr(void) {
  CmEnv.localNamePtr = VM_OFFSET_LOCALVAR;
}

void CmEnv_clear_bind(int preserve_idx) {
  // clear reference counter only, until preserve_idx
  for (int i=0; i<=preserve_idx; i++) {
    CmEnv.bind[i].refnum = 0;
  }    

  // after that, clear everything
  for (int i=preserve_idx+1; i<MAX_NBIND; i++) {
    CmEnv.bind[i].name = NULL;
    CmEnv.bind[i].refnum = 0;
    CmEnv.bind[i].reg = 0;
  }

  // new name information will be stored from preserve_idx+1
  CmEnv.bindPtr = preserve_idx+1;
}

void CmEnv_clear_register_assignment_table_all(void) {
  for (int i=0; i<VM_OFFSET_LOCALVAR; i++) {
    CmEnv.tmpRegState[i] = i;    // occupied already
  }    
  for (int i=VM_OFFSET_LOCALVAR; i<VM_REG_SIZE; i++) {
    CmEnv.tmpRegState[i] = -1;   // free
  }
}

void CmEnv_clear_all(void) 
{
  // clear all the information of names.
  CmEnv_clear_bind(-1);

  // reset the annotation properties for rule agents.
  CmEnv.bindPtr_metanames = -1;
  CmEnv.annotateL = ANNOTATE_NOTHING;
  CmEnv.annotateR = ANNOTATE_NOTHING;
  
  // reset the beginning number for local vars.  
  CmEnv_clear_localnamePtr();  

  // reset the index of storage for imtermediate codes.
  IMCode_init();

  // reset the index of labels;
  CmEnv.label = 0;

  // reset the register assignment table
  CmEnv_clear_register_assignment_table_all();
}

void CmEnv_clear_keeping_rule_properties(void) 
{
  // clear the information of names EXCEPT meta ones.
  CmEnv_clear_bind(CmEnv.bindPtr_metanames);
  
  if (CmEnv.annotateL != ANNOTATE_AS_INT_AGENT) {
    CmEnv.annotateL = ANNOTATE_NOTHING;
  }
  if (CmEnv.annotateR != ANNOTATE_AS_INT_AGENT) {
    CmEnv.annotateR = ANNOTATE_NOTHING;
  }

  
  // reset the beginning number for local vars.  
  CmEnv_clear_localnamePtr();  

  /*
  // reset the index of storage for imtermediate codes.
  IMCode_init();
  */
}


int CmEnv_get_newlabel(void) {
  return CmEnv.label++;
}


int CmEnv_set_symbol_as_name(char *name) {
  // return: a regnum for the given name.
  
  int result;

  if (name != NULL) {
    CmEnv.bind[CmEnv.bindPtr].name = name;
    CmEnv.bind[CmEnv.bindPtr].reg = CmEnv.localNamePtr;
    CmEnv.bind[CmEnv.bindPtr].refnum = 0;
    CmEnv.bind[CmEnv.bindPtr].type = NB_NAME;
    
    CmEnv.bindPtr++;
    if (CmEnv.bindPtr > MAX_NBIND) {
      puts("SYSTEM ERROR: CmEnv.bindPtr exceeded MAX_NBIND.");
      exit(-1);
    }
    
    result = CmEnv.localNamePtr;
    CmEnv.localNamePtr++;
    if (CmEnv.localNamePtr > VM_REG_SIZE) {
      puts("SYSTEM ERROR: CmEnv.localNamePtr exceeded VM_REG_SIZE.");
      exit(-1);
    }
    
    return result;
  }
  return -1;
}


void CmEnv_set_symbol_as_meta(char *name, int reg, NB_TYPE type) {

  if (name != NULL) {
    CmEnv.bind[CmEnv.bindPtr].name = name;
    CmEnv.bind[CmEnv.bindPtr].reg = reg;
    CmEnv.bind[CmEnv.bindPtr].refnum = 0;
    CmEnv.bind[CmEnv.bindPtr].type = type;

    // update the last index for metanames
    CmEnv.bindPtr_metanames = CmEnv.bindPtr;
    
    CmEnv.bindPtr++;
    if (CmEnv.bindPtr > MAX_NBIND) {
      puts("SYSTEM ERROR: CmEnv.bindPtr exceeded MAX_NBIND.");
      exit(-1);
    }
  }
}


int CmEnv_set_as_INTVAR(char *name) {
  int result;

  if (name != NULL) {
    CmEnv.bind[CmEnv.bindPtr].name = name;
    CmEnv.bind[CmEnv.bindPtr].reg = CmEnv.localNamePtr;
    CmEnv.bind[CmEnv.bindPtr].refnum = 0;
    CmEnv.bind[CmEnv.bindPtr].type = NB_INTVAR;
    result = CmEnv.localNamePtr;

    CmEnv.bindPtr++;
    if (CmEnv.bindPtr > MAX_NBIND) {
      puts("SYSTEM ERROR: CmEnv.bindPtr exceeded MAX_NBIND.");
      exit(-1);
    }

    CmEnv.localNamePtr++;
    if (CmEnv.localNamePtr > VM_REG_SIZE) {
      puts("SYSTEM ERROR: CmEnv.localNamePtr exceeded VM_REG_SIZE.");
      exit(-1);
    }

    return result;
  }
  return -1;
}


int CmEnv_find_var(char *key) {
  int i;
  for (i=0; i<CmEnv.bindPtr; i++) {
    if (strcmp(key, CmEnv.bind[i].name) == 0) {
      CmEnv.bind[i].refnum++;
      return CmEnv.bind[i].reg;
    }
  }
  return -1;
}

int CmEnv_gettype_forname(char *key, NB_TYPE *type) {
  int i;
  for (i=0; i<CmEnv.bindPtr; i++) {
    if (strcmp(key, CmEnv.bind[i].name) == 0) {
      *type = CmEnv.bind[i].type;
      return 1;
    }
  }
  return 0;
}



int CmEnv_newvar(void) {

  int result;
  result = CmEnv.localNamePtr;
  CmEnv.localNamePtr++;
  if (CmEnv.localNamePtr > VM_REG_SIZE) {
    puts("SYSTEM ERROR: CmEnv.localNamePtr exceeded VM_REG_SIZE.");
    exit(-1);
  }

  return result;
}



int CmEnv_check_meta_occur_once(void) {
  int i;

  for (i=0; i<CmEnv.bindPtr; i++) {

    if (CmEnv.bind[i].type == NB_META) {
      if (CmEnv.bind[i].refnum != 1) { // Be just once!
	printf("ERROR: '%s' is referred not once in the right-hand side of the rule definition", CmEnv.bind[i].name);
	return 0;
      }
      //    } else if (CmEnv.bind[i].type == NB_INTVAR) {
      //      if (CmEnv.bind[i].refnum == 0) {
      //	printf("Error: %s does not occur at RHS.\n", CmEnv.bind[i].name);
      //	return 0;
      //      }
    }
  }

  return 1;

}


int CmEnv_check_name_reference_times(void) {
  int i;
  for (i=0; i<CmEnv.bindPtr; i++) {
    if (CmEnv.bind[i].type == NB_NAME) {
      if (CmEnv.bind[i].refnum > 2) {
	printf("ERROR: The name '%s' occurs more than twice.\n", 
	       CmEnv.bind[i].name);
	return 0;
      }
    }
  }
  return 1;
}


void CmEnv_Retrieve_GNAME(void) {
  int local_var;

  for (int i=0; i<IMCode_n; i++) {
    if (IMCode[i].opcode != OP_MKNAME) {
      continue;
    }

    local_var = IMCode[i].operand1;

    for (int j=0; j<CmEnv.bindPtr; j++) {
      if ((CmEnv.bind[j].type == NB_NAME) &&
	  (CmEnv.bind[j].reg == local_var) &&
	  (CmEnv.bind[j].refnum  == 0)) {

	// ==> OP_MKGNAME id dest
	char *sym = CmEnv.bind[j].name;
	int sym_id = NameTable_get_id(sym);
	if (!IS_GNAMEID(sym_id)) {
	  // new occurrence
	  sym_id = IdTable_new_gnameid();
	  NameTable_set_id(sym, sym_id);
	  IdTable_set_name(sym_id, sym);
	}
	
	IMCode[i].opcode = OP_MKGNAME;
	IMCode[i].operand2 = IMCode[i].operand1;
	IMCode[i].operand1 = sym_id;
      }
    }
  }      
}






int CmEnv_using_reg(int localvar) {
  for (int i=0; i<VM_REG_SIZE; i++) {
    if (CmEnv.tmpRegState[i] == localvar) {
      return i;
    }
  }

  printf("ERROR[CmEnv_using_reg]: No register assigned to var%d\n", localvar);
  exit(1);
}

int CmEnv_get_newreg(int localvar) {
  for (int i=VM_OFFSET_LOCALVAR; i<VM_REG_SIZE; i++) {
    if (CmEnv.tmpRegState[i] == -1) {
      CmEnv.tmpRegState[i] = localvar;
      return i;
    }
  }

  printf("ERROR[CmEnv_get_newreg]: All registers run up.\n");
  exit(1);  
}



int CmEnv_Optimise_check_occurence_in_block(int localvar,
					    int target_imcode_addr) {
  struct IMCode_tag *imcode;

  for (int i=target_imcode_addr+1; i<IMCode_n; i++) {
    imcode = &IMCode[i];
    
    if (imcode->opcode == OP_BEGIN_BLOCK) {
      // This optimisation will last until OP_BEGIN_BLOCK
      return 0;
    }

    switch (imcode->opcode) {
    case OP_MKNAME:
    case OP_MKGNAME:
      break;

    case OP_MKAGENT5:
      // OP_MKAGENT5 id src1 src2 src3 src4 src5 dest
      if (imcode->operand6 == localvar) {
	return 1;
      }
    case OP_MKAGENT4:
      if (imcode->operand5 == localvar) {
	return 1;
      }
    case OP_MKAGENT3:
      if (imcode->operand4 == localvar) {
	return 1;
      }
    case OP_MKAGENT2:
      if (imcode->operand3 == localvar) {
	return 1;
      }
    case OP_MKAGENT1:
      if (imcode->operand2 == localvar) {
	return 1;
      }
    case OP_MKAGENT0:
      break;


    case OP_REUSEAGENT5:
      if (imcode->operand7 == localvar) {
	return 1;
      }
    case OP_REUSEAGENT4:
      if (imcode->operand6 == localvar) {
	return 1;
      }
    case OP_REUSEAGENT3:
      if (imcode->operand5 == localvar) {
	return 1;
      }
    case OP_REUSEAGENT2:
      if (imcode->operand4 == localvar) {
	return 1;
      }
    case OP_REUSEAGENT1:
      if (imcode->operand3 == localvar) {
	return 1;
      }
    case OP_REUSEAGENT0:
      break;


    case OP_PUSH:
    case OP_MYPUSH:
      if (imcode->operand1 == localvar) {
	return 1;
      }
      if (imcode->operand2 == localvar) {
	return 1;
      }
      break;
      
    case OP_JMPEQ0:
    case OP_JMPNEQ0:
    case OP_JMPCNCT_CONS:
    case OP_JMPCNCT:
    case OP_PUSHI:
      if (imcode->operand1 == localvar) {
	return 1;
      }
      break;

    case OP_LOAD:
    case OP_LOADI:
      // OP src1 dest
      if (imcode->operand1 == localvar) {
	return 1;
      }
      break;
      
    case OP_MUL:
    case OP_DIV:
    case OP_MOD:
    case OP_LT:
    case OP_LE:
    case OP_EQ:
    case OP_NE:
    case OP_ADD:
    case OP_SUB:
      // OP src1 src2 dest
      if (imcode->operand1 == localvar) {
	return 1;
      }
      if (imcode->operand2 == localvar) {
	return 1;
      }
      break;

    case OP_ADDI:
    case OP_SUBI:
    case OP_EQI:
      // OP src1 $2 dest
      if (imcode->operand1 == localvar) {
	return 1;
      }
      break;

    case OP_LT_R0:
    case OP_LE_R0:
    case OP_EQ_R0:
    case OP_NE_R0:
      // OP src1 src2
      if (imcode->operand1 == localvar) {
	return 1;
      }
      if (imcode->operand2 == localvar) {
	return 1;
      }
      break;
      
    case OP_EQI_R0:
      // OP src1
      if (imcode->operand1 == localvar) {
	return 1;
      }
      break;
      
    }
    
  }

  return 0;  
    
        
}


void CmEnv_free_reg(int reg) {
  if (reg >= VM_OFFSET_LOCALVAR)
    CmEnv.tmpRegState[reg] = -1;
}



int CmEnv_Optimise_VMCode_CopyPropagation_LOADI(int target_imcode_addr) {

  struct IMCode_tag *imcode;
  int load_i, load_to;

  load_i = IMCode[target_imcode_addr].operand1;
  load_to = IMCode[target_imcode_addr].operand2;

  for (int i=target_imcode_addr+1; i<IMCode_n; i++) {
    imcode = &IMCode[i];    

    if (imcode->opcode == OP_BEGIN_BLOCK) {
      // This optimisation will last until OP_BEGIN_BLOCK
      return 0;
    }
    
    switch (imcode->opcode) {


      
    case OP_PUSH:
      if (imcode->operand1 == load_to) {
	imcode->opcode = OP_PUSHI;
	imcode->operand1 = imcode->operand2;
	imcode->operand2 = load_i;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
      if (imcode->operand2 == load_to) {
	imcode->opcode = OP_PUSHI;
	imcode->operand2 = load_i;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
      break;

      
    case OP_ADD:
      // op src1 src2 dest
      if (imcode->operand1 == load_to) {
	if (load_i == 1) {
	  // OP_INC src2 dest
	  imcode->opcode = OP_INC;
	  imcode->operand1 = imcode->operand2;
	  imcode->operand2 = imcode->operand3;
	} else {
	  imcode->opcode = OP_ADDI;
	  imcode->operand1 = imcode->operand2;
	  imcode->operand2 = load_i;
	}
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }      
      if (imcode->operand2 == load_to) {
	if (load_i == 1) {
	  // OP_INC src1 dest
	  imcode->opcode = OP_INC;
	  imcode->operand2 = imcode->operand3;
	} else {
	  imcode->opcode = OP_ADDI;
	  imcode->operand2 = load_i;
	}
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
      break;

      
    case OP_SUB: 
      // op src1 src2 dest
      if (imcode->operand2 == load_to) {
	if (load_i == 1) {
	  // DEC src1 dest
	  imcode->opcode = OP_DEC;
	  imcode->operand2 = imcode->operand3;
	} else {
	  imcode->opcode = OP_SUBI;
	  imcode->operand2 = load_i;
	}
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
      break;
      
    case OP_EQ:
    case OP_EQ_R0:
      // op src1 src2 dest
      if (imcode->operand1 == load_to) {
	if (imcode->opcode == OP_EQ) {
	  imcode->opcode = OP_EQI;
	} else {
	  imcode->opcode = OP_EQI_R0;
	}	  
	imcode->operand1 = imcode->operand2;
	imcode->operand2 = load_i;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
      if (imcode->operand2 == load_to) {
	if (imcode->opcode == OP_EQ) {
	  imcode->opcode = OP_EQI;
	} else {
	  imcode->opcode = OP_EQI_R0;
	}	  
	imcode->operand2 = load_i;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
      break;
      


    }
    
  }

  return 0;  
  
}



int CmEnv_Optimise_VMCode_CopyPropagation(int target_imcode_addr) {

  struct IMCode_tag *imcode;
  int load_from, load_to;

  load_from = IMCode[target_imcode_addr].operand1;
  load_to = IMCode[target_imcode_addr].operand2;

  // When the given line is: LOAD src src
  if ((load_from == load_to) &&
      (IMCode[target_imcode_addr].opcode == OP_LOAD)) {
    IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
    return 1;
  }
  
  for (int i=target_imcode_addr+1; i<IMCode_n; i++) {
    imcode = &IMCode[i];    

    if (imcode->opcode == OP_BEGIN_BLOCK) {
      // This optimisation will last until OP_BEGIN_BLOCK
      return 0;
    }
    
    switch (imcode->opcode) {

    case OP_MKNAME:
    case OP_MKGNAME:
      break;


    case OP_MKAGENT5:
      if (imcode->operand6 == load_to) {
	imcode->operand6 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
    case OP_MKAGENT4:
      if (imcode->operand5 == load_to) {
	imcode->operand5 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
    case OP_MKAGENT3:
      if (imcode->operand4 == load_to) {
	imcode->operand4 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
    case OP_MKAGENT2:
      if (imcode->operand3 == load_to) {
	imcode->operand3 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
    case OP_MKAGENT1:
      if (imcode->operand2 == load_to) {
	imcode->operand2 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
    case OP_MKAGENT0:
      break;


    case OP_REUSEAGENT5:
      if (imcode->operand7 == load_to) {
	imcode->operand7 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
    case OP_REUSEAGENT4:
      if (imcode->operand6 == load_to) {
	imcode->operand6 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
    case OP_REUSEAGENT3:
      if (imcode->operand5 == load_to) {
	imcode->operand5 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
    case OP_REUSEAGENT2:
      if (imcode->operand4 == load_to) {
	imcode->operand4 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
    case OP_REUSEAGENT1:
      if (imcode->operand3 == load_to) {
	imcode->operand3 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
    case OP_REUSEAGENT0:
      break;



      
    case OP_PUSH:
    case OP_MYPUSH:
      if (imcode->operand1 == load_to) {
	imcode->operand1 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
      if (imcode->operand2 == load_to) {
	imcode->operand2 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
      break;
      
    case OP_JMPEQ0:
    case OP_JMPNEQ0:
    case OP_JMPCNCT_CONS:
    case OP_JMPCNCT:
    case OP_PUSHI:
      if (imcode->operand1 == load_to) {
	imcode->operand1 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
      break;
      
    case OP_MUL:
    case OP_DIV:
    case OP_MOD:
    case OP_LT:
    case OP_LE:
    case OP_EQ:
    case OP_NE:
    case OP_ADD:
    case OP_SUB:
      // op src1 src2 dest
      if (imcode->operand1 == load_to) {
	imcode->operand1 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
      if (imcode->operand2 == load_to) {
	imcode->operand2 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
      break;

    case OP_ADDI:
    case OP_SUBI:
    case OP_EQI:
      // op src1 $2 dest
      if (imcode->operand1 == load_to) {
	imcode->operand1 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
      break;

    case OP_LT_R0:
    case OP_LE_R0:
    case OP_EQ_R0:
    case OP_NE_R0:
      // op src1 src2
      if (imcode->operand1 == load_to) {
	imcode->operand1 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
      if (imcode->operand2 == load_to) {
	imcode->operand2 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
      break;
      
    case OP_EQI_R0:
      // op src1 $2
      if (imcode->operand1 == load_to) {
	imcode->operand1 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
      break;

    case OP_UNM:
    case OP_RAND:
    case OP_INC:
    case OP_DEC:
      // op src dest
      if (imcode->operand1 == load_to) {
	imcode->operand1 = load_from;
	IMCode[target_imcode_addr].opcode = OP_DEAD_CODE;
	return 1;
      }
      break;
      
      
    }
    
  }

  return 0;  
  
}
					   

#define MAX_LABEL 50
#define MAX_BACKPATCH MAX_LABEL*2
int CmEnv_generate_VMCode(void **code) {
  int addr = 0;
  struct IMCode_tag *imcode;

  int label_table[MAX_LABEL];
  int backpatch_num = 0;
  int backpatch_table[MAX_BACKPATCH];

#ifdef OPTIMISE_IMCODE      
  CmEnv_clear_register_assignment_table_all();
#endif	
  
  for (int i=0; i<IMCode_n; i++) {
    imcode = &IMCode[i];    
    
#ifdef OPTIMISE_IMCODE
    // optimisation
    // Copy Propagation for OP_LOAD reg1, reg2 --> [reg2/reg1]
    // and Dead Code Elimination
    if (imcode->opcode == OP_LOAD) {
      if (CmEnv_Optimise_VMCode_CopyPropagation(i)) {
	continue;
      }
    }
    if (imcode->opcode == OP_LOADI) {
      if (CmEnv_Optimise_VMCode_CopyPropagation_LOADI(i)) {
	continue;
      }
    }
#endif    
    
    switch (imcode->opcode) {
    case OP_MKNAME: {
      //      printf("OP_MKNAME var%d\n", imcode->operand1);
      int dest = imcode->operand1;

#ifdef OPTIMISE_IMCODE
      dest = CmEnv_get_newreg(dest);
#endif
      
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)dest;      
      break;
    }
    case OP_MKGNAME: {
      //      printf("OP_MKGNAME sym:%d var%d (as `%s')\n",
      //	     imcode->operand1, imcode->operand2,
      //	     CmEnv.bind[imcode->operand1].name);
      int dest = imcode->operand2;

#ifdef OPTIMISE_IMCODE
      dest = CmEnv_get_newreg(dest);
#endif
      
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)imcode->operand1;
      code[addr++] = (void *)(unsigned long)dest;
      
      break;
    }
      
    case OP_MKAGENT0: {
      //      printf("OP_MKAGENT0 id var%d:%d\n", 
      //	     imcode->operand1, imcode->operand2);
      int dest = imcode->operand2;

#ifdef OPTIMISE_IMCODE
      if (imcode->opcode != OP_REUSEAGENT0)
	dest = CmEnv_get_newreg(dest);
#endif

      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)imcode->operand1;
      code[addr++] = (void *)(unsigned long)dest;
      break;
    }
    case OP_MKAGENT1: {
      //      printf("OP_MKAGENT1 id:%d var%d var%d\n", 
      //	     imcode->operand1, imcode->operand2, imcode->operand3);
      int src1 = imcode->operand2;
      int dest = imcode->operand3;

#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand2, i))
	CmEnv_free_reg(src1);
      
      if (imcode->opcode != OP_REUSEAGENT1)
	dest = CmEnv_get_newreg(dest);
#endif

      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)imcode->operand1;
      code[addr++] = (void *)(unsigned long)src1;      
      code[addr++] = (void *)(unsigned long)dest;      
      break;
    }
    case OP_MKAGENT2: {
      //      printf("OP_MKAGENT2 id:%d var%d var%d var%d\n", 
      //	     imcode->operand1, imcode->operand2,
      //	     imcode->operand3, imcode->operand4);

      int src1 = imcode->operand2;
      int src2 = imcode->operand3;
      int dest = imcode->operand4;


#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand2, i))
	  && (imcode->operand2 != imcode->operand3))
	CmEnv_free_reg(src1);

      src2 = CmEnv_using_reg(src2);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand3, i))
	CmEnv_free_reg(src2);
      
      if (imcode->opcode != OP_REUSEAGENT2)
	dest = CmEnv_get_newreg(dest);
#endif
      
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)imcode->operand1;
      code[addr++] = (void *)(unsigned long)src1;      
      code[addr++] = (void *)(unsigned long)src2;      
      code[addr++] = (void *)(unsigned long)dest;      
      
      break;
    }
    case OP_MKAGENT3: {
      //      printf("OP_MKAGENT3 id:%d var%d var%d var%d var%d \n", 
      //	     imcode->operand1, imcode->operand2,
      //	     imcode->operand3, imcode->operand4, imcode->operand5);
      int src1 = imcode->operand2;
      int src2 = imcode->operand3;
      int src3 = imcode->operand4;
      int dest = imcode->operand5;
      

#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand2, i))
	  && (imcode->operand2 != imcode->operand3)
	  && (imcode->operand2 != imcode->operand4))
	CmEnv_free_reg(src1);
      
      src2 = CmEnv_using_reg(src2);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand3, i))
	  && (imcode->operand3 != imcode->operand4))
	CmEnv_free_reg(src2);
      
      src3 = CmEnv_using_reg(src3);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand4, i))
	CmEnv_free_reg(src3);
	  
      if (imcode->opcode != OP_REUSEAGENT3)
	dest = CmEnv_get_newreg(dest);
#endif
      
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)imcode->operand1;
      code[addr++] = (void *)(unsigned long)src1;      
      code[addr++] = (void *)(unsigned long)src2;            
      code[addr++] = (void *)(unsigned long)src3;      
      code[addr++] = (void *)(unsigned long)dest;      
      
      break;
    }
    case OP_MKAGENT4:  {
      //      printf("OP_MKAGENT3 var%d id:%d var%d var%d var%d var%d\n", 
      //	     imcode->operand1, imcode->operand2,
      //	     imcode->operand3, imcode->operand4, imcode->operand5);
      int src1 = imcode->operand2;
      int src2 = imcode->operand3;
      int src3 = imcode->operand4;
      int src4 = imcode->operand5;
      int dest = imcode->operand6;

#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand2, i))
	  && (imcode->operand2 != imcode->operand3)
	  && (imcode->operand2 != imcode->operand4)
	  && (imcode->operand2 != imcode->operand5))
	CmEnv_free_reg(src1);

      src2 = CmEnv_using_reg(src2);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand3, i))
	  && (imcode->operand3 != imcode->operand4)
	  && (imcode->operand3 != imcode->operand5))
	CmEnv_free_reg(src2);

      src3 = CmEnv_using_reg(src3);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand4, i))
	  && (imcode->operand4 != imcode->operand5))
	CmEnv_free_reg(src3);

      src4 = CmEnv_using_reg(src4);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand5, i))
	CmEnv_free_reg(src4);

      if (imcode->opcode != OP_REUSEAGENT4)
	dest = CmEnv_get_newreg(dest);
#endif

      
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)imcode->operand1;
      code[addr++] = (void *)(unsigned long)src1;      
      code[addr++] = (void *)(unsigned long)src2;            
      code[addr++] = (void *)(unsigned long)src3;      
      code[addr++] = (void *)(unsigned long)src4;      
      code[addr++] = (void *)(unsigned long)dest;      
      break;
    }      
    case OP_MKAGENT5: {
      //      printf("OP_MKAGENT3 var%d id:%d var%d var%d var%d var%d\n", 
      //	     imcode->operand1, imcode->operand2,
      //	     imcode->operand3, imcode->operand4, imcode->operand5);
      int src1 = imcode->operand2;
      int src2 = imcode->operand3;
      int src3 = imcode->operand4;
      int src4 = imcode->operand5;
      int src5 = imcode->operand6;
      int dest = imcode->operand7;

#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand2, i))
	  && (imcode->operand2 != imcode->operand3)
	  && (imcode->operand2 != imcode->operand4)
	  && (imcode->operand2 != imcode->operand5)
	  && (imcode->operand2 != imcode->operand6))
	CmEnv_free_reg(src1);

      src2 = CmEnv_using_reg(src2);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand3, i))
	  && (imcode->operand3 != imcode->operand4)
	  && (imcode->operand3 != imcode->operand5)
	  && (imcode->operand3 != imcode->operand6))
	CmEnv_free_reg(src2);

      src3 = CmEnv_using_reg(src3);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand4, i))
	  && (imcode->operand4 != imcode->operand5)
	  && (imcode->operand4 != imcode->operand6))
	CmEnv_free_reg(src3);

      src4 = CmEnv_using_reg(src4);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand5, i))
	  && (imcode->operand5 != imcode->operand6))
	CmEnv_free_reg(src4);

      src5 = CmEnv_using_reg(src5);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand6, i))
	CmEnv_free_reg(src5);
      
      if (imcode->opcode != OP_REUSEAGENT5)
	dest = CmEnv_get_newreg(dest);
#endif
      
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)imcode->operand1;
      code[addr++] = (void *)(unsigned long)src1;      
      code[addr++] = (void *)(unsigned long)src2;            
      code[addr++] = (void *)(unsigned long)src3;      
      code[addr++] = (void *)(unsigned long)src4;      
      code[addr++] = (void *)(unsigned long)src5;      
      code[addr++] = (void *)(unsigned long)dest;      
      break;
    }      


    case OP_REUSEAGENT0: {
      //      printf("OP_MKAGENT0 var%d id:%d\n", 
      //	     imcode->operand1, imcode->operand2);
      int dest = imcode->operand1;

#ifdef OPTIMISE_IMCODE
      if (imcode->opcode != OP_REUSEAGENT0)
	dest = CmEnv_get_newreg(dest);
#endif

      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)dest;
      code[addr++] = (void *)(unsigned long)imcode->operand2;
      break;
    }
      
    case OP_REUSEAGENT1: {
      //      printf("OP_MKAGENT1 var%d id:%d var%d\n", 
      //	     imcode->operand1, imcode->operand2, imcode->operand3);
      int dest = imcode->operand1;
      int src1 = imcode->operand3;

#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand3, i))
	CmEnv_free_reg(src1);
      
      if (imcode->opcode != OP_REUSEAGENT1)
	dest = CmEnv_get_newreg(dest);
#endif

      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)dest;      
      code[addr++] = (void *)(unsigned long)imcode->operand2;
      code[addr++] = (void *)(unsigned long)src1;      
      break;
    }
      
    case OP_REUSEAGENT2: {
      //      printf("OP_MKAGENT2 var%d id:%d var%d var%d\n", 
      //	     imcode->operand1, imcode->operand2,
      //	     imcode->operand3, imcode->operand4);

      int dest = imcode->operand1;
      int src1 = imcode->operand3;
      int src2 = imcode->operand4;


#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand3, i))
	  && (imcode->operand3 != imcode->operand4))
	CmEnv_free_reg(src1);

      src2 = CmEnv_using_reg(src2);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand4, i))
	CmEnv_free_reg(src2);
      
      if (imcode->opcode != OP_REUSEAGENT2)
	dest = CmEnv_get_newreg(dest);
#endif
      
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)dest;      
      code[addr++] = (void *)(unsigned long)imcode->operand2;
      code[addr++] = (void *)(unsigned long)src1;      
      code[addr++] = (void *)(unsigned long)src2;      
      
      break;
    }
      
    case OP_REUSEAGENT3: {
      //      printf("OP_MKAGENT3 var%d id:%d var%d var%d var%d\n", 
      //	     imcode->operand1, imcode->operand2,
      //	     imcode->operand3, imcode->operand4, imcode->operand5);
      int dest = imcode->operand1;
      int src1 = imcode->operand3;
      int src2 = imcode->operand4;
      int src3 = imcode->operand5;
      

#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand3, i))
	  && (imcode->operand3 != imcode->operand4)
	  && (imcode->operand3 != imcode->operand5))
	CmEnv_free_reg(src1);
      
      src2 = CmEnv_using_reg(src2);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand4, i))
	  && (imcode->operand4 != imcode->operand5))
	CmEnv_free_reg(src2);
      
      src3 = CmEnv_using_reg(src3);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand5, i))
	CmEnv_free_reg(src3);
	  
      if (imcode->opcode != OP_REUSEAGENT3)
	dest = CmEnv_get_newreg(dest);
#endif
      
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)dest;      
      code[addr++] = (void *)(unsigned long)imcode->operand2;
      code[addr++] = (void *)(unsigned long)src1;      
      code[addr++] = (void *)(unsigned long)src2;            
      code[addr++] = (void *)(unsigned long)src3;      
      
      break;
    }
      
    case OP_REUSEAGENT4: {
      //      printf("OP_MKAGENT3 var%d id:%d var%d var%d var%d\n", 
      //	     imcode->operand1, imcode->operand2,
      //	     imcode->operand3, imcode->operand4, imcode->operand5);
      int dest = imcode->operand1;
      int src1 = imcode->operand3;
      int src2 = imcode->operand4;
      int src3 = imcode->operand5;
      int src4 = imcode->operand6;

#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand3, i))
	  && (imcode->operand3 != imcode->operand4)
	  && (imcode->operand3 != imcode->operand5)
	  && (imcode->operand3 != imcode->operand6))
	CmEnv_free_reg(src1);

      src2 = CmEnv_using_reg(src2);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand4, i))
	  && (imcode->operand4 != imcode->operand5)
	  && (imcode->operand4 != imcode->operand6))
	CmEnv_free_reg(src2);

      src3 = CmEnv_using_reg(src3);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand5, i))
	  && (imcode->operand5 != imcode->operand6))
	CmEnv_free_reg(src3);

      src4 = CmEnv_using_reg(src4);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand6, i))
	CmEnv_free_reg(src4);

      if (imcode->opcode != OP_REUSEAGENT4)
	dest = CmEnv_get_newreg(dest);
#endif

      
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)dest;      
      code[addr++] = (void *)(unsigned long)imcode->operand2;
      code[addr++] = (void *)(unsigned long)src1;      
      code[addr++] = (void *)(unsigned long)src2;            
      code[addr++] = (void *)(unsigned long)src3;      
      code[addr++] = (void *)(unsigned long)src4;      
      break;
    }      
    case OP_REUSEAGENT5: {
      //      printf("OP_MKAGENT3 var%d id:%d var%d var%d var%d\n", 
      //	     imcode->operand1, imcode->operand2,
      //	     imcode->operand3, imcode->operand4, imcode->operand5);
      int dest = imcode->operand1;
      int src1 = imcode->operand3;
      int src2 = imcode->operand4;
      int src3 = imcode->operand5;
      int src4 = imcode->operand6;
      int src5 = imcode->operand7;

#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand3, i))
	  && (imcode->operand3 != imcode->operand4)
	  && (imcode->operand3 != imcode->operand5)
	  && (imcode->operand3 != imcode->operand6)
	  && (imcode->operand3 != imcode->operand7))
	CmEnv_free_reg(src1);

      src2 = CmEnv_using_reg(src2);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand4, i))
	  && (imcode->operand4 != imcode->operand5)
	  && (imcode->operand4 != imcode->operand6)
	  && (imcode->operand4 != imcode->operand7))
	CmEnv_free_reg(src2);

      src3 = CmEnv_using_reg(src3);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand5, i))
	  && (imcode->operand5 != imcode->operand6)
	  && (imcode->operand5 != imcode->operand7))
	CmEnv_free_reg(src3);

      src4 = CmEnv_using_reg(src4);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand6, i))
	  && (imcode->operand6 != imcode->operand7))
	CmEnv_free_reg(src4);

      src5 = CmEnv_using_reg(src5);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand7, i))
	CmEnv_free_reg(src5);
      
      if (imcode->opcode != OP_REUSEAGENT5)
	dest = CmEnv_get_newreg(dest);
#endif
      
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)dest;      
      code[addr++] = (void *)(unsigned long)imcode->operand2;
      code[addr++] = (void *)(unsigned long)src1;      
      code[addr++] = (void *)(unsigned long)src2;            
      code[addr++] = (void *)(unsigned long)src3;      
      code[addr++] = (void *)(unsigned long)src4;      
      code[addr++] = (void *)(unsigned long)src5;      
      break;
    }      

      
      
    case OP_LOAD: {
      // OP_LOAD src1 dest
      int src1 = imcode->operand1;
      int dest = imcode->operand2;
      
#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand1, i))
	CmEnv_free_reg(src1);
      
      dest = CmEnv_get_newreg(dest);
#endif
      
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)src1;      
      code[addr++] = (void *)(unsigned long)dest;      
      break;
      
    }

      
    case OP_LOADI: {
      // OP_LOADI int1 dest
      int dest = imcode->operand2;

#ifdef OPTIMISE_IMCODE
      dest = CmEnv_get_newreg(dest);
#endif
      
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)INT2FIX(imcode->operand1);      
      code[addr++] = (void *)(unsigned long)dest;      
      
      break;
    }
      
      
    case OP_PUSH:
    case OP_MYPUSH: {
      //      printf("OP_PUSH var%d var%d\n",
      //	     imcode->operand1, imcode->operand2);
      int src1 = imcode->operand1;
      int src2 = imcode->operand2;
      
      
#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if (imcode->operand1 != imcode->operand2)
	CmEnv_free_reg(src1);
      
      src2 = CmEnv_using_reg(src2);
      CmEnv_free_reg(src2);      
#endif
      
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)src1;      
      code[addr++] = (void *)(unsigned long)src2;      
      
      break;
    }      
    case OP_JMPEQ0:
    case OP_JMPNEQ0:
    case OP_JMPCNCT_CONS: {
      // OP_JMPEQ0 reg label
      int src1 = imcode->operand1;
      
#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand1, i))
	CmEnv_free_reg(src1);
#endif
      
      code[addr++] = CodeAddr[imcode->opcode];      
      code[addr++] = (void *)(unsigned long)src1;      
      // for label
      backpatch_table[backpatch_num++] = addr;
      code[addr++] = (void *)(unsigned long)imcode->operand2;      
      break;
    }
      
    case OP_JMPEQ0_R0: {
      code[addr++] = CodeAddr[imcode->opcode];
      
      // for label
      backpatch_table[backpatch_num++] = addr;
      code[addr++] = (void *)(unsigned long)imcode->operand1;      
      break;
    }      
      
    case OP_ADD:
    case OP_SUB:
    case OP_MUL:
    case OP_DIV:
    case OP_MOD:
    case OP_LT:
    case OP_LE:
    case OP_EQ:
    case OP_NE: {
      // op src1 src2 dest
      int src1 = imcode->operand1;
      int src2 = imcode->operand2;
      int dest = imcode->operand3;
      
#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand1, i))
	  && (imcode->operand1 != imcode->operand2))
	CmEnv_free_reg(src1);
      
      src2 = CmEnv_using_reg(src2);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand2, i))
	CmEnv_free_reg(src2);

      dest = CmEnv_get_newreg(dest);
#endif

      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)src1;      
      code[addr++] = (void *)(unsigned long)src2;      
      code[addr++] = (void *)(unsigned long)dest;      

      break;
    }

    case OP_ADDI:
    case OP_SUBI: {
      // op src1 $2 dest
      int src1 = imcode->operand1;
      int dest = imcode->operand3;

#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand1, i))
	CmEnv_free_reg(src1);

      dest = CmEnv_get_newreg(dest);
#endif
            
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)src1;      
      code[addr++] = (void *)(unsigned long)imcode->operand2;
      code[addr++] = (void *)(unsigned long)dest;      

      break;
    }      


    case OP_EQI: {
      // op src1 int2fix($2) dest
      int src1 = imcode->operand1;
      int dest = imcode->operand3;

#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand1, i))
	CmEnv_free_reg(src1);

      dest = CmEnv_get_newreg(dest);
#endif
            
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)src1;      
      code[addr++] = (void *)INT2FIX(imcode->operand2);
      code[addr++] = (void *)(unsigned long)dest;      

      break;
    }      
      
    case OP_LT_R0:
    case OP_LE_R0:
    case OP_EQ_R0:
    case OP_NE_R0: {
      // op src1 src2
      int src1 = imcode->operand1;
      int src2 = imcode->operand2;

#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand1, i))
	  && (imcode->operand1 != imcode->operand2))
	CmEnv_free_reg(src1);

      src2 = CmEnv_using_reg(src2);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand2, i))
	CmEnv_free_reg(src2);
#endif
	  
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)src1;      
      code[addr++] = (void *)(unsigned long)src2;      
      break;      
    }

    case OP_EQI_R0: {
      // op src1 int2

#ifdef OPTIMISE_IMCODE
      if ((imcode->operand2 == 0) && (IMCode[i+1].opcode == OP_JMPEQ0_R0)) {
	// OP_EQI_Ro reg1 $0
	// OP_JMPEQ0_R0 pc
	// ==>
	// DEAD_CODE
	// OP_JMPNEQ reg1 pc
	IMCode[i+1].opcode = OP_JMPNEQ0;
	IMCode[i+1].operand2 = IMCode[i+1].operand1;
	IMCode[i+1].operand1 = imcode->operand1;
	imcode->opcode = OP_DEAD_CODE;
	break;
      }
#endif

      
      int src1 = imcode->operand1;

#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand1, i))
	CmEnv_free_reg(src1);
#endif

      
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)src1;      
      code[addr++] = (void *)INT2FIX(imcode->operand2);
      break;      
    }
      
    case OP_UNM:
    case OP_INC:
    case OP_DEC:
    case OP_RAND: {
      // op src dest
      int src1 = imcode->operand1;
      int dest = imcode->operand2;

#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand1, i))
	CmEnv_free_reg(src1);

      dest = CmEnv_get_newreg(dest);
#endif

      code[addr++] = CodeAddr[imcode->opcode];      
      code[addr++] = (void *)(unsigned long)src1;      
      code[addr++] = (void *)(unsigned long)dest;      
      break;
    }
      
    case OP_PUSHI: {
      // OP src1 int2
      int src1 = imcode->operand1;

#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand1, i))
	CmEnv_free_reg(src1);
#endif
      
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)src1;      
      // int
      code[addr++] = (void *)INT2FIX(imcode->operand2);      
      
      break;
    }
      

    case OP_RET:
    case OP_RET_FREE_L:
    case OP_RET_FREE_R:
    case OP_RET_FREE_LR:
    case OP_LOOP:
    case OP_NOP:
      code[addr++] = CodeAddr[imcode->opcode];
      break;
      

    case OP_LOOP_RREC1:
    case OP_LOOP_RREC2: {
      //      printf("OP_LOOP_RREC1 var%d\n",
      //	     imcode->operand1);
      int src1 = imcode->operand1;

#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand1, i))
	CmEnv_free_reg(src1);
#endif
            
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)src1;      
      break;
    }
      
    case OP_JMPCNCT: {
      //      printf("OP_JMPCNCT var%d id:%d $%d\n",
      //	     imcode->operand1, imcode->operand2, imcode->operand3);
      int src1 = imcode->operand1;

#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand1, i))
	CmEnv_free_reg(src1);
#endif
      
      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)src1;      
      // int
      code[addr++] = (void *)(unsigned long)imcode->operand2;                  
      code[addr++] = (void *)(unsigned long)imcode->operand3;
      break;
    }
      
    case OP_JMP:
      //      printf("OP_JMP $%d\n",
      //	     imcode->operand1);
      code[addr++] = CodeAddr[imcode->opcode];

      backpatch_table[backpatch_num++] = addr;
      code[addr++] = (void *)(unsigned long)imcode->operand1;            
      break;
      
      
    case OP_CNCTGN:
    case OP_SUBSTGN: {
      //      printf("OP_CNCTGN var%d $%d\n",
      //	     imcode->operand1, imcode->operand2);
      int src1 = imcode->operand1;
      int src2 = imcode->operand2;
      
#ifdef OPTIMISE_IMCODE
      src1 = CmEnv_using_reg(src1);
      if ((!CmEnv_Optimise_check_occurence_in_block(imcode->operand1, i))
	  && (imcode->operand1 != imcode->operand2))
	CmEnv_free_reg(src1);

      src2 = CmEnv_using_reg(src2);
      if (!CmEnv_Optimise_check_occurence_in_block(imcode->operand2, i))
	CmEnv_free_reg(src2);
#endif

      code[addr++] = CodeAddr[imcode->opcode];
      code[addr++] = (void *)(unsigned long)src1;      
      code[addr++] = (void *)(unsigned long)src2;      
      break;
    }

    case OP_DEAD_CODE:
      break;
      
    case OP_BEGIN_BLOCK:
#ifdef OPTIMISE_IMCODE      
      CmEnv_clear_register_assignment_table_all();
#endif	
      break;

    case OP_LABEL:
      if (imcode->operand1 > MAX_LABEL) {
	printf("Critical Error: Label number overfllow.");
	exit(-1);
      }
      label_table[imcode->operand1] = addr;
      break;
      
    default:
      printf("Error[CmEnv_generate_VMCode]: %d does not match any opcode\n",
	     imcode->opcode);
      exit(-1);
    }
  }


  // two pass for label
  for (int i=0; i<backpatch_num; i++) {
    int hole_addr = backpatch_table[i];
    int jmp_label = (unsigned long)code[hole_addr];
    code[hole_addr] = (void *)(unsigned long)
      (label_table[jmp_label]-(hole_addr+1));
  }
    
  return addr;
}


void CopyCode(int byte, void **source, void **target) {
  int i;
  for (i=0; i<byte; i++) {
    target[i]=source[i];
  }
}


void IMCode_puts(int n) {

  static char *string_opcode[] = {
    "OP_PUSH", "OP_PUSHI", "OP_MYPUSH",
    "OP_MKNAME", "OP_MKGNAME",

    "OP_MKAGENT0", "OP_MKAGENT1", "OP_MKAGENT2", "OP_MKAGENT3",
    "OP_MKAGENT4", "OP_MKAGENT5", 

    "OP_REUSEAGENT0", "OP_REUSEAGENT1", "OP_REUSEAGENT2",
    "OP_REUSEAGENT3", "OP_REUSEAGENT4", "OP_REUSEAGENT5", 

    "OP_RET", "OP_RET_FREE_LR", "OP_RET_FREE_L", "OP_RET_FREE_R", 

    "OP_LOADI", "OP_LOAD",

    "OP_ADD", "OP_SUB", "OP_ADDI", "OP_SUBI", "OP_MUL", "OP_DIV", "OP_MOD",
    "OP_LT", "OP_LE", "OP_EQ", "OP_EQI", "OP_NE",
    "OP_UNM", "OP_RAND", "OP_INC", "OP_DEC",

    "OP_LT_R0", "OP_LE_R0", "OP_EQ_R0", "OP_EQI_R0", "OP_NE_R0",
    
    "OP_JMPEQ0", "OP_JMPEQ0_R0", "OP_JMP", "OP_JMPNEQ0",
  
    "OP_JMPCNCT_CONS", "OP_JMPCNCT",
    "OP_LOOP", "OP_LOOP_RREC", "OP_LOOP_RREC1", "OP_LOOP_RREC2", 

    "OP_CNCTGN", "OP_SUBSTGN",

    "OP_NOP",

    "OP_LABEL", "DEAD_CODE", "BEGIN_BLOCK"

    
  };


  struct IMCode_tag *imcode;
  
  puts("[IMCode_puts]");
  if (n==-1) return;

  for (int i=n; i<IMCode_n; i++) {
    imcode = &IMCode[i];    
    printf("%2d: ", i);
    
    switch (imcode->opcode) {
    case OP_MKNAME:
      printf("%s var%d\n", string_opcode[imcode->opcode],
	     imcode->operand1);
      break;

    case OP_MKGNAME:
      printf("%s id:%d var%d; \"%s\"\n", string_opcode[imcode->opcode],
	     imcode->operand1, imcode->operand2,
	     IdTable_get_name(imcode->operand1));
      break;

    case OP_MKAGENT0:
      printf("%s id:%d var%d\n", string_opcode[imcode->opcode],
	     imcode->operand1, imcode->operand2);
      break;

    case OP_MKAGENT1:
      printf("%s id:%d var%d var%d\n", string_opcode[imcode->opcode],
	     imcode->operand1, imcode->operand2, imcode->operand3);
      break;

    case OP_MKAGENT2:
      printf("%s id:%d var%d var%d var%d\n", string_opcode[imcode->opcode],
	     imcode->operand1, imcode->operand2,
	     imcode->operand3, imcode->operand4);
      break;

    case OP_MKAGENT3:
      printf("%s id:%d var%d var%d var%d var%d\n", string_opcode[imcode->opcode],
	     imcode->operand1, imcode->operand2,
	     imcode->operand3, imcode->operand4, imcode->operand5);
      break;

    case OP_MKAGENT4:
      printf("%s id:%d var%d var%d var%d var%d var%d \n", string_opcode[imcode->opcode],
	     imcode->operand1, imcode->operand2,
	     imcode->operand3, imcode->operand4, imcode->operand5,
	     imcode->operand6);
      break;

    case OP_MKAGENT5:
      printf("%s id:%d var%d var%d var%d var%d var%d var%d \n", string_opcode[imcode->opcode],
	     imcode->operand1, imcode->operand2,
	     imcode->operand3, imcode->operand4, imcode->operand5,
	     imcode->operand6, imcode->operand7);
      break;

      
    case OP_REUSEAGENT0:
      printf("%s var%d id:%d\n", string_opcode[imcode->opcode],
	     imcode->operand1, imcode->operand2);
      break;

    case OP_REUSEAGENT1:
      printf("%s var%d id:%d var%d\n", string_opcode[imcode->opcode],
	     imcode->operand1, imcode->operand2, imcode->operand3);
      break;

    case OP_REUSEAGENT2:
      printf("%s var%d id:%d var%d var%d\n", string_opcode[imcode->opcode],
	     imcode->operand1, imcode->operand2,
	     imcode->operand3, imcode->operand4);
      break;

    case OP_REUSEAGENT3:
      printf("%s var%d id:%d var%d var%d var%d\n", string_opcode[imcode->opcode],
	     imcode->operand1, imcode->operand2,
	     imcode->operand3, imcode->operand4, imcode->operand5);
      break;

    case OP_REUSEAGENT4:
      printf("%s var%d id:%d var%d var%d var%d var%d\n", string_opcode[imcode->opcode],
	     imcode->operand1, imcode->operand2,
	     imcode->operand3, imcode->operand4, imcode->operand5,
	     imcode->operand6);
      break;

    case OP_REUSEAGENT5:
      printf("%s var%d id:%d var%d var%d var%d var%d var%d\n", string_opcode[imcode->opcode],
	     imcode->operand1, imcode->operand2,
	     imcode->operand3, imcode->operand4, imcode->operand5,
	     imcode->operand6, imcode->operand7);
      break;


    case OP_LABEL:
      printf(":LABEL%d\n",
	     imcode->operand1);
      break;

      
      // 0 arity: opcode    
    case OP_RET:
    case OP_RET_FREE_L:
    case OP_RET_FREE_R:
    case OP_RET_FREE_LR:
    case OP_LOOP:
    case OP_NOP:
    case OP_DEAD_CODE:
    case OP_BEGIN_BLOCK:
      printf("%s\n", string_opcode[imcode->opcode]);
      break;

      
      // 1 arity: opcode var1
    case OP_LOOP_RREC1:
    case OP_LOOP_RREC2:
      printf("%s var%d\n", string_opcode[imcode->opcode],
	     imcode->operand1);
      break;

            
      // arity is 2: opcode var1 var2
    case OP_UNM:
    case OP_INC:
    case OP_DEC:
    case OP_RAND:
    case OP_PUSH:
    case OP_MYPUSH:
    case OP_LOAD:
    case OP_LT_R0:
    case OP_LE_R0:
    case OP_EQ_R0:
    case OP_NE_R0:
    case OP_CNCTGN:
    case OP_SUBSTGN:
      printf("%s var%d var%d\n", string_opcode[imcode->opcode],
	     imcode->operand1, imcode->operand2);
      break;


      // arity is 2: opcode var1 $2
    case OP_PUSHI:
    case OP_LOADI:
    case OP_LOOP_RREC:
    case OP_EQI_R0:
      printf("%s $%d var%d\n", string_opcode[imcode->opcode],
	     imcode->operand1, imcode->operand2);
      break;


      // arity is 3: opcode var1 var2 var3
    case OP_ADD:
    case OP_SUB:
    case OP_MUL:
    case OP_DIV:
    case OP_MOD:
    case OP_LT:
    case OP_LE:
    case OP_EQ:
    case OP_NE:
      printf("%s var%d var%d var%d\n", string_opcode[imcode->opcode],
	     imcode->operand1, imcode->operand2, imcode->operand3);
      break;
      
      
      // arity is 3: opcode var1 var2 $3
    case OP_ADDI:
    case OP_SUBI:
    case OP_EQI:
      printf("%s var%d $%d var%d\n", string_opcode[imcode->opcode],
	     imcode->operand1, imcode->operand2, imcode->operand3);
      break;


      // arity is 2: opcode var1 LABEL2
    case OP_JMPEQ0:
    case OP_JMPNEQ0:
    case OP_JMPCNCT_CONS:
      printf("%s var%d LABEL%d\n", string_opcode[imcode->opcode],
	     imcode->operand1, imcode->operand2);
      break;

      
      // arity is 3: opcode var1 id2 LABEL3
    case OP_JMPCNCT:
      printf("%s var%d id:%d LABEL%d\n", string_opcode[imcode->opcode],
	     imcode->operand1, imcode->operand2, imcode->operand3);

      
      // others      
    case OP_JMPEQ0_R0:
      printf("OP_JMPEQ0_RO LABEL%d\n",
	     imcode->operand1);
      break;
      
            
    case OP_JMP:
      printf("OP_JMP LABEL%d\n",
	     imcode->operand1);
      break;
      
            
    default:
      printf("CODE %d %d %d %d %d %d\n",
	     imcode->operand1, imcode->operand2, imcode->operand3, 
	     imcode->operand4, imcode->operand5, imcode->operand6);
    }
  }
}



void VMCode_puts(void **code, int n) {
  
  puts("[PutsCode]");
  if (n==-1) n = MAX_CODE_SIZE;
  
  for (int i=0; i<n; i++) {
    printf("%2d: ", i);
    
    if (code[i] == CodeAddr[OP_MKNAME]) {
      printf("mkname reg%lu\n",
	     (unsigned long)code[i+1]);
      i+=1;
      
    } else if (code[i] == CodeAddr[OP_MKGNAME]) {
      printf("mkgname id:%lu reg%lu; \"%s\"\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2],
	     IdTable_get_name((unsigned long)code[i+1]));
      i+=2;

    } else if (code[i] == CodeAddr[OP_MKAGENT0]) {
      printf("mkagent0 id:%lu reg%lu\n", 
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;

    } else if (code[i] == CodeAddr[OP_MKAGENT1]) {
      printf("mkagent1 id:%lu reg%lu reg%lu\n", 
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2],
	     (unsigned long)code[i+3]);
      i+=3;

    } else if (code[i] == CodeAddr[OP_MKAGENT2]) {
      printf("mkagent2 id:%lu reg%lu reg%lu reg%lu\n", 
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2],
	     (unsigned long)code[i+3],
	     (unsigned long)code[i+4]);
      i+=4;

    } else if (code[i] == CodeAddr[OP_MKAGENT3]) {
      printf("mkagent3 id:%lu reg%lu reg%lu reg%lu reg%lu\n", 
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2],
	     (unsigned long)code[i+3],
	     (unsigned long)code[i+4],
	     (unsigned long)code[i+5]);
      i+=5;

    } else if (code[i] == CodeAddr[OP_MKAGENT4]) {
      printf("mkagent4 id:%lu reg%lu reg%lu reg%lu reg%lu reg%lu\n", 
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2],
	     (unsigned long)code[i+3],
	     (unsigned long)code[i+4],
	     (unsigned long)code[i+5],
	     (unsigned long)code[i+6]);
      i+=6;

    } else if (code[i] == CodeAddr[OP_MKAGENT5]) {
      printf("mkagent5 id:%lu reg%lu reg%lu reg%lu reg%lu reg%lu reg%lu\n", 
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2],
	     (unsigned long)code[i+3],
	     (unsigned long)code[i+4],
	     (unsigned long)code[i+5],
	     (unsigned long)code[i+6],
	     (unsigned long)code[i+7]);
      i+=7;
      
    } else if (code[i] == CodeAddr[OP_REUSEAGENT0]) {
      printf("reuseagent0 reg%lu as id=%lu", 
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      puts("");
      i+=2;

    } else if (code[i] == CodeAddr[OP_REUSEAGENT1]) {
      printf("reuseagent0 reg%lu as id=%lu", 
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      printf(" reg%lu", (unsigned long)code[i+3]);
      puts("");
      i+=3;
      
    } else if (code[i] == CodeAddr[OP_REUSEAGENT2]) {
      printf("reuseagent2 reg%lu as id=%lu", 
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      printf(" reg%lu", (unsigned long)code[i+3]);
      printf(" reg%lu", (unsigned long)code[i+4]);
      puts("");
      i+=4;

    } else if (code[i] == CodeAddr[OP_REUSEAGENT3]) {
      printf("reuseagent3 reg%lu as id=%lu", 
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      printf(" reg%lu", (unsigned long)code[i+3]);
      printf(" reg%lu", (unsigned long)code[i+4]);
      printf(" reg%lu", (unsigned long)code[i+5]);
      puts("");
      i+=5;
      
    } else if (code[i] == CodeAddr[OP_REUSEAGENT4]) {
      printf("reuseagent4 reg%lu as id=%lu", 
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      printf(" reg%lu", (unsigned long)code[i+3]);
      printf(" reg%lu", (unsigned long)code[i+4]);
      printf(" reg%lu", (unsigned long)code[i+5]);
      printf(" reg%lu", (unsigned long)code[i+6]);
      puts("");
      i+=6;

    } else if (code[i] == CodeAddr[OP_REUSEAGENT5]) {
      printf("reuseagent5 reg%lu as id=%lu", 
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      printf(" reg%lu", (unsigned long)code[i+3]);
      printf(" reg%lu", (unsigned long)code[i+4]);
      printf(" reg%lu", (unsigned long)code[i+5]);
      printf(" reg%lu", (unsigned long)code[i+6]);
      printf(" reg%lu", (unsigned long)code[i+7]);
      puts("");
      i+=7;
      
    } else if (code[i] == CodeAddr[OP_PUSH]) {
      printf("push reg%lu reg%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;

    } else if (code[i] == CodeAddr[OP_PUSHI]) {
      printf("pushi reg%lu $%d\n",
	     (unsigned long)code[i+1],
	     FIX2INT((unsigned long)code[i+2]));
      i+=2;

    } else if (code[i] == CodeAddr[OP_MYPUSH]) {
      printf("mypush reg%lu reg%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;

    } else if (code[i] == CodeAddr[OP_RET]) {
      puts("ret");

    } else if (code[i] == CodeAddr[OP_RET_FREE_L]) {
      puts("ret_free_l");

    } else if (code[i] == CodeAddr[OP_RET_FREE_R]) {
      puts("ret_free_r");

    } else if (code[i] == CodeAddr[OP_RET_FREE_LR]) {
      puts("ret_free_lr");

    } else if (code[i] == CodeAddr[OP_LOADI]) {
      printf("loadi $%d reg%lu\n",
	     FIX2INT((unsigned long)code[i+1]),
	     (unsigned long)code[i+2]);
      i+=2;
      
    } else if (code[i] == CodeAddr[OP_LOOP]) {
      puts("loop\n");

    } else if (code[i] == CodeAddr[OP_LOOP_RREC]) {
      printf("loop_rrec reg%lu $%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;

    } else if (code[i] == CodeAddr[OP_LOOP_RREC1]) {
      printf("loop_rrec1 reg%lu\n",
	     (unsigned long)code[i+1]);
      i+=1;

    } else if (code[i] == CodeAddr[OP_LOOP_RREC2]) {
      printf("loop_rrec2 reg%lu\n",
	     (unsigned long)code[i+1]);
      i+=1;

    } else if (code[i] == CodeAddr[OP_LOAD]) {
      printf("load reg%lu reg%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;


    } else if (code[i] == CodeAddr[OP_ADD]) {
      printf("add reg%lu reg%lu reg%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2],
	     (unsigned long)code[i+3]);
      i+=3;

    } else if (code[i] == CodeAddr[OP_SUB]) {
      printf("sub reg%lu reg%lu reg%lu\n", 
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2],
	     (unsigned long)code[i+3]);
      i+=3;

    } else if (code[i] == CodeAddr[OP_ADDI]) {
      printf("addi reg%lu $%lu reg%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2],
	     (unsigned long)code[i+3]);
      i+=3;
    } else if (code[i] == CodeAddr[OP_SUBI]) {
      printf("subi reg%lu $%lu reg%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2],
	     (unsigned long)code[i+3]);
      i+=3;

    } else if (code[i] == CodeAddr[OP_MUL]) {
      printf("mul reg%lu reg%lu reg%lu\n", 
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2],
	     (unsigned long)code[i+3]);
      i+=3;

    } else if (code[i] == CodeAddr[OP_DIV]) {
      printf("div reg%lu reg%lu reg%lu\n", 
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2],
	     (unsigned long)code[i+3]);
      i+=3;

    } else if (code[i] == CodeAddr[OP_MOD]) {
      printf("mod reg%lu reg%lu reg%lu\n", 
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2],
	     (unsigned long)code[i+3]);
      i+=3;

    } else if (code[i] == CodeAddr[OP_LT]) {
      printf("lt reg%lu reg%lu reg%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2],
	     (unsigned long)code[i+3]);
      i+=3;

    } else if (code[i] == CodeAddr[OP_EQ]) {
      printf("eq reg%lu reg%lu reg%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2],
	     (unsigned long)code[i+3]);
      i+=3;

    } else if (code[i] == CodeAddr[OP_EQI]) {
      printf("eqi reg%lu $%d reg%lu\n",
	     (unsigned long)code[i+1],
	     FIX2INT((unsigned long)code[i+2]),
	     (unsigned long)code[i+3]);
      i+=3;

    } else if (code[i] == CodeAddr[OP_NE]) {
      printf("ne reg%lu reg%lu reg%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2],
	     (unsigned long)code[i+3]);
      i+=3;
      
    } else if (code[i] == CodeAddr[OP_LT_R0]) {
      printf("lt_r0 reg%lu reg%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;

    } else if (code[i] == CodeAddr[OP_LE_R0]) {
      printf("le_r0 reg%lu reg%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;

    } else if (code[i] == CodeAddr[OP_EQ_R0]) {
      printf("eq_r0 reg%lu reg%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;

    } else if (code[i] == CodeAddr[OP_EQI_R0]) {
      printf("eqi_r0 reg%lu $%d\n",
	     (unsigned long)code[i+1],
	     FIX2INT((unsigned long)code[i+2]));
      i+=2;

    } else if (code[i] == CodeAddr[OP_NE_R0]) {
      printf("ne_r0 reg%lu reg%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;

    } else if (code[i] == CodeAddr[OP_JMPNEQ0]) {
      printf("jmpneq0 reg%lu $%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;

    } else if (code[i] == CodeAddr[OP_JMPEQ0]) {
      printf("jmpeq0 reg%lu $%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;

    } else if (code[i] == CodeAddr[OP_JMPEQ0_R0]) {
      printf("jmpeq0_r0 $%lu\n",
	     (unsigned long)code[i+1]);
      i+=1;

    } else if (code[i] == CodeAddr[OP_JMPCNCT_CONS]) {
      printf("jmpcnct_cons reg%lu $%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;

    } else if (code[i] == CodeAddr[OP_JMPCNCT]) {
      printf("jmpcnct reg%lu $%lu $%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2],
	     (unsigned long)code[i+3]);
      i+=3;

    } else if (code[i] == CodeAddr[OP_JMP]) {
      printf("jmp $%lu\n", (unsigned long)code[i+1]);
      i+=1;

    } else if (code[i] == CodeAddr[OP_UNM]) {
      printf("unm reg%lu reg%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;

    } else if (code[i] == CodeAddr[OP_INC]) {
      printf("inc reg%lu reg%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;

    } else if (code[i] == CodeAddr[OP_DEC]) {
      printf("dec reg%lu reg%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;

    } else if (code[i] == CodeAddr[OP_RAND]) {
      printf("rnd reg%lu reg%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;

    } else if (code[i] == CodeAddr[OP_CNCTGN]) {
      printf("cnctgn reg%lu reg%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;

    } else if (code[i] == CodeAddr[OP_SUBSTGN]) {
      printf("substgn reg%lu reg%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;

    } else if (code[i] == CodeAddr[OP_NOP]) {
      puts("nop");

    } else {
      printf("code %lu\n", (unsigned long)code[i]);      
    }
  }
}




int is_expr(Ast *ptr) {

  if (ptr == NULL) {
    return 0;
  }

  switch (ptr->id) {
  case AST_INT:
    return 1;
    break;

  case AST_NAME: {
    NB_TYPE type;
    int result = CmEnv_gettype_forname(ptr->left->sym, &type);
    if (result == 0) {
      return 9;
    }
    if (type != NB_INTVAR) {
      return 0;
    }

    return 1;
    break;
  }
    
  case AST_RAND: 
  case AST_UNM: {
    if (!is_expr(ptr->left)) return 0;

    return 1;
    break;
  }
    
  case AST_PLUS: 
  case AST_SUB:
  case AST_MUL:
  case AST_DIV:
  case AST_MOD:
  case AST_LT:
  case AST_LE:
  case AST_EQ:
  case AST_NE: {
    if (!is_expr(ptr->left)) return 0;
    if (!is_expr(ptr->right)) return 0;

    return 1;
    break;
  }
  default:
    return 0;
  }
}



int CompileExprFromAst(Ast *ptr, int target) {
  
  if (ptr == NULL) {
    return 1;
  }

  switch (ptr->id) {
  case AST_INT:
    IMCode_genCode2(OP_LOADI, ptr->intval, target);
    return 1;
    break;

  case AST_NAME: {
    int result = CmEnv_find_var(ptr->left->sym);
    if (result == -1) {
      //      result=CmEnv_set_as_INTVAR(ptr->left->sym);
      printf("ERROR: '%s' has not been defined previously.\n",
	     ptr->left->sym);
      return 0;
    }
    
    IMCode_genCode2(OP_LOAD, result, target);
    return 1;
    break;
  }
  case AST_RAND: {
    int newreg = CmEnv_newvar();
    if (!CompileExprFromAst(ptr->left, newreg)) return 0;
    
    IMCode_genCode2(OP_RAND, newreg, target);
    return 1;
    break;
  }
  case AST_UNM: {
    int newreg = CmEnv_newvar();
    if (!CompileExprFromAst(ptr->left, newreg)) return 0;
    
    IMCode_genCode2(OP_UNM, newreg, target);
    return 1;
    break;
  }
  case AST_PLUS: 
  case AST_SUB:
  case AST_MUL:
  case AST_DIV:
  case AST_MOD:
  case AST_LT:
  case AST_LE:
  case AST_EQ:
  case AST_NE: {
    int newreg = CmEnv_newvar();
    int newreg2 = CmEnv_newvar();
    if (!CompileExprFromAst(ptr->left, newreg)) return 0;
    if (!CompileExprFromAst(ptr->right, newreg2)) return 0;

    int opcode;
    switch (ptr->id) {
    case AST_PLUS:
      opcode = OP_ADD;
      break;
    case AST_SUB:
      opcode = OP_SUB;
      break;
    case AST_MUL:
      opcode = OP_MUL;
      break;
    case AST_DIV:
      opcode = OP_DIV;
      break;
    case AST_MOD:
      opcode = OP_MOD;
      break;
    case AST_LT:
      opcode = OP_LT;
      break;
    case AST_LE:
      opcode = OP_LE;
      break;
    case AST_EQ:
      opcode = OP_EQ;
      break;
    case AST_NE:
      opcode = OP_NE;
      break;
    default:
      opcode = OP_MOD;
    }
    
    IMCode_genCode3(opcode, newreg, newreg2, target);   
    return 1;
    break;
  }
  case AST_AND: {
    // compilation of expr1 && expr2

    // if (expr1 == 0) goto L1;
    // if (expr2 == 0) goto L1;
    // target = 1;
    // goto L2;
    // L1:
    // target = 0;
    // L2;
    
    int newreg = CmEnv_newvar();
    if (!CompileExprFromAst(ptr->left, newreg)) return 0;
    
    int label1 = CmEnv_get_newlabel();
    IMCode_genCode2(OP_JMPEQ0, newreg, label1);

    int newreg2 = CmEnv_newvar();
    if (!CompileExprFromAst(ptr->right, newreg2)) return 0;
    IMCode_genCode2(OP_JMPEQ0, newreg2, label1);

    IMCode_genCode2(OP_LOADI, 1, target);
    
    int label2 = CmEnv_get_newlabel();
    IMCode_genCode1(OP_JMP, label2);

    IMCode_genCode1(OP_LABEL, label1);
    IMCode_genCode2(OP_LOADI, 0, target);
    
    IMCode_genCode1(OP_LABEL, label2);

    return 1;
    break;
  }
  case AST_OR: {
    // compilation of expr1 || expr2

    // calc expr1
    // if (expr1 != 0) goto L1;
    // if (expr2 != 0) goto L1;
    // target = 0;
    // goto L2;
    // L1:
    // target = 1;
    // L2;
    
    int newreg = CmEnv_newvar();
    if (!CompileExprFromAst(ptr->left, newreg)) return 0;
    
    int label1 = CmEnv_get_newlabel();
    IMCode_genCode2(OP_JMPNEQ0, newreg, label1);

    int newreg2 = CmEnv_newvar();
    if (!CompileExprFromAst(ptr->right, newreg2)) return 0;
    IMCode_genCode2(OP_JMPNEQ0, newreg2, label1);

    IMCode_genCode2(OP_LOADI, 0, target);
    
    int label2 = CmEnv_get_newlabel();
    IMCode_genCode1(OP_JMP, label2);

    IMCode_genCode1(OP_LABEL, label1);
    IMCode_genCode2(OP_LOADI, 1, target);
    
    IMCode_genCode1(OP_LABEL, label2);

    return 1;
    break;
  }
  case AST_NOT: {
    // compilation of !(expr1)
    // if (expr1 == 0) goto L1;
    // target = 0;
    // goto L2;
    // L1:
    // target = 1;
    // L2;
    
    int newreg = CmEnv_newvar();
    if (!CompileExprFromAst(ptr->left, newreg)) return 0;
    
    int label1 = CmEnv_get_newlabel();
    IMCode_genCode2(OP_JMPEQ0, newreg, label1);

    IMCode_genCode2(OP_LOADI, 0, target);
    
    int label2 = CmEnv_get_newlabel();
    IMCode_genCode1(OP_JMP, label2);

    IMCode_genCode1(OP_LABEL, label1);
    IMCode_genCode2(OP_LOADI, 1, target);
    
    IMCode_genCode1(OP_LABEL, label2);

    return 1;
    break;
  }
    
  default:
    puts("System ERROR: Wrong AST was given to CompileExpr.\n");
    return 0;

  }

}

// Rule や eq の中の term をコンパイルするときに使う
int CompileTermFromAst(Ast *ptr, int target) {
  // input:
  // target == -1  => a new node is allocated from localHeap.
  //   otherwise   => a node specified by the `target' is reused as a new node.
  //
  // output:
  // return: offset in localHeap

  int result, mkagent;
  int i, arity;

  int alloc[MAX_PORT];
  
  if (ptr == NULL) {
    return -1;
  }

  switch (ptr->id) {
  case AST_NAME:
    
    result = CmEnv_find_var(ptr->left->sym);
    if (result == -1) {
      result=CmEnv_set_symbol_as_name(ptr->left->sym);
      IMCode_genCode1(OP_MKNAME, result);    
    }
    return result;
    break;

  case AST_INT:
    result = CmEnv_newvar();
    
    IMCode_genCode2(OP_LOADI, ptr->intval, result);
    return result;
    break;

  case AST_NIL:
    if (target == -1) {      
      result = CmEnv_newvar();
      mkagent = OP_MKAGENT0;
      IMCode_genCode2(mkagent, ID_NIL, result);
    } else {
      result = target;
      mkagent = OP_REUSEAGENT0;
      IMCode_genCode2(mkagent, result, ID_NIL);
    }

    return result;
    break;

    
  case AST_CONS:
    alloc[0] = CompileTermFromAst(ptr->left, -1);
    alloc[1] = CompileTermFromAst(ptr->right, -1);
    
    if (target == -1) {      
      result = CmEnv_newvar();
      mkagent = OP_MKAGENT2;
      IMCode_genCode4(mkagent, ID_CONS, alloc[0], alloc[1], result);
    } else {
      result = target;
      mkagent = OP_REUSEAGENT2;
      IMCode_genCode4(mkagent, result, ID_CONS, alloc[0], alloc[1]);
    }
    
    return result;
    break;

    
  case AST_OPCONS:
    ptr = ptr->right;
    alloc[0] = CompileTermFromAst(ptr->left, -1);
    alloc[1] = CompileTermFromAst(ptr->right->left, -1);
    
    if (target == -1) {      
      result = CmEnv_newvar();
      mkagent = OP_MKAGENT2;
      IMCode_genCode4(mkagent, ID_CONS, alloc[0], alloc[1], result);
    } else {
      result = target;
      mkagent = OP_REUSEAGENT2;
      IMCode_genCode4(mkagent, result, ID_CONS, alloc[0], alloc[1]);
    }

    return result;
    break;


    
  case AST_TUPLE:
    arity = ptr->intval;

    if (arity == 1) {      
      // The case of the single tuple such as `(A)'.
      // The `A' is recognised as not an argument, but as a first-class object.
      ptr=ptr->right;
      alloc[0] = CompileTermFromAst(ptr->left, target);      
      result = alloc[0];
      
    } else {      
      // normal case
      ptr=ptr->right;
      for(i=0; i< arity; i++) {
	alloc[i] = CompileTermFromAst(ptr->left, -1);
	ptr = ast_getTail(ptr);
      }

      if (target == -1) {      
	result = CmEnv_newvar();
      } else {
	result = target;
      }
          
      switch (arity) {
      case 0:
	if (target == -1) {
	  mkagent = OP_MKAGENT0;
	  IMCode_genCode2(mkagent, GET_TUPLEID(arity), result);
	} else {
	  mkagent = OP_REUSEAGENT0;
	  IMCode_genCode2(mkagent, result, GET_TUPLEID(arity));
	}
	break;
      
      
      case 2:
	if (target == -1) {
	  mkagent = OP_MKAGENT2;
	  IMCode_genCode4(mkagent, GET_TUPLEID(arity),
			  alloc[0], alloc[1], result);
	} else {
	  mkagent = OP_REUSEAGENT2;
	  IMCode_genCode4(mkagent, result, GET_TUPLEID(arity),
			  alloc[0], alloc[1]);
	}
	break;
      
      case 3:
	if (target == -1) {
	  mkagent = OP_MKAGENT3;
	  IMCode_genCode5(mkagent, GET_TUPLEID(arity),
			  alloc[0], alloc[1], alloc[2], result);
	} else {
	  mkagent = OP_REUSEAGENT3;
	  IMCode_genCode5(mkagent, result, GET_TUPLEID(arity),
			  alloc[0], alloc[1], alloc[2]);
	}
	break;
      
      case 4:
	if (target == -1) {
	  mkagent = OP_MKAGENT4;
	  IMCode_genCode6(mkagent, GET_TUPLEID(arity),
			  alloc[0], alloc[1], alloc[2], alloc[3], result);
	} else {
	  mkagent = OP_REUSEAGENT4;
	  IMCode_genCode6(mkagent, result, GET_TUPLEID(arity),
			  alloc[0], alloc[1], alloc[2], alloc[3]);
	}
	break;
      
      default:
	if (target == -1) {
	  mkagent = OP_MKAGENT5;
	  IMCode_genCode7(mkagent, GET_TUPLEID(arity),
			  alloc[0], alloc[1], alloc[2], alloc[3], alloc[4],
			  result);
	} else {
	  mkagent = OP_REUSEAGENT5;
	  IMCode_genCode7(mkagent, result, GET_TUPLEID(arity),
			  alloc[0], alloc[1], alloc[2], alloc[3], alloc[4]);
	}
      
      }
      
    }
    
    return result;
    break;

    
    
  case AST_AGENT:

    if (target == -1) {      
      result = CmEnv_newvar();
    } else {
      result = target;
    }
    
    int id = IdTable_getid_builtin_funcAgent(ptr);
    if (id == -1) {
      id = NameTable_get_set_id_with_IdTable_forAgent((char *)ptr->left->sym);
    }

    arity=0;
    ptr=ptr->right;
    for(i=0; i< MAX_PORT; i++) {
      if (ptr == NULL) break;
      alloc[i] = CompileTermFromAst(ptr->left, -1);
      arity++;
      ptr = ast_getTail(ptr);
    }
    
    IdTable_set_arity(id, arity);

    switch (arity) {
    case 0:
      if (target == -1) {
	mkagent = OP_MKAGENT0;
	IMCode_genCode2(mkagent, id, result);
      } else {
	mkagent = OP_REUSEAGENT0;
	IMCode_genCode2(mkagent, result, id);
      }
      break;
      
    case 1:
      if (target == -1) {
	mkagent = OP_MKAGENT1;
	IMCode_genCode3(mkagent, id, alloc[0], result);
      } else {
	mkagent = OP_REUSEAGENT1;
	IMCode_genCode3(mkagent, result, id, alloc[0]);
      }
      break;
      
    case 2:
      if (target == -1) {
	mkagent = OP_MKAGENT2;
	IMCode_genCode4(mkagent, id, alloc[0], alloc[1], result);
      } else {
	mkagent = OP_REUSEAGENT2;
	IMCode_genCode4(mkagent, result, id, alloc[0], alloc[1]);
      }
      break;
      
    case 3:
      if (target == -1) {
	mkagent = OP_MKAGENT3;
	IMCode_genCode5(mkagent, id, alloc[0], alloc[1], alloc[2], result);
      } else {
	mkagent = OP_REUSEAGENT3;
	IMCode_genCode5(mkagent, result, id, alloc[0], alloc[1], alloc[2]);
      }
      break;

    case 4:
      if (target == -1) {
	mkagent = OP_MKAGENT4;
	IMCode_genCode6(mkagent, id, alloc[0], alloc[1], alloc[2],
			alloc[3], result);
      } else {
	mkagent = OP_REUSEAGENT4;
	IMCode_genCode6(mkagent, result, id, alloc[0], alloc[1], alloc[2],
			alloc[3]);
      }
      break;
      
    default:
      if (target == -1) {
	mkagent = OP_MKAGENT5;
	IMCode_genCode7(mkagent, id, alloc[0], alloc[1], alloc[2],
			alloc[3], alloc[4], result);
      } else {
	mkagent = OP_REUSEAGENT5;
	IMCode_genCode7(mkagent, result, id, alloc[0], alloc[1], alloc[2],
			alloc[3], alloc[4]);
      }
      break;
    }
    
    return result;
    break;

    
  case AST_ANNOTATION_L:
  case AST_ANNOTATION_R:
    if (ptr->id == AST_ANNOTATION_L) {
      CmEnv.annotateL = ANNOTATE_REUSE; // *L が出現したことを示す
      result = CmEnv.reg_agentL; //VM_OFFSET_ANNOTATE_L;
    } else {
      CmEnv.annotateR = ANNOTATE_REUSE; // *L が出現したことを示す
      result = CmEnv.reg_agentR; // VM_OFFSET_ANNOTATE_R;
    }

    
    result = CompileTermFromAst(ptr->left, result);
    return result;
    break;

    

  default:
    // expression case
    result = CmEnv_newvar();    
    int compile_result = CompileExprFromAst(ptr, result);
    if (compile_result != 0) {
      return result;
    } else {
      puts("ERROR: something strange in CompileTermFromAst.");
      ast_puts(ptr);
      exit(1);      
    }
  }

}




// rule の中の eqs をコンパイルするときに使う
// この関数が呼ばれる前に、rule agents の meta names は
// Environment に積まれている。
int check_invalid_occurrence_as_rule(Ast *ast) {
  NB_TYPE type;

  if (ast->id == AST_NAME) {

    if (CmEnv_gettype_forname(ast->left->sym, &type)) {
      /*
      if (type == NB_INTVAR) {
	printf("ERROR: The variable '%s' for an integer cannot be used as an agent ",
	       ast->left->sym);
	return 0;
      }
      */
    } else {
      //      printf("ERROR: The name '%s' is not bound ", ast->left->sym);
      //      return 0;
    }
  } else if (ast->id == AST_INT) {
    //    printf("ERROR: The integer '%d' is used as an agent ",
    //	   ast->intval);
    //    return 0;
  }

  return 1;
}


int check_invalid_occurrence(Ast *ast) {
  // communication with global names
  int count;

  if (ast->id == AST_NAME) {
    int sym_id = NameTable_get_id(ast->left->sym);

    
    if (IS_GNAMEID(sym_id)) {
      // already exists as a global
      VALUE aheap = IdTable_get_heap(sym_id);

      /*
      // it is connected with something.
      if (NAME(aheap)->port != (VALUE)NULL) {
	printf("ERROR: '%s' is already connected with ", sym);
	puts_term(NAME(aheap)->port);
	puts(".");
	return 1;
      }
      */
	
      count = keynode_exists_in_another_term(aheap, NULL);
      if (count == 2) {
	// already twice
	printf("ERROR: '%s' occurs twice already. \n", ast->left->sym);
	printf("        Use 'ifce' command to see the occurrence.\n");
	return 1;	    
      }	  
      
    }
  }
    
  
  return 0;
}



int CompileEQListFromAst(Ast *at) {
  int t1,t2;
  Ast *next;
  
  while (at!=NULL) {
    if (!check_invalid_occurrence_as_rule(at->left->left) ||
	!check_invalid_occurrence_as_rule(at->left->right)) {
      return 0;
    }

    t1 = CompileTermFromAst(at->left->left, -1);
    t2 = CompileTermFromAst(at->left->right, -1);

    next = ast_getTail(at);

    // 2021/9/6: It seems, always EnvAddCodePUSH is selected
    // because at is not NULL in this step. Should be (next == NULL)?
    //
    // 2021/9/12: It is found that at==NULL faster than next==NULL
    // in parallel execution.

    /*
    if (at == NULL) {
      EnvAddCodeMYPUSH((void *)(unsigned long)t1, (void *)(unsigned long)t2);
    } else {
      EnvAddCodePUSH((void *)(unsigned long)t1, (void *)(unsigned long)t2);     
    }
    */
    IMCode_genCode2(OP_PUSH, t1, t2);

    
    at = next;
  }

  return 1;
}

void Compile_Put_Ret_ForRuleBody(void) {
  
  if ((CmEnv.annotateL == ANNOTATE_NOTHING) &&
      (CmEnv.annotateR == ANNOTATE_NOTHING)) {
    IMCode_genCode0(OP_RET_FREE_LR);
    
  } else if ((CmEnv.annotateL == ANNOTATE_NOTHING) &&
	     (CmEnv.annotateR != ANNOTATE_NOTHING)) {
    // FreeL
    if (CmEnv.reg_agentL == VM_OFFSET_ANNOTATE_L) {
      IMCode_genCode0(OP_RET_FREE_L);
      
    } else {
      IMCode_genCode0(OP_RET_FREE_R);
    }

  } else if ((CmEnv.annotateL != ANNOTATE_NOTHING) &&
	     (CmEnv.annotateR == ANNOTATE_NOTHING)) {
    // FreeR
    if (CmEnv.reg_agentL == VM_OFFSET_ANNOTATE_L) {
      IMCode_genCode0(OP_RET_FREE_R);
      
    } else {
      IMCode_genCode0(OP_RET_FREE_L);
      
    }
  } else {
    IMCode_genCode0(OP_RET);
    
  }    
	     
}


int CompileStmListFromAst(Ast *at) {
  Ast *ptr;
  int toRegLeft;

  while (at!=NULL) {
    ptr=at->left;

    // (AST_LD (AST_NAME sym NULL) some)
    if (ptr->id != AST_LD) {
      puts("System ERROR: The given StmList contains something besides statements.");
      exit(-1);
    }
    // operation of x=y:
    // for the x
    toRegLeft = CmEnv_find_var(ptr->left->left->sym);
    if (toRegLeft == -1) {
      // the sym is new
      toRegLeft = CmEnv_set_as_INTVAR(ptr->left->left->sym);
    } else {
      printf("Warning: '%s' has been already defined.\n", ptr->left->left->sym);
    }

    // for the y
    if (ptr->right->id == AST_NAME) {
      // y is a name
      int toRegRight = CmEnv_find_var(ptr->right->left->sym);
      if (toRegRight == -1) {
	toRegRight = CmEnv_set_as_INTVAR(ptr->right->left->sym);
      }
      IMCode_genCode2(OP_LOAD, toRegRight, toRegLeft);
      

    } else if (ptr->right->id == AST_INT) {
      // y is an integer
      IMCode_genCode2(OP_LOADI, ptr->right->intval, toRegLeft);
      
    } else {
      // y is an expression
      if (!CompileExprFromAst(ptr->right, toRegLeft)) return 0;

    }



    at = ast_getTail(at);
  }

  return 1;
}




// --- BEGIN: Rewrite Optimisation  ---
Ast* Ast_Subst(char *sym, Ast *aterm, Ast *target, int *result) {
  // target is astterm: (AST asttermL asttermR)
  // this function replaces sym with aterm in target, i.e. tgs[aterm/sym].
  
  switch (target->id) {
  case AST_NAME:
    
    if (strcmp(target->left->sym, sym) == 0) {
      *result = 1;
      return aterm;
      
    } else {
      return target;
    }
    break;

  case AST_OPCONS:
    target->right = Ast_Subst(sym, aterm, target->right, result);
    return target;
  
  case AST_CONS:
    target->left = Ast_Subst(sym, aterm, target->left, result);
    if (*result) {
      return target;
    } else {
      target->right = Ast_Subst(sym, aterm, target->right, result);
      return target;
    }


  case AST_ANNOTATION_L:
  case AST_ANNOTATION_R:

    
  case AST_TUPLE:
  case AST_AGENT:
    {
      Ast *port;
      if ((target->id == AST_ANNOTATION_L) ||
	  (target->id == AST_ANNOTATION_R)) {

	// (AST_ANNOTATION (AST_AGENT (ID_SYM sym NULL) paramlist) NULL)
	port = target->left->right;
      } else {
	
	// (AST_AGENT (ID_SYM sym NULL) paramlist)
	port = target->right;
      }
      
      for(int i=0; i< MAX_PORT; i++) {      
	if (port == NULL) break;
	
	port->left = Ast_Subst(sym, aterm, port->left, result);      
	if (*result) break;
	
      port = ast_getTail(port);
      }
    }
    return target;
    
  case AST_LIST:
    {
      Ast *elem = target->right;

      while (elem != NULL) {
	elem = Ast_Subst(sym, aterm, elem, result);
	if (*result) break;
	
	elem = ast_getTail(elem);
      }
    }
    return target;

  default:
    return target;
  }

}


int Ast_Subst_EQList(int nth, char *sym, Ast *aterm, Ast *eqlist) {
  // eqlist[aterm/sym] except for n-th eq

  Ast *eq, *at = eqlist;
  int ct = 0;
  int result;

  while (at != NULL) {
    eq = at->left;

    if (ct == nth) {
      ct++;
      at = ast_getTail(at);
      continue;
    }
    
    result=0;
    eq->left = Ast_Subst(sym, aterm, eq->left, &result);
    
    if (result) {
      return 1;
    }
    
    result=0;
    eq->right = Ast_Subst(sym, aterm, eq->right, &result);

    if (result) {
      return 1;
    }

    ct++;
    at = ast_getTail(at);

  }

  return 0;
}


void Ast_RewriteOptimisation_EQList(Ast *eqlist) {
  // Every eq such as x~t in eqlist is replaced as eqlist[t/x].
  //
  // Structure
  // eqlist : (AST_LIST eq1 (AST_LIST eq2 (AST_LIST eq3 NULL)))
  // eq : (AST_CNCT astterm1 astterm2)
  
  Ast *at, *prev, *target, *term;
  char *sym;
  int nth=0, exists_in_table;
  NB_TYPE type = NB_NAME;

  at = prev = eqlist;
  
  while (at != NULL) {
    // (id, left, right)
    // at : (AST_LIST, x1, NULL)
    // at : (AST_LIST, x1, (AST_LIST, x2, NULL))    
    target = at->left;

    //            printf("\n[target] "); ast_puts(target);
    //            printf("\n%dnth in ", nth); ast_puts(eqlist); printf("\n\n");


    if (target->left->id == AST_NAME) {

      sym = target->left->left->sym;
      exists_in_table=CmEnv_gettype_forname(sym, &type);
      
      if ((!exists_in_table) ||
	  (type == NB_NAME)){
	// When no entry in CmEnv table or its type is NB_NAME,
	// it is a local name, so it is the candidate.
	
	term = target->right;
	//	printf("%s~",sym); ast_puts(term); puts("");
      
	if (Ast_Subst_EQList(nth, sym, term, eqlist)) {
	  //		 printf("=== hit %dth\n", nth);
	
	  if (prev != at) {
	    // 前のリストの接続先を、現在地を省いて、その次の要素に変更。
	    prev->right = at->right;  
	    at = at->right;	  
	  } else {
	    // 先頭の要素が代入に使われたので、
	    // body 内の eqlist から先頭を削除
	    // (AST_LIST, x1, (AST_LIST, x2, *next)) ==> (AST_LIST, x2, *next)  
	    eqlist->left = eqlist->right->left;
	    eqlist->right = eqlist->right->right;
	    eqlist = eqlist->right;
	    // 対象 at を次の要素に更新し、prev も at とする
	    prev = at = at->right;
	  }
	
	  continue;
	}
      }
      
    }

      
    if (target->right->id == AST_NAME) {
      sym = target->right->left->sym;
      exists_in_table=CmEnv_gettype_forname(sym, &type);      

      if ((!exists_in_table) ||
	  (type == NB_NAME)){
	// When no entry in CmEnv table or its type is NB_NAME
	
	term = target->left;
	//	ast_puts(term); printf("~%s",sym);puts("");

	if (Ast_Subst_EQList(nth, sym, term, eqlist)) {
	  //	 printf("=== hit %dth\n", nth);
	
	  if (prev != at) {
	    // 前のリストの接続先を、現在地を省いて、その次の要素に変更。
	    prev->right = at->right;  
	    at = at->right;	  
	  } else {
	    // 先頭の要素が代入に使われたので、
	    // body 内の eqlist から先頭を削除
	    // (AST_LIST, x1, (AST_LIST, x2, *next)) ==> (AST_LIST, x2, *next)  
	    eqlist->left = eqlist->right->left;
	    eqlist->right = eqlist->right->right;
	    eqlist = eqlist->right;
	    // 対象 at を次の要素に更新し、prev も at とする
	    prev = at = at->right;
	  }

	  continue;      

	}
      }
    }

    nth++;
    prev = at;
    at = at->right;
    
  }
}
// --- END: Rewrite Optimisation  ---





int CompileBodyFromAst(Ast *body) {
  Ast *stms, *eqs;

  if (body == NULL) return 1;
  
  stms = body->left;
  eqs = body->right;
  
  Ast_RewriteOptimisation_EQList(eqs);

  if (!CompileStmListFromAst(stms)) return 0;
  if (!CompileEQListFromAst(eqs)) {
    printf("in the rule:\n  %s >< %s\n",
	   IdTable_get_name(CmEnv.idL),
	   IdTable_get_name(CmEnv.idR));
    return 0;
  }

  return 1;
}
  





/**************************************
 TABLE for RULES
**************************************/
typedef struct RuleList {
  int sym;
  int available;
  void* code[MAX_CODE_SIZE];
  struct RuleList *next;
} RuleList;

RuleList *RuleList_new(void) {
  RuleList *alist;
  alist = malloc(sizeof(RuleList));
  if (alist == NULL) {
    printf("Malloc error\n");
    exit(-1);
  }
  alist->available = 0;
  return alist;
}

void RuleList_set_code(RuleList *at, int sym, void **code, int byte, RuleList *next) {
  at->sym = sym;
  at->available = 1;
  CopyCode(byte, code, at->code);
  at->next = next;
}

void RuleList_inavailable(RuleList *at) {
  at->available = 0;
}


#define RULEHASH_SIZE NUM_AGENTS
static RuleList *RuleTable[RULEHASH_SIZE];

void RuleTable_init(void) {
  int i;
  for (i=0; i<RULEHASH_SIZE; i++) {
    RuleTable[i] = NULL;
  }
}


void RuleTable_record(int symlID, int symrID, void **code, int byte) {

  RuleList *add;

  if (RuleTable[symlID] == NULL) {
    // No entry for symlID
    
    add = RuleList_new();

    // Make a new linear list whose node is (symrID, code, byte)
    RuleList_set_code(add, symrID, code, byte, NULL);

    // Set the linear list to RuleTable[symlID]
    RuleTable[symlID] = add;
    return;
    
  }

  // Linear Search
  RuleList *at = RuleTable[symlID];  // Set the top of the list to `at'.
    
  while( at != NULL ) {
    if( at->sym == symrID) {
      // already exists

      // overwrite 
      CopyCode(byte, code, at->code);
      return;
    }
    at = at->next;
  }
  
  // No entry for symlID in the linear list

  // Make a new linear list
  // and add it as the top of the list (that is RuleTable[symlID]).
  add = RuleList_new();
  RuleList_set_code(add, symrID, code, byte, RuleTable[symlID]);
  RuleTable[symlID] = add; 
  return;
}



void RuleTable_delete(int symlID, int symrID) {
  
  if (RuleTable[symlID] == NULL) {
    // No entry for symlID
    return;
    
  }

  // Linear Search
  RuleList *at = RuleTable[symlID];
    
  while( at != NULL ) {
    if( at->sym == symrID) {
      // already exists

      // Make it void
      RuleList_inavailable(at);
      return;
    }
    at = at->next;
  }
    
}





// -------------------------------------------------------------

int getArityFromAST(Ast *ast) {
  int i;
  Ast *ptr;

  ptr = ast->right;
  for (i=0; i<MAX_PORT; i++) {
    if (ptr == NULL) break;
    ptr = ast_getTail(ptr);
  }
  return i;
}
  

// setMetaL(Ast *ast)
// A(x1,x2) が ast に与えられれば、rule 内で x1, x2 が
// VM のレジスタである VM_OFFSET_METAVAR_L(0)番、VM_OFFSET_METAVAR_L(1)番を
// 参照できるようにする。
void setMetaL(Ast *ast) {
  int i; 
  Ast *ptr;
  NB_TYPE type;
  
  ptr = ast->right;
  for (i=0; i<MAX_PORT; i++) {
    if (ptr == NULL) break;
    if (ptr->left->id == AST_NAME) {
      type = NB_META;
    } else {
      type = NB_INTVAR;
    }      
    CmEnv_set_symbol_as_meta(ptr->left->left->sym, VM_OFFSET_METAVAR_L(i), type);
    
    ptr = ast_getTail(ptr);
  }
}
void setMetaR(Ast *ast) {
  int i; 
  Ast *ptr;
  NB_TYPE type;
  
  ptr = ast->right;
  for (i=0; i<MAX_PORT; i++) {
    if (ptr == NULL) break;
    if (ptr->left->id == AST_NAME) {
      type = NB_META;
    } else {
      type = NB_INTVAR;
    }      
    CmEnv_set_symbol_as_meta(ptr->left->left->sym, VM_OFFSET_METAVAR_R(i), type);    
    ptr = ast_getTail(ptr);
  }
}

void setMetaL_asIntName(Ast *ast) {
  //CmEnv_set_symbol_as_meta(ast->left->sym, VM_OFFSET_METAVAR_L(0), NB_INTVAR);
  CmEnv_set_symbol_as_meta(ast->left->sym, CmEnv.reg_agentL, NB_INTVAR);
  
}

void setMetaR_asIntName(Ast *ast) {
  //  CmEnv_set_symbol_as_meta(ast->left->sym, VM_OFFSET_METAVAR_R(0), NB_INTVAR);      
  CmEnv_set_symbol_as_meta(ast->left->sym, CmEnv.reg_agentR, NB_INTVAR);
}



void setAnnotateLR(int left, int right) {
  CmEnv.reg_agentL = left;
  CmEnv.reg_agentR = right;  
}



int getRuleAgentID(Ast *ruleAgent) {
  // Returns agents ids of ast type.
  // This is called from makeRule to get ids of rule agents.
  
  int id;

  if (ruleAgent->id == AST_TUPLE) {
    id = GET_TUPLEID(ruleAgent->intval);
    
  } else if (ruleAgent->id == AST_OPCONS) {
    id = ID_CONS;
    
  } else if (ruleAgent->id == AST_NIL) {
    id = ID_NIL;
    
  } else if (ruleAgent->id == AST_INTVAR) {
    id = ID_INT;

  } else if (strcmp((char *)ruleAgent->left->sym, "Int") == 0) {
    id = ID_INTAGENT;
  } else {

    id = IdTable_getid_builtin_funcAgent(ruleAgent);
    if (id == -1) {
      id=NameTable_get_set_id_with_IdTable_forAgent(ruleAgent->left->sym);
    }
  }

  return id;
}
  





int CompileIfSentenceFromAST(Ast *if_sentence_top) {
  // return 1: success
  //        0: compile error

  //      <if-sentence> ::= (AST_IF guard (AST_BRANCH <then> <else>))
  //                      | <body>
  //      <then> ::= <if-sentence>
  //      <else> ::= <if-sentence>

  Ast *if_sentence;
  
  if_sentence = if_sentence_top;

  CmEnv_clear_keeping_rule_properties();


  if ((if_sentence == NULL) || (if_sentence->id == AST_BODY)) {
    // 通常コンパイル
    Ast *body = if_sentence;

    
    if (!CompileBodyFromAst(body)) return 0;
    Compile_Put_Ret_ForRuleBody();
      
    CmEnv_Retrieve_GNAME();

    
    if (!CmEnv_check_meta_occur_once()) {
      printf("in the rule:\n  %s >< %s.\n", 
	     IdTable_get_name(CmEnv.idL),
	     IdTable_get_name(CmEnv.idR));
      return 0;
    }
    
    return 1;
      
  } else {
    // if_sentence
    Ast *guard, *then_branch, *else_branch;
    int label;  // jump label

    IMCode_genCode0(OP_BEGIN_BLOCK);

    
    guard = if_sentence->left;
    then_branch = if_sentence->right->left;
    else_branch = if_sentence->right->right;

    // Compilation of Guard expressions
    int newreg = CmEnv_newvar();
    if (!CompileExprFromAst(guard, newreg)) return -1;


#ifdef OPTIMISE_IMCODE    
    // optimisation for R0
    // OP src1 src2 dest ==> OP_R0 src1 src2
    int opt = 0;
    struct IMCode_tag *imcode = &IMCode[IMCode_n-1];
    switch(imcode->opcode) {
    case OP_LT:
      imcode->opcode = OP_LT_R0;
      opt=1;
      break;

    case OP_LE:
      imcode->opcode = OP_LE_R0;
      opt=1;
      break;

    case OP_EQ:
      imcode->opcode = OP_EQ_R0;
      opt=1;
      break;

    case OP_EQI:
      imcode->opcode = OP_EQI_R0;
      opt=1;
      break;

    case OP_NE:
      imcode->opcode = OP_NE_R0;
      opt=1;
    }    
#endif


    // CmEnv_Retrieve_GNAME();  // <- no need for guard expressions

    // Generate OP_JMPEQ0 for VM
    label = CmEnv_get_newlabel();    
#ifdef OPTIMISE_IMCODE        
    if (opt != 1) {      
      IMCode_genCode2(OP_JMPEQ0, newreg, label);
      
    } else {
      IMCode_genCode1(OP_JMPEQ0_R0, label);
    }
#else
    IMCode_genCode2(OP_JMPEQ0, newreg, label);
#endif
        
    
    // Compilation of then_branch
    IMCode_genCode0(OP_BEGIN_BLOCK);
    CmEnv_clear_localnamePtr();  // 局所変数の割り当て番号を初期化
    if (!CompileIfSentenceFromAST(then_branch)) return 0;

    
    

    // Compilation of else_branch
    IMCode_genCode0(OP_BEGIN_BLOCK);
    IMCode_genCode1(OP_LABEL, label);
        
    CmEnv_clear_localnamePtr();  // 局所変数の割り当て番号を初期化    
    if (!CompileIfSentenceFromAST(else_branch)) return 0;

    return 1;
  }

  
}




int makeRule(Ast *ast) {
  //    (ASTRULE (AST_CNCT agentL agentR)
  //      <if-sentence>)
  //
  //      WHERE
  //      <if-sentence> ::= (AST_IF guard (AST_BRANCH <then> <else>))
  //                      | <body>
  //      <then> ::= <if-sentence>
  //      <else> ::= <if-sentence>

  
  int idR, idL;
  Ast *ruleL, *ruleR, *if_sentence;

  void* code[MAX_CODE_SIZE];
  int gencode_num=0;

  ruleL = ast->left->left;
  ruleR = ast->left->right;

  if (ruleL->id == AST_NAME) {
    printf("ERROR: The name '%s' was specified as the left-hand side of rule agents. It should be an agent.\n", ruleL->left->sym);
    return 0;
  }
  if (ruleR->id == AST_NAME) {
    printf("ERROR: The name '%s' was specified as the right-hand side of rule agents. It should be an agent.\n", ruleR->left->sym);
    return 0;
  }
  
  
  if_sentence = ast->right;

  ruleL = ast_remove_tuple1(ruleL);
  ruleR = ast_remove_tuple1(ruleR);
  
  
    //    #define MYDEBUG1
#ifdef MYDEBUG1
  ast_puts(ruleL); puts("");
  ast_puts(ruleR); puts("");
  ast_puts(bodies);
  exit(1);
#endif

  

  // store ids of rule agent
  idL = getRuleAgentID(ruleL);
  idR = getRuleAgentID(ruleR);  


  /*
  // prevent re-defining of built-in agents.
  if (IdTable_is_builtin_rule(ruleL, ruleR)) {
      printf("Warning: %s >< %s is already defined as built-in.\n",
	     IdTable_get_name(idL), IdTable_get_name(idR));

  } else  {
  
    if (IdTable_is_builtin_rule(ruleR, ruleL)) {
      printf("Warning: %s >< %s is already defined as built-in.\n",
	     IdTable_get_name(idR), IdTable_get_name(idL));
    }

  }
  */
  
  
  // >< (int i) 対策
  // int i は (AST_INTVAR (AST_SYM sym NULL) NULL) として構築されているので
  // ID_TUPLE1 である間は読み飛ばす
  while (idL == ID_TUPLE1) {
    ruleL = ruleL->right->left;
    idL = getRuleAgentID(ruleL);    
  }
  while (idR == ID_TUPLE1) {
    ruleR = ruleR->right->left;
    idR = getRuleAgentID(ruleR);    
  }
  
  
  // Annotation (*L)、(*R) の処理があるため
  // 単純に ruleAgentL、ruleAgentR を入れ替えれば良いわけではない。

  if (idL > idR) {
    // Generally the order should be as Append(xs,r) >< y:ys,
    // so idL should be greater than idR.
    
    // JAPANESE: 標準では Append(xs, r) >< [y|ys] なので
    // idL の方が大きくなって欲しい

    
    // (*L) is interpreted as the left-hand side agent, (*R) is the right one.
    // JAPANESE: annotation が (*L) なら左側、(*R) なら右側を指すものとする
    setAnnotateLR(VM_OFFSET_ANNOTATE_L, VM_OFFSET_ANNOTATE_R);
    
  } else {
    Ast *tmp;
    tmp = ruleL;
    ruleL = ruleR;
    ruleR = tmp;

    int idTmp;
    idTmp = idL;
    idL = idR;
    idR = idTmp;

    // Keep the occurrence (*L) and (*R) in aplist,
    // change the interpretation of (*L) as (*R), vice versa.

    // JAPANESE: aplist 内の (*L) (*R) はそのままにしておき、
    // annotation が (*L) なら右側、(*R) なら左側を指すものとする
    setAnnotateLR(VM_OFFSET_ANNOTATE_R, VM_OFFSET_ANNOTATE_L);
  }

  int arity;
  
  // IMPORTANT:
  // The first two codes stores arities of idL and idR, respectively.
  if (idL == ID_INT) {
    arity = 0;
  } else {
    arity = getArityFromAST(ruleL);
  }
  IdTable_set_arity(idL, arity);
  code[0] = (void *)(unsigned long)arity;
  
  if (idR == ID_INT) {
    arity = 0;
  } else {
    arity = getArityFromAST(ruleR);
  }
  IdTable_set_arity(idR, arity);
  code[1] = (void *)(unsigned long)arity;
  
  gencode_num = 2;
  


  
  CmEnv_clear_all();
  
  if (idL == ID_INT) {
    setMetaL_asIntName(ruleL);
    CmEnv.annotateL = ANNOTATE_AS_INT_AGENT; // to prevent putting FreeL out
  } else {
    setMetaL(ruleL);
  }
  
  if (idR == ID_INT) {
    setMetaR_asIntName(ruleR);
    CmEnv.annotateR = ANNOTATE_AS_INT_AGENT;  // to prevent putting FreeR out
  } else {
    setMetaR(ruleR);
  }
  
  CmEnv.idL = idL;
  CmEnv.idR = idR;


  if (!CompileIfSentenceFromAST(if_sentence)) return 0;

  
  gencode_num += CmEnv_generate_VMCode(&code[2]);

  
  //    puts("-----------------------------------");
  //    IMCode_puts(0);
  //    gencode_num += CmEnv_generate_VMCode(&code[2]);
  //    VMCode_puts(code, gencode_num);
  //    puts("-----------------------------------");
  
  
#ifdef MYDEBUG
  VMCode_puts(code, gencode_num); exit(1);
#endif
  //    VMCode_puts(code, gencode_num);  exit(1);

  //    printf("Rule: %s(id:%d) >< %s(id:%d).\n", 
  //	   IdTable_get_name(idL), idL,
  //	   IdTable_get_name(idR), idR);
  //    VMCode_puts(&code[2], gencode_num-2);
  //    exit(1);
  
  //ast_puts(ruleL); printf("><");
  //ast_puts(ruleR); puts("");

  
  // Record the rule code for idR >< idL
  RuleTable_record(idL, idR, code, gencode_num); 
  
  if (idL != idR) {    
    // Delete the rule code for idR >< idL
    // because we need only the rule idL >< idR.    
    RuleTable_delete(idR, idL);
    
  }

  
  //    #define DEBUG_PUT_RULE_CODE    
#ifdef DEBUG_PUT_RULE_CODE  
  if (((strcmp(IdTable_get_name(idL), "Fib") == 0) &&
       (idR == ID_INT))
      ||
      ((strcmp(IdTable_get_name(idL), "fib") == 0) &&
       (idR == ID_INT))
      ||
      ((strcmp(IdTable_get_name(idL), "Ack") == 0) &&
       (idR == ID_INT))
      ||
      ((strcmp(IdTable_get_name(idL), "Ackm") == 0) &&
       (idR == ID_INT))
      ||
      ((strcmp(IdTable_get_name(idL), "MergeCC") == 0) &&
       (idR == ID_CONS))
      ) {

      printf("Rule: %s >< %s.\n", 
	     IdTable_get_name(idL),
	     IdTable_get_name(idR));
      
      IMCode_puts(0);
      VMCode_puts(code, gencode_num);
      //      exit(1);
    }
#endif

  
  
  
  return 1;
}


void *getRuleCode(VALUE heap_syml, VALUE heap_symr, int *result) {
  // returns:
  //   *code  :  for syml><symr
  //   result :  1 for success, otherwise 0.
  
  int syml = AGENT(heap_syml)->basic.id;
  int symr = AGENT(heap_symr)->basic.id;
  
  //RuleList *add;
  
  if (RuleTable[syml] == NULL) {
    // When ResultTable for syml is empty
    
    *result=0;
    return NULL;
  }

  // Linear search for the entry RuleTable[syml]
  RuleList *at = RuleTable[syml];  // set the top 
  while (at != NULL) {
    if (at->sym == symr) {  // already exists

      if (at->available == 0) {
	*result=0;
	return NULL;
	  
      } else {
	*result=1;
	return at->code;
      }
    }
    at = at->next;  
  }

  // no entry
  
  *result=0;
  return NULL;

}


static inline
void getRuleCodeInt(VALUE heap_syml, void ***code) {
  int syml = AGENT(heap_syml)->basic.id;
    
  if (RuleTable[syml] == NULL) {
    return;
  }

  RuleList *at = RuleTable[syml];
  while (at != NULL) {
    if (at->sym == ID_INT) {

      if (at->available == 0) {
	return;
      } else {
	*code = at->code;
	return;
      }
    }
    at = at->next;
  }

  return;
}




#ifdef COUNT_CNCT    
int Count_cnct = 0;
int Count_cnct_true = 0;
int Count_cnct_indirect_op = 0;
#endif


//void *ExecCode(int arg, VirtualMachine *vm, void** code) {
void *ExecCode(int mode, VirtualMachine *restrict vm, void *restrict *code) {

  //http://magazine.rubyist.net/?0008-YarvManiacs
  static const void *table[] = {
    &&E_PUSH, &&E_PUSHI, &&E_MYPUSH,
    &&E_MKNAME, &&E_MKGNAME,
    &&E_MKAGENT0, &&E_MKAGENT1, &&E_MKAGENT2,
    &&E_MKAGENT3, &&E_MKAGENT4, &&E_MKAGENT5,
    &&E_REUSEAGENT0 ,&&E_REUSEAGENT1, &&E_REUSEAGENT2,
    &&E_REUSEAGENT3, &&E_REUSEAGENT4, &&E_REUSEAGENT5,
    &&E_RET, &&E_RET_FREE_LR, &&E_RET_FREE_L, &&E_RET_FREE_R,
    &&E_LOADI, &&E_LOAD,
    &&E_ADD, &&E_SUB, &&E_ADDI, &&E_SUBI, &&E_MUL, &&E_DIV, &&E_MOD, 
    &&E_LT, &&E_LE, &&E_EQ, &&E_EQI, &&E_NE, 
    &&E_UNM, &&E_RAND, &&E_INC, &&E_DEC,
    &&E_LT_R0, &&E_LE_R0, &&E_EQ_R0, &&E_EQI_R0, &&E_NE_R0,

    &&E_JMPEQ0, &&E_JMPEQ0_R0, &&E_JMP, &&E_JMPNEQ0,
    &&E_JMPCNCT_CONS, &&E_JMPCNCT, 

    &&E_LOOP, &&E_LOOP_RREC, &&E_LOOP_RREC1, &&E_LOOP_RREC2,
    &&E_CNCTGN, &&E_SUBSTGN,
    &&E_NOP, 
  };

  // To create the table.
  // mode=0: Create table (only for initialise)
  // mode=1: Execute codes (the normal operation)
  if (mode == 0) {
    return table;
  }

  int i, pc=0;
  VALUE a1;
  VALUE *reg = vm->reg;
  
  goto *code[0];
  

 E_MKNAME:
  //    puts("mkname dest");
  pc++;
  reg[(unsigned long)code[pc++]] = makeName(vm);
  goto *code[pc];

 E_MKGNAME:
  //    puts("mkgname id dest");
  pc++;
  
  i = (unsigned long)code[pc++];
  a1 = IdTable_get_heap(i);
  //  a1 = NameTable_get_heap((char *)code[pc+2]);
  if (a1 == (VALUE)NULL) {
    a1 = makeName(vm);

    // set GID obtained by IdTable_new_gnameid()    
    BASIC(a1)->id = i;
    IdTable_set_heap(i, a1);
    
  }

  reg[(unsigned long)code[pc++]] = a1;
  goto *code[pc];

  
 E_MKAGENT0:
  //    puts("mkagent0 id dest");
  pc++;
  i = (unsigned long)code[pc++];
  reg[(unsigned long)code[pc++]] = makeAgent(vm, i);
  goto *code[pc];

 E_MKAGENT1:
  //    puts("mkagent1 id src1 dest");
  pc++;
  a1 = makeAgent(vm, (unsigned long)code[pc++]);
  AGENT(a1)->port[0] = reg[(unsigned long)code[pc++]];
  reg[(unsigned long)code[pc++]] = a1;

  goto *code[pc];
  
 E_MKAGENT2:
  //      puts("mkagent2 id src1 src2 dest");
  pc++;  
  a1 = makeAgent(vm, (unsigned long)code[pc++]);
  {
    volatile VALUE *a1port = AGENT(a1)->port;
    a1port[0] = reg[(unsigned long)code[pc++]];
    a1port[1] = reg[(unsigned long)code[pc++]];
  }
  reg[(unsigned long)code[pc++]] = a1;
  
  goto *code[pc];


 E_MKAGENT3:
  //    puts("mkagent3 id src1 src2 src3 dest");
  pc++;
  a1 = makeAgent(vm, (unsigned long)code[pc++]);
  {
    volatile VALUE *a1port = AGENT(a1)->port;
    a1port[0] = reg[(unsigned long)code[pc++]];
    a1port[1] = reg[(unsigned long)code[pc++]];
    a1port[2] = reg[(unsigned long)code[pc++]];
  }
  reg[(unsigned long)code[pc++]] = a1;
  goto *code[pc];

 E_MKAGENT4:
  //    puts("mkagent4 id src1 src2 src3 src4 dest");
  pc++;
  a1 = makeAgent(vm, (unsigned long)code[pc++]);
  {
    volatile VALUE *a1port = AGENT(a1)->port;
    a1port[0] = reg[(unsigned long)code[pc++]];
    a1port[1] = reg[(unsigned long)code[pc++]];
    a1port[2] = reg[(unsigned long)code[pc++]];
    a1port[3] = reg[(unsigned long)code[pc++]];
  }
  reg[(unsigned long)code[pc++]] = a1;
  goto *code[pc];

 E_MKAGENT5:
  //    puts("mkagent5 id src1 src2 src3 src4 src5 dest");
  pc++;
  a1 = makeAgent(vm, (unsigned long)code[pc++]);
  {
    volatile VALUE *a1port = AGENT(a1)->port;
    a1port[0] = reg[(unsigned long)code[pc++]];
    a1port[1] = reg[(unsigned long)code[pc++]];
    a1port[2] = reg[(unsigned long)code[pc++]];
    a1port[3] = reg[(unsigned long)code[pc++]];
    a1port[4] = reg[(unsigned long)code[pc++]];
  }
  reg[(unsigned long)code[pc++]] = a1;
  goto *code[pc];

  

 E_REUSEAGENT0:
  //    puts("reuseagent target id");
  pc++;
  a1 = reg[(unsigned long)code[pc++]];
  AGENT(a1)->basic.id = (unsigned long)code[pc++];  
  goto *code[pc];

 E_REUSEAGENT1:
 //    puts("reuseagent target id src1");
  pc++;
  a1 = reg[(unsigned long)code[pc++]];
  AGENT(a1)->basic.id = (unsigned long)code[pc++];
  AGENT(a1)->port[0] = reg[(unsigned long)code[pc++]];
  
  goto *code[pc];
  

 E_REUSEAGENT2:
 //    puts("reuseagent target id src1 src2");
  pc++;
  a1 = reg[(unsigned long)code[pc++]];
  AGENT(a1)->basic.id = (unsigned long)code[pc++];
  {
    volatile VALUE *a1port = AGENT(a1)->port;
    a1port[0] = reg[(unsigned long)code[pc++]];
    a1port[1] = reg[(unsigned long)code[pc++]];
  }    
  goto *code[pc];


 E_REUSEAGENT3:
 //    puts("reuseagent target id src1 src2 src3");
  pc++;
  a1 = reg[(unsigned long)code[pc++]];
  AGENT(a1)->basic.id = (unsigned long)code[pc++];
  {
    volatile VALUE *a1port = AGENT(a1)->port;
    a1port[0] = reg[(unsigned long)code[pc++]];
    a1port[1] = reg[(unsigned long)code[pc++]];
    a1port[2] = reg[(unsigned long)code[pc++]];
  }  
  goto *code[pc];

 E_REUSEAGENT4:
 //    puts("reuseagent target id src1 src2 src3 src4");
  pc++;
  a1 = reg[(unsigned long)code[pc++]];
  AGENT(a1)->basic.id = (unsigned long)code[pc++];
  {
    volatile VALUE *a1port = AGENT(a1)->port;
    a1port[0] = reg[(unsigned long)code[pc++]];
    a1port[1] = reg[(unsigned long)code[pc++]];
    a1port[2] = reg[(unsigned long)code[pc++]];
    a1port[3] = reg[(unsigned long)code[pc++]];
  }  
  goto *code[pc];

 E_REUSEAGENT5:
 //    puts("reuseagent target id src1 src2 src3 src4 src5");
  pc++;
  a1 = reg[(unsigned long)code[pc++]];
  AGENT(a1)->basic.id = (unsigned long)code[pc++];
  {
    volatile VALUE *a1port = AGENT(a1)->port;
    a1port[0] = reg[(unsigned long)code[pc++]];
    a1port[1] = reg[(unsigned long)code[pc++]];
    a1port[2] = reg[(unsigned long)code[pc++]];
    a1port[3] = reg[(unsigned long)code[pc++]];
    a1port[4] = reg[(unsigned long)code[pc++]];
  }  
  goto *code[pc];

  

  /*
    ===TODO===
    2021/9/18
    a2->t であるところに a1->a2 が与えられても a2->t, a1->a2 のままにしてある。
    a2 がここで解放できればメモリ利用が助かるのでは？
    仮に助からないとしても、グローバル環境で与えられたネットの場合には
    単純に eval_equation へ持ち込んだ方が、indirection を生成しなくて済むのでは？

    ==>
    DONE 21 September 2021
    誤差程度しか変わらない。

   */  
#ifndef THREAD
#define PUSH(vm, a1, a2)				         	\
  if ((!IS_FIXNUM(a1)) && (IS_NAMEID(BASIC(a1)->id)) &&			\
      (NAME(a1)->port == (VALUE)NULL)) {				\
    NAME(a1)->port = a2;						\
  } else if ((!IS_FIXNUM(a2)) && (IS_NAMEID(BASIC(a2)->id)) &&		\
	     (NAME(a2)->port == (VALUE)NULL)) {				\
    NAME(a2)->port = a1;						\
  } else {								\
    VM_EQStack_Push(vm, a1, a2);					\
  }
#else
#define PUSH(vm, a1, a2)				                \
  if ((!IS_FIXNUM(a1)) && (IS_NAMEID(BASIC(a1)->id)) &&			\
      (NAME(a1)->port == (VALUE)NULL)) {				\
    if (!(__sync_bool_compare_and_swap(&(NAME(a1)->port), NULL, a2))) { \
      if (SleepingThreadsNum == 0) {					\
	VM_EQStack_Push(vm, NAME(a1)->port, a2);			\
	freeName(a1);							\
      } else {								\
	GlobalEQStack_Push(NAME(a1)->port,a2);				\
	freeName(a1);							\
      }									\
    }									\
  } else if ((!IS_FIXNUM(a2)) && (IS_NAMEID(BASIC(a2)->id)) &&		\
	     (NAME(a2)->port == (VALUE)NULL)) {				\
    if (!(__sync_bool_compare_and_swap(&(NAME(a2)->port), NULL, a1))) { \
      if (SleepingThreadsNum == 0) {					\
	VM_EQStack_Push(vm, a1,NAME(a2)->port);				\
	freeName(a2);							\
      } else {								\
	GlobalEQStack_Push(a1,NAME(a2)->port);				\
	freeName(a2);							\
      }									\
    }									\
  } else {								\
    if (SleepingThreadsNum == 0) {					\
      VM_EQStack_Push(vm, a1,a2);					\
    } else {								\
      GlobalEQStack_Push(a1,a2);					\
    }									\
  }
#endif  



 E_PUSH:
  //    puts("push reg reg");
  PUSH(vm, reg[(unsigned long)code[pc+1]], reg[(unsigned long)code[pc+2]]);
  pc +=3;
  goto *code[pc];


 E_PUSHI:
  //    puts("pushi reg fixint");
  PUSH(vm, reg[(unsigned long)code[pc+1]], (unsigned long)code[pc+2]);
  pc +=3;
  goto *code[pc];
  


#ifndef THREAD
#define MYPUSH(vm, a1, a2)				 \
  if ((!IS_FIXNUM(a1)) && (IS_NAMEID(BASIC(a1)->id)) &&	\
      (NAME(a1)->port == (VALUE)NULL)) {			\
    NAME(a1)->port = a2;					\
  } else if ((!IS_FIXNUM(a2)) && (BASIC(a2)->id == ID_NAME) && \
	     (NAME(a2)->port == (VALUE)NULL)) {		\
    NAME(a2)->port = a1;					\
  } else {							\
    VM_EQStack_Push(vm, a1,a2);					\
  }
#else
#define MYPUSH(vm, a1, a2)						\
  if ((!IS_FIXNUM(a1)) && (IS_NAMEID(BASIC(a1)->id)) &&	\
      (NAME(a1)->port == (VALUE)NULL)) {				\
    if (!(__sync_bool_compare_and_swap(&(NAME(a1)->port), NULL, a2))) { \
      VM_EQStack_Push(vm, a1,a2);					\
    }									\
  } else if ((!IS_FIXNUM(a2)) && (IS_NAMEID(BASIC(a2)->id)) && \
	     (NAME(a2)->port == (VALUE)NULL)) {			\
    if (!(__sync_bool_compare_and_swap(&(NAME(a2)->port), NULL, a1))) { \
      VM_EQStack_Push(vm, a1,a2);					\
    }									\
  } else {								\
    VM_EQStack_Push(vm, a1,a2);						\
  }
#endif  




 E_MYPUSH:
  //    puts("mypush reg reg");
  MYPUSH(vm, reg[(unsigned long)code[pc+1]], reg[(unsigned long)code[pc+2]]);
  pc +=3;
  goto *code[pc];

  
  
 E_LOADI:
  //    puts("loadi num dest");
  pc++;
  i = (long)code[pc++];  
  reg[(unsigned long)code[pc++]] = i;
  goto *code[pc];




 E_RET:
  //    puts("ret");
  return NULL;

 E_RET_FREE_LR:
  //    puts("ret_free_LR");
  freeAgent(reg[VM_OFFSET_ANNOTATE_L]);
  freeAgent(reg[VM_OFFSET_ANNOTATE_R]);
  return NULL;
  
 E_RET_FREE_L:
  //    puts("ret_free_L");
  freeAgent(reg[VM_OFFSET_ANNOTATE_L]);
  return NULL;

 E_RET_FREE_R:
  //    puts("ret_free_R");
  freeAgent(reg[VM_OFFSET_ANNOTATE_R]);
  return NULL;


 E_LOOP:
  //    puts("loop");
  pc = 0;
  goto *code[0];

  
 E_LOOP_RREC:
  //      puts("looprrec reg ar");
  freeAgent(reg[VM_OFFSET_ANNOTATE_R]);
  
  a1 = reg[(unsigned long)code[pc+1]];
  for (int i=0; i<(unsigned long)code[pc+2]; i++) {
    reg[VM_OFFSET_METAVAR_R(i)] = AGENT(a1)->port[i];
  }
  
  reg[VM_OFFSET_ANNOTATE_R] = a1;
  
  pc = 0;
  goto *code[0];

  
 E_LOOP_RREC1:
  //      puts("looprrec reg ar");
  freeAgent(reg[VM_OFFSET_ANNOTATE_R]);
  
  a1 = reg[(unsigned long)code[pc+1]];

  reg[VM_OFFSET_METAVAR_R(0)] = AGENT(a1)->port[0];
  
  reg[VM_OFFSET_ANNOTATE_R] = a1;
  
  pc = 0;
  goto *code[0];

  
 E_LOOP_RREC2:
  //      puts("looprrec reg ar");
  freeAgent(reg[VM_OFFSET_ANNOTATE_R]);
  
  a1 = reg[(unsigned long)code[pc+1]];

  reg[VM_OFFSET_METAVAR_R(0)] = AGENT(a1)->port[0];
  reg[VM_OFFSET_METAVAR_R(1)] = AGENT(a1)->port[1];
  
  reg[VM_OFFSET_ANNOTATE_R] = a1;
  
  pc = 0;
  goto *code[0];
  

  

  
 E_LOAD:
  //    puts("load src dest");
  pc++;
  a1 = reg[(unsigned long)code[pc++]];
  reg[(unsigned long)code[pc++]] = a1;
    
  goto *code[pc];


  
 E_ADD:
  //    puts("ADD src1 src2 dest");
  pc++;
  {
    int i = FIX2INT(reg[(unsigned long)code[pc++]]);
    int j = FIX2INT(reg[(unsigned long)code[pc++]]);
    
    reg[(unsigned long)code[pc++]] = INT2FIX(i+j);
  }
  goto *code[pc];

 E_SUB:
  //    puts("SUB src1 src2 dest");
  pc++;
  {
    int i = FIX2INT(reg[(unsigned long)code[pc++]]);
    int j = FIX2INT(reg[(unsigned long)code[pc++]]);
    
    reg[(unsigned long)code[pc++]] = INT2FIX(i-j);
  }
  goto *code[pc];

  
 E_ADDI:
  //  puts("ADDI src int dest");
  pc++;
  {
    int i = FIX2INT(reg[(unsigned long)code[pc++]]);
    int j = (unsigned long)code[pc++];
    
    reg[(unsigned long)code[pc++]] = INT2FIX(i+j);
  }
  goto *code[pc];

  
 E_SUBI:
  //  puts("SUBI src int dest");
  pc++;
  {
    int i = FIX2INT(reg[(unsigned long)code[pc++]]);
    int j = (unsigned long)code[pc++];
    
    reg[(unsigned long)code[pc++]] = INT2FIX(i-j);
  }
  goto *code[pc];

  
 E_MUL:
  //    puts("MUL src1 src2 dest");
  pc++;
  {
    int i = FIX2INT(reg[(unsigned long)code[pc++]]);
    int j = FIX2INT(reg[(unsigned long)code[pc++]]);
    
    reg[(unsigned long)code[pc++]] = INT2FIX(i*j);
  }
  goto *code[pc];

  
 E_DIV:
  //    puts("DIV src1 src2 dest");
  pc++;
  {
    int i = FIX2INT(reg[(unsigned long)code[pc++]]);
    int j = FIX2INT(reg[(unsigned long)code[pc++]]);
    
    reg[(unsigned long)code[pc++]] = INT2FIX(i/j);
  }
  goto *code[pc];

 E_MOD:
  //    puts("MOD src1 src2 dest");
  pc++;
  {
    int i = FIX2INT(reg[(unsigned long)code[pc++]]);
    int j = FIX2INT(reg[(unsigned long)code[pc++]]);
    
    reg[(unsigned long)code[pc++]] = INT2FIX(i%j);
  }
  goto *code[pc];

 E_LT:
  //    puts("LT src1 src2 dest");
  pc++;
  {
    //    int i = FIX2INT(reg[(unsigned long)code[pc++]]);
    //    int j = FIX2INT(reg[(unsigned long)code[pc++]]);
    int i = reg[(unsigned long)code[pc++]];
    int j = reg[(unsigned long)code[pc++]];

    if (i<j) {
      reg[(unsigned long)code[pc++]] = INT2FIX(1);
    } else {
      reg[(unsigned long)code[pc++]] = INT2FIX(0);
    }
  }
  goto *code[pc];


 E_LE:
  //    puts("LT src1 src2 dest");
  pc++;
  {
    int i = reg[(unsigned long)code[pc++]];
    int j = reg[(unsigned long)code[pc++]];

    if (i<=j) {
      reg[(unsigned long)code[pc++]] = INT2FIX(1);
    } else {
      reg[(unsigned long)code[pc++]] = INT2FIX(0);
    }
  }
  goto *code[pc];


 E_EQ:
  //    puts("EQ src1 src2 dest");
  pc++;
  {
    int i = reg[(unsigned long)code[pc++]];
    int j = reg[(unsigned long)code[pc++]];

    if (i==j) {
      reg[(unsigned long)code[pc++]] = INT2FIX(1);
    } else {
      reg[(unsigned long)code[pc++]] = INT2FIX(0);
    }
  }
  goto *code[pc];



 E_EQI:
  //    puts("EQI src1 int dest");
  pc++;
  {
    int i = reg[(unsigned long)code[pc++]];
    int j = (unsigned long)code[pc++];

    if (i==j) {
      reg[(unsigned long)code[pc++]] = INT2FIX(1);
    } else {
      reg[(unsigned long)code[pc++]] = INT2FIX(0);
    }
  }
  goto *code[pc];


  
 E_NE:
  //    puts("NE src1 src2 dest");
  pc++;
  {
    int i = reg[(unsigned long)code[pc++]];
    int j = reg[(unsigned long)code[pc++]];

    if (i!=j) {
      reg[(unsigned long)code[pc++]] = INT2FIX(1);
    } else {
      reg[(unsigned long)code[pc++]] = INT2FIX(0);
    }
  }
  goto *code[pc];



 E_LT_R0:
  //    puts("LT_R0 src1 src2");
  pc++;
  {
    int i = reg[(unsigned long)code[pc++]];
    int j = reg[(unsigned long)code[pc++]];

    if (i<j) {
      reg[0] = 1;
    } else {
      reg[0] = 0;
    }
  }
  goto *code[pc];


 E_LE_R0:
  //    puts("LE_R0 src1 src2");
  pc++;
  {
    int i = reg[(unsigned long)code[pc++]];
    int j = reg[(unsigned long)code[pc++]];

    if (i<=j) {
      reg[0] = 1;
    } else {
      reg[0] = 0;
    }
  }
  goto *code[pc];

  
 E_EQ_R0:
  //    puts("EQ_R0 src1 src2");
  pc++;
  {
    int i = reg[(unsigned long)code[pc++]];
    int j = reg[(unsigned long)code[pc++]];

    if (i==j) {
      reg[0] = 1;
    } else {
      reg[0] = 0;
    }
  }
  goto *code[pc];


 E_EQI_R0:
  //    puts("EQ_R0 src1 int");
  pc++;
  {
    int i = reg[(unsigned long)code[pc++]];
    int j = (unsigned long)code[pc++];

    if (i==j) {
      reg[0] = 1;
    } else {
      reg[0] = 0;
    }
  }
  goto *code[pc];

  

  
 E_NE_R0:
  //    puts("NE_R0 src1 src2");
  pc++;
  {
    int i = reg[(unsigned long)code[pc++]];
    int j = reg[(unsigned long)code[pc++]];

    if (i!=j) {
      reg[0] = 1;
    } else {
      reg[0] = 0;
    }
  }
  goto *code[pc];
  


  
 E_JMPEQ0:
  //    puts("JMPEQ0 reg pc");
  //    the pc is a relative address, not absolute one!
  pc++;
  {
    int i = reg[(unsigned long)code[pc++]];
    if (!FIX2INT(i)) {
      int j = (unsigned long)code[pc++];
      pc += j;
    } else {
      pc++;
    }
  }
  goto *code[pc];


 E_JMPEQ0_R0:
  //    puts("JMPEQ0_R0 pc");
  pc++;
  {
    int i = reg[0];
    if (!i) {
      int j = (unsigned long)code[pc++];
      pc += j;
    } else {
      pc++;
    }
  }
  goto *code[pc];



 E_JMPNEQ0:
  //    puts("JMPNEQ0 reg pc");
  pc++;
  {
    int i = reg[(unsigned long)code[pc++]];
    if (FIX2INT(i)) {
      int j = (unsigned long)code[pc++];
      pc += j;
    } else {
      pc++;
    }
  }
  goto *code[pc];

  
    
 E_JMPCNCT_CONS:
  //    puts("JMPCNCT_CONS reg pc");
#ifdef COUNT_CNCT    
  Count_cnct++;
#endif

  a1 = reg[(unsigned long)code[pc+1]];
  if (IS_FIXNUM(a1)) {
    pc +=3;
    goto *code[pc];
  }

  while (IS_NAMEID(BASIC(a1)->id)) {

    if (NAME(a1)->port == (VALUE)NULL) {
      pc +=3;
      goto *code[pc];
    }

#ifdef COUNT_CNCT    
      Count_cnct_indirect_op++;
#endif      
    VALUE a2 = NAME(a1)->port;
    freeName(a1);
    a1 = a2;
    reg[(unsigned long)code[pc+1]] = a2;   // これ必要? 2022/02/02
  }

  if (BASIC(a1)->id == ID_CONS) {
#ifdef COUNT_CNCT    
    Count_cnct_true++;
#endif    

    pc += (unsigned long)code[pc+2];
    pc +=3;
    goto *code[pc];
  }

  pc +=3;
  goto *code[pc];
  

 E_JMPCNCT:
  //    puts("JMPCNCT reg id pc");
#ifdef COUNT_CNCT    
  Count_cnct++;
#endif
  
  a1 = reg[(unsigned long)code[pc+1]];
  if (IS_FIXNUM(a1)) {
    pc +=4;
    goto *code[pc];
  }

  while (IS_NAMEID(BASIC(a1)->id)) {

    if (NAME(a1)->port == (VALUE)NULL) {
      pc +=4;
      goto *code[pc];
    }

#ifdef COUNT_CNCT    
      Count_cnct_indirect_op++;
#endif      
    VALUE a2 = NAME(a1)->port;
    freeName(a1);
    a1 = a2;
    reg[(unsigned long)code[pc+1]] = a2;
  }

  if (BASIC(a1)->id == (unsigned long)code[pc+2]) {
#ifdef COUNT_CNCT    
    Count_cnct_true++;
#endif    
    pc += (unsigned long)code[pc+3];
    pc +=4;
    goto *code[pc];
  }

  pc +=4;
  goto *code[pc];

  
  
 E_JMP:
  //      puts("JMP pc");
  pc += (unsigned long)code[pc+1];
  pc +=2;
  goto *code[pc];


  
 E_UNM:
  //    puts("UNM src dest");
  pc++;
  {
    int i = FIX2INT(reg[(unsigned long)code[pc++]]);
    
    reg[(unsigned long)code[pc++]] = INT2FIX(-1 * i);
  }
  goto *code[pc];
  

 E_RAND:
  //    puts("RAND src dest");
  pc++;
  {
    int i = FIX2INT(reg[(unsigned long)code[pc++]]);
    
    reg[(unsigned long)code[pc++]] = INT2FIX(rand() % i);
  }
  goto *code[pc];
  

 E_INC:
  //    puts("INC src dest");
  pc++;
  {
    int i = FIX2INT(reg[(unsigned long)code[pc++]]);
    
    reg[(unsigned long)code[pc++]] = INT2FIX(++i);
  }
  goto *code[pc];
  
 E_DEC:
  //    puts("DEC src dest");
  pc++;
  {
    int i = FIX2INT(reg[(unsigned long)code[pc++]]);
    
    reg[(unsigned long)code[pc++]] = INT2FIX(--i);
  }
  goto *code[pc];
  

  
 E_CNCTGN:
  //    puts("CNCTGN reg reg");
  // "x"~s, "x"->t     ==> push(s,t), free("x") where "x" is a global name.
  {
    VALUE x = reg[(unsigned long)code[pc+1]];
    a1 = NAME(x)->port;
    freeName(x);
    PUSH(vm, reg[(unsigned long)code[pc+2]], a1);
  }
  pc +=3;
  goto *code[pc];
       
  

 E_SUBSTGN:
  //    puts("SUBSTGN reg reg");  
  // "x"~s, t->u("x")  ==> t->u(s), free("x") where "x" is a global name.
  {
    VALUE x = reg[(unsigned long)code[pc+1]];
    global_replace_keynode_in_another_term(x,reg[(unsigned long)code[pc+2]]);
    freeName(x);
  }
  pc +=3;
  goto *code[pc];
  
  
  
  
  // extended codes should be ended here.


 E_NOP:
  pc++;
  goto *code[pc];



}





/******************************************
 Mark and Sweep for error recovery
******************************************/
#ifndef THREAD

#ifdef EXPANDABLE_HEAP
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
#else

// v0.5.6
void sweep_AgentHeap(Heap *hp) {
  int i;
  for (i=0; i < hp->size; i++) {
    if (!IS_FLAG_MARKED( ((Agent *)hp->heap)[i].basic.id)) {
      SET_HEAPFLAG_READYFORUSE( ((Agent *)hp->heap)[i].basic.id);
    } else {
      TOGGLE_FLAG_MARKED( ((Agent *)hp->heap)[i].basic.id);
    }
  }
}
void sweep_NameHeap(Heap *hp) {
  int i;
  for (i=0; i < hp->size; i++) {
    if (!IS_FLAG_MARKED( ((Name *)hp->heap)[i].basic.id)) {
      SET_HEAPFLAG_READYFORUSE( ((Name *)hp->heap)[i].basic.id);
    } else {
      TOGGLE_FLAG_MARKED( ((Name *)hp->heap)[i].basic.id);
    }
  }
}


#endif


void mark_and_sweep(void) {

  mark_allHash();  
  sweep_AgentHeap(&(VM.agentHeap));  
  sweep_NameHeap(&VM.nameHeap);
  VM.nextPtr_eqStack = -1;  
}

#endif



/***********************************
 exec coequation
**********************************/
//#define DEBUG


//#define CAS_USLEEP 4
#define CAS_USLEEP 100


// It seems better WITHOUT `static inline'
//static inline
void eval_equation(VirtualMachine *restrict vm, VALUE a1, VALUE a2) {

loop:

  // a2 is fixnum
  if (IS_FIXNUM(a2)) {
loop_a2IsFixnum:    
    if (IS_FIXNUM(a1)) {
      printf("Runtime ERROR: "); puts_term(a1); printf("~"); puts_term(a2); 
      printf("\nInteger %d >< %d can not be used as an active pair\n",
	     FIX2INT(a1), FIX2INT(a2));
#ifndef THREAD
      mark_and_sweep();
    return;
#else
    printf("Retrieve is not supported in the multi-threaded version.\n");
    exit(-1);
#endif
    }

    // a1 is agent
    if (IS_AGENTID(BASIC(a1)->id)) {

      void **code = NULL;
     
      getRuleCodeInt(a1, &code);

      if (code == NULL) {	
	// built-in
	switch (BASIC(a1)->id) {
	case ID_ADD:
	  {
	    COUNTUP_INTERACTION(vm);
	    
	    BASIC(a1)->id = ID_ADD2;
	    VALUE a1port1 = AGENT(a1)->port[1];
	    AGENT(a1)->port[1] = a2;
	    a2 = a1port1;
	    goto loop;
	  }
	case ID_ADD2:
	  {
	    COUNTUP_INTERACTION(vm);
	    
	    // r << Add(m,n)
	    int n = FIX2INT(AGENT(a1)->port[1]);
	    int m = FIX2INT(a2);
	    a2 = INT2FIX(m+n);
	    VALUE a1port0 = AGENT(a1)->port[0];
	    freeAgent(a1);
	    a1 = a1port0;
	    goto loop;
	  }
	case ID_SUB:
	  {
	    COUNTUP_INTERACTION(vm);
	    
	    BASIC(a1)->id = ID_SUB2;
	    VALUE a1port1 = AGENT(a1)->port[1];
	    AGENT(a1)->port[1] = a2;
	    a2 = a1port1;
	    goto loop;
	  }
	case ID_SUB2:
	  {	    
	    COUNTUP_INTERACTION(vm);
	    
	    // r << Sub(m,n)
	    int n = FIX2INT(AGENT(a1)->port[1]);
	    int m = FIX2INT(a2);
	    a2 = INT2FIX(m-n);
	    VALUE a1port0 = AGENT(a1)->port[0];
	    freeAgent(a1);
	    a1 = a1port0;
	    goto loop;
	  }
	case ID_MUL:
	  {
	    COUNTUP_INTERACTION(vm);
	    
	    BASIC(a1)->id = ID_MUL2;
	    VALUE a1port1 = AGENT(a1)->port[1];
	    AGENT(a1)->port[1] = a2;
	    a2 = a1port1;
	    goto loop;
	  }
	case ID_MUL2:
	  {
	    COUNTUP_INTERACTION(vm);
	    
	    // r << Mult(m,n)
	    int n = FIX2INT(AGENT(a1)->port[1]);
	    int m = FIX2INT(a2);
	    a2 = INT2FIX(m*n);
	    VALUE a1port0 = AGENT(a1)->port[0];
	    freeAgent(a1);
	    a1 = a1port0;
	    goto loop;
	  }
	case ID_DIV:
	  {
	    COUNTUP_INTERACTION(vm);
	    
	    BASIC(a1)->id = ID_DIV2;
	    VALUE a1port1 = AGENT(a1)->port[1];
	    AGENT(a1)->port[1] = a2;
	    a2 = a1port1;
	    goto loop;
	  }
	case ID_DIV2:
	  {
	    COUNTUP_INTERACTION(vm);
	    
	    // r << DIV(m,n)
	    int n = FIX2INT(AGENT(a1)->port[1]);
	    int m = FIX2INT(a2);
	    a2 = INT2FIX(m/n);
	    VALUE a1port0 = AGENT(a1)->port[0];
	    freeAgent(a1);
	    a1 = a1port0;
	    goto loop;
	  }
	case ID_MOD:
	  {
	    COUNTUP_INTERACTION(vm);
	    
	    BASIC(a1)->id = ID_MOD2;
	    VALUE a1port1 = AGENT(a1)->port[1];
	    AGENT(a1)->port[1] = a2;
	    a2 = a1port1;
	    goto loop;
	  }
	case ID_MOD2:
	  {
	    COUNTUP_INTERACTION(vm);
	    
	    // r << MOD(m,n)
	    int n = FIX2INT(AGENT(a1)->port[1]);
	    int m = FIX2INT(a2);
	    a2 = INT2FIX(m%n);
	    VALUE a1port0 = AGENT(a1)->port[0];
	    freeAgent(a1);
	    a1 = a1port0;
	    goto loop;
	  }
	}
      
	
	printf("Runtime Error: There is no interaction rule for the following pair:\n  ");
	puts_term(a1);
	printf("~");
	puts_term(a2);
	puts("");

	if (yyin != stdin) exit(-1);

#ifndef THREAD
	mark_and_sweep();
	return;
#else
	printf("Retrieve is not supported in the multi-threaded version.\n");
	exit(-1);
#endif
      }

      int i;
      unsigned long arity;
      arity = (unsigned long)code[0];

      switch(arity) {
      case 0:
	break;

      case 1:
	vm->reg[VM_OFFSET_METAVAR_L(0)] = AGENT(a1)->port[0];
	break;

      case 2:
	vm->reg[VM_OFFSET_METAVAR_L(0)] = AGENT(a1)->port[0];
	vm->reg[VM_OFFSET_METAVAR_L(1)] = AGENT(a1)->port[1];
	break;
	
      case 3:
	vm->reg[VM_OFFSET_METAVAR_L(0)] = AGENT(a1)->port[0];
	vm->reg[VM_OFFSET_METAVAR_L(1)] = AGENT(a1)->port[1];
	vm->reg[VM_OFFSET_METAVAR_L(2)] = AGENT(a1)->port[2];
	break;

      default:	
	for (i=0; i<arity; i++) {
	  vm->reg[VM_OFFSET_METAVAR_L(i)] = AGENT(a1)->port[i];
	}
      }
	
      vm->reg[VM_OFFSET_ANNOTATE_L] = a1;
      vm->reg[VM_OFFSET_ANNOTATE_R] = a2;

      COUNTUP_INTERACTION(vm);
      
      ExecCode(1, vm, &code[2]);
      return;
      
    } else {
      // a1 is name, a2 is Fixint
      if (NAME(a1)->port != (VALUE)NULL) {
	VALUE a1p0;
	a1p0=NAME(a1)->port;
	freeName(a1);
	a1=a1p0;
	goto loop_a2IsFixnum;
      } else {
#ifndef THREAD
	NAME(a1)->port=a2;	
#else
	if (!(__sync_bool_compare_and_swap(&(NAME(a1)->port), NULL, a2))) {
	  VALUE a1p0;
	  a1p0=NAME(a1)->port;
	  freeName(a1);
	  a1=a1p0;
	  goto loop_a2IsFixnum;
	  
	}
#endif
      }
      
    }
    return;
  }

  
  
  // a2 is agent
  if (IS_AGENTID(BASIC(a2)->id)) {
loop_a2IsAgent:

    // a1 is Fixnum
    if (IS_FIXNUM(a1)) {
      // Fixnum >< agent
      VALUE tmp = a1;
      a1 = a2;
      a2 = tmp;
      goto loop_a2IsFixnum;
    }

    // a1 is agent
    if (IS_AGENTID(BASIC(a1)->id)) {
      /* for the case of  Agent - Agent  */
      
#ifdef DEBUG   
      puts("");
      puts("--------------------------------------");
      puts("execActive");
      puts("--------------------------------------");
      puts_term(a1);puts("");
      printf("><");puts("");
      puts_term(a2);puts("");
      puts("--------------------------------------");
      puts("");
#endif


      if (BASIC(a1)->id < BASIC(a2)->id) {
	VALUE tmp;
	tmp=a1;
	a1=a2;
	a2=tmp;
      }

      int result;
      void **code;
            
      code = getRuleCode(a1, a2, &result);

      if (result == 0) {


	if (BASIC(a2)->id < START_ID_OF_BUILTIN_AGENT)  {
	
	  // built-in
	  switch (BASIC(a1)->id) {
	  
	  case ID_TUPLE0:
	    if (BASIC(a2)->id == ID_TUPLE0) {
	      // [] ~ [] --> nothing
	      COUNTUP_INTERACTION(vm);
      
	      freeAgent(a1);
	      freeAgent(a2);	    
	      return;
	    }
	  
	    break; // end ID_TUPLE0


	  case ID_TUPLE2:
	    if (BASIC(a2)->id == ID_TUPLE2) {
	      // (x1,x2) ~ (y1,y2) --> x1~y1, x2~y2
	      COUNTUP_INTERACTION(vm);
	      
	      VALUE a1p1 = AGENT(a1)->port[1];
	      VALUE a2p1 = AGENT(a2)->port[1];
	      PUSH(vm, a1p1, a2p1);

	      freeAgent(a1);
	      freeAgent(a2);	    
	      a1 = AGENT(a1)->port[0];
	      a2 = AGENT(a2)->port[0];
	      goto loop;
	    }
	  
	    break; // end ID_TUPLE2

	  case ID_TUPLE3:
	    if (BASIC(a2)->id == ID_TUPLE3) {
	      // (x1,x2,x3) ~ (y1,y2,y3) --> x1~y1, x2~y2, x3~y3
	      COUNTUP_INTERACTION(vm);
	      
	      PUSH(vm, AGENT(a1)->port[2], AGENT(a2)->port[2]);
	      PUSH(vm, AGENT(a1)->port[1], AGENT(a2)->port[1]);

	      freeAgent(a1);
	      freeAgent(a2);	    
	      a1 = AGENT(a1)->port[0];
	      a2 = AGENT(a2)->port[0];
	      goto loop;
	    }
	  
	    break; // end ID_TUPLE2


	  case ID_TUPLE4:
	    if (BASIC(a2)->id == ID_TUPLE4) {
	      // (x1,x2,x3) ~ (y1,y2,y3) --> x1~y1, x2~y2, x3~y3
	      COUNTUP_INTERACTION(vm);
	      
	      PUSH(vm, AGENT(a1)->port[3], AGENT(a2)->port[3]);
	      PUSH(vm, AGENT(a1)->port[2], AGENT(a2)->port[2]);
	      PUSH(vm, AGENT(a1)->port[1], AGENT(a2)->port[1]);

	      freeAgent(a1);
	      freeAgent(a2);	    
	      a1 = AGENT(a1)->port[0];
	      a2 = AGENT(a2)->port[0];
	      goto loop;
	    }
	  
	    break; // end ID_TUPLE2

	  
	  case ID_TUPLE5:
	    if (BASIC(a2)->id == ID_TUPLE5) {
	      // (x1,x2,x3) ~ (y1,y2,y3) --> x1~y1, x2~y2, x3~y3
	      COUNTUP_INTERACTION(vm);
	      
	      PUSH(vm, AGENT(a1)->port[4], AGENT(a2)->port[4]);
	      PUSH(vm, AGENT(a1)->port[3], AGENT(a2)->port[3]);
	      PUSH(vm, AGENT(a1)->port[2], AGENT(a2)->port[2]);
	      PUSH(vm, AGENT(a1)->port[1], AGENT(a2)->port[1]);

	      freeAgent(a1);
	      freeAgent(a2);	    
	      a1 = AGENT(a1)->port[0];
	      a2 = AGENT(a2)->port[0];
	      goto loop;
	    }
	  
	    break; // end ID_TUPLE2

	  
	  case ID_NIL:
	    if (BASIC(a2)->id == ID_NIL) {
	      // [] ~ [] --> nothing
	      COUNTUP_INTERACTION(vm);
	      
	      freeAgent(a1);
	      freeAgent(a2);	    
	      return;
	    }
	  
	    break; // end ID_NIL

	  
	  case ID_CONS:
	    if (BASIC(a2)->id == ID_CONS) {
	      // a:b ~ c:d --> a~c, b~d
	      COUNTUP_INTERACTION(vm);
	      
	      VALUE a1p1 = AGENT(a1)->port[1];
	      VALUE a2p1 = AGENT(a2)->port[1];
	      PUSH(vm, a1p1, a2p1);

	      freeAgent(a1);
	      freeAgent(a2);	    
	      a1 = AGENT(a1)->port[0];
	      a2 = AGENT(a2)->port[0];
	      goto loop;
	    }
	  
	    break; // end ID_CONS


	  
	    // built-in funcAgent for lists and tuples
	  case ID_APPEND:
	    switch (BASIC(a2)->id) {
	    case ID_NIL:
	      {
		// App(r,a) >< [] => r~a;
		COUNTUP_INTERACTION(vm);
	      
		VALUE a1p0 = AGENT(a1)->port[0];
		VALUE a1p1 = AGENT(a1)->port[1];
		freeAgent(a1);
		freeAgent(a2);
		a1=a1p0;
		a2=a1p1;
		goto loop;
	      }
	    
	    case ID_CONS:
	      {
		// App(r,a) >< [x|xs] => r~(*R)[x|w], (*L)App(w,a)~xs;
		COUNTUP_INTERACTION(vm);
		
		VALUE a1p0 = AGENT(a1)->port[0];
		VALUE a2p1 = AGENT(a2)->port[1];
		VALUE w = makeName(vm);
	      
		AGENT(a2)->port[1] = w;
		PUSH(vm, a1p0, a2);
		//VM_EQStack_Push(vm, a1p1, a2);
	      
		AGENT(a1)->port[0] = w;
		a2 = a2p1;
		goto loop;
	      }
	    }
	    
	    break; // end ID_APPEND

	  
	  case ID_MERGER:
	    switch (BASIC(a2)->id) {
	    case ID_TUPLE2:
	      {
		// MG(r) ~ (a|b) => *MGp(*r)~a, *MGp(*r)~b
		COUNTUP_INTERACTION(vm);
		
		BASIC(a1)->id = ID_MERGER_P;
		AGENT(a1)->port[1] = (VALUE)NULL;
		AGENT(a1)->port[2] = (VALUE)NULL;
		PUSH(vm, a1, AGENT(a2)->port[1]);
		PUSH(vm, a1, AGENT(a2)->port[0]);
		freeAgent(a2);
		return;
		
		
	      }
	    }
	    break; // end ID_MG

	  case ID_MERGER_P:
	    switch (BASIC(a2)->id) {
	    case ID_NIL:
	      // *MGP(r)~[]
#ifndef THREAD

	      COUNTUP_INTERACTION(vm);
	      
	      if (AGENT(a1)->port[1] == (VALUE)NULL) {
		AGENT(a1)->port[1] = a2;
		return;
	      } else {
		VALUE a1p0 = AGENT(a1)->port[0];
		freeAgent(AGENT(a1)->port[1]);
		freeAgent(a1);
		a1 = a1p0;
		goto loop;
	      }
#else
	      // AGENT(a1)->port[2] is used as a lock for NIL case
	      if (AGENT(a1)->port[2] == (VALUE)NULL) {
		if (!(__sync_bool_compare_and_swap(&(AGENT(a1)->port[2]),
						   NULL, a2))) {
		  // something exists already
		  goto loop;		
		  
		} else {
		  return;
		}
	      } else if ((AGENT(a1)->port[2] != (VALUE)NULL) &&
			 (BASIC(AGENT(a1)->port[2])->id == ID_NIL)) {

		COUNTUP_INTERACTION(vm);
		
		VALUE a1p0 = AGENT(a1)->port[0];
		freeAgent(AGENT(a1)->port[2]);
		freeAgent(a1);
		a1 = a1p0;
		goto loop;
	      } else {
		goto loop;
	      }
	      
#endif
	    case ID_CONS:
	      // *MGP(r)~x:xs => r~x:w, *MGP(w)~xs;
	      {
#ifndef THREAD

		COUNTUP_INTERACTION(vm);
		
		VALUE a1p0 = AGENT(a1)->port[0];
		VALUE w = makeName(vm);
		AGENT(a1)->port[0] = w;
		PUSH(vm, a1, AGENT(a2)->port[1]);
		
		AGENT(a2)->port[1] = w;
		a1 = a1p0;
		goto loop;
#else
		// AGENT(a1)->port[1] is used as a lock for CONS case
		// AGENT(a1)->port[2] is used as a lock for NIL case

		if (AGENT(a1)->port[2] != (VALUE)NULL) {
		  // The other MGP finished still, so:
		  // *MGP(r)~x:xs => r~x:xs;

		  COUNTUP_INTERACTION(vm);
		  
		  VALUE a1p0 = AGENT(a1)->port[0];
		  freeAgent(AGENT(a1)->port[2]);   // free the lock for NIL
		  freeAgent(a1);
		  a1 = a1p0;
		  goto loop;
		  
		} else if (AGENT(a1)->port[1] == (VALUE)NULL) {
		  if (!(__sync_bool_compare_and_swap(&(AGENT(a1)->port[1]),
						     NULL,
						     a2))) {
		    // Failure to be locked.
		    goto loop;
		  }

		  // Succeed the lock
		  COUNTUP_INTERACTION(vm);
		  
		  VALUE a1p0 = AGENT(a1)->port[0];		  
		  VALUE w = makeName(vm);
		  AGENT(a1)->port[0] = w;
		  PUSH(vm, a1, AGENT(a2)->port[1]);
		  
		  AGENT(a2)->port[1] = w;
		  
		  AGENT(a1)->port[1] = (VALUE)NULL; // free the lock
		  
		  a1 = a1p0;
		  
		  goto loop;
		  
		} else {
		  // MPG works for the other now.
		  
		  goto loop;
		}
		
		
#endif
	      }
	      
	    }
	    break; // end ID_MERGER_P
	  }
	}
    

	
	printf("Runtime Error: There is no interaction rule for the following pair:\n  ");
	puts_term(a1);
	printf("~");
	puts_term(a2);
	puts("");

	if (yyin != stdin) exit(-1);

#ifndef THREAD
	mark_and_sweep();
	return;
#else
	printf("Retrieve is not supported in the multi-threaded version.\n");
	exit(-1);
#endif
      }
      // normal op
      

      //      PutsCode(at);
      //      return;

      
      int i;
      unsigned long arity;
      arity = (unsigned long)code[0];

      switch(arity) {
      case 0:
	break;

      case 1:
	vm->reg[VM_OFFSET_METAVAR_L(0)] = AGENT(a1)->port[0];
	break;

      case 2:
	vm->reg[VM_OFFSET_METAVAR_L(0)] = AGENT(a1)->port[0];
	vm->reg[VM_OFFSET_METAVAR_L(1)] = AGENT(a1)->port[1];
	break;
	
      case 3:
	vm->reg[VM_OFFSET_METAVAR_L(0)] = AGENT(a1)->port[0];
	vm->reg[VM_OFFSET_METAVAR_L(1)] = AGENT(a1)->port[1];
	vm->reg[VM_OFFSET_METAVAR_L(2)] = AGENT(a1)->port[2];
	break;

      default:	
	for (i=0; i<arity; i++) {
	  vm->reg[VM_OFFSET_METAVAR_L(i)] = AGENT(a1)->port[i];
	}
      }

      
      arity = (unsigned long)code[1];
      switch(arity) {
      case 0:
	break;

      case 1:
	vm->reg[VM_OFFSET_METAVAR_R(0)] = AGENT(a2)->port[0];
	break;

      case 2:
	vm->reg[VM_OFFSET_METAVAR_R(0)] = AGENT(a2)->port[0];
	vm->reg[VM_OFFSET_METAVAR_R(1)] = AGENT(a2)->port[1];
	break;
	
      case 3:
	vm->reg[VM_OFFSET_METAVAR_R(0)] = AGENT(a2)->port[0];
	vm->reg[VM_OFFSET_METAVAR_R(1)] = AGENT(a2)->port[1];
	vm->reg[VM_OFFSET_METAVAR_R(2)] = AGENT(a2)->port[2];
	break;

      default:	
	for (i=0; i<arity; i++) {
	  vm->reg[VM_OFFSET_METAVAR_R(i)] = AGENT(a2)->port[i];
	}
      }

      
      vm->reg[VM_OFFSET_ANNOTATE_L] = a1;
      vm->reg[VM_OFFSET_ANNOTATE_R] = a2;

      //freeAgent(a1);
      //freeAgent(a2);

      //      vm->L = a1;
      //      vm->R = a2;

      COUNTUP_INTERACTION(vm);
      
      ExecCode(1, vm, &code[2]);


	
      return;
    }  else {

      // a1 is name
      // a2 is agent
      if (NAME(a1)->port != (VALUE)NULL) {

	VALUE a1p0;
	a1p0=NAME(a1)->port;
	freeName(a1);
	a1=a1p0;
	goto loop_a2IsAgent;
      } else {
#ifndef THREAD
	NAME(a1)->port=a2;
#else
	if (!(__sync_bool_compare_and_swap(&(NAME(a1)->port), NULL, a2))) {
	  VALUE a1p0;
	  a1p0=NAME(a1)->port;
	  freeName(a1);
	  a1=a1p0;
	  goto loop_a2IsAgent;
	  
	}
#endif

      }
    }
  } else {
    // a2 is name, a1 is unknown.
    
    if (NAME(a2)->port != (VALUE)NULL) {
      VALUE a2p0;
      a2p0=NAME(a2)->port;
      freeName(a2);
      a2=a2p0;
      goto loop;
    } else {
#ifndef THREAD
      NAME(a2)->port=a1;
#else
      if (!(__sync_bool_compare_and_swap(&(NAME(a2)->port), NULL, a1))) {
	VALUE a2p0;
	a2p0=NAME(a2)->port;
	freeName(a2);
	a2=a2p0;
	goto loop;
      }
#endif
    }
  }
}








void select_kind_of_push(Ast *ast, int p1, int p2) {  
  int sym_id = NameTable_get_id(ast->left->sym);
  
  if (IS_GNAMEID(sym_id)) {
    // aheap already exists as a global
    VALUE aheap = IdTable_get_heap(sym_id);
    
    // aheap is connected with something such as aheap->t
    // ==> p2 should be conncected with t, so OP_CNCTGN(p1,p2)
    if (NAME(aheap)->port != (VALUE)NULL) {
      IMCode_genCode2(OP_CNCTGN, p1, p2);
      
    } else {
      // aheap occurs somewhere, so it should be replaced by OP_SUBSTGN(p1,p2)
      IMCode_genCode2(OP_SUBSTGN, p1, p2);
    }
  } else {
    IMCode_genCode2(OP_PUSH, p1, p2);
  }
    
}




#ifndef THREAD


#define WHNF_UNUSED_STACK_SIZE 100
typedef struct {
  // EQStack
  EQ *eqs;
  int eqs_index;
  int size;
  int enabled;  // 0: not Enabled, 1: Enabled.  
} WHNF_Info; 
WHNF_Info WHNFinfo;

void Init_WHNFinfo(void) {
  WHNFinfo.eqs_index = 0;
  WHNFinfo.size = WHNF_UNUSED_STACK_SIZE;
  WHNFinfo.enabled = 0;  // not Enabled

  WHNFinfo.eqs = malloc(sizeof(EQ) * WHNF_UNUSED_STACK_SIZE);
  if (WHNFinfo.eqs == NULL) {
    printf("WHNFinfo.eqs: Malloc error\n");
    exit(-1);
  }
}
  
void WHNFInfo_push_equation(VALUE t1, VALUE t2) {
  WHNFinfo.eqs[WHNFinfo.eqs_index].l = t1;
  WHNFinfo.eqs[WHNFinfo.eqs_index].r = t2;
  WHNFinfo.eqs_index++;
  if (WHNFinfo.eqs_index >= WHNF_UNUSED_STACK_SIZE) {
    printf("ERROR: WHNFinfo.eqs stack becomes full.\n");
    exit(-1);
  }
}
  

void WHNF_execution_loop(void) {
  VALUE t1, t2;

  while (EQStack_Pop(&VM, &t1, &t2)) {

    puts_term(t1); printf("~"); puts_term(t2); puts("");
    
    if ((NameTable_check_if_term_has_gname(t1) == 1) ||
	(NameTable_check_if_term_has_gname(t2) == 1)) {

      eval_equation(&VM, t1, t2);
	
    } else {
      
      WHNFInfo_push_equation(t1, t2);
    }
  }
  
}




int exec(Ast *at) {
  // Ast at: (AST_BODY stmlist aplist)

  unsigned long long t, time;  
  
  void* code[MAX_CODE_SIZE];

  
  start_timer(&t);

  CmEnv_clear_all();

  // for `where' expression
  if (!CompileStmListFromAst(at->left)) return 0;


  // aplist
  at = at->right;

  // for aplists
  //      puts(""); ast_puts(at); puts("");
  Ast_RewriteOptimisation_EQList(at);
  //      puts(""); ast_puts(at); puts("");
  //      exit(1);

  
  // Syntax error check
  {
    Ast *tmp_at=at;
    while (tmp_at != NULL) {
      if ((check_invalid_occurrence(tmp_at->left->left))
	  && (check_invalid_occurrence(tmp_at->left->right))) {
	// both ara invalid
	if (yyin != stdin) exit(-1);
	return 0;
      }
      
      tmp_at = ast_getTail(tmp_at);
    }
  }

  
  while (at != NULL) {
    int p1,p2;
    Ast *left, *right;

    left = at->left->left;
    right = at->left->right;
    p1 = CompileTermFromAst(left, -1);
    p2 = CompileTermFromAst(right, -1);


    if (left->id == AST_NAME) {
      select_kind_of_push(left, p1, p2);
      
    } else if (right->id == AST_NAME) {
      select_kind_of_push(right, p2, p1);
      
    } else {
      IMCode_genCode2(OP_PUSH, p1, p2);
    }
    
    at = ast_getTail(at);



  }
  IMCode_genCode0(OP_RET);

  

  // checking whether names occur more than twice
  if (!CmEnv_check_name_reference_times()) {
    if (yyin != stdin) exit(-1);
    return 0;
  }


  CmEnv_Retrieve_GNAME();
  CmEnv_generate_VMCode(code);

  
  /*
  // for debug
  CmEnv_Retrieve_GNAME();
  IMCode_puts(0); //exit(1);

  int codenum = CmEnv_generate_VMCode(code);
  VMCode_puts(code, codenum-2); //exit(1);
  // end for debug
  */
  
  
#ifdef COUNT_MKAGENT
  NumberOfMkAgent=0;
#endif

  
  // WHNF: Unused equations are stacked to be execution targets again.  
  if (WHNFinfo.enabled) {    
    for (int i=0; i < WHNFinfo.eqs_index ; i++) {
      MYPUSH(&VM, WHNFinfo.eqs[i].l, WHNFinfo.eqs[i].r);
    }
    WHNFinfo.eqs_index = 0;
  }

  
  ExecCode(1, &VM, code);


#ifdef COUNT_INTERACTION
  VM_Clear_InteractionCount(&VM);
#endif



  // EXECUTION LOOP

  if (!WHNFinfo.enabled) {
    // no-stategy execution
    
    VALUE t1, t2;
    while (EQStack_Pop(&VM, &t1, &t2)) {
      eval_equation(&VM, t1, t2);   
    }
    
  } else {
    // WHNF stragety
    WHNF_execution_loop();
  }	
    

  time=stop_timer(&t);
#ifdef COUNT_INTERACTION
  printf("(%d interactions, %.2f sec)\n", VM_Get_InteractionCount(&VM),
	 (double)(time)/1000000);
#else
  printf("(%.2f sec)\n", 
	 (double)(time)/1000000);
#endif

#ifdef COUNT_MKAGENT
  printf("(%d mkAgent calls)\n", NumberOfMkAgent);
#endif

  
#ifdef VERBOSE_NODE_USE
  printf("(%lu agents and %lu names nodes are used.)\n", 
	 Heap_GetNum_Usage_forAgent(&VM.agentHeap),
	 Heap_GetNum_Usage_forName(&VM.nameHeap));
#endif	 

#ifdef COUNT_CNCT
  printf("JMP_CNCT:%d true:%d ratio:%.2f%%\n",
	 Count_cnct, Count_cnct_true, Count_cnct_true*100.0/Count_cnct);
  printf("  ind_op:%d ratio(ind/JMP_CNCT):%.2f%%\n",
	 Count_cnct_indirect_op, Count_cnct_indirect_op*100.0/Count_cnct);
#endif
  
  return 1;
}

#else

int CpuNum=1; // CPU 数の設定用（sysconf(_SC_NPROSSEORS_CONF)) を使って求める）

static pthread_cond_t ActiveThread_all_sleep = PTHREAD_COND_INITIALIZER;
static pthread_t *Threads;
static VirtualMachine **VMs;

void *tpool_thread(void *arg) {

  VirtualMachine *vm;

  vm = (VirtualMachine *)arg;

  
#ifdef CPU_ZERO
  cpu_set_t mask;
  CPU_ZERO(&mask);
  CPU_SET((vm->id)%CpuNum, &mask);
  if(sched_setaffinity(0, sizeof(mask), &mask)==-1) {
    printf("WARNING:");
    printf("Thread%d works on Core%d/%d\n", vm->id, (vm->id)%CpuNum, CpuNum-1);
  }
  //  printf("Thread%d works on Core%d/%d\n", vm->id, (vm->id)%CpuNum, CpuNum-1);  
#endif


  while (1) {

    VALUE t1, t2;
    while (!EQStack_Pop(vm, &t1, &t2)) {

      // Not sure, but it works well. Perhaps it can reduce race condition.
      usleep(CAS_LOCK_USLEEP);

      
      pthread_mutex_lock(&Sleep_lock);
      SleepingThreadsNum++;

      if (SleepingThreadsNum == MaxThreadsNum) {
	pthread_mutex_lock(&AllSleep_lock);
	pthread_cond_signal(&ActiveThread_all_sleep);
	pthread_mutex_unlock(&AllSleep_lock);
      }

      //            printf("[Thread %d is slept.]\n", vm->id);
      pthread_cond_wait(&EQStack_not_empty, &Sleep_lock);
      SleepingThreadsNum--;
      pthread_mutex_unlock(&Sleep_lock);  
      //            printf("[Thread %d is waked up.]\n", vm->id);



      
    }



    eval_equation(vm, t1, t2);

    
  }

  return (void *)NULL;
}

#ifdef EXPANDABLE_HEAP    
void tpool_init(unsigned int eqstack_size) {
#else
  //v0.5.6
void tpool_init(unsigned int agentBufferSize, unsigned int eqstack_size) {  
#endif
  
  
  int i, status;
  //  static int id[100];


  pthread_attr_t attr;
  pthread_attr_init(&attr);
  pthread_attr_setscope(&attr, PTHREAD_SCOPE_SYSTEM);


  CpuNum = sysconf(_SC_NPROCESSORS_CONF);

  pthread_setconcurrency(CpuNum);


  SleepingThreadsNum = 0;
  Threads = (pthread_t *)malloc(sizeof(pthread_t)*MaxThreadsNum);
  if (Threads == NULL) {
    printf("the thread pool could not be created.");
    exit(-1);
  }

  VMs = malloc(sizeof(VirtualMachine*)*MaxThreadsNum);
  if (VMs == NULL) {
    printf("the thread pool could not be created.");
    exit(-1);
  }


  for (i=0; i<MaxThreadsNum; i++) {
    VMs[i] = malloc(sizeof(VirtualMachine));
    VMs[i]->id = i;
    
#ifdef EXPANDABLE_HEAP    
    VM_Init(VMs[i], eqstack_size);
#else
    VM_Init(VMs[i], agentBufferSize, eqstack_size);
#endif
    
    status = pthread_create( &Threads[i],
		    &attr,
		    tpool_thread,
		    (void *)VMs[i]);
    if (status!=0) {
      printf("ERROR: Thread%d could not be created.", i);
      exit(-1);
    }
  }
}

void tpool_destroy(void) {
  int i;
  for (i=0; i<MaxThreadsNum; i++) {
    pthread_join( Threads[i],
		  NULL);
  }
  free(Threads);


}


int exec(Ast *at) {
  // Ast at: (AST_BODY stmlist aplist)
  
  unsigned long long t, time;
  int i;

#ifdef COUNT_INTERACTION
  for (i=0; i<MaxThreadsNum; i++) {
    VM_Clear_InteractionCount(VMs[i]);
  }
#endif

  void* code[MAX_CODE_SIZE];
  
  int eqsnum = 0;

  start_timer(&t);
  
  CmEnv_clear_all();

  // for `where' expression
  if (!CompileStmListFromAst(at->left)) return 0;

  
  // aplist
  at = at->right;
  
  Ast_RewriteOptimisation_EQList(at);

  // Syntax error check
  {
    Ast *tmp_at=at;
    while (tmp_at != NULL) {
      if ((check_invalid_occurrence(tmp_at->left->left))
	  && (check_invalid_occurrence(tmp_at->left->right))) {
	// both ara invalid
	if (yyin != stdin) exit(-1);
	return 0;
      }
      
      tmp_at = ast_getTail(tmp_at);
    }
  }

  
  while (at!=NULL) {
    int p1,p2;
    Ast *left, *right;
    left = at->left->left;
    right = at->left->right;
    p1 = CompileTermFromAst(left, -1);
    p2 = CompileTermFromAst(right, -1);

    if (left->id == AST_NAME) {
      select_kind_of_push(left, p1, p2);
      
    } else if (right->id == AST_NAME) {
      select_kind_of_push(right, p2, p1);
      
    } else {
      IMCode_genCode2(OP_PUSH, p1, p2);
    }
        
    eqsnum++;   //分散用
    at = ast_getTail(at);
  }
  IMCode_genCode0(OP_RET);

  
  // checking whether names occur more than twice
  if (!CmEnv_check_name_reference_times()) {
    return 0;
  }


  CmEnv_Retrieve_GNAME();
  CmEnv_generate_VMCode(code);

  /*
  // for debug
  CmEnv_Retrieve_GNAME();
  IMCode_puts(0); //exit(1);

  int codenum = CmEnv_generate_VMCode(code);
  VMCode_puts(code, codenum-2); //exit(1);
  // end for debug
  */
  
      
  ExecCode(1, VMs[0], code);


  
  //分散用
  {
    int each_eqsnum = eqsnum / MaxThreadsNum;
    if (each_eqsnum == 0) each_eqsnum = 1;
    for (i=1; i<MaxThreadsNum; i++) {
      VALUE t1, t2;
      int j;
      for (j=0; j<each_eqsnum; j++) {
	if (!VM_EQStack_Pop(VMs[0], &t1, &t2)) goto endloop;
	VM_EQStack_Push(VMs[i], t1, t2);
      }
    }
  }
 endloop:


  
  pthread_mutex_lock(&Sleep_lock);
  pthread_cond_broadcast(&EQStack_not_empty);
  pthread_mutex_unlock(&Sleep_lock);

  // a little wait until all threads start.
  //usleep(CAS_LOCK_USLEEP);  
  usleep(10000);  // 0.01 sec wait


  // if some threads are working, wait for all of these to sleep.
  if (SleepingThreadsNum < MaxThreadsNum) {
    pthread_mutex_lock(&AllSleep_lock);
    pthread_cond_wait(&ActiveThread_all_sleep, &AllSleep_lock);
    pthread_mutex_unlock(&AllSleep_lock);
  }

  time=stop_timer(&t);

#ifdef COUNT_INTERACTION
  unsigned long total=0;
  for (i=0; i<MaxThreadsNum; i++) {
    total += VM_Get_InteractionCount(VMs[i]);
  }
  printf("(%lu interactions by %d threads, %.2f sec)\n", 
	 total,
	 MaxThreadsNum,
	 (double)(time)/1000000.0);


#else
  printf("(%.2f sec by %d threads)\n", 	
          (double)(time)/1000000.0,
          MaxThreadsNum);
#endif


  return 0;
}
#endif



int destroy() {

  return 0;
}

int yywrap() {
  return 1;
}


int main(int argc, char *argv[])
{ 
  int i, param;
  char *fname = NULL;
  int max_EQStack=1<<8; // 512
  int retrieve_flag = 1; // 1: retrieve to interpreter even if error occurs

#ifndef EXPANDABLE_HEAP
  // v0.5.6
  unsigned int heap_size=100000;
#endif

  
#ifdef MY_YYLINENO
  InfoLineno_Init();
#endif

 // Pritty printing for local variables
#ifdef PRETTY_VAR
  Pretty_init();
#endif

  
#ifndef THREAD
  Init_WHNFinfo();
#endif

  ast_heapInit();


#ifdef THREAD  
  MaxThreadsNum = sysconf(_SC_NPROCESSORS_CONF);
#endif
  
  
  for (i=1; i<argc; i++) {
    if (*argv[i] == '-') {
      switch (*(argv[i] +1)) {
      case 'v':
	printf("Inpla version %s\n", VERSION);
	exit(-1);
	break;
      case '-':
      case 'h':
      case '?':
	printf("Inpla version %s\n", VERSION);	  
	puts("Usage: inpla [options]\n");
	puts("Options:");
	printf(" -f <filename>    Set input file name                 (Defalut:    STDIN)\n");

#ifndef EXPANDABLE_HEAP
	//v0.5.6
	printf(" -c <number>      Set the size of heaps               (Defalut: %8u)\n", heap_size);
#endif
	
	printf(" -e <number>      Set the unit size of the EQ stack   (Default: %8u)\n", max_EQStack);
	

	// Special Options
#ifdef THREAD
	printf(" -t <number>      Set the number of threads           (Default: %8d)\n", MaxThreadsNum);

#else
	printf(" -w               Enable Weak Reduction strategy      (Default:    false)\n");
#endif
	  
	printf(" -d <Name>=<val>  Bind <val> to <Name>\n");
        printf(" -h               Print this help message\n\n");
        exit(-1);
	break;

	
      case 'd':
	i++;
	if (i < argc) {
	  char varname[100], val[100];
	  char *tp;

	  tp = strtok(argv[i], "=");
	    
	  // parsing for an identifier
	  snprintf(varname, sizeof(varname)-1, "%s", tp);
	  if ((varname == NULL) || (varname[0] < 'A') || (varname[0] > 'Z')) {
      	    puts("ERROR: 'id' in the format 'id=value' must start from a capital letter.");
      	    exit(-1);
	  }

	  
	  tp = strtok(NULL, "=");

	  // parsing for a number
	  snprintf(val, sizeof(val)-1, "%s", tp);
	  if (val == NULL) {
	    puts("ERROR: 'value' in the format 'id=value' must an integer value.");
	    exit(-1);	      
	  }

	  int offset = 0;
	  if (val[0] == '-') {
	    offset = 1;
	  }
	  int valid = 1;
	  for (int idx = offset; idx < strlen(val); idx++) {
	    if ((val[idx] < '0') || (val[idx] > '9')) {
	      valid = 0;
	      break;
	    }
	  }

	  if (!valid) {
	    puts("ERROR: 'value' in the format 'id=value' must an integer value.");
	    exit(-1);	      	      
	  }
	  
	  ast_recordConst(varname, atoi(val));

	} else {
	  puts("ERROR: The option switch '-d' needs a string such as VarName=value.");
	  exit(-1);
	}
	break;
	  
      case 'f':
	i++;
	if (i < argc) {
	  fname = argv[i];
	  retrieve_flag = 0;
	} else {
	  printf("ERROR: The option switch '-f' needs a string of an input file name.");
	  exit(-1);
	}
	break;


#ifndef EXPANDABLE_HEAP
      case 'c':
	// v0.5.6
        i++;
        if (i < argc) {
          param = atoi(argv[i]);
          if (param == 0) {
            printf("ERROR: '%s' is illegal parameter for -c\n", argv[i]);
            exit(-1);
          }
        } else {
          printf("ERROR: The option switch '-c' needs a number as an argument.");
          exit(-1);
        }
        heap_size=param;
        break;
#endif	  
	  
	  
      case 'e':
        i++;
        if (i < argc) {
          param = atoi(argv[i]);
          if (param == 0) {
            printf("ERROR: '%s' is illegal parameter for -e\n", argv[i]);
            exit(-1);
          }
        } else {
          printf("ERROR: The option switch '-e' needs a natural number.");
          exit(-1);
        }
        max_EQStack=param;
        break;
	  
	  
#ifdef THREAD
      case 't':
        i++;
        if (i < argc) {
          param = atoi(argv[i]);
          if (param == 0) {
            printf("ERROR: '%s' is illegal parameter for -t\n", argv[i]);
            exit(-1);
          }
        } else {
          printf("ERROR: The option switch '-t' needs a number of threads.");
          exit(-1);
        }
  
        MaxThreadsNum=param;
        break;
#else
      case 'w':
        WHNFinfo.enabled = 1;
        break;	  
#endif
	  
	  
      default:
        printf("ERROR: Unrecognized option %s\n", argv[i]);
        printf("Use -h option for getting more information.\n\n");
        exit(-1);
      }
    } else {
      printf("ERROR: Unrecognized option %s\n", argv[i]);
      printf("Use -h option for getting more information.\n\n");
      exit(-1);
    }
  }


  // Dealing with fname
  if (fname == NULL) {
    yyin = stdin;
    
  } else {
    if (!(yyin = fopen(fname, "r"))) {
      printf("Error: The file '%s' can not be opened.\n", fname);
      exit(-1);
    }
  }

#ifndef THREAD
  if (WHNFinfo.enabled) {
    printf("Inpla %s (Weak Strategy) : Interaction nets as a programming language", VERSION);
    printf(" [%s]\n", BUILT_DATE);
  } else {
    printf("Inpla %s : Interaction nets as a programming language", VERSION);
    printf(" [built: %s]\n", BUILT_DATE);
  }
#else
  printf("Inpla %s : Interaction nets as a programming language", VERSION);
  printf(" [built: %s]\n", BUILT_DATE);    
#endif



#ifndef EXPANDABLE_HEAP
  // v0.5.6
  heap_size = heap_size/MaxThreadsNum;    
#endif
    
    
  IdTable_init();    
  NameTable_init();
  RuleTable_init();
  CodeAddr_init();
  
#ifdef THREAD
  GlobalEQStack_Init(MaxThreadsNum*8);
#endif

    
    
    
    
#ifdef EXPANDABLE_HEAP

#ifndef THREAD    
  VM_Init(&VM, max_EQStack);
#else
  tpool_init(max_EQStack);    
#endif
  
#else // ifndef EXPANDABLE_HEAP
  //v0.5.6

#ifndef THREAD        
  VM_Init(&VM, heap_size, max_EQStack);
#else    
  tpool_init(heap_size, max_EQStack);
#endif

  
#endif
    


  
#ifdef THREAD
  // if some threads invoked by the initialise are still working,
  // wait for all of these to sleep.
  if (SleepingThreadsNum < MaxThreadsNum) {
    pthread_mutex_lock(&AllSleep_lock);
    pthread_cond_wait(&ActiveThread_all_sleep, &AllSleep_lock);
    pthread_mutex_unlock(&AllSleep_lock);
  }
#endif
  
  
  linenoiseHistoryLoad(".inpla.history.txt");

  
  // the main loop of parsing and execution
  while(1) {

    // When errors occur during parsing
    if (yyparse()!=0) {
      
      if (!retrieve_flag) {
      	exit(0);
      }
      
      if (yyin != stdin) {
      	fclose(yyin);
        while (yyin!=stdin) {
      	  popFP();
      	}
#ifdef MY_YYLINENO
      	InfoLineno_AllDestroy();
#endif
      }
      
    }
  }
  
  exit(0);
}
 

#include "lex.yy.c"
