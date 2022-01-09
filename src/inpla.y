%{
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sched.h>

#include "linenoise/linenoise.h"
  
#include "ast.h"
#include "id_table.h"
#include "name_table.h"

#include "timer.h" //#include <time.h>

//#define DEBUG
#define COUNT_INTERACTION // count of interaction
//#define NODE_USE_VERBOSE  // count of memory access


// For experiments of the tail recursion optimisation.
//#define COUNT_CNCT    // count of execution of JMP_CNCT
//#define COUNT_MKAGENT // count of execution fo mkagent



  
/**************************************
 NAME TABLE
**************************************/
//#include "name_table.h"


// ----------------------------------------------

int MaxThreadsNum=1;

#ifdef THREAD
#include <pthread.h>
extern int pthread_setconcurrency(int concurrency); 

int SleepingThreadsNum=0;

// for cas spinlock
#include "cas_spinlock.h"

#endif

//#define YYDEBUG 1

#define VERSION "0.6.0"
#define BUILT_DATE  "9 Jan. 2022"

 
extern FILE *yyin;


#include "mytype.h"

// Equation
typedef struct EQ_tag {
  VALUE l, r;
} EQ;

typedef struct EQList_tag {  
  EQ eq;
  struct EQList_tag *next;
} EQList;







int makeRule(Ast *ast);
void freeAgentRec(VALUE ptr);

//static inline void freeName(VALUE ptr);
void freeName(VALUE ptr);

//static inline void freeAgent(VALUE ptr);
void freeAgent(VALUE ptr);

void puts_names_ast(Ast *ast);
void free_names_ast(Ast *ast);
void puts_name_port0_nat(VALUE ptr);
void puts_term(VALUE ptr);
void puts_aplist(EQList *at);
void PushEQStack(VALUE l, VALUE r);


int exec(Ast *st);
int destroy(void);
int AstHeap_MakeAgent(int arity, char *name, int *port);
int AstHeap_MakeTerm(char *name);
int AstHeap_MakeName(char *name);



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


// In order to prevent from putting yyerror message,
// the message will be stored here.
static char *Errormsg = NULL;


//#define YYDEBUG			1
//#define YYERROR_VERBOSE		1
//int yydebug = 1;

/*
extern void eat_to_newline(void);
void eat_to_newline(void)
{
    int c;
    while ((c = getchar()) != EOF && c != '\n')
        ;
}
*/

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

%token PIPE AMP LD EQUAL NE GT GE LT LE
%token ADD SUB MUL DIV MOD INT LET IN END IF THEN ELSE ANY WHERE RAND DEF
%token INTERFACE IFCE PRNAT FREE EXIT
%token END_OF_FILE USE

%type <ast> body astterm astterm_item nameterm agentterm astparam astparams
val_declare
rule 
ap aplist
stm stmlist_nondelimiter
stmlist 
expr additive_expr equational_expr relational_expr unary_expr
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
  puts_name_port0_nat(NameTable_get_heap($2)); 
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
: relational_expr
| equational_expr EQUAL relational_expr { $$ = ast_makeAST(AST_EQ, $1, $3); }
| equational_expr NE relational_expr { $$ = ast_makeAST(AST_NE, $1, $3); }

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




/**************************************
 TABLE for SYMBOLS
**************************************/
//#include "id_table.h"




/**********************************
  Heap
*********************************/

//#define HOOP_SIZE (1 << 14)
#define HOOP_SIZE (1 << 18)
#define HOOP_SIZE_MASK ((HOOP_SIZE) -1)
typedef struct HoopList_tag {
  VALUE *hoop;
  struct HoopList_tag *next;
} HoopList;


typedef struct Heap_tag {
  HoopList *last_alloc_list;
  int last_alloc_idx;
} Heap;  



/**********************************
  VIRTUAL MACHINE 
*********************************/
#define VM_LOCALVAR_SIZE 200
#define VM_OFFSET_META_L(a) (a)
#define VM_OFFSET_META_R(a) (MAX_PORT+(a))
#define VM_OFFSET_ANNOTATE_L (MAX_PORT*2)
#define VM_OFFSET_ANNOTATE_R (MAX_PORT*2+1)
#define VM_OFFSET_LOCALVAR (MAX_PORT*2+2)



typedef struct {
  // Heaps for agents and names
  Heap agentHeap, nameHeap;
  
  // EQStack
  EQ *eqStack;
  int nextPtr_eqStack;
  unsigned int eqStack_size;


  // code execution
  VALUE reg[VM_LOCALVAR_SIZE+(MAX_PORT*2 + 2)];

  unsigned int id;
#ifdef COUNT_INTERACTION
  unsigned int count_interaction;
  
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


/*************************************
 AGENT and NAME Heaps
**************************************/

// Nodes in hoops with '1' on the 31bit are ready for use and
// '0' are occupied, that is to say, using now.
#define HEAPFLAG_READYFORUSE 0x01 << 31 
#define IS_READYFORUSE(a) ((a) & HEAPFLAG_READYFORUSE)
#define SET_HEAPFLAG_READYFORUSE(a) ((a) = ((a) | HEAPFLAG_READYFORUSE))
#define TOGGLE_HEAPFLAG_READYFORUSE(a) ((a) = ((a) ^ HEAPFLAG_READYFORUSE))



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
    ((Name *)(hp_list->hoop))[i].basic.id = ID_NAME;
    SET_HEAPFLAG_READYFORUSE(((Name *)(hp_list->hoop))[i].basic.id);
  }

  // hp->next = NULL;   // this should be executed only for the first creation.
  return hp_list;
}




HoopList *HoopList_New_forAgent() {
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
    SET_HEAPFLAG_READYFORUSE(((Agent *)(hp_list->hoop))[i].basic.id);
  }

  // hp->next = NULL;   // this should be executed only for the first creation.
  return hp_list;
}




void VM_Buffer_Init(VirtualMachine *vm) {

  // Agent Heap
  /*
  vm->agentHeap.hoop_list = HoopList_New_forAgent();
  vm->agentHeap.hoop_list->next = vm->agentHeap.hoop_list;
  vm->agentHeap.last_alloc_idx = 0;
  vm->agentHeap.last_alloc_list = vm->agentHeap.hoop_list;
  */
  
  vm->agentHeap.last_alloc_list = HoopList_New_forAgent();
  vm->agentHeap.last_alloc_list->next = vm->agentHeap.last_alloc_list;
  vm->agentHeap.last_alloc_idx = 0;
  
		    
  // Name Heap
  vm->nameHeap.last_alloc_list = HoopList_New_forName();
  vm->nameHeap.last_alloc_list->next = vm->nameHeap.last_alloc_list;
  vm->nameHeap.last_alloc_idx = 0;

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
	TOGGLE_HEAPFLAG_READYFORUSE(hoop[idx].basic.id);

	hp->last_alloc_idx = idx;  
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
	TOGGLE_HEAPFLAG_READYFORUSE(hoop[idx].basic.id);

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

  SET_HEAPFLAG_READYFORUSE(BASIC(ptr)->id);

}


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
    puts_name_port0(NameTable_get_heap(sym));
    param = ast_getTail(param);
    if (param != NULL)
      printf(" ");
    
  }
  puts("");

  PutIndirection = preserve;  
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
  

#ifdef NODE_USE_VERBOSE
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
    char *sym = param->left->sym;
    VALUE heap = NameTable_get_heap(sym);
    flush_name_port0(heap);
    param = ast_getTail(param);		     
  }
}


