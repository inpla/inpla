#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"
#include "id_table.h"


static IdTableT IdTable[IDTABLE_SIZE];

static int NextAgentId, NextGnameId;

void IdTable_init() {

  int i;
  NextAgentId = START_ID_OF_AGENT -1;
  NextGnameId = START_ID_OF_GNAME -1;
  // 0 : ID_INT(used in expressions)
  // 1 .. START_ID_OF_AGENT-1 : built-in agents
  // START_IS_OF_AGENT .. NUM_AGENTS-1: user defined agents
  // NUM_AGENTS(=ID_NAME) .. : names

  for (i=0; i<IDTABLE_SIZE; i++) {
    IdTable[i].arity = -1;
    IdTable[i].name = NULL;
  }

  // built-in agent
  IdTable[ID_TUPLE0].arity = 0;
  IdTable[ID_TUPLE1].arity = 1;
  IdTable[ID_TUPLE2].arity = 2;
  IdTable[ID_TUPLE3].arity = 3;
  IdTable[ID_TUPLE4].arity = 4;
  IdTable[ID_TUPLE5].arity = 5;
  IdTable[ID_NIL].arity = 0;
  IdTable[ID_CONS].arity = 2;
  IdTable[ID_INTAGENT].arity = 1;

  IdTable[ID_APPEND].arity = 2;
  IdTable[ID_MERGER].arity = 1;
  IdTable[ID_MERGER_P].arity = 1;
  IdTable[ID_ADD].arity = 2;
  IdTable[ID_ADD2].arity = 2;
  IdTable[ID_SUB].arity = 2;
  IdTable[ID_SUB2].arity = 2;
  IdTable[ID_MUL].arity = 2;
  IdTable[ID_MUL2].arity = 2;
  IdTable[ID_DIV].arity = 2;
  IdTable[ID_DIV2].arity = 2;
  IdTable[ID_MOD].arity = 2;
  IdTable[ID_MOD2].arity = 2;

  IdTable[ID_INT].name = "int";
  IdTable[ID_TUPLE0].name = "Tuple0";
  IdTable[ID_TUPLE1].name = "Tuple1";
  IdTable[ID_TUPLE2].name = "Tuple2";
  IdTable[ID_TUPLE3].name = "Tuple3";
  IdTable[ID_TUPLE4].name = "Tuple4";
  IdTable[ID_TUPLE5].name = "Tuple5";
  IdTable[ID_NIL].name = "[]";
  IdTable[ID_CONS].name = "Cons";
  IdTable[ID_INTAGENT].name = "Int";
  
  IdTable[ID_APPEND].name = "Append";
  IdTable[ID_MERGER].name = "Merger";
  IdTable[ID_MERGER_P].name = "_MergerP";
  IdTable[ID_ADD].name = "Add";
  IdTable[ID_ADD2].name = "_Add";
  IdTable[ID_SUB].name = "Sub";
  IdTable[ID_SUB2].name = "_Sub";
  IdTable[ID_MUL].name = "Mul";
  IdTable[ID_MUL2].name = "_Mul";
  IdTable[ID_DIV].name = "Div";
  IdTable[ID_DIV2].name = "_Div";
  IdTable[ID_MOD].name = "Mod";
  IdTable[ID_MOD2].name = "_Mod";
}


int IdTable_getid_builtin_funcAgent(Ast *agent) {
  // returns -1 if the agent is not built-in.
  
  int id = -1;

  if (agent->id != AST_AGENT) {
    return -1;
  }
  
  if (strcmp((char *)agent->left->sym, "Add") == 0) {
    id = ID_ADD;      
  } else if (strcmp((char *)agent->left->sym, "Sub") == 0) {
    id = ID_SUB;      
  } else if (strcmp((char *)agent->left->sym, "Mul") == 0) {
    id = ID_MUL;      
  } else if (strcmp((char *)agent->left->sym, "Div") == 0) {
    id = ID_DIV;      
  } else if (strcmp((char *)agent->left->sym, "Mod") == 0) {
    id = ID_MOD;      
  } else if (strcmp((char *)agent->left->sym, "Append") == 0) {
    id = ID_APPEND;      
  } else if (strcmp((char *)agent->left->sym, "Int") == 0) {
    id = ID_INTAGENT;
  } else if (strcmp((char *)agent->left->sym, "Merger") == 0) {
    id = ID_MERGER;
  }

  return id;
}


int IdTable_is_builtin_rule(Ast *agentL, Ast *agentR) {
  //  puts_ast(agentL);
  //  printf(" ");
  //  puts_ast(agentR);
  //  printf("\n");
  
  
  if ( (agentL->id == AST_TUPLE) && (agentR->id == AST_TUPLE) ) {
    // compare these arities
    if (agentL->intval == agentR->intval) {
      return 1;
    }
    return 0;
  }

  int idL = IdTable_getid_builtin_funcAgent(agentL);
  if (agentR->id == AST_INT) {
    if ((idL == ID_ADD) || (idL == ID_SUB) || (idL == ID_MUL)
	|| (idL == ID_DIV) || (idL == ID_MOD)) {
      return 1;
    }
    return 0;
  }

  if (idL == ID_APPEND) {
    if ((agentR->id == AST_CONS) || (agentR->id == AST_NIL)) {
      return 1;
    }
    return 0;
  }

  if (idL == ID_MERGER) {
    if ((agentR->id == AST_TUPLE) && (agentR->intval == 2)) {
      // Merger >< Tuple2
      return 1;
    }
    return 0;
  }


  
  return 0;
}


void IdTable_set_name(int id, char *symname)
{
  if (id > IDTABLE_SIZE) {
    printf("Error: The given id %d was beyond of the size of IdTable (%d)\n",
	   id, IDTABLE_SIZE);
    exit(-1);
  }
  IdTable[id].name = symname;
}


void IdTable_set_arity(int id, int arity)
{
  if ((IdTable[id].arity == -1) || (IdTable[id].arity == arity)) {
    IdTable[id].arity = arity;
  } else {
    printf("Warning: The agent '%s' has been already defined as whose arity is %d, but now used as the arity is %d.\n",  
	   IdTable[id].name, IdTable[id].arity, arity);
    IdTable[id].arity = arity;
  } 
}


char *IdTable_get_name(int id)
{
  return IdTable[id].name;
}

int IdTable_get_arity(int id)
{
  return IdTable[id].arity;
}

int IdTable_new_agentid() {
  NextAgentId++;
  if (NextAgentId > ID_NAME) {
    printf("ERROR: The number of agents exceeded the size of agents in SYMTABLE (%d)\n",
	 ID_NAME);
    exit(-1);
  }
  return(NextAgentId);
}

int IdTable_new_gnameid() {
  NextGnameId++;
  if (NextGnameId < IDTABLE_SIZE) {
    return(NextGnameId);
  } else {
    
    printf("ERROR: The total number of agents and names exceeded the size of names in IDTABLE (%d)\n",
	 IDTABLE_SIZE);
    exit(-1);
  }
}
