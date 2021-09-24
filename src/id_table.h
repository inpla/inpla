#ifndef _ID_TABLE_
#define _ID_TABLE_


// When NUM_AGENT is 256:
// 0 .. 255: AGENT
// 256     : NAME,
// 257 ..  : GNAME


#define ID_INT 0

// builtin を加えたら void IdTable_init() 内で
// IdTable に arity と 表示方法の登録を忘れないように！
#define ID_TUPLE0 1
#define ID_TUPLE1 2
#define ID_TUPLE2 3
#define ID_TUPLE3 4
#define ID_TUPLE4 5
#define ID_TUPLE5 6
#define GET_TUPLEID(arity) (ID_TUPLE0+arity)
#define IS_TUPLEID(id) ((id >= ID_TUPLE0) && (id <= ID_TUPLE5))
#define GET_TUPLEARITY(id) (id - ID_TUPLE0)

#define ID_NIL 7
#define ID_CONS 8
#define IS_LISTID(id) ((id == ID_NIL) && (id == ID_CONS))

#define ID_INTAGENT 9

#define START_ID_OF_BUILTIN_AGENT 10
#define ID_ADD  10
#define ID_ADD2 11
#define ID_APPEND  12
#define ID_APPEND2 13
#define END_ID_OF_BUILTIN_AGENT 13

 
#define START_ID_OF_AGENT 20
//#define NUM_AGENTS 1024
#define END_ID_OF_AGENT 255
#define NUM_AGENTS END_ID_OF_AGENT+1  // 256

#define ID_NAME NUM_AGENTS // 256
#define START_ID_OF_GNAME  ID_NAME+1
#define IS_AGENTID(a) (a < ID_NAME)
#define IS_NAMEID(a) (a >= ID_NAME)
#define IS_GNAMEID(a) (a > ID_NAME)
#define IS_LOCAL_NAMEID(a) (a == ID_NAME)
#define IS_BUILTIN_AGENTID(a) (a <= END_ID_OF_BUILTIN_AGENT)
#define SET_LOCAL_NAMEID(a) (a = ID_NAME)

/**************************************
 TABLE for SYMBOLS
**************************************/
typedef struct {
  char *name;
  int arity;
} IdTableT;

#define IDTABLE_SIZE  (NUM_AGENTS)*2 // AGENT + NAME

void IdTable_init();
void IdTable_set_name(int id, char *symname);
void IdTable_set_arity(int id, int arity);
char *IdTable_get_name(int id);
int IdTable_get_arity(int id);
int IdTable_new_agentid();
int IdTable_new_gnameid();

int IdTable_getid_builtin_funcAgent(Ast *agent);
int IdTable_is_builtin_rule(Ast *agentL, Ast *agentR);


#endif