void puts_name_port0_nat(VALUE a1) {
  int result=0;
  int idS, idZ;
  idS = NameTable_get_set_id("S");
  idZ = NameTable_get_set_id("Z");
  
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

    NameTable_erase(IdTable_get_name(BASIC(ptr)->id));
    //    BASIC(ptr)->id = ID_NAME;
    SET_LOCAL_NAMEID(BASIC(ptr)->id);
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







/**************************************
 NAME TABLE
**************************************/
//#include "name_table.h"
// Just include it, because the object file version causes *inefficiency* !
#include "name_table.c"  



/*************************************
 Exec STACK
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
    printf("Critical ERROR: Overflow of the EQ stack.\n");
    printf("You should have larger size by '-x option'.\n");
    printf("Please see help by using -h option.\n");
    exit(-1);
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


#ifdef THREAD
void GlobalEQStack_Push(VALUE l, VALUE r) {



  lock(&GlobalEQS.lock);

  GlobalEQS.nextPtr++;
  if (GlobalEQS.nextPtr >= GlobalEQS.size) {
    printf("Critical ERROR: Overflow of the global execution stack.\n");
    exit(-1);
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
 BYTECODE
**************************************/
// *** The occurrence order must be the same in labels in ExecCode. ***
typedef enum {
  PUSH=0,
  PUSHI,
  MKNAME,
  MKGNAME,
  MKAGENT,
  REUSEAGENT,
  MYPUSH,

  RET,
  RET_FREE_LR,
  RET_FREE_L,
  RET_FREE_R,

  LOOP,
  LOOP_RREC,
  LOOP_RREC1,
  LOOP_RREC2,
  
  LOADI,
  LOAD,
  LOADP,
  OP_ADD,
  OP_SUB,
  OP_SUBI,
  OP_MUL,
  OP_DIV,
  OP_MOD,
  OP_LT,
  OP_LE,
  OP_EQ,
  OP_EQI,
  OP_NE,
  OP_JMPEQ0,
  OP_JMPCNCT_CONS,
  OP_JMPCNCT,
  OP_JMP,
  OP_UNM,
  OP_RAND,

  // connect operation for global names in given nets in the interactive mode.
  CNCTGN,
  SUBSTGN,
  
  NOP,  
} Code;


// The real addresses for the `Code':
static void* CodeAddr[NOP+1];


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



#define MAX_CODE_SIZE 1024
typedef struct {
  
  // Management table for local and global names
  NameBind bind[MAX_NBIND];   
  int bindPtr;                // its index
  int bindPtr_metanames;      // The max index that stores info of meta names
                              // (default: -1)

  
  // Index for local and global names in Regs
  int localNamePtr;           // It starts from VM_OFFSET_LOCALVAR
  int vmStackSize;            // the array size of the Regs.
                              

  // Compiled code and its index
  void *code[MAX_CODE_SIZE];
  int codeptr;              

  
  // For rule agents
  int idL, idR;               // ids of ruleAgentL and ruleAgentR
  int reg_agentL, reg_agentR; // Beginning reg nums for args of
                              // ruleAgentL, ruleAgentR
  int annotateL, annotateR;   // `Annotation properties' such as (*L) (*R) (int)

} CmEnvironment;

// The annotation properties
#define ANNOTATE_NOTHING  0     // The rule agent is not reused,
#define ANNOTATE_REUSE 1        // annotation (*L), (*R) is specified,
#define ANNOTATE_AS_INT_AGENT 2 // (int i), therefore it should not be freed.


static CmEnvironment CmEnv;

//void *ExecCode(int arg, VirtualMachine *vm, void **code);
void *ExecCode(int mode, VirtualMachine *restrict vm, void *restrict *code);


void CmEnv_clear_all();


void CmEnv_Init(int vm_heapsize) {
  CmEnv.vmStackSize = vm_heapsize;

  void **table;
  table = ExecCode(0, NULL, NULL);
  for (int i=0; i<NOP; i++) {
    CodeAddr[i] = table[i];
  }

  CmEnv_clear_all();
}


static inline
void CmEnv_clear_localnamePtr() {
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


void CmEnv_clear_all() 
{
  // clear all the information of names.
  CmEnv_clear_bind(-1);

  // reset the annotation properties for rule agents.
  CmEnv.bindPtr_metanames = -1;
  CmEnv.annotateL = ANNOTATE_NOTHING;
  CmEnv.annotateR = ANNOTATE_NOTHING;
  
  // reset the beginning number for local vars.  
  CmEnv_clear_localnamePtr();  

  // reset the index of code array in CmEnv.  
  CmEnv.codeptr = 0;  

}

void CmEnv_clear_keeping_rule_properties() 
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

  // reset the index of code array in CmEnv.  
  CmEnv.codeptr = 0;  

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
    if (CmEnv.localNamePtr > CmEnv.vmStackSize) {
      puts("SYSTEM ERROR: CmEnv.localNamePtr exceeded CmEnv.vmStackSize.");
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
    if (CmEnv.localNamePtr > CmEnv.vmStackSize) {
      puts("SYSTEM ERROR: CmEnv.localNamePtr exceeded CmEnv.vmStackSize.");
      exit(-1);
    }

    return result;
  }
  return -1;
}


int CmEnv_reg_search(char *key) {
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


// Agent用の RegNo を取得する (just for newreg)
//（これらは、Envコンパイル時に mkName、mkGname の対象にならないため
// 一時的な変数として使われる）
int CmEnv_newreg() {

  int result;
  result = CmEnv.localNamePtr;
  CmEnv.localNamePtr++;
  if (CmEnv.localNamePtr > CmEnv.vmStackSize) {
    puts("SYSTEM ERROR: CmEnv.localNamePtr exceeded CmEnv.vmStackSize.");
    exit(-1);
  }

  return result;
}



#define EnvAddCode(c)\
  if (CmEnv.codeptr >= MAX_CODE_SIZE) {\
  puts("SYSTEM ERROR: The codeptr exceeded MAX_CODE_SIZE");\
  exit(-1);\
  }\
  CmEnv.code[CmEnv.codeptr] = c;\
  CmEnv.codeptr++;

#define EnvAddCode2(c1,c2)			\
  if (CmEnv.codeptr+1 >= MAX_CODE_SIZE) {\
  puts("SYSTEM ERROR: The codeptr exceeded MAX_CODE_SIZE");\
  exit(-1);\
  }\
  CmEnv.code[CmEnv.codeptr++] = c1;\
  CmEnv.code[CmEnv.codeptr++] = c2;

#define EnvAddCode3(c1,c2,c3)			\
  if (CmEnv.codeptr+2 >= MAX_CODE_SIZE) {\
  puts("SYSTEM ERROR: The codeptr exceeded MAX_CODE_SIZE");\
  exit(-1);\
  }\
  CmEnv.code[CmEnv.codeptr++] = c1;\
  CmEnv.code[CmEnv.codeptr++] = c2;\
  CmEnv.code[CmEnv.codeptr++] = c3;

#define EnvAddCode4(c1,c2,c3,c4)			\
  if (CmEnv.codeptr+3 >= MAX_CODE_SIZE) {\
  puts("SYSTEM ERROR: The codeptr exceeded MAX_CODE_SIZE");\
  exit(-1);\
  }\
  CmEnv.code[CmEnv.codeptr++] = c1;\
  CmEnv.code[CmEnv.codeptr++] = c2;\
  CmEnv.code[CmEnv.codeptr++] = c3;\
  CmEnv.code[CmEnv.codeptr++] = c4;

#define EnvAddCode5(c1,c2,c3,c4,c5)		\
  if (CmEnv.codeptr+4 >= MAX_CODE_SIZE) {\
  puts("SYSTEM ERROR: The codeptr exceeded MAX_CODE_SIZE");\
  exit(-1);\
  }\
  CmEnv.code[CmEnv.codeptr++] = c1;\
  CmEnv.code[CmEnv.codeptr++] = c2;\
  CmEnv.code[CmEnv.codeptr++] = c3;\
  CmEnv.code[CmEnv.codeptr++] = c4;\
  CmEnv.code[CmEnv.codeptr++] = c5;


#define EnvAddCode6(c1,c2,c3,c4,c5,c6)		\
  if (CmEnv.codeptr+5 >= MAX_CODE_SIZE) {\
  puts("SYSTEM ERROR: The codeptr exceeded MAX_CODE_SIZE");\
  exit(-1);\
  }\
  CmEnv.code[CmEnv.codeptr++] = c1;\
  CmEnv.code[CmEnv.codeptr++] = c2;\
  CmEnv.code[CmEnv.codeptr++] = c3;\
  CmEnv.code[CmEnv.codeptr++] = c4;\
  CmEnv.code[CmEnv.codeptr++] = c5;\
  CmEnv.code[CmEnv.codeptr++] = c6;



#define EnvCodeClear() CmEnv.codeptr=0
  

void EnvAddCodePUSH(void* c1, void* c2) {
  EnvAddCode3(CodeAddr[PUSH],c1,c2);
}


void EnvAddCodeMYPUSH(void* c1, void* c2) {
  EnvAddCode3(CodeAddr[MYPUSH],c1,c2);
}

void EnvAddCodeCNCTGN(void* c1, void* c2) {
  EnvAddCode3(CodeAddr[CNCTGN],c1,c2);
}

void EnvAddCodeSUBSTGN(void* c1, void* c2) {
  EnvAddCode3(CodeAddr[SUBSTGN],c1,c2);
}


int CmEnv_check_meta_occur_once() {
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


int CmEnv_check_name_reference_times() {
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

int CmEnv_generate_code_with_nameinfo(void **code, int offset) {
  // return: the number of produced codes

  int i;

  /*
  // check whether the code size estimation is exceeded.
  { 
    int count_names=0;
    for (i=0; i<CmEnv.bindPtr; i++) {
      if (CmEnv.bind[i].type == NB_NAME) {
	count_names++;
      }
    }
    if (offset + count_names*3 > MAX_CODE_SIZE) {
      puts("System ERROR: Generated codes were too big.");
      return -1;
    }
  }
  */

  
  { 
    int ptr=offset;
    
    for (i=0; i<CmEnv.bindPtr; i++) {
      
      if (CmEnv.bind[i].type == NB_NAME) {
	
	if (CmEnv.bind[i].refnum > 0) {
	  code[ptr++] = CodeAddr[MKNAME];
	  
	} else {
	  code[ptr++] = CodeAddr[MKGNAME];
	  code[ptr++] = CmEnv.bind[i].name;
	}
	code[ptr++] = (void *)(unsigned long)CmEnv.bind[i].reg;
      }
    }
    
    if (ptr + CmEnv.codeptr > MAX_CODE_SIZE) {
      puts("System ERROR: Generated codes were too big.");
      return -1;
    }
    
    for (i=0; i<CmEnv.codeptr; i++) {
      code[ptr++] = CmEnv.code[i];
    }
    
    return (ptr-offset);
  }
}


int CmEnv_generate_code(void **code, int offset) {
  int ptr=offset;
  int i;
  for (i=0; i<CmEnv.codeptr; i++) {
    code[ptr] = CmEnv.code[i];
    ptr++;
  }

  return CmEnv.codeptr;
}


void CopyCode(int byte, void **source, void **target) {
  int i;
  for (i=0; i<byte; i++) {
    target[i]=source[i];
  }
}




void PutsCodeN(void **code, int n) {
  int i,j;
  unsigned long arity;
  i=0;

  puts("[PutsCode]");
  if (n==-1) n = MAX_CODE_SIZE;
  for (i=0; i<n; i++) {
    printf("%2d: ", i);
    if (code[i] == CodeAddr[MKNAME]) {
      printf("var%lu=mkname\n", (unsigned long)code[i+1]);
      i +=1;
    } else if (code[i] == CodeAddr[MKGNAME]) {
      printf("var%lu=mkgname %s\n", (unsigned long)code[i+2], (char *)code[i+1]);
      i +=2;
    } else if (code[i] == CodeAddr[MKAGENT]) {
      printf("MKAGENT var%lu id:%lu ar:%lu", 
	     (unsigned long)code[i+1], (unsigned long)code[i+2], (unsigned long)code[i+3]);
      arity = (unsigned long)code[i+3];
      i +=3;
      for(j=0; j<arity; j++) {
	i++;
	printf(" var%lu", (unsigned long)code[i]);
      }
      puts("");
    } else if (code[i] == CodeAddr[REUSEAGENT]) {
      printf("reuseagent var%lu as id=%lu arity=%lu", 
	     (unsigned long)code[i+1], (unsigned long)code[i+2], (unsigned long)code[i+3]);
      arity = (unsigned long)code[i+3];
      i +=3;
      for(j=0; j<arity; j++) {
	i++;
	printf(" var%lu", (unsigned long)code[i]);
      }
      puts("");
    } else if (code[i] == CodeAddr[PUSH]) {
      printf("PUSH var%lu var%lu\n", (unsigned long)code[i+1], (unsigned long)code[i+2]);
      i +=2;
    } else if (code[i] == CodeAddr[PUSHI]) {
      printf("PUSHI var%lu $%d\n", (unsigned long)code[i+1], FIX2INT((unsigned long)code[i+2]));
      i +=2;
    } else if (code[i] == CodeAddr[MYPUSH]) {
      printf("MYPUSH var%lu var%lu\n", (unsigned long)code[i+1], (unsigned long)code[i+2]);
      i +=2;
    } else if (code[i] == CodeAddr[RET]) {
	puts("RET");
      if (n==MAX_CODE_SIZE) {
	return;
      }
    } else if (code[i] == CodeAddr[RET_FREE_L]) {
	puts("RET_FREE_L");
      if (n==MAX_CODE_SIZE) {
	return;
      }
    } else if (code[i] == CodeAddr[RET_FREE_R]) {
	puts("RET_FREE_R");
      if (n==MAX_CODE_SIZE) {
	return;
      }
    } else if (code[i] == CodeAddr[RET_FREE_LR]) {
	puts("RET_FREE_LR");
      if (n==MAX_CODE_SIZE) {
	return;
      }
    } else if (code[i] == CodeAddr[LOADI]) {
      printf("LOADI var%lu $%lu\n", (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;
    } else if (code[i] == CodeAddr[LOOP]) {
      printf("LOOP\n");
      
    } else if (code[i] == CodeAddr[LOOP_RREC]) {
      printf("LOOP_RREC var%lu $%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;
      
    } else if (code[i] == CodeAddr[LOOP_RREC1]) {
      printf("LOOP_RREC1 var%lu\n",
	     (unsigned long)code[i+1]);
      i+=1;
      
    } else if (code[i] == CodeAddr[LOOP_RREC2]) {
      printf("LOOP_RREC2 var%lu\n",
	     (unsigned long)code[i+1]);
      i+=1;
      
    } else if (code[i] == CodeAddr[LOAD]) {
      printf("LOAD var%lu var%lu\n", (unsigned long)code[i+1],
	     (unsigned long)code[i+2]);
      i+=2;
    } else if (code[i] == CodeAddr[LOADP]) {
      printf("LOADP var%lu var%lu[%lu]\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2],
	     (unsigned long)code[i+3]);
      i+=3;
    } else if (code[i] == CodeAddr[OP_ADD]) {
      printf("ADD var%lu var%lu var%lu\n", (unsigned long)code[i+1], (unsigned long)code[i+2], (unsigned long)code[i+3]);
      i+=3;
    } else if (code[i] == CodeAddr[OP_SUB]) {
      printf("SUB var%lu var%lu var%lu\n", (unsigned long)code[i+1], (unsigned long)code[i+2], (unsigned long)code[i+3]);
      i+=3;
    } else if (code[i] == CodeAddr[OP_SUBI]) {
      printf("SUBI var%lu var%lu $%ld\n", (unsigned long)code[i+1], (unsigned long)code[i+2], (long int)code[i+3]);
      i+=3;
    } else if (code[i] == CodeAddr[OP_MUL]) {
      printf("MUL var%lu var%lu var%lu\n", (unsigned long)code[i+1], (unsigned long)code[i+2], (unsigned long)code[i+3]);
      i+=3;
    } else if (code[i] == CodeAddr[OP_DIV]) {
      printf("DIV var%lu var%lu var%lu\n", (unsigned long)code[i+1], (unsigned long)code[i+2], (unsigned long)code[i+3]);
      i+=3;
    } else if (code[i] == CodeAddr[OP_MOD]) {
      printf("MOD var%lu var%lu var%lu\n", (unsigned long)code[i+1], (unsigned long)code[i+2], (unsigned long)code[i+3]);
      i+=3;
    } else if (code[i] == CodeAddr[OP_LT]) {
      printf("LT var%lu var%lu var%lu\n", (unsigned long)code[i+1], (unsigned long)code[i+2], (unsigned long)code[i+3]);
      i+=3;
    } else if (code[i] == CodeAddr[OP_LE]) {
      printf("LE var%lu var%lu var%lu\n", (unsigned long)code[i+1], (unsigned long)code[i+2], (unsigned long)code[i+3]);
      i+=3;
    } else if (code[i] == CodeAddr[OP_EQ]) {
      printf("EQ var%lu var%lu var%lu\n", (unsigned long)code[i+1], (unsigned long)code[i+2], (unsigned long)code[i+3]);
      i+=3;
    } else if (code[i] == CodeAddr[OP_EQI]) {
      printf("EQI var%lu var%lu $%ld\n", (unsigned long)code[i+1], (unsigned long)code[i+2], (long int)code[i+3]);
      i+=3;
    } else if (code[i] == CodeAddr[OP_NE]) {
      printf("NE var%lu var%lu var%lu\n", (unsigned long)code[i+1], (unsigned long)code[i+2], (unsigned long)code[i+3]);
      i+=3;
    } else if (code[i] == CodeAddr[OP_JMPEQ0]) {
      printf("JMPEQ0 var%lu $%lu\n", (unsigned long)code[i+1], (unsigned long)code[i+2]);
      i+=2;
    } else if (code[i] == CodeAddr[OP_JMPCNCT_CONS]) {
      printf("JMPCNCT_CONS var%lu $%lu\n", (unsigned long)code[i+1], (unsigned long)code[i+2]);
      i+=2;
    } else if (code[i] == CodeAddr[OP_JMPCNCT]) {
      printf("JMPCNCT var%lu $%lu $%lu\n",
	     (unsigned long)code[i+1],
	     (unsigned long)code[i+2],
	     (unsigned long)code[i+3]);
      i+=3;
    } else if (code[i] == CodeAddr[OP_JMP]) {
      printf("JMP $%lu\n", (unsigned long)code[i+1]);
      i+=1;
    } else if (code[i] == CodeAddr[OP_UNM]) {
      printf("UNM var%lu var%lu\n", (unsigned long)code[i+1], (unsigned long)code[i+2]);
      i+=2;
    } else if (code[i] == CodeAddr[OP_RAND]) {
      printf("RND var%lu var%lu\n", (unsigned long)code[i+1], (unsigned long)code[i+2]);
      i+=2;
    } else if (code[i] == CodeAddr[CNCTGN]) {
      printf("CNCTGN var%lu var%lu\n", (unsigned long)code[i+1], (unsigned long)code[i+2]);
      i +=2;    
    } else if (code[i] == CodeAddr[SUBSTGN]) {
      printf("SUBSTGN var%lu var%lu\n", (unsigned long)code[i+1], (unsigned long)code[i+2]);
      i +=2;    
    } else if (code[i] == CodeAddr[NOP]) {
      printf("NOP\n");
    } else {
      printf("CODE %lu\n", (unsigned long)code[i]);      
    }
  }
}


void PutsCode(void **code) {
  PutsCodeN(code, -1);
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



int CompileExprFromAst(int target, Ast *ptr) {

  if (ptr == NULL) {
    return 1;
  }

  switch (ptr->id) {
  case AST_INT:
    EnvAddCode3(CodeAddr[LOADI],
		 (void *)(unsigned long)target,
		 (void *)(unsigned long)(ptr->intval));
    return 1;
    break;

  case AST_NAME: {
    int result = CmEnv_reg_search(ptr->left->sym);
    if (result == -1) {
      //      result=CmEnv_set_as_INTVAR(ptr->left->sym);
      printf("ERROR: '%s' has not been defined previously.\n",
	     ptr->left->sym);
      return 0;
    }
    EnvAddCode3(CodeAddr[LOAD],
		(void *)(unsigned long)target,
		(void *)(unsigned long)result);
    return 1;
    break;
  }
  case AST_RAND: {
    int newreg = CmEnv_newreg();
    if (!CompileExprFromAst(newreg, ptr->left)) return 0;
    EnvAddCode3(CodeAddr[OP_RAND],
		(void *)(unsigned long)target,
		(void *)(unsigned long)newreg);

    return 1;
    break;
  }
  case AST_UNM: {
    int newreg = CmEnv_newreg();
    if (!CompileExprFromAst(newreg, ptr->left)) return 0;
    EnvAddCode3(CodeAddr[OP_UNM],
		(void *)(unsigned long)target,
		(void *)(unsigned long)newreg);

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
    int newreg = CmEnv_newreg();
    int newreg2 = CmEnv_newreg();
    if (!CompileExprFromAst(newreg, ptr->left)) return 0;
    if (!CompileExprFromAst(newreg2, ptr->right)) return 0;

    switch (ptr->id) {
    case AST_PLUS:
      EnvAddCode(CodeAddr[OP_ADD]);
      break;
    case AST_SUB:
      EnvAddCode(CodeAddr[OP_SUB]);
      break;
    case AST_MUL:
      EnvAddCode(CodeAddr[OP_MUL]);
      break;
    case AST_DIV:
      EnvAddCode(CodeAddr[OP_DIV]);
      break;
    case AST_MOD:
      EnvAddCode(CodeAddr[OP_MOD]);
      break;
    case AST_LT:
      EnvAddCode(CodeAddr[OP_LT]);
      break;
    case AST_LE:
      EnvAddCode(CodeAddr[OP_LE]);
      break;
    case AST_EQ:
      EnvAddCode(CodeAddr[OP_EQ]);
      break;
    case AST_NE:
      EnvAddCode(CodeAddr[OP_NE]);
      break;
    default:
      EnvAddCode(CodeAddr[OP_MOD]);
    }
    EnvAddCode3((void *)(unsigned long)target,
		(void *)(unsigned long)newreg,
		(void *)(unsigned long)newreg2);

    return 1;
    break;
  }
  default:
    puts("System ERROR: Wrong AST was given to CompileExpr.");
    return 0;

  }

}

// Rule や eq の中の term をコンパイルするときに使う
int CompileTermFromAst(Ast *ptr, int target) {
  // input:
  // target == -1  => a new node is allocated from localHeap.
  //   othereise   => a node specified by the `target' is reused as a new node.
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
    
    result = CmEnv_reg_search(ptr->left->sym);
    if (result == -1) {
      result=CmEnv_set_symbol_as_name(ptr->left->sym);
    }
    return result;
    break;

  case AST_INT:
    result = CmEnv_newreg();
    EnvAddCode3(CodeAddr[LOADI],
		(void *)(unsigned long)result,
		(void *)(unsigned long)(ptr->intval));
    return result;
    break;

  case AST_NIL:
    if (target == -1) {      
      result = CmEnv_newreg();
      mkagent = MKAGENT;
    } else {
      result = target;
      mkagent = REUSEAGENT;
    }
    EnvAddCode4(CodeAddr[mkagent],
		(void *)(unsigned long)result,
		(void *)(unsigned long)(ID_NIL),
		(void *)(unsigned long)0);
    return result;
    break;

    
  case AST_CONS:
    if (target == -1) {      
      result = CmEnv_newreg();
      mkagent = MKAGENT;
    } else {
      result = target;
      mkagent = REUSEAGENT;
    }
    alloc[0] = CompileTermFromAst(ptr->left, -1);
    alloc[1] = CompileTermFromAst(ptr->right, -1);
    EnvAddCode6(CodeAddr[mkagent],
		(void *)(unsigned long)result,
		(void *)(unsigned long)(ID_CONS),
		(void *)(unsigned long)(2),
		(void *)(unsigned long)alloc[0],
		(void *)(unsigned long)alloc[1]);    
    return result;
    break;

  case AST_OPCONS:
    if (target == -1) {      
      result = CmEnv_newreg();
      mkagent = MKAGENT;
    } else {
      result = target;
      mkagent = REUSEAGENT;
    }
    ptr = ptr->right;
    alloc[0] = CompileTermFromAst(ptr->left, -1);
    alloc[1] = CompileTermFromAst(ptr->right->left, -1);
    EnvAddCode6(CodeAddr[mkagent],
		(void *)(unsigned long)result,
		(void *)(unsigned long)(ID_CONS),
		(void *)(unsigned long)(2),
		(void *)(unsigned long)alloc[0],
		(void *)(unsigned long)alloc[1]);    
    return result;
    break;

    /*
  case AST_TUPLE:
    if (target == -1) {      
      result = CmEnv_newreg();
      mkagent = MKAGENT;
    } else {
      result = target;
      mkagent = REUSEAGENT;
    }
    arity = ptr->intval;
    ptr=ptr->right;
    for(i=0; i< MAX_PORT; i++) {
      if (ptr == NULL) break;
      alloc[i] = CompileTermFromAst(ptr->left, -1);
      ptr = ast_getTail(ptr);
    }

    EnvAddCode4(CodeAddr[mkagent],
		(void *)(unsigned long)result,
		(void *)(unsigned long)(GET_TUPLEID(arity)),
		(void *)(unsigned long)(arity));
    for(i=0; i< arity; i++) {
      EnvAddCode((void *)(unsigned long)alloc[i]);    
    }
    return result;
    break;
    */

    
  case AST_TUPLE:
    arity = ptr->intval;

    if (arity == 1) {
      // The case of (A),
      // `A' is recognised not as an argument, as a first-class object.
      ptr=ptr->right;
      alloc[0] = CompileTermFromAst(ptr->left, target);      
      result = alloc[0];
      
    } else {
      // normal case
      
      if (target == -1) {      
	result = CmEnv_newreg();
	mkagent = MKAGENT;
      } else {
	result = target;
	mkagent = REUSEAGENT;
      }

      ptr=ptr->right;
      /*
      for(i=0; i< MAX_PORT; i++) {
	if (ptr == NULL) break;
	alloc[i] = CompileTermFromAst(ptr->left, -1);
	ptr = ast_getTail(ptr);
      }
      */
      for(i=0; i< arity; i++) {
	alloc[i] = CompileTermFromAst(ptr->left, -1);
	ptr = ast_getTail(ptr);
      }
      
      EnvAddCode4(CodeAddr[mkagent],
		  (void *)(unsigned long)result,
		  (void *)(unsigned long)(GET_TUPLEID(arity)),
		  (void *)(unsigned long)(arity));
      for(i=0; i< arity; i++) {
	EnvAddCode((void *)(unsigned long)alloc[i]);    
      }

    }
    
    return result;
    break;

    
    
  case AST_AGENT:

    if (target == -1) {      
      result = CmEnv_newreg();
      mkagent = MKAGENT;
    } else {
      result = target;
      mkagent = REUSEAGENT;
    }
    
    int id = IdTable_getid_builtin_funcAgent(ptr);
    if (id == -1) {
      id = NameTable_get_set_id((char *)ptr->left->sym);
    }

    /* For arity */
    //    result->arity = ptr->arity;
    arity=0;
    ptr=ptr->right;
    for(i=0; i< MAX_PORT; i++) {
      if (ptr == NULL) break;
      alloc[i] = CompileTermFromAst(ptr->left, -1);
      arity++;
      ptr = ast_getTail(ptr);
    }
    // MKAGENT var ID ARITY var0 var1 ...
    EnvAddCode4(CodeAddr[mkagent],
		(void *)(unsigned long)result,
		(void *)(unsigned long)id,
		(void *)(unsigned long)arity);
    IdTable_set_arity(id, arity);

    for(i=0; i< arity; i++) {
      EnvAddCode((void *)(unsigned long)alloc[i]);    
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
    result = CmEnv_newreg();    
    int compile_result = CompileExprFromAst(result, ptr);
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
    char *sym = ast->left->sym;

    
    VALUE aheap = NameTable_get_heap(sym);
    if (aheap != (VALUE)NULL) {
      // already exists as a global

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
	printf("ERROR: '%s' occurs twice already. \n", sym);
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
    EnvAddCodePUSH((void *)(unsigned long)t1, (void *)(unsigned long)t2);
    
    at = next;
  }

  return 1;
}

void Compile_Put_Ret_ForRuleBody() {
  
  if ((CmEnv.annotateL == ANNOTATE_NOTHING) &&
      (CmEnv.annotateR == ANNOTATE_NOTHING)) {
    EnvAddCode(CodeAddr[RET_FREE_LR]);  

  } else if ((CmEnv.annotateL == ANNOTATE_NOTHING) &&
	     (CmEnv.annotateR != ANNOTATE_NOTHING)) {
    // FreeL
    if (CmEnv.reg_agentL == VM_OFFSET_ANNOTATE_L) {
      EnvAddCode(CodeAddr[RET_FREE_L]);  
    } else {
      EnvAddCode(CodeAddr[RET_FREE_R]);  
    }

  } else if ((CmEnv.annotateL != ANNOTATE_NOTHING) &&
	     (CmEnv.annotateR == ANNOTATE_NOTHING)) {
    // FreeR
    if (CmEnv.reg_agentL == VM_OFFSET_ANNOTATE_L) {
      EnvAddCode(CodeAddr[RET_FREE_R]);  
    } else {
      EnvAddCode(CodeAddr[RET_FREE_L]);  
    }
  } else {
    EnvAddCode(CodeAddr[RET]);  
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
    toRegLeft = CmEnv_reg_search(ptr->left->left->sym);
    if (toRegLeft == -1) {
      toRegLeft = CmEnv_set_as_INTVAR(ptr->left->left->sym);
    } else {
      printf("Warning: '%s' has been already defined.\n", ptr->left->left->sym);
    }

    // for the y
    if (ptr->right->id == AST_NAME) {
      // y is a name
      int toRegRight = CmEnv_reg_search(ptr->right->left->sym);
      if (toRegRight == -1) {
	toRegRight = CmEnv_set_as_INTVAR(ptr->right->left->sym);
      }
      EnvAddCode3(CodeAddr[LOAD],
		  (void *)(unsigned long)toRegLeft,
		  (void *)(unsigned long)toRegRight);

    } else if (ptr->right->id == AST_INT) {
      // y is an integer
      EnvAddCode3(CodeAddr[LOADI],
		  (void *)(unsigned long)toRegLeft,
		  (void *)(unsigned long)ptr->right->intval);
      
    } else {
      // y is an expression
      if (!CompileExprFromAst(toRegLeft, ptr->right)) return 0;

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


    //      NB_NAME=0,
    //  NB_META,
    //  NB_INTVAR,

    if (target->left->id == AST_NAME) {

      sym = target->left->left->sym;
      exists_in_table=CmEnv_gettype_forname(sym, &type);
      
      if ((!exists_in_table) ||
	  (type == NB_NAME)){
	// When no entry in CmEnv table or its type is NB_NAME
	
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

RuleList *RuleList_new() {
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

void RuleTable_init() {
  int i;
  for (i=0; i<RULEHASH_SIZE; i++) {
    RuleTable[i] = NULL;
  }
}


void RuleTable_record(int symlID, int symrID, int byte, void **code) {

  RuleList *add;

  if (RuleTable[symlID] == NULL) {  /* もしテーブルが空ならば */
    add = RuleList_new();             /* データノードを作成し */

    RuleList_set_code(add, symrID, code, byte, NULL);
    RuleTable[symlID] = add;        /* 単にセット */
    return;
    
  }

  /* 線形探査が必要 */
  RuleList *at = RuleTable[symlID];  // 先頭をセット
    
  while( at != NULL ) {
    if( at->sym == symrID) {  // すでにあれば書き換える
      CopyCode(byte, code, at->code);
      return;
    }
    at = at->next;
  }
  
  // key がなかったら、 先頭に追加

  /* 以前の先頭を自分の次にする */
  add = RuleList_new();
  RuleList_set_code(add, symrID, code, byte, RuleTable[symlID]);
  RuleTable[symlID] = add; 
  return;
}



void RuleTable_delete(int symlID, int symrID) {
  
  if (RuleTable[symlID] == NULL) {  /* もしテーブルが空ならば */
    // 何もしない
    return;
    
  }
  
  /* 線形探査が必要 */
  RuleList *at = RuleTable[symlID];  /* 先頭をセット */
    
  while( at != NULL ) {
    if( at->sym == symrID) {  /* すでにあれば書き換える */
      RuleList_inavailable(at);
      return;
    }
    at = at->next;  /* 次のチェーンを辿る */
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
// VM のレジスタである VM_OFFSET_META_L(0)番、VM_OFFSET_META_L(1)番を
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
    CmEnv_set_symbol_as_meta(ptr->left->left->sym, VM_OFFSET_META_L(i), type);
    
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
    CmEnv_set_symbol_as_meta(ptr->left->left->sym, VM_OFFSET_META_R(i), type);    
    ptr = ast_getTail(ptr);
  }
}

void setMetaL_asIntName(Ast *ast) {
  //CmEnv_set_symbol_as_meta(ast->left->sym, VM_OFFSET_META_L(0), NB_INTVAR);
  CmEnv_set_symbol_as_meta(ast->left->sym, CmEnv.reg_agentL, NB_INTVAR);
  
}

void setMetaR_asIntName(Ast *ast) {
  //  CmEnv_set_symbol_as_meta(ast->left->sym, VM_OFFSET_META_R(0), NB_INTVAR);      
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
      id=NameTable_get_set_id(ruleAgent->left->sym);
    }
  }

  return id;
}
  





int CompileIfSentenceFromAST(Ast *if_sentence_top,
			      void **code, int offset_code) {
  // return
  //  generated codesize
  //  -1 : compile error

  //      <if-sentence> ::= (AST_IF guard (AST_BRANCH <then> <else>))
  //                      | <body>
  //      <then> ::= <if-sentence>
  //      <else> ::= <if-sentence>

  Ast *if_sentence;
  
  int generated_codesize; // コンパイルで生成されたコード数保存用

  if_sentence = if_sentence_top;

  CmEnv_clear_keeping_rule_properties();


  if ((if_sentence == NULL) || (if_sentence->id == AST_BODY)) {
    // 通常コンパイル
    Ast *body = if_sentence;
    
    if (!CompileBodyFromAst(body)) return -1;
    Compile_Put_Ret_ForRuleBody();
      
    generated_codesize = CmEnv_generate_code_with_nameinfo(code, offset_code);
      
    if (generated_codesize < 0) {
      puts("System ERROR: Generated codes were too long.");
      return -1;
    }
    
    if (!CmEnv_check_meta_occur_once()) {
      printf("in the rule:\n  %s >< %s.\n", 
	     IdTable_get_name(CmEnv.idL),
	     IdTable_get_name(CmEnv.idR));
      return -1;
    }
    
    return generated_codesize;
      
  } else {
    // if_sentence
    Ast *guard, *then_branch, *else_branch;
    int label;  // 飛び先指定用

    int offset = offset_code;

    guard = if_sentence->left;
    then_branch = if_sentence->right->left;
    else_branch = if_sentence->right->right;

    // Gurad のコンパイル
    int newreg = CmEnv_newreg();
    if (!CompileExprFromAst(newreg, guard)) return -1;
    generated_codesize = CmEnv_generate_code(code, offset);
    offset += generated_codesize;


    //JMPEQ0 用コードを作成
    code[offset++] = CodeAddr[OP_JMPEQ0];
    code[offset++] = (void *)(unsigned long)newreg;
    label = offset++;  // 飛び先を格納するアドレスを記憶しておく

    // then_branch のコンパイル
    EnvCodeClear();
    CmEnv_clear_localnamePtr();  // 局所変数としての reg番号を初期化

    generated_codesize = CompileIfSentenceFromAST(then_branch, code, offset);
    if (generated_codesize < 0) return -1;
    
    offset += generated_codesize;

    if (offset > MAX_CODE_SIZE) {
      puts("System ERROR: Generated codes were too big.");
      return -1;
    }

    // JMPEQ0 のとび先を格納（相対ジャンプ）
    code[label]=(void *)(unsigned long)generated_codesize;


    // else_branch のコンパイル
    EnvCodeClear();
    CmEnv_clear_localnamePtr();  // 局所変数としての reg番号を初期化
    
    generated_codesize = CompileIfSentenceFromAST(else_branch, code, offset);
    if (generated_codesize < 0) return -1;
    
    offset += generated_codesize;

    if (offset > MAX_CODE_SIZE) {
      puts("System ERROR: Generated codes were too big.");
      return -1;
    }

    return offset - offset_code;
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
  int code_size=0;

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

  {
    int arity;

    // IMPORTANT:
    // The first two codes store arities of idL and idR.
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

    code_size = 2;
  }
  
  

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


  {
    int generated_codesize = CompileIfSentenceFromAST(if_sentence, code, code_size);
    if (generated_codesize < 0) {
      return 0;
    }
    code_size += generated_codesize;
  }  

#ifdef MYDEBUG
    PutsCodeN(code, code_size); exit(1);
#endif

    //    printf("Rule: %s(id:%d) >< %s(id:%d).\n", 
    //	   IdTable_get_name(idL), idL,
    //	   IdTable_get_name(idR), idR);
    //    PutsCodeN(&code[2], code_size-2);
    //    exit(1);
    
    
// --------------------------------------------------------------
// For Fibonacci (as much as possible)
// #define HAND_FIB_AS_MUCH_AS_POSSIBLE
// --------------------------------------------------------------
#ifdef HAND_FIB_AS_MUCH_AS_POSSIBLE
    if ((strcmp(IdTable_get_name(idL), "Fib") == 0) &&
	(idR == ID_INT)) {

      printf("Rule is optimised: %s >< %s.\n", 
	     IdTable_get_name(idL),
	     IdTable_get_name(idR));
      
      //      PutsCodeN(&code[2], code_size-2);
      
      int i=2;
      //   code[i++] = CodeAddr[MKVAL];
      //   code[i++] = (void *)14;
      //   code[i++] = (void *)0;
      //   code[i++] = (void *)0;
      //
      //   code[i++] = CodeAddr[OP_EQ];
      //   code[i++] = (void *)12;
      //   code[i++] = (void *)11;
      //   code[i++] = (void *)14;
   
      code[i++] = CodeAddr[OP_EQI];
      //code[i++] = (void *)11;  // ここで 11(OFFSET_R)を壊してしまうと他で影響あり
      code[i++] = (void *)12;
      code[i++] = (void *)11;
      code[i++] = (void *)0;

      code[i++] = CodeAddr[OP_JMPEQ0];
      code[i++] = (void *)12;
      //   code[i++] = (void *)8;   
      code[i++] = (void *)4;
   
      //   code[i++] = CodeAddr[MKVAL];
      //   code[i++] = (void *)12;
      //   code[i++] = (void *)0;
      //   code[i++] = (void *)1;
      //   
      //   code[i++] = CodeAddr[PUSH];
      //   code[i++] = (void *)0;
      //   code[i++] = (void *)12;
   
      code[i++] = CodeAddr[PUSHI];
      code[i++] = (void *)0;
      code[i++] = (void *)INT2FIX(1);

      code[i++] = CodeAddr[RET_FREE_L];

   


      //   code[i++] = CodeAddr[MKVAL];
      //   code[i++] = (void *)14;
      //   code[i++] = (void *)0;
      //   code[i++] = (void *)1;
      //
      //   code[i++] = CodeAddr[OP_EQ];
      //   code[i++] = (void *)12;
      //   code[i++] = (void *)11;
      //   code[i++] = (void *)14;

      code[i++] = CodeAddr[OP_EQI];
      code[i++] = (void *)12;
      code[i++] = (void *)11;
      code[i++] = (void *)1;

      code[i++] = CodeAddr[OP_JMPEQ0];
      code[i++] = (void *)12;
      //   code[i++] = (void *)8;
      code[i++] = (void *)4;

      //   code[i++] = CodeAddr[MKVAL];
      //   code[i++] = (void *)12;
      //   code[i++] = (void *)0;
      //   code[i++] = (void *)1;
      //   
      //   code[i++] = CodeAddr[PUSH];
      //   code[i++] = (void *)0;
      //   code[i++] = (void *)12;

      code[i++] = CodeAddr[PUSHI];
      code[i++] = (void *)0;
      code[i++] = (void *)INT2FIX(1);

   
      code[i++] = CodeAddr[RET_FREE_L];



   
      code[i++] = CodeAddr[MKNAME];
      code[i++] = (void *)16;

   
      //   code[i++] = CodeAddr[MKVAL];
      //   code[i++] = (void *)14;
      //   code[i++] = (void *)0;
      //   code[i++] = (void *)1;
      //
      //   code[i++] = CodeAddr[OP_SUB];
      //   code[i++] = (void *)12;
      //   code[i++] = (void *)11;
      //   code[i++] = (void *)14;

      code[i++] = CodeAddr[OP_SUBI];
      code[i++] = (void *)12;
      code[i++] = (void *)11;
      code[i++] = (void *)1;
   

      //   code[i++] = CodeAddr[MKVAL];
      //   code[i++] = (void *)17;
      //   code[i++] = (void *)0;
      //   code[i++] = (void *)2;
      //
      //   code[i++] = CodeAddr[OP_SUB];
      //   code[i++] = (void *)15;
      //   code[i++] = (void *)11;
      //   code[i++] = (void *)17;

      code[i++] = CodeAddr[OP_SUBI];
      code[i++] = (void *)13;
      code[i++] = (void *)11;
      code[i++] = (void *)2;

   
      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)14;
      code[i++] = (void *)10;
      code[i++] = (void *)2;
      code[i++] = (void *)16;
      code[i++] = (void *)0;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)14;
      code[i++] = (void *)20;
      code[i++] = (void *)1;
      code[i++] = (void *)14;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)14;
      code[i++] = (void *)12;

   
      //   code[i++] = CodeAddr[REUSEAGENT];
      //   code[i++] = (void *)10;
      //   code[i++] = (void *)21;
      //   code[i++] = (void *)1;
      //   code[i++] = (void *)20;
      //
      //   code[i++] = CodeAddr[PUSH];
      //   code[i++] = (void *)10;
      //   code[i++] = (void *)15;
      //   
      //   code[i++] = CodeAddr[RET];


      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(0);
      code[i++] = (void *)16;

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_ANNOTATE_R;
      code[i++] = (void *)13;
   
      code[i++] = CodeAddr[LOOP];
   
      code_size = i;
      
      //      PutsCodeN(&code[2], i-2);
      //    exit(1);
    }
#endif


// --------------------------------------------------------------
// For Fibonacci (naive)
//    #define HAND_FIB
// --------------------------------------------------------------
#ifdef HAND_FIB
    if ((strcmp(IdTable_get_name(idL), "Fib") == 0) &&
	(idR == ID_INT)) {

      printf("Rule is optimised: %s >< %s.\n", 
	     IdTable_get_name(idL),
	     IdTable_get_name(idR));
      
      //            PutsCodeN(&code[2], code_size-2);
      
      int i=2;
      
      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)13;
      code[i++] = (void *)VM_OFFSET_ANNOTATE_R;

      code[i++] = CodeAddr[LOADI];
      code[i++] = (void *)14;
      code[i++] = (void *)0;
      
      code[i++] = CodeAddr[OP_EQ];
      code[i++] = (void *)12;
      code[i++] = (void *)13;
      code[i++] = (void *)14;
   
      code[i++] = CodeAddr[OP_JMPEQ0];
      code[i++] = (void *)12;
      code[i++] = (void *)7;
   
      code[i++] = CodeAddr[LOADI];
      code[i++] = (void *)12;
      code[i++] = (void *)0;
         
      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)0;
      code[i++] = (void *)12;
   
      code[i++] = CodeAddr[RET_FREE_L];


      
      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)13;
      code[i++] = (void *)VM_OFFSET_ANNOTATE_R;

      code[i++] = CodeAddr[LOADI];
      code[i++] = (void *)14;
      code[i++] = (void *)1;
      
      code[i++] = CodeAddr[OP_EQ];
      code[i++] = (void *)12;
      code[i++] = (void *)13;
      code[i++] = (void *)14;

      code[i++] = CodeAddr[OP_JMPEQ0];
      code[i++] = (void *)12;
      code[i++] = (void *)7;

      code[i++] = CodeAddr[LOADI];
      code[i++] = (void *)12;
      code[i++] = (void *)1;
         
      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)0;
      code[i++] = (void *)12;
   
      code[i++] = CodeAddr[RET_FREE_L];



   
      code[i++] = CodeAddr[MKNAME];
      code[i++] = (void *)14;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)13;
      code[i++] = (void *)21;
      code[i++] = (void *)2;
      code[i++] = (void *)0;
      code[i++] = (void *)14;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)12;
      code[i++] = (void *)20;
      code[i++] = (void *)1;
      code[i++] = (void *)13;

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)16;
      code[i++] = (void *)VM_OFFSET_ANNOTATE_R;
      
      code[i++] = CodeAddr[LOADI];
      code[i++] = (void *)17;
      code[i++] = (void *)1;
      
      code[i++] = CodeAddr[OP_SUB];
      code[i++] = (void *)15;
      code[i++] = (void *)16;
      code[i++] = (void *)17;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)12;
      code[i++] = (void *)15;

      
      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(0);
      code[i++] = (void *)14;
      
      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)20;
      code[i++] = (void *)VM_OFFSET_ANNOTATE_R;
   
      code[i++] = CodeAddr[LOADI];
      code[i++] = (void *)21;
      code[i++] = (void *)2;
      
      code[i++] = CodeAddr[OP_SUB];
      code[i++] = (void *)19;
      code[i++] = (void *)20;
      code[i++] = (void *)21;


      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_ANNOTATE_R;
      code[i++] = (void *)19;
      
      code[i++] = CodeAddr[LOOP];
   
      code_size = i;
      
      //            PutsCodeN(&code[2], i-2);
	    //                exit(1);
    }
#endif



// --------------------------------------------------------------
// For Fibonacci (naive)
//    #define HAND_FIB_INT
// --------------------------------------------------------------
#ifdef HAND_FIB_INT
    if ((strcmp(IdTable_get_name(idL), "Fibi") == 0) &&
	(strcmp(IdTable_get_name(idR), "Int") == 0)) {

      printf("Rule is optimised: %s >< %s.\n", 
	     IdTable_get_name(idL),
	     IdTable_get_name(idR));
      
      //            PutsCodeN(&code[2], code_size-2);
      
      int i=2;
      
      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)13;
      code[i++] = (void *)VM_OFFSET_META_R(0);

      code[i++] = CodeAddr[LOADI];
      code[i++] = (void *)14;
      code[i++] = (void *)0;
      
      code[i++] = CodeAddr[OP_EQ];
      code[i++] = (void *)12;
      code[i++] = (void *)13;
      code[i++] = (void *)14;
   
      code[i++] = CodeAddr[OP_JMPEQ0];
      code[i++] = (void *)12;
      code[i++] = (void *)12;
   
      code[i++] = CodeAddr[LOADI];
      code[i++] = (void *)13;
      code[i++] = (void *)0;
         
      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)12;
      code[i++] = (void *)(unsigned long)idR;
      code[i++] = (void *)1;
      code[i++] = (void *)13;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)0;
      code[i++] = (void *)12;
   
      code[i++] = CodeAddr[RET_FREE_LR];


      
      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)13;
      code[i++] = (void *)VM_OFFSET_META_R(0);

      code[i++] = CodeAddr[LOADI];
      code[i++] = (void *)14;
      code[i++] = (void *)1;
      
      code[i++] = CodeAddr[OP_EQ];
      code[i++] = (void *)12;
      code[i++] = (void *)13;
      code[i++] = (void *)14;

      code[i++] = CodeAddr[OP_JMPEQ0];
      code[i++] = (void *)12;
      code[i++] = (void *)12;

      code[i++] = CodeAddr[LOADI];
      code[i++] = (void *)13;
      code[i++] = (void *)1;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)12;
      code[i++] = (void *)(unsigned long)idR;
      code[i++] = (void *)1;
      code[i++] = (void *)13;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)0;
      code[i++] = (void *)12;
   
      code[i++] = CodeAddr[RET_FREE_LR];

   
      code[i++] = CodeAddr[MKNAME];
      code[i++] = (void *)20;

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)13;
      code[i++] = (void *)VM_OFFSET_META_R(0);
   
      code[i++] = CodeAddr[LOADI];
      code[i++] = (void *)14;
      code[i++] = (void *)1;
      
      code[i++] = CodeAddr[OP_SUB];
      code[i++] = (void *)12;
      code[i++] = (void *)13;
      code[i++] = (void *)14;


      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)16;
      code[i++] = (void *)VM_OFFSET_META_R(0);
      
      code[i++] = CodeAddr[LOADI];
      code[i++] = (void *)17;
      code[i++] = (void *)2;
      
      code[i++] = CodeAddr[OP_SUB];
      code[i++] = (void *)15;
      code[i++] = (void *)16;
      code[i++] = (void *)17;

   
      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)19;
      code[i++] = (void *)21;
      code[i++] = (void *)2;
      code[i++] = (void *)0;
      code[i++] = (void *)20;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)18;
      code[i++] = (void *)20;
      code[i++] = (void *)1;
      code[i++] = (void *)19;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)21;
      code[i++] = (void *)9;
      code[i++] = (void *)1;
      code[i++] = (void *)12;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)18;
      code[i++] = (void *)21;

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(0);
      code[i++] = (void *)20;
      
      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_R(0);
      code[i++] = (void *)15;
      
      code[i++] = CodeAddr[LOOP];
      
   
      code_size = i;
      
      //            PutsCodeN(&code[2], i-2);
	    //                exit(1);
    }
