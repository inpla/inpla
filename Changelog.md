# Changelog

## v0.5.0 (released 28 October 2021)
### New features:
- **Abbreviation notation**: An abbreviation notation `<<` is introduced. The following description:

  ```
  a,b,...,z << Agent(aa,bb,...,yy,zz)
  ```

  is rewritten internally as follows:

  ```
  Agent(a,b,...,z,aa,bb,...,yy) ~ zz
  ```

  For instance, `r << Add(1,2)` is rewritten internally as `Add(r,1)~2`. It is handy to denote ports that take computation results. As a special case we prepare a built-in abbreviation for the built-in agent `Append(a,b)` because the order of those arguments `a`, `b` is different from the abbreviation rewriting rule:

  ```
  ret << Append(a,b)  --- rewritten as ---> Append(ret,b)~a
  ```

- **Merger agent that merges two lists into one**: Merger agent is implemented, such that it has two principal ports for the two lists, and whose interactions are performed as soon as one of the principal ports is ready for the interaction, that is to say, connected to a list. So, the merged result is decided non-deterministically, especially in multi-threaded execution.
  
  ![merger](pic/merger.png)
  
  We overload `<<` in order to use the Merger agent naturally as follows:

  ```
  ret << Merger(alist, blist)
  ```

- **Built-in rules for arithmetic operations between two agents**: These are implemented, and these operations are managed agents `Sub`, `Mul`, `Div`, `Mod`:

  ```
  >>> r1 << Add(3,5), r2 << Sub(r1,2);
  >>> ifce;      // put all interface (living names) and connected nets.
  r2
  
  Connections:
  r2 ->6
  
  >>>
  ```



- ## v0.4.2 (released 16 October 2021)
  ### Improved
  - Line edit was improved to support multi-line paste, according to the following suggestion: https://github.com/antirez/linenoise/issues/43
  - History in Line edit becomes available.

  ### Bug Fix
  - Long length lists are printed out as abbreviation of 14-length lists, though these were printed out as 1-length lists after putting long lists.



## v0.4.1 (released 24 September 2021)

### Improved

- Line edit is improved so that history can be handled by linenoise:
  https://github.com/antirez/linenoise

- The priority of rules are changed so that user defined rules can be taken before built-in rules.

### Bug Fix

- Constants were consumed when they are referred to, but these should be kept and it was fixed as so.

- A global name that has evaluated and occurred twice already was able to be defined. Now it is prevented.

- A global name that has evaluated and occurred twice already was able to be defined. Now it is prevented.



## v0.4.0 (released 17 September 2021)

### New Feature: 

- Nested guards are supported. As shown in below, nested guards are supported now:

  ```
  A(r)><B(int a, int b)
  | a==1 =>
         | b==0 => r~10
         | _    =>
                 | a+b>10 => r~20
  	       | _      => r~2000
  | _ => r~100;
  ```

- Strings that have brackets, such as `inc(x)`, are recognised as agents even if these starts from a not capital letter.


- Built-in rules that match each element for the same built-in agents are implemented. For instance, the following rules are realised as built-in:

  ```
  a:b >< x:y => a~x, b~y;
  [] >< [] =>;
  (a,b) >< (x,y) => a~x, b~y; 
  ```



## v0.3.2 (released 3 August 2021)

### New Feature: 

- WHNF strategy is supported with -w option. Weak Head Normal Form strategy is available when the Inpla is invoked with -w option. The following is an execution log:

  ```
  $ ./inpla -w
  Inpla 0.32 (WHNF) : Interaction nets as a programming language [3 August 2021]
  >>> use "sample/processnet1.in";
  (2 interactions, 0.00 sec)
  >>> ifce;     # show interfaces
  r 
  >>> r;        # show the connected net from the `r'
  [1,<a1>...
  >>> h:t ~ r;  # decompose it as h:t
  (3 interactions, 0.00 sec)
  >>> ifce;
  h t 
  >>> h;
  1
  >>> t;
  [2,<b1>...
  >>> 
  ```

  

## v0.3.1 (released 7 May 2021)

### New Feature: 

- New notation for the built-in Cons agent, h:t. The built-in Cons agent is also written as h:t, besides [h|t]. For instance, a reverse list operation is written as follows:

  ```
  Rev(ret, acc) >< [] => ret ~ acc;
  Rev(ret, acc) >< h:t => Rev(ret, h:acc) ~ t;
  
  Rev(ret,[]) ~ [1,3,5,8];
  ret; // -> [8,5,3,1]
  ```

- The built-in agent for integer numbers is introduced. Integer numbers are recognised as agents. In addition:

  - expressions on attributes are written as agents.
  - `Add(ret, m)><(int n)` is implemented as a built-in rule.

  For instance, Fibonacci number is obtained as follows:

  ```
  Fib(ret) >< (int n)
  | n == 0 => ret~0
  | n == 1 => ret~1
  | _ => Add(ret,cnt2)~cnt1, Fib(cnt1)~(n-1), Fib(cnt2)~(n-2);
  
  Fib(r)~38;
  r; // it should be 39088169.
  ```

  As another example, the greatest common divisor is obtained as follows:

  ```
  Gcd(ret, int a) >< (int b)
  | b==0 => ret~a
  | _ => Gcd(ret, b) ~ (a%b);
  
  Gcd(r, 14) ~ 21;
  r; // it should be 7
  ```

- Append for two lists is implemented as built-in as follows:

  ```
  Append(r,[1,2,3])~[7,8,9];
  r; // it should be [7,8,9,1,2,3]
  ```

  
