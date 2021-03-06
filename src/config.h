// Configurations  ---------------------------------------------------

// To show the computation process:
//#define DEBUG


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

// 
// Optimisation inspired by Tail Recursion Optimisation  
//
#define OPTIMISE_IMCODE_TRO   

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
//#define OPTIMISE_TWO_ADDRESS_UNARY // For Unary operator like INC, DEC
#endif  


#endif
// -------------------------------------------------




#define COUNT_INTERACTION  // Count interaction.


  
  
//#define VERBOSE_NODE_USE  // Put memory usage of agents and names.
//#define VERBOSE_HOOP_EXPANSION  // Put messages when hoops are expanded.
//#define VERBOSE_EQSTACK_EXPANSION  // Put messages when Eqstacks are expanded.