#endif
    
    
// --------------------------------------------------------------
// For Fibonacci (tail call version)
//    #define HAND_FIB_TAIL
// --------------------------------------------------------------
#ifdef HAND_FIB_TAIL
    if (strcmp(IdTable_get_name(idL), "Fibt") == 0) {
      printf("Rule is optimised: %s >< %s.\n", 
	     IdTable_get_name(idL),
	     IdTable_get_name(idR));
      
      //      PutsCodeN(&code[2], code_size-2);
      
      int i=2;
      
      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)13;
      code[i++] = (void *)VM_OFFSET_ANNOTATE_R;

      code[i++] = CodeAddr[LOADI];
      code[i++] = (void *)14;
      code[i++] = (void *)0;
      
      code[i++] = CodeAddr[OP_EQ];
      code[i++] = (void *)12;
      code[i++] = (void *)13;
      code[i++] = (void *)14;
   
      code[i++] = CodeAddr[OP_JMPEQ0];
      code[i++] = (void *)12;
      code[i++] = (void *)7;
   
      code[i++] = CodeAddr[LOADI];
      code[i++] = (void *)12;
      code[i++] = (void *)1;
         
      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)0;
      code[i++] = (void *)12;
   
      code[i++] = CodeAddr[RET_FREE_L];


      
      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)13;
      code[i++] = (void *)VM_OFFSET_ANNOTATE_R;

      code[i++] = CodeAddr[LOADI];
      code[i++] = (void *)14;
      code[i++] = (void *)1;
      
      code[i++] = CodeAddr[OP_EQ];
      code[i++] = (void *)12;
      code[i++] = (void *)13;
      code[i++] = (void *)14;

      code[i++] = CodeAddr[OP_JMPEQ0];
      code[i++] = (void *)12;
      code[i++] = (void *)4;
         
      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)0;
      code[i++] = (void *)VM_OFFSET_META_L(1);
   
      code[i++] = CodeAddr[RET_FREE_L];


   
      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)14;
      code[i++] = (void *)VM_OFFSET_META_L(1);

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)15;
      code[i++] = (void *)VM_OFFSET_META_L(2);

      code[i++] = CodeAddr[OP_ADD];
      code[i++] = (void *)13;
      code[i++] = (void *)14;
      code[i++] = (void *)15;

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)16;
      code[i++] = (void *)VM_OFFSET_ANNOTATE_R;

      code[i++] = CodeAddr[LOADI];
      code[i++] = (void *)17;
      code[i++] = (void *)1;
      
      code[i++] = CodeAddr[OP_SUB];
      code[i++] = (void *)18;
      code[i++] = (void *)16;
      code[i++] = (void *)17;
      
      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)19;
      code[i++] = (void *)VM_OFFSET_META_L(1);

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(1);
      code[i++] = (void *)13;

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(2);
      code[i++] = (void *)19;

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_ANNOTATE_R;
      code[i++] = (void *)18;
      
      code[i++] = CodeAddr[LOOP];
   
      code_size = i;
      
      //      PutsCodeN(&code[2], i-2);
      //          exit(1);
    }
