#ifndef _ID_TABLE_
#define _ID_TABLE_
#include "ast.h"
#include "mytype.h"

// When NUM_AGENT is 256:
// 0 .. 255: AGENT
// 256     : NAME,
// 257 ..  : GNAME


#define ID_INT       0


// NOTE:
// For a NEW BUILT-IN AGENT,
// STORE the ARITY on IdTable in the function IdTable_init()!
#define ID_TUPLE0    1
#define ID_TUPLE1    2
#define ID_TUPLE2    3
#define ID_TUPLE3    4
#define ID_TUPLE4    5
#define ID_TUPLE5    6
#define GET_TUPLEID(arity) (ID_TUPLE0+arity)
#define IS_TUPLEID(id) ((id >= ID_TUPLE0) && (id <= ID_TUPLE5))
#define GET_TUPLEARITY(id) (id - ID_TUPLE0)

#define ID_NIL       7
#define ID_CONS      8
#define IS_LISTID(id) ((id == ID_NIL) && (id == ID_CONS))

#define ID_WILDCARD  9

#define ID_INTAGENT 10   // This is an experimental dummy agent
                         // to show the use effect of Int agent.
#define START_ID_OF_BUILTIN_CONSTRUCTOR_AGENT 10


#define START_ID_OF_BUILTIN_OP_AGENT 15
#define ID_APPEND   15
#define ID_ZIP      16
#define ID_ZIPC     17
#define ID_MERGER   18
#define ID_MERGER_P 19
#define ID_ADD      20
#define ID_ADD2     21
#define ID_SUB      22
#define ID_SUB2     23
#define ID_MUL      24
#define ID_MUL2     25
#define ID_DIV      26
#define ID_DIV2     27
#define ID_MOD      28
#define ID_MOD2     29
#define ID_PERCENT  30
#define ID_MAP      31
#define END_ID_OF_BUILTIN_OP_AGENT 31

// ID_ERASER and ID_DUP were put as 254, 255
// because these IDs are wanted larger like ID_DUP > any_agent.id


#define START_ID_OF_USER_AGENT END_ID_OF_BUILTIN_OP_AGENT+1
#define END_ID_OF_AGENT 255

#define END_ID_OF_USER_AGENT END_ID_OF_AGENT-2
#define ID_ERASER END_ID_OF_AGENT-1
#define ID_DUP END_ID_OF_AGENT


#define NUM_AGENTS END_ID_OF_AGENT+1  // 256

#define ID_NAME NUM_AGENTS // starts from 256 (NUM_AGENTS)
#define START_ID_OF_GNAME  ID_NAME+1


#define NUM_GNAMES NUM_AGENTS // 256: the same as the size of AGENT


//#define IS_AGENTID(a) (a <= ID_END_ID_OF_AGENT)
#define IS_AGENTID(a) (!(a & 0x100)) // less than 256


#define IS_NAMEID(a) ((a) >= ID_NAME)
#define IS_GNAMEID(a) ((a) > ID_NAME)
#define IS_LOCAL_NAMEID(a) ((a) == ID_NAME)
//#define IS_BUILTIN_AGENTID(a) (a <= END_ID_OF_BUILTIN_AGENT)
#define SET_LOCAL_NAMEID(a) ((a) = ID_NAME)

/**************************************
 TABLE for SYMBOLS
**************************************/
typedef struct {
  char *name;
  union {
    int arity;
    VALUE heap;
  } aux;
} IdTableT;


#define IDTABLE_SIZE  (NUM_AGENTS + NUM_GNAMES) // AGENT + GNAME

void IdTable_init();

void IdTable_set_name(int id, char *symname);
char *IdTable_get_name(int id);

void IdTable_set_arity(int id, int arity);
int IdTable_get_arity(int id);

void IdTable_set_heap(int id, VALUE heap);
VALUE IdTable_get_heap(int id);


int IdTable_new_agentid();
int IdTable_new_gnameid();

int IdTable_getid_builtin_funcAgent(Ast *agent);


#endif
