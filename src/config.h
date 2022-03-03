// Configurations  ---------------------------------------------------

/* Heaps ------------------------------------------ 
   Choose one among the following three definitions:
   -------------------------------------------------- */
#define FLEX_EXPANDABLE_HEAP     // Inserted heaps size can be flexible.
//#define EXPANDABLE_HEAP        // Expandable heaps for agents and names
//#define FIXED_HEAP             // The heap size is fixed. (Default)


  
/* Optimisation ------------------------------------
   Comment out definitions if not needed.
   ------------------------------------------------- */

// Optimisation inspired by Tail Recursion Optimisation  
#define OPTIMISE_IMCODE_TRO   

  
// Optimisation of the intermediate codes
/*  
   * Assign registers as little as possible with expecting cache works.
   * Copy propagation and Dead code elimination for LOAD are performed.
   * Reg0 is used as a special one that stores results of comparison.
   * Some combinations are rewritten.
     For instance, `SUBI src $1 dest' becomes `DEC src dest'.
*/
#define OPTIMISE_IMCODE    
  

#ifdef OPTIMISE_IMCODE
// Furthermore optimisations for codes:
// the following can work when the OPTIMISE_IMCODE is defined:


// Generate virtual machine codes with two-address notation
#define OPTIMISE_TWO_ADDRESS

#ifdef OPTIMISE_TWO_ADDRESS
#define OPTIMISE_TWO_ADDRESS_MKAGENT1 // For MKAGENT1
#define OPTIMISE_TWO_ADDRESS_MKAGENT2 // For MKAGENT2
#define OPTIMISE_TWO_ADDRESS_MKAGENT3 // For MKAGENT3
//#define OPTIMISE_TWO_ADDRESS_UNARY // For Unary operator like INC, DEC
#endif  


#endif
// END Optimisation configuration --------------


#define COUNT_INTERACTION  // Count interaction.


  
  
//#define VERBOSE_NODE_USE  // Put memory usage of agents and names.
//#define VERBOSE_HOOP_EXPANSION  // Put messages when hoops are expanded.
//#define VERBOSE_EQSTACK_EXPANSION  // Put messages when Eqstacks are expanded.