#endif
    

    
// --------------------------------------------------------------
// For Insersion Sort
// #define HAND_I_CONS
// #define HAND_IS_CONS
// --------------------------------------------------------------
#ifdef HAND_I_CONS
    if ((strcmp(IdTable_get_name(idL), "I") == 0) &&
	(strcmp(IdTable_get_name(idR), "Cons") == 0)) {

      printf("Rule is optimised: %s >< %s.\n", 
	     IdTable_get_name(idL),
	     IdTable_get_name(idR));
      
      //      PutsCodeN(&code[2], code_size-2);
      
      int i=2;

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)13;
      code[i++] = (void *)1;

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)14;
      code[i++] = (void *)5;

      code[i++] = CodeAddr[OP_LE];
      code[i++] = (void *)12;
      code[i++] = (void *)13;
      code[i++] = (void *)14;
  
      code[i++] = CodeAddr[OP_JMPEQ0];
      code[i++] = (void *)12;
      code[i++] = (void *)16;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)13;
      code[i++] = (void *)8;
      code[i++] = (void *)2;
      code[i++] = (void *)5;
      code[i++] = (void *)6;


      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)12;
      code[i++] = (void *)8;
      code[i++] = (void *)2;
      code[i++] = (void *)1;
      code[i++] = (void *)13;
      
      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)0;
      code[i++] = (void *)12;
      
      code[i++] = CodeAddr[RET_FREE_LR];



      
      code[i++] = CodeAddr[MKNAME];
      code[i++] = (void *)13;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)12;
      code[i++] = (void *)8;
      code[i++] = (void *)2;
      code[i++] = (void *)5;
      code[i++] = (void *)13;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)0;
      code[i++] = (void *)12;

      code[i++] = CodeAddr[OP_JMPCNCT_CONS];
      code[i++] = (void *)VM_OFFSET_META_R(1);
      code[i++] = (void *)10;
            
      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)14;
      code[i++] = (void *)21;
      code[i++] = (void *)2;
      code[i++] = (void *)13;
      code[i++] = (void *)1;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)14;
      code[i++] = (void *)6;

      code[i++] = CodeAddr[RET_FREE_LR];

      
      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(0);
      code[i++] = (void *)13;

      code[i++] = CodeAddr[LOOP_RREC2];
      code[i++] = (void *)VM_OFFSET_META_R(1);
      
      code_size = i;
      
      //      PutsCodeN(&code[2], i-2);
      //      exit(1);
    }
