// Configurations  ---------------------------------------------------

// ------------------------------------------------
// Number of Agent Ports 
// ------------------------------------------------
// MAX_PORT defines a number of ports of agents.
// Default is 5 and should be 2 or more.

#define MAX_PORT 5



// ------------------------------------------------
// Heaps 
// ------------------------------------------------
// There are three methods for agents and names heaps:
//   - Fixed-size ring buffers (default)
//       The size is specified by an execution option -c
//
//   - Expandable ring buffers
//       Automatically new buffers are inserted when all are run up.
//
//   - Ring buffers whose Initial size and newly inserted size
//     are flexibly changed.
//       The initial size and the expansion magnification are
//       specified by execution options -Xms, -Xmt, respectively.
//
// Choose one among the following three definitions with uncomment.


//#define FIXED_HEAP
//#define EXPANDABLE_HEAP
#define FLEX_EXPANDABLE_HEAP


//
// For the expandable ring buffer, the unit size HOOP_SIZE can be changed.
// We note that HOOP_SIZE must be two to power.
//
#ifdef EXPANDABLE_HEAP
//#define HOOP_SIZE (1 << 12)    // good for small heaps such as fib
#define HOOP_SIZE (1 << 18)      // good for large heaps such as msort-80000
#endif





// ------------------------------------------------
// RuleTable
// ------------------------------------------------
// There are two implementation for the rule table:
//   - Hashed linear table (default)
//   - Simple array table
// To use the hashed one, comment out the following RULETABLE_SIMPLE definition.

//#define RULETABLE_SIMPLE





  
// ------------------------------------------------
// Optimisation
// ------------------------------------------------
// Comment out definitions if not needed.

// Use MKAGENTn codes
//#define USE_MKAGENT_N


// Optimisation inspired by Tail Call Optimisation  
//
#define OPTIMISE_IMCODE_TCO   

//  
// Optimisation of the intermediate codes
//
//  
//   - Assign registers as little as possible with expecting cache works.
//   - Copy propagation and Dead code elimination for LOAD are performed.
//   - Reg0 is used as a special one that stores results of comparison.
//   - Some combinations are rewritten.
//     For instance, `SUBI src $1 dest' becomes `DEC src dest'.
//
#define OPTIMISE_IMCODE    
  

#ifdef OPTIMISE_IMCODE
// Furthermore optimisations on virtual machine codes:
// the following can work when the OPTIMISE_IMCODE is defined:

//
// Generate virtual machine codes with two-address notation
//
#define OPTIMISE_TWO_ADDRESS

#ifdef OPTIMISE_TWO_ADDRESS
#define OPTIMISE_TWO_ADDRESS_MKAGENT1 // For MKAGENT1
#define OPTIMISE_TWO_ADDRESS_MKAGENT2 // For MKAGENT2
#define OPTIMISE_TWO_ADDRESS_MKAGENT3 // For MKAGENT3
#define OPTIMISE_TWO_ADDRESS_MKAGENT4 // For MKAGENT4

//#define OPTIMISE_TWO_ADDRESS_UNARY // For Unary operator like INC, DEC
                                     // (Unfinished)
#endif  


#endif
// -------------------------------------------------


// ------------------------------------------------
// For developers
// ------------------------------------------------
//#define DEBUG             // Show the computation process.
//#define DEBUG_MKRULE      // Show compiled codes for rules.
//#define DEBUG_NETS        // Show compiled codes for nets.
//#define DEBUG_EXPR_COMPILE_ERROR // Show AST of an expression
                                     // comes with compile errors.

//#define OLD_REUSEAGENT    // Use the old mechanism to reuse agents.
                            // Thus, `REUSEAGENTn' is used
                            // instead of `CHID_L`, `LOADP_L` and so on.



//#define VERBOSE_NODE_USE  // Put memory usage of agents and names.
//#define VERBOSE_HOOP_EXPANSION  // Put messages when hoops are expanded.
//#define VERBOSE_EQSTACK_EXPANSION  // Put messages when Eqstacks are expanded.
//#define VERBOSE_TCO                // Put message when TCO is enable.






#define COUNT_INTERACTION  // Count the amount of interactions.