#endif



#ifdef HAND_IS_CONS
    if ((strcmp(IdTable_get_name(idL), "IS") == 0) &&
	(strcmp(IdTable_get_name(idR), "Cons") == 0)) {

      printf("Rule is optimised: %s >< %s.\n", 
	     IdTable_get_name(idL),
	     IdTable_get_name(idR));
      
      //      PutsCodeN(&code[2], code_size-2);
      
      int i=2;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)13;
      code[i++] = (void *)21;
      code[i++] = (void *)2;
      code[i++] = (void *)VM_OFFSET_META_L(0);
      code[i++] = (void *)VM_OFFSET_META_R(0);

      code[i++] = CodeAddr[OP_JMPCNCT_CONS];
      code[i++] = (void *)VM_OFFSET_META_R(1);
      code[i++] = (void *)9;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)12;
      code[i++] = (void *)20;
      code[i++] = (void *)1;
      code[i++] = (void *)13;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)12;
      code[i++] = (void *)VM_OFFSET_META_R(1);;
      
      code[i++] = CodeAddr[RET_FREE_LR];
      
      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(0);
      code[i++] = (void *)13;

      code[i++] = CodeAddr[LOOP_RREC2];
      code[i++] = (void *)VM_OFFSET_META_R(1);
      
      code_size = i;
      
      //      PutsCodeN(&code[2], i-2);
      //      exit(1);
    }
#endif


// --------------------------------------------------------------
// For Quick Sort
//     #define HAND_Apnd_CONS
//     #define HAND_Part_CONS
// --------------------------------------------------------------
    
#ifdef HAND_Apnd_CONS
    if ((strcmp(IdTable_get_name(idL), "Apnd") == 0) &&
	(idR == ID_CONS)) {

      printf("Rule is optimised: %s >< %s.\n", 
	     IdTable_get_name(idL),
	     IdTable_get_name(idR));
      
      //      PutsCodeN(&code[2], code_size-2);
      
      int i=2;

      code[i++] = CodeAddr[MKNAME];
      code[i++] = (void *)13;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)12;
      code[i++] = (void *)8;
      code[i++] = (void *)2;
      code[i++] = (void *)5;
      code[i++] = (void *)13;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)0;
      code[i++] = (void *)12;


      code[i++] = CodeAddr[OP_JMPCNCT_CONS];
      code[i++] = (void *)VM_OFFSET_META_R(1);
      code[i++] = (void *)10;
            
      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)14;
      code[i++] = (void *)(unsigned long)idL;
      code[i++] = (void *)2;
      code[i++] = (void *)13;
      code[i++] = (void *)1;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)14;
      code[i++] = (void *)6;

      code[i++] = CodeAddr[RET_FREE_LR];

      
      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(0);
      code[i++] = (void *)13;

      code[i++] = CodeAddr[LOOP_RREC2];
      code[i++] = (void *)VM_OFFSET_META_R(1);
      
      code_size = i;
      
      //      PutsCodeN(&code[2], i-2);
      //                  exit(1);
    }
#endif

    
#ifdef HAND_Part_CONS
    if ((strcmp(IdTable_get_name(idL), "Part") == 0) &&
	(strcmp(IdTable_get_name(idR), "Cons") == 0)) {

      printf("Rule is optimised: %s >< %s.\n", 
	     IdTable_get_name(idL),
	     IdTable_get_name(idR));
      
      //      PutsCodeN(&code[2], code_size-2);
      
      int i=2;

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)13;
      code[i++] = (void *)VM_OFFSET_META_R(0);

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)14;
      code[i++] = (void *)VM_OFFSET_META_L(0);

      code[i++] = CodeAddr[OP_LT];
      code[i++] = (void *)12;
      code[i++] = (void *)13;
      code[i++] = (void *)14;
      
      code[i++] = CodeAddr[OP_JMPEQ0];
      code[i++] = (void *)12;
      code[i++] = (void *)30;

      code[i++] = CodeAddr[MKNAME];
      code[i++] = (void *)13;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)12;
      code[i++] = (void *)8;
      code[i++] = (void *)2;
      code[i++] = (void *)5;
      code[i++] = (void *)13;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)VM_OFFSET_META_L(2);
      code[i++] = (void *)12;

      code[i++] = CodeAddr[OP_JMPCNCT_CONS];
      code[i++] = (void *)VM_OFFSET_META_R(1);
      code[i++] = (void *)11;
            
      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)14;
      code[i++] = (void *)(unsigned long)idL;
      code[i++] = (void *)3;
      code[i++] = (void *)VM_OFFSET_META_L(0);
      code[i++] = (void *)VM_OFFSET_META_L(1);
      code[i++] = (void *)13;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)14;
      code[i++] = (void *)VM_OFFSET_META_R(1);

      code[i++] = CodeAddr[RET_FREE_LR];

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(2);
      code[i++] = (void *)13;

      code[i++] = CodeAddr[LOOP_RREC2];
      code[i++] = (void *)VM_OFFSET_META_R(1);


      
      code[i++] = CodeAddr[MKNAME];
      code[i++] = (void *)13;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)12;
      code[i++] = (void *)8;
      code[i++] = (void *)2;
      code[i++] = (void *)5;
      code[i++] = (void *)13;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)VM_OFFSET_META_L(1);
      code[i++] = (void *)12;

      code[i++] = CodeAddr[OP_JMPCNCT_CONS];
      code[i++] = (void *)VM_OFFSET_META_L(2);
      code[i++] = (void *)11;
            
      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)14;
      code[i++] = (void *)(unsigned long)idL;
      code[i++] = (void *)3;
      code[i++] = (void *)VM_OFFSET_META_L(0);
      code[i++] = (void *)13;
      code[i++] = (void *)VM_OFFSET_META_L(2);

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)14;
      code[i++] = (void *)VM_OFFSET_META_R(1);

      code[i++] = CodeAddr[RET_FREE_LR];

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(1);
      code[i++] = (void *)13;

      code[i++] = CodeAddr[LOOP_RREC2];
      code[i++] = (void *)VM_OFFSET_META_R(1);

      
      
      code_size = i;
      
      //      PutsCodeN(&code[2], i-2);
      //                  exit(1);
    }
#endif

    

// --------------------------------------------------------------
// For Merge Sort
//    #define HAND_Split_CONS
//    #define HAND_MergeCC_CONS
// --------------------------------------------------------------
    
#ifdef HAND_Split_CONS
    if ((strcmp(IdTable_get_name(idL), "Split") == 0) &&
	(strcmp(IdTable_get_name(idR), "Cons") == 0)) {

      printf("Rule is optimised: %s >< %s.\n", 
	     IdTable_get_name(idL),
	     IdTable_get_name(idR));
      
      //PutsCodeN(&code[2], code_size-2);
      
      int i=2;

      code[i++] = CodeAddr[MKNAME];
      code[i++] = (void *)13;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)12;
      code[i++] = (void *)8;
      code[i++] = (void *)2;
      code[i++] = (void *)5;
      code[i++] = (void *)13;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)0;
      code[i++] = (void *)12;

      code[i++] = CodeAddr[OP_JMPCNCT_CONS];
      code[i++] = (void *)VM_OFFSET_META_R(1);
      code[i++] = (void *)10;
            
      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)14;
      code[i++] = (void *)22;
      code[i++] = (void *)2;
      code[i++] = (void *)1;
      code[i++] = (void *)13;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)14;
      code[i++] = (void *)6;

      code[i++] = CodeAddr[RET_FREE_LR];

      
      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(0);
      code[i++] = (void *)VM_OFFSET_META_L(1);

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(1);
      code[i++] = (void *)13;
      
      code[i++] = CodeAddr[LOOP_RREC2];
      code[i++] = (void *)VM_OFFSET_META_R(1);
      
      code_size = i;
      
      //      PutsCodeN(&code[2], i-2);
      //            exit(1);
    }
#endif


    //        #define HAND_MergeCC_CONS
#ifdef HAND_MergeCC_CONS
    if ((strcmp(IdTable_get_name(idL), "MergeCC") == 0) &&
	(strcmp(IdTable_get_name(idR), "Cons") == 0)) {

      printf("Rule is optimised: %s >< %s.\n", 
	     IdTable_get_name(idL),
	     IdTable_get_name(idR));
      
      PutsCodeN(&code[2], code_size-2);
      //exit(1);
      
      int i=2;

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)13;
      code[i++] = (void *)VM_OFFSET_META_R(0);

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)14;
      code[i++] = (void *)VM_OFFSET_META_L(1);

      code[i++] = CodeAddr[OP_LE];
      code[i++] = (void *)12;
      code[i++] = (void *)13;
      code[i++] = (void *)14;
      
      code[i++] = CodeAddr[OP_JMPEQ0];
      code[i++] = (void *)12;
      code[i++] = (void *)30;

      code[i++] = CodeAddr[MKNAME];
      code[i++] = (void *)13;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)12;
      code[i++] = (void *)8;
      code[i++] = (void *)2;
      code[i++] = (void *)5;
      code[i++] = (void *)13;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)0;
      code[i++] = (void *)12;

      code[i++] = CodeAddr[OP_JMPCNCT_CONS];
      code[i++] = (void *)VM_OFFSET_META_R(1);
      code[i++] = (void *)11;
            
      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)14;
      code[i++] = (void *)(unsigned long)idL;
      code[i++] = (void *)3;
      code[i++] = (void *)13;
      code[i++] = (void *)1;
      code[i++] = (void *)2;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)14;
      code[i++] = (void *)6;

      code[i++] = CodeAddr[RET_FREE_LR];

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(0);
      code[i++] = (void *)13;

      code[i++] = CodeAddr[LOOP_RREC2];
      code[i++] = (void *)VM_OFFSET_META_R(1);


      
      code[i++] = CodeAddr[MKNAME];
      code[i++] = (void *)13;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)12;
      code[i++] = (void *)8;
      code[i++] = (void *)2;
      code[i++] = (void *)1;
      code[i++] = (void *)13;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)0;
      code[i++] = (void *)12;

      code[i++] = CodeAddr[OP_JMPCNCT_CONS];
      code[i++] = (void *)VM_OFFSET_META_L(2);
      code[i++] = (void *)11;
            
      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)14;
      code[i++] = (void *)(unsigned long)idL;
      code[i++] = (void *)3;
      code[i++] = (void *)13;
      code[i++] = (void *)5;
      code[i++] = (void *)6;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)14;
      code[i++] = (void *)2;

      code[i++] = CodeAddr[RET_FREE_LR];

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)14;
      code[i++] = (void *)VM_OFFSET_META_L(2); // ys

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(0);
      code[i++] = (void *)13;

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(1);
      code[i++] = (void *)VM_OFFSET_META_R(0);

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(2);
      code[i++] = (void *)VM_OFFSET_META_R(1);

      code[i++] = CodeAddr[LOOP_RREC2];
      code[i++] = (void *)14;


      
      
      code_size = i;
      
      //      PutsCodeN(&code[2], i-2);
      //                  exit(1);
    }
#endif




// --------------------------------------------------------------
// For Bubble Sort
//    #define HAND_B_CONS
// --------------------------------------------------------------
    
#ifdef HAND_B_CONS
    if ((strcmp(IdTable_get_name(idL), "B") == 0) &&
	(strcmp(IdTable_get_name(idR), "Cons") == 0)) {

      printf("Rule is optimised: %s >< %s.\n", 
	     IdTable_get_name(idL),
	     IdTable_get_name(idR));
      
      //      PutsCodeN(&code[2], code_size-2);
      
      int i=2;

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)13;
      code[i++] = (void *)VM_OFFSET_META_L(1);

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)14;
      code[i++] = (void *)VM_OFFSET_META_R(0);

      code[i++] = CodeAddr[OP_LT];
      code[i++] = (void *)12;
      code[i++] = (void *)13;
      code[i++] = (void *)14;
      
      code[i++] = CodeAddr[OP_JMPEQ0];
      code[i++] = (void *)12;
      code[i++] = (void *)32;

      code[i++] = CodeAddr[MKNAME];
      code[i++] = (void *)13;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)12;
      code[i++] = (void *)8;
      code[i++] = (void *)2;
      code[i++] = (void *)1;
      code[i++] = (void *)13;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)0;
      code[i++] = (void *)12;

      code[i++] = CodeAddr[OP_JMPCNCT_CONS];
      code[i++] = (void *)VM_OFFSET_META_R(1);
      code[i++] = (void *)10;
            
      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)14;
      code[i++] = (void *)(unsigned long)idL;
      code[i++] = (void *)2;
      code[i++] = (void *)13;
      code[i++] = (void *)5;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)14;
      code[i++] = (void *)6;

      code[i++] = CodeAddr[RET_FREE_LR];

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(0);
      code[i++] = (void *)13;

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(1);
      code[i++] = (void *)VM_OFFSET_META_R(0);

      code[i++] = CodeAddr[LOOP_RREC2];
      code[i++] = (void *)VM_OFFSET_META_R(1);


      
      code[i++] = CodeAddr[MKNAME];
      code[i++] = (void *)13;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)12;
      code[i++] = (void *)8;
      code[i++] = (void *)2;
      code[i++] = (void *)5;
      code[i++] = (void *)13;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)0;
      code[i++] = (void *)12;

      code[i++] = CodeAddr[OP_JMPCNCT_CONS];
      code[i++] = (void *)VM_OFFSET_META_R(1);
      code[i++] = (void *)10;
            
      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)14;
      code[i++] = (void *)(unsigned long)idL;
      code[i++] = (void *)2;
      code[i++] = (void *)13;
      code[i++] = (void *)1;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)14;
      code[i++] = (void *)6;

      code[i++] = CodeAddr[RET_FREE_LR];

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(0);
      code[i++] = (void *)13;

      code[i++] = CodeAddr[LOOP_RREC2];
      code[i++] = (void *)VM_OFFSET_META_R(1);


      
      
      code_size = i;
      
      //      PutsCodeN(&code[2], i-2);
      //                  exit(1);
    }
#endif




// --------------------------------------------------------------
// For Dup_SZ
//       #define HAND_DUP_S
// --------------------------------------------------------------
#ifdef HAND_DUP_S
    if ((strcmp(IdTable_get_name(idL), "Dup") == 0) &&
	(strcmp(IdTable_get_name(idR), "S") == 0)) {

      printf("Rule is optimised: %s >< %s.\n", 
	     IdTable_get_name(idL),
	     IdTable_get_name(idR));
      //      PutsCodeN(&code[2], code_size-2);
      
      int i=2;

      code[i++] = CodeAddr[MKNAME];
      code[i++] = (void *)13;

      code[i++] = CodeAddr[MKNAME];
      code[i++] = (void *)15;
      
      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)12;
      code[i++] = (void *)(unsigned long)idR;
      code[i++] = (void *)1;
      code[i++] = (void *)13;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)VM_OFFSET_META_L(0);
      code[i++] = (void *)12;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)14;
      code[i++] = (void *)(unsigned long)idR;
      code[i++] = (void *)1;
      code[i++] = (void *)15;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)VM_OFFSET_META_L(1);
      code[i++] = (void *)14;

      
      code[i++] = CodeAddr[OP_JMPCNCT];
      code[i++] = (void *)VM_OFFSET_META_R(0);
      code[i++] = (void *)(unsigned long)idR;
      code[i++] = (void *)10;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)16;
      code[i++] = (void *)(unsigned long)idL;
      code[i++] = (void *)2;
      code[i++] = (void *)13;
      code[i++] = (void *)15;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)16;
      code[i++] = (void *)VM_OFFSET_META_R(0);
      
      code[i++] = CodeAddr[RET_FREE_LR];

      
      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(0);
      code[i++] = (void *)13;

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(1);
      code[i++] = (void *)15;
      
      code[i++] = CodeAddr[LOOP_RREC1];
      code[i++] = (void *)VM_OFFSET_META_R(0);
      //code[i++] = (void *)1;
      
      code_size = i;
      
      //PutsCodeN(&code[2], i-2);
      //            exit(1);
    }
#endif
    


// --------------------------------------------------------------
// For ADD_SZ
//#define HAND_ADD_S
// --------------------------------------------------------------
#ifdef HAND_ADD_S
    if ((strcmp(IdTable_get_name(idL), "AddSZ") == 0) &&
	(strcmp(IdTable_get_name(idR), "S") == 0)) {

      printf("Rule is optimised: %s >< %s.\n", 
	     IdTable_get_name(idL),
	     IdTable_get_name(idR));
      //PutsCodeN(&code[2], code_size-2);
      
      int i=2;

      code[i++] = CodeAddr[MKNAME];
      code[i++] = (void *)13;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)12;
      code[i++] = (void *)(unsigned long)idR;
      code[i++] = (void *)1;
      code[i++] = (void *)13;

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)VM_OFFSET_META_L(0);;
      code[i++] = (void *)12;

      code[i++] = CodeAddr[OP_JMPCNCT];
      code[i++] = (void *)VM_OFFSET_META_R(0);
      code[i++] = (void *)(unsigned long)idR;
      code[i++] = (void *)10;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)14;
      code[i++] = (void *)(unsigned long)idL;
      code[i++] = (void *)2;
      code[i++] = (void *)13;
      code[i++] = (void *)VM_OFFSET_META_L(1);

      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)14;
      code[i++] = (void *)VM_OFFSET_META_R(0);
      
      code[i++] = CodeAddr[RET_FREE_LR];

      
      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(0);
      code[i++] = (void *)13;

      code[i++] = CodeAddr[LOOP_RREC1];
      code[i++] = (void *)VM_OFFSET_META_R(0);
      
      code_size = i;
      //      PutsCodeN(&code[2], i-2);
      //            exit(1);
    }
#endif


// --------------------------------------------------------------
// For ACK_Sx
// #define HAND_ACK_S
// --------------------------------------------------------------
#ifdef HAND_ACK_S
    if ((strcmp(IdTable_get_name(idL), "Ack_Sx") == 0) &&
	(strcmp(IdTable_get_name(idR), "S") == 0)) {

      printf("Rule is optimised: %s >< %s.\n", 
	     IdTable_get_name(idL),
	     IdTable_get_name(idR));
      //      PutsCodeN(&code[2], code_size-2);
      
      int i=2;

      code[i++] = CodeAddr[MKNAME];
      code[i++] = (void *)14;

      code[i++] = CodeAddr[MKNAME];
      code[i++] = (void *)15;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)13;
      code[i++] = (void *)20; // Ack
      code[i++] = (void *)2;
      code[i++] = (void *)VM_OFFSET_META_L(0);
      code[i++] = (void *)14;

      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)12;
      code[i++] = (void *)24; // Dup
      code[i++] = (void *)2;
      code[i++] = (void *)13;
      code[i++] = (void *)15;
      
      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)12;
      code[i++] = (void *)1;

      code[i++] = CodeAddr[OP_JMPCNCT];
      code[i++] = (void *)VM_OFFSET_META_R(0);
      code[i++] = (void *)(unsigned long)idR;
      code[i++] = (void *)10;
      
      code[i++] = CodeAddr[MKAGENT];
      code[i++] = (void *)16;
      code[i++] = (void *)(unsigned long)idL;
      code[i++] = (void *)2;
      code[i++] = (void *)14;
      code[i++] = (void *)15;
      
      code[i++] = CodeAddr[PUSH];
      code[i++] = (void *)16;
      code[i++] = (void *)5;

      code[i++] = CodeAddr[RET_FREE_LR];
            
      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(0);
      code[i++] = (void *)14;

      code[i++] = CodeAddr[LOAD];
      code[i++] = (void *)VM_OFFSET_META_L(1);
      code[i++] = (void *)15;

      code[i++] = CodeAddr[LOOP_RREC1];
      code[i++] = (void *)VM_OFFSET_META_R(0);
      
      code_size = i;
      //            PutsCodeN(&code[2], i-2);
	    //                  exit(1);
    }
#endif
    
    
    
   
   //   #define HAND_FIB2
#ifdef HAND_FIB2
    PutsCodeN(&code[2], code_size-2);
   int i=2;
   //   code[i++] = CodeAddr[MKVAL];
   //   code[i++] = (void *)14;
   //   code[i++] = (void *)0;
   //   code[i++] = (void *)0;
   //
   //   code[i++] = CodeAddr[OP_EQ];
   //   code[i++] = (void *)12;
   //   code[i++] = (void *)11;
   //   code[i++] = (void *)14;
   
   code[i++] = CodeAddr[OP_EQI];
   //code[i++] = (void *)11;  // ここで 11(OFFSET_R)を壊してしまうと他で影響あり
   code[i++] = (void *)12;
   code[i++] = (void *)11;
   code[i++] = (void *)0;

   code[i++] = CodeAddr[OP_JMPEQ0];
   code[i++] = (void *)12;
   //   code[i++] = (void *)8;   
   code[i++] = (void *)4;
   
   //   code[i++] = CodeAddr[MKVAL];
   //   code[i++] = (void *)12;
   //   code[i++] = (void *)0;
   //   code[i++] = (void *)1;
   //   
   //   code[i++] = CodeAddr[PUSH];
   //   code[i++] = (void *)0;
   //   code[i++] = (void *)12;
   
      code[i++] = CodeAddr[PUSHI];
      code[i++] = (void *)0;
      code[i++] = (void *)INT2FIX(1);

   code[i++] = CodeAddr[RET_FREE_L];

   


   //   code[i++] = CodeAddr[MKVAL];
   //   code[i++] = (void *)14;
   //   code[i++] = (void *)0;
   //   code[i++] = (void *)1;
   //
   //   code[i++] = CodeAddr[OP_EQ];
   //   code[i++] = (void *)12;
   //   code[i++] = (void *)11;
   //   code[i++] = (void *)14;

   code[i++] = CodeAddr[OP_EQI];
   code[i++] = (void *)12;
   code[i++] = (void *)11;
   code[i++] = (void *)1;

   code[i++] = CodeAddr[OP_JMPEQ0];
   code[i++] = (void *)12;
   //   code[i++] = (void *)8;
   code[i++] = (void *)4;

   //   code[i++] = CodeAddr[MKVAL];
   //   code[i++] = (void *)12;
   //   code[i++] = (void *)0;
   //   code[i++] = (void *)1;
   //   
   //   code[i++] = CodeAddr[PUSH];
   //   code[i++] = (void *)0;
   //   code[i++] = (void *)12;

      code[i++] = CodeAddr[PUSHI];
      code[i++] = (void *)0;
      code[i++] = (void *)INT2FIX(1);

   
   code[i++] = CodeAddr[RET_FREE_L];


   
   // Fib(Add(n2,r))~b, Fib(n2)~c
   // -------------------------------
   // Fib(n2)~c   
   code[i++] = CodeAddr[MKNAME];
   code[i++] = (void *)16;

   
   code[i++] = CodeAddr[OP_SUBI];
   code[i++] = (void *)12;
   code[i++] = (void *)11;
   code[i++] = (void *)2;

   code[i++] = CodeAddr[MKAGENT];
   code[i++] = (void *)13;
   code[i++] = (void *)20;
   code[i++] = (void *)1;
   code[i++] = (void *)16;

   code[i++] = CodeAddr[PUSH];
   code[i++] = (void *)13;
   code[i++] = (void *)12;
   

   // -------------------------------
   // Fib(Add(n2,r))~b
   code[i++] = CodeAddr[OP_SUBI];
   code[i++] = (void *)13;
   code[i++] = (void *)11;
   code[i++] = (void *)1;

   
   code[i++] = CodeAddr[MKAGENT];
   code[i++] = (void *)14;
   code[i++] = (void *)10;
   code[i++] = (void *)2;
   code[i++] = (void *)16;
   code[i++] = (void *)0;


   code[i++] = CodeAddr[LOAD];
   code[i++] = (void *)VM_OFFSET_META_L(0);
   code[i++] = (void *)14;

   code[i++] = CodeAddr[LOAD];
   code[i++] = (void *)VM_OFFSET_ANNOTATE_R;
   code[i++] = (void *)13;
   
   code[i++] = CodeAddr[LOOP];
   
   code_size = i;
   PutsCodeN(&code[2], i-2);
   //    exit(1);
#endif   


   
		    //ast_puts(ruleL); printf("><");
		    //ast_puts(ruleR); puts("");

  // Record the rule code for idR >< idL
  RuleTable_record(idL, idR, code_size, code); 

  if (idL != idR) {    
    // Delete the rule code for idR >< idL
    // because we need only the rule idL >< idR.    
    RuleTable_delete(idR, idL);
    
  }

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
    &&E_PUSH, &&E_PUSHI, &&E_MKNAME, &&E_MKGNAME, &&E_MKAGENT,
    &&E_REUSEAGENT, &&E_MYPUSH,
    &&E_RET, &&E_RET_FREE_LR, &&E_RET_FREE_L, &&E_RET_FREE_R,
    &&E_LOOP, &&E_LOOP_RREC, &&E_LOOP_RREC1, &&E_LOOP_RREC2,
    &&E_LOADI, &&E_LOAD, &&E_LOADP,
    &&E_ADD, &&E_SUB, &&E_SUBI, &&E_MUL, &&E_DIV, &&E_MOD, 
    &&E_LT, &&E_LE, &&E_EQ, &&E_EQI, &&E_NE,
    &&E_JMPEQ0, &&E_JMPCNCT_CONS, &&E_JMPCNCT, &&E_JMP,
    &&E_UNM, &&E_RAND,
    &&E_CNCTGN, &&E_SUBSTGN,
    &&E_NOP, 
  };

  // To create the table.
  // mode=0: Create table (only for initialise)
  // mode=1: Execute codes (the normal operation)
  if (mode == 0) {
    return table;
  }

  int arity, i, pc=0;
  VALUE a1;
  
  goto *code[0];
  

 E_MKNAME:
  //    puts("mkname");
  vm->reg[(unsigned long)code[pc+1]] = makeName(vm);
  pc +=2;
  goto *code[pc];

 E_MKGNAME:
  //    puts("mkgname");

  //a1 = makeGlobalName(vm, (char *)code[pc+1]);

  a1 = NameTable_get_heap((char *)code[pc+1]);
  if (a1 == (VALUE)NULL) {
    i = IdTable_new_gnameid();
    a1 = makeName(vm);

    // set GID obtained by IdTable_new_gnameid()    
    BASIC(a1)->id = i;  
    NameTable_set_heap_id((char *)code[pc+1], a1, i);
  }

  vm->reg[(unsigned long)code[pc+2]] = a1;
  pc +=3;
  goto *code[pc];

  
 E_MKAGENT:
  //    puts("mkagent");
  arity = (unsigned long)code[pc+3];
  a1 = makeAgent(vm, (unsigned long)code[pc+2]);
  vm->reg[(unsigned long)code[pc+1]] = a1;
  {
    volatile VALUE *a1port = AGENT(a1)->port;
    
    pc +=4;
    
    for(i=0; i<arity; i++) {
      //    AGENT(a1)->port[i] = vm->reg[(unsigned long)code[pc]];
      a1port[i] = vm->reg[(unsigned long)code[pc++]];	  
    }
    
  }
  goto *code[pc];

 E_REUSEAGENT: // reuseagent target id arity
  //    puts("reuseagent");
  a1 = vm->reg[(unsigned long)code[pc+1]];
  AGENT(a1)->basic.id = (unsigned long)code[pc+2];
  {
    volatile VALUE *a1port = AGENT(a1)->port;
    arity = (unsigned long)code[pc+3];
    pc +=4;
    for(i=0; i<arity; i++) {
      //    AGENT(a1)->port[i] = vm->reg[(unsigned long)code[pc]];	  
      a1port[i] = vm->reg[(unsigned long)code[pc]];	  
      pc++;
    }
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
  //    puts("push");
  PUSH(vm, vm->reg[(unsigned long)code[pc+1]], vm->reg[(unsigned long)code[pc+2]]);
  pc +=3;
  goto *code[pc];


 E_PUSHI:
  //    puts("pushi reg int");
  PUSH(vm, vm->reg[(unsigned long)code[pc+1]], (unsigned long)code[pc+2]);
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
  //    puts("mypush");
  //  VM_EQStack_Push(vm, vm->reg[(unsigned long)code[pc+1]], vm->reg[(unsigned long)code[pc+2]]);
  MYPUSH(vm, vm->reg[(unsigned long)code[pc+1]], vm->reg[(unsigned long)code[pc+2]]);
  pc +=3;
  goto *code[pc];

  
  
 E_LOADI:
  //    puts("loadi reg num");
  //a1 = makeVal_int(vm, (unsigned long)code[pc+3]);
  a1 = INT2FIX((long)code[pc+2]);
  vm->reg[(unsigned long)code[pc+1]] = a1;
  pc +=3;
  goto *code[pc];




 E_RET:
  //    puts("ret");
  return NULL;

 E_RET_FREE_LR:
  //    puts("ret");
  freeAgent(vm->reg[VM_OFFSET_ANNOTATE_L]);
  freeAgent(vm->reg[VM_OFFSET_ANNOTATE_R]);
  //

  //  freeAgent(vm->L);
  //  freeAgent(vm->R);
  return NULL;
  
 E_RET_FREE_L:
  //    puts("ret");
  freeAgent(vm->reg[VM_OFFSET_ANNOTATE_L]);
  //  freeAgent(vm->L);
  return NULL;

 E_RET_FREE_R:
  //    puts("ret");
  freeAgent(vm->reg[VM_OFFSET_ANNOTATE_R]);
  //  freeAgent(vm->R);
  return NULL;


 E_LOOP:
  //    puts("loop");
  pc = 0;
  goto *code[0];

  
 E_LOOP_RREC:
  //      puts("looprrec reg ar");
  freeAgent(vm->reg[VM_OFFSET_ANNOTATE_R]);
  
  a1 = vm->reg[(unsigned long)code[pc+1]];
  for (int i=0; i<(unsigned long)code[pc+2]; i++) {
    vm->reg[VM_OFFSET_META_R(i)] = AGENT(a1)->port[i];
  }
  
  vm->reg[VM_OFFSET_ANNOTATE_R] = a1;
  
  pc = 0;
  goto *code[0];

  
 E_LOOP_RREC1:
  //      puts("looprrec reg ar");
  freeAgent(vm->reg[VM_OFFSET_ANNOTATE_R]);
  
  a1 = vm->reg[(unsigned long)code[pc+1]];

  vm->reg[VM_OFFSET_META_R(0)] = AGENT(a1)->port[0];
  
  vm->reg[VM_OFFSET_ANNOTATE_R] = a1;
  
  pc = 0;
  goto *code[0];

  
 E_LOOP_RREC2:
  //      puts("looprrec reg ar");
  freeAgent(vm->reg[VM_OFFSET_ANNOTATE_R]);
  
  a1 = vm->reg[(unsigned long)code[pc+1]];

  vm->reg[VM_OFFSET_META_R(0)] = AGENT(a1)->port[0];
  vm->reg[VM_OFFSET_META_R(1)] = AGENT(a1)->port[1];
  
  vm->reg[VM_OFFSET_ANNOTATE_R] = a1;
  
  pc = 0;
  goto *code[0];
  

  

  
 E_LOAD:
  //    puts("load reg reg");
  //a1 = makeVal_int(vm, (unsigned long)code[pc+3]);
  vm->reg[(unsigned long)code[pc+1]] = 
    vm->reg[(unsigned long)code[pc+2]];
  pc +=3;
  goto *code[pc];

 E_LOADP:
  //    puts("loadp reg reg port");
  vm->reg[(unsigned long)code[pc+1]] = 
    AGENT(vm->reg[(unsigned long)code[pc+2]])->port[vm->reg[(unsigned long)code[pc+3]]];
  pc +=4;
  goto *code[pc];

  
 E_ADD:
  //    puts("ADD reg reg reg");
  vm->reg[(unsigned long)code[pc+1]] = 
        INT2FIX(FIX2INT(vm->reg[(unsigned long)code[pc+2]])+FIX2INT(vm->reg[(unsigned long)code[pc+3]]));
  pc +=4;
  goto *code[pc];

 E_SUB:
  //    puts("SUB reg reg reg");
  vm->reg[(unsigned long)code[pc+1]] = 
    INT2FIX(FIX2INT(vm->reg[(unsigned long)code[pc+2]])-
	    FIX2INT(vm->reg[(unsigned long)code[pc+3]]));
  pc +=4;
  goto *code[pc];

 E_SUBI:
  //puts("SUBI reg reg int");exit(1);
  vm->reg[(unsigned long)code[pc+1]] = 
    INT2FIX(FIX2INT(vm->reg[(unsigned long)code[pc+2]])-
	    (unsigned long)code[pc+3]);
  pc +=4;
  goto *code[pc];

  
 E_MUL:
  //    puts("SUB reg reg reg");
  vm->reg[(unsigned long)code[pc+1]] = 
    INT2FIX(FIX2INT(vm->reg[(unsigned long)code[pc+2]])*
	    FIX2INT(vm->reg[(unsigned long)code[pc+3]]));
  pc +=4;
  goto *code[pc];

 E_DIV:
  //    puts("SUB reg reg reg");
  vm->reg[(unsigned long)code[pc+1]] = 
    INT2FIX(FIX2INT(vm->reg[(unsigned long)code[pc+2]])/
	    FIX2INT(vm->reg[(unsigned long)code[pc+3]]));
  pc +=4;
  goto *code[pc];

 E_MOD:
  //    puts("SUB reg reg reg");
  vm->reg[(unsigned long)code[pc+1]] = 
    INT2FIX(FIX2INT(vm->reg[(unsigned long)code[pc+2]])%
	    FIX2INT(vm->reg[(unsigned long)code[pc+3]]));
  pc +=4;
  goto *code[pc];

 E_LT:
  //    puts("SUB reg reg reg");
  if (FIX2INT(vm->reg[(unsigned long)code[pc+2]]) <
      FIX2INT(vm->reg[(unsigned long)code[pc+3]])) {
    vm->reg[(unsigned long)code[pc+1]] = INT2FIX(1);
  } else {
    vm->reg[(unsigned long)code[pc+1]] = INT2FIX(0);
  }    
  pc +=4;
  goto *code[pc];

 E_LE:
  //    puts("SUB reg reg reg");
  if (FIX2INT(vm->reg[(unsigned long)code[pc+2]]) <=
      FIX2INT(vm->reg[(unsigned long)code[pc+3]])) {
    vm->reg[(unsigned long)code[pc+1]] = INT2FIX(1);
  } else {
    vm->reg[(unsigned long)code[pc+1]] = INT2FIX(0);
  }    
  pc +=4;
  goto *code[pc];

 E_EQ:
  //    puts("SUB reg reg reg");
  if (vm->reg[(unsigned long)code[pc+2]] ==
      vm->reg[(unsigned long)code[pc+3]]) {
    vm->reg[(unsigned long)code[pc+1]] = INT2FIX(1);
  } else {
    vm->reg[(unsigned long)code[pc+1]] = INT2FIX(0);
  }    
  pc +=4;
  goto *code[pc];


 E_EQI:
  //    puts("SUB reg reg int");
  if (FIX2INT(vm->reg[(unsigned long)code[pc+2]]) ==
      (unsigned long)code[pc+3]) {
    vm->reg[(unsigned long)code[pc+1]] = INT2FIX(1);
  } else {
    vm->reg[(unsigned long)code[pc+1]] = INT2FIX(0);
  }
  
  pc +=4;
  goto *code[pc];


  
 E_NE:
  //    puts("SUB reg reg reg");
  if (vm->reg[(unsigned long)code[pc+2]] !=
      vm->reg[(unsigned long)code[pc+3]]) {
    vm->reg[(unsigned long)code[pc+1]] = INT2FIX(1);
  } else {
    vm->reg[(unsigned long)code[pc+1]] = INT2FIX(0);
  }    
  pc +=4;
  goto *code[pc];

 E_JMPEQ0:
  //    puts("JMPEQ0 reg pc");
  //    pc is a relative address, not absolute one!
  if (!FIX2INT(vm->reg[(unsigned long)code[pc+1]])) {
    pc += (unsigned long)code[pc+2];
  }
  pc +=3;
  goto *code[pc];


 E_JMPCNCT_CONS:
  //    puts("JMPCNCT_CONS reg pc");
#ifdef COUNT_CNCT    
  Count_cnct++;
#endif

  a1 = vm->reg[(unsigned long)code[pc+1]];
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
    vm->reg[(unsigned long)code[pc+1]] = a2;
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
  
  a1 = vm->reg[(unsigned long)code[pc+1]];
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
    vm->reg[(unsigned long)code[pc+1]] = a2;
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
  //    puts("JMP pc");
  pc += vm->reg[(unsigned long)code[pc+1]];
  pc +=2;
  goto *code[pc];


  
 E_UNM:
  //    puts("UNM reg reg");
  vm->reg[(unsigned long)code[pc+1]] = 
    INT2FIX(-1 * FIX2INT(vm->reg[(unsigned long)code[pc+2]]));
  pc +=3;
  goto *code[pc];

 E_RAND:
  //    puts("RAND reg reg");
  vm->reg[(unsigned long)code[pc+1]] = 
    INT2FIX(rand()%FIX2INT(vm->reg[(unsigned long)code[pc+2]]));
  pc +=3;
  goto *code[pc];


 E_CNCTGN:
  //    puts("CNCTGN reg reg");
  // "x"~s, "x"->t     ==> push(s,t), free("x") where "x" is a global name.
  {
    VALUE x = vm->reg[(unsigned long)code[pc+1]];
    a1 = NAME(x)->port;
    freeName(x);
    PUSH(vm, vm->reg[(unsigned long)code[pc+2]], a1);
  }
  pc +=3;
  goto *code[pc];
       
  

 E_SUBSTGN:
  //    puts("SUBSTGN reg reg");  
  // "x"~s, t->u("x")  ==> t->u(s), free("x") where "x" is a global name.
  {
    VALUE x = vm->reg[(unsigned long)code[pc+1]];
    global_replace_keynode_in_another_term(x,vm->reg[(unsigned long)code[pc+2]]);
    freeName(x);
  }
  pc +=3;
  goto *code[pc];
  
  
  
  
  // extended codes should be ended here.


 E_NOP:
  pc++;
  goto *code[pc];



}





void errprintf(int tid) {
  printf("%2d:", tid);
}  

void errputs(char *s, int tid) {
  /*
    errprintf(tid);
    puts(s);
  */
}


/******************************************
 Mark and Sweep for error recovery
******************************************/
#ifndef THREAD

/* 30bit目が 1 ならば、Garbage Collection の Mark&Sweep にて、
   Mark されたことを意味する*/
#define FLAG_MARKED 0x01 << 30
#define IS_FLAG_MARKED(a) ((a) & FLAG_MARKED)
#define SET_FLAG_MARKED(a) ((a) = ((a) | FLAG_MARKED))
#define TOGGLE_FLAG_MARKED(a) ((a) = ((a) ^ FLAG_MARKED))


void markHeapRec(VALUE ptr) {
 loop:  
  if ((ptr == (VALUE)NULL) || (IS_FIXNUM(ptr))) {
    return;
  } else if (IS_NAMEID(BASIC(ptr)->id)) {
    if (ptr == ShowNameHeap) return;

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
      ShowNameHeap=ptr;
      markHeapRec(NAME(ptr)->port);
      ShowNameHeap=(VALUE)NULL;
    }      
  }
}


void mark_allHash() {
  int i;
  NameList *at;

  for (i=0; i<NAME_HASHSIZE; i++) {
    at = NameHashTable[i];
    while (at != NULL) {
      if (at->heap != (VALUE)NULL) {
	if (IS_NAMEID(BASIC(at->heap)->id))  {
	  mark_name_port0(at->heap);
	}
      }
      at = at->next;
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
	SET_HEAPFLAG_READYFORUSE(hoop[i].basic.id);
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
	SET_HEAPFLAG_READYFORUSE(hoop[i].basic.id);
      } else {
	TOGGLE_FLAG_MARKED(hoop[i].basic.id);
      }
      
    }
    hoop_list = hoop_list->next;
  } while (hoop_list != hp->last_alloc_list);
  
}



void mark_and_sweep() {

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
	vm->reg[VM_OFFSET_META_L(0)] = AGENT(a1)->port[0];
	break;

      case 2:
	vm->reg[VM_OFFSET_META_L(0)] = AGENT(a1)->port[0];
	vm->reg[VM_OFFSET_META_L(1)] = AGENT(a1)->port[1];
	break;
	
      case 3:
	vm->reg[VM_OFFSET_META_L(0)] = AGENT(a1)->port[0];
	vm->reg[VM_OFFSET_META_L(1)] = AGENT(a1)->port[1];
	vm->reg[VM_OFFSET_META_L(2)] = AGENT(a1)->port[2];
	break;

      default:	
	for (i=0; i<arity; i++) {
	  vm->reg[VM_OFFSET_META_L(i)] = AGENT(a1)->port[i];
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
	vm->reg[VM_OFFSET_META_L(0)] = AGENT(a1)->port[0];
	break;

      case 2:
	vm->reg[VM_OFFSET_META_L(0)] = AGENT(a1)->port[0];
	vm->reg[VM_OFFSET_META_L(1)] = AGENT(a1)->port[1];
	break;
	
      case 3:
	vm->reg[VM_OFFSET_META_L(0)] = AGENT(a1)->port[0];
	vm->reg[VM_OFFSET_META_L(1)] = AGENT(a1)->port[1];
	vm->reg[VM_OFFSET_META_L(2)] = AGENT(a1)->port[2];
	break;

      default:	
	for (i=0; i<arity; i++) {
	  vm->reg[VM_OFFSET_META_L(i)] = AGENT(a1)->port[i];
	}
      }

      
      arity = (unsigned long)code[1];
      switch(arity) {
      case 0:
	break;

      case 1:
	vm->reg[VM_OFFSET_META_R(0)] = AGENT(a2)->port[0];
	break;

      case 2:
	vm->reg[VM_OFFSET_META_R(0)] = AGENT(a2)->port[0];
	vm->reg[VM_OFFSET_META_R(1)] = AGENT(a2)->port[1];
	break;
	
      case 3:
	vm->reg[VM_OFFSET_META_R(0)] = AGENT(a2)->port[0];
	vm->reg[VM_OFFSET_META_R(1)] = AGENT(a2)->port[1];
	vm->reg[VM_OFFSET_META_R(2)] = AGENT(a2)->port[2];
	break;

      default:	
	for (i=0; i<arity; i++) {
	  vm->reg[VM_OFFSET_META_R(i)] = AGENT(a2)->port[i];
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





void VM_Init(VirtualMachine *vm, unsigned int eqStackSize) {
  VM_Buffer_Init(vm);
  VM_EQStack_Init(vm, eqStackSize);
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

void Init_WHNFinfo() {
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
  

void WHNF_execution_loop() {
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


void select_kind_of_push(Ast *ast, int p1, int p2) {  
  char *sym = ast->left->sym;
  VALUE aheap = NameTable_get_heap(sym);
  
  if (aheap != (VALUE)NULL) {
    // aheap already exists as a global
    
    // aheap is connected with something such as aheap->t
    // ==> p2 should be conncected with t, so CNCTGN(p1,p2)
    if (NAME(aheap)->port != (VALUE)NULL) {
      EnvAddCodeCNCTGN((void *)(unsigned long)p1,
		       (void *)(unsigned long)p2);
    } else {
      // aheap occurs somewhere, so it should be replaced by SUBSTGN(p1,p2)
      EnvAddCodeSUBSTGN((void *)(unsigned long)p1,
			(void *)(unsigned long)p2);
    }
  } else {
    EnvAddCodePUSH((void *)(unsigned long)p1, (void *)(unsigned long)p2);
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


    /*
    EnvAddCodePUSH((void *)(unsigned long)p1, (void *)(unsigned long)p2);
    at = ast_getTail(at);
    */

    if (left->id == AST_NAME) {
      select_kind_of_push(left, p1, p2);
      
    } else if (right->id == AST_NAME) {
      select_kind_of_push(right, p2, p1);
      
    } else {
      EnvAddCodePUSH((void *)(unsigned long)p1, (void *)(unsigned long)p2);    
    }
    
    at = ast_getTail(at);



  }
  EnvAddCode(CodeAddr[RET]);  

  // checking whether names occur more than twice
  if (!CmEnv_check_name_reference_times()) {
    if (yyin != stdin) exit(-1);
    return 0;
  }

  // Generate codes from CmEnv, where '0' means index of the `code',
  // so here codes are stored from code[0].
  CmEnv_generate_code_with_nameinfo(code,0); 


  //PutsCode(code); exit(1);

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

  
#ifdef NODE_USE_VERBOSE
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
	printf("CPUNUM=%d, id=%d, cpuid=%d\n", CpuNum, vm->id, (vm->id)%CpuNum);
  }
  //printf("CPUNUM=%d, id=%d, cpuid=%d\n", CpuNum, vm->id, (vm->id)%CpuNum);
#endif

  while (1) {

    VALUE t1, t2;
    while (!EQStack_Pop(vm, &t1, &t2)) {
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

void tpool_init(unsigned int eqstack_size) {
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
    VM_Init(VMs[i], eqstack_size);
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

void tpool_destroy() {
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
    p1 = CompileTermFromAst(at->left->left, -1);
    p2 = CompileTermFromAst(at->left->right, -1);
    EnvAddCodeMYPUSH((void *)(unsigned long)p1, (void *)(unsigned long)p2);
    eqsnum++;   //分散用
    at = ast_getTail(at);
  }
  EnvAddCode(CodeAddr[RET]);  

  // checking whether names occur more than twice
  if (!CmEnv_check_name_reference_times()) {
    return 0;
  }
  // '0' means that generated codes are stored in code[0,...].
  CmEnv_generate_code_with_nameinfo(code,0);

  //PutsCode(code); exit(1);

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

  //usleep(CAS_LOCK_USLEEP);  // a little wait untill threads start.
  usleep(10000);


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

  /*
  printf("[");
  for (i=0; i<MaxThreadsNum-1; i++) {
    printf("%.1f%%, ", VM_Get_InteractionCount(VMs[i])/(double)total*100.0);
  }
  printf("%.1f%%] (CPUNUM=%d)\n", VM_Get_InteractionCount(VMs[i])/(double)total*100.0, CpuNum);
  */

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
  int retrieve_flag = 1; // 1:エラー時にインタプリタへ復帰, 0:終了


#ifdef MY_YYLINENO
 InfoLineno_Init();
#endif

 // Pritty printing for local variables
#ifdef PRETTY_VAR
 Pretty_init();
#endif

  {
    int i, param;
    char *fname = NULL;

    //int max_EQStack=10000;
    int max_EQStack=1 << 13;


#ifndef THREAD
    Init_WHNFinfo();
#endif

    ast_heapInit();


    
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
	  printf(" -f <filename>    Set input file name            (Defalut:    STDIN)\n");
	  
	  printf(" -x <number>      Set the size of the EQ stack   (Default: %8u)\n",
		 max_EQStack);


	  // Extended Options for threads or non-threads
#ifdef THREAD
	  printf(" -t <number>      Set the number of threads      (Default: %8d)\n",
		 MaxThreadsNum);

#else
	  printf(" -w               Enable Weak Reduction strategy (Default: false)\n"
		 );
	  
	  
#endif
	  
	  printf(" -d <Name>=<val>  Bind <val> to <Name>\n"
		 );
	  
	  printf(" -h               Print this help message\n\n");
	  exit(-1);
	  break;
	  
	case 'd':
	  i++;
	  if (i < argc) {
	    char varname[100], val[100];
	    char *tp;
	    tp = strtok(argv[i], "=");
	    snprintf(varname, sizeof(varname)-1, "%s", tp);
	    
	    if ((varname == NULL)
		|| (varname[0] < 'A')
		|| (varname[0] > 'Z')) {
	      puts("ERROR: 'id' in the format 'id=value' must start from a capital letter.");
	      exit(-1);
	    }

	    
	    tp = strtok(NULL, "=");
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
	    printf("ERROR: The option switch '-f' needs a string that specifies an input file name.");
	    exit(-1);
	  }
	  break;
	  
	  
	  
	case 'x':
	  i++;
	  if (i < argc) {
	    param = atoi(argv[i]);
	    if (param == 0) {
	      printf("ERROR: '%s' is illegal parameter for -x\n", argv[i]);
	      exit(-1);
	    }
	  } else {
	    printf("ERROR: The option switch '-x' needs a number as an argument.");
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
	    printf("ERROR: The option switch '-t' needs a number as an argument.");
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
	  printf("Please use -h option for getting more information.\n\n");
	  exit(-1);
	}
      } else {
	printf("ERROR: Unrecognized option %s\n", argv[i]);
	printf("Please use -h option for getting more information.\n\n");
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
      printf("Inpla %s (Weak Strategy) : Interaction nets as a programming language",
	     VERSION);
      printf(" [%s]\n", BUILT_DATE);
    } else {
      printf("Inpla %s : Interaction nets as a programming language",
	     VERSION);
      printf(" [built: %s]\n", BUILT_DATE);
    }
#else
    printf("Inpla %s : Interaction nets as a programming language",
	   VERSION);
    printf(" [built: %s]\n", BUILT_DATE);    
#endif


    
    
    IdTable_init();    
    NameTable_init();
    RuleTable_init();
    
#ifdef THREAD
    //        GlobalEQStack_Init(max_EQStack);
        GlobalEQStack_Init(MaxThreadsNum*1024);
#endif
    
    
    CmEnv_Init(VM_LOCALVAR_SIZE);
    
    
    
#ifndef THREAD
    VM_Init(&VM, max_EQStack);
#else
    tpool_init(max_EQStack);
#endif    
  }
    
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
