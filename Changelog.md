# Change log

### v0.7.3 (released on 20 February 2022)

#### Polished:
* **Bytecode optimisation inspired by Tail Recursive Optimisation**:  As a result, this optimisation brings about faster computation up to about twice in comparison with no reuse-annotated computation.

  * When an interaction rule has a connection whose both sides agents have the same IDs to the active pair, computation of the connection can be realised by applying the same bytecode sequence of the rule to the connection with replacing ports of active pairs into the agent ports of the connection. Moreover, when the connection is placed at the tail of a connection sequence, we can restart the same bytecode sequence after replacing these ports. For instance, take the following rule for Fibonacci number:

    ```
    fib(ret) >< (int n)
    | n == 0 => ret~0
    | n == 1 => ret~1
    | _ => Add(ret, cnt2)~cnt1, fib(cnt1)~(n-1), fib(cnt2)~(n-2);
    ```
    This rule has a connection `fib(cnt2)~(n-2)` at the tail of the third connection sequence. The connection is computable by using the same bytecode sequence of `fib(ret)><(int n)` with replacing these ports `ret`,  `n` into `cnt2`, `n-2`, respectively. So, the computation of the third connection sequence is realised by the instructions of the other connections and the port replacing, and a loop operation to start execution from the top of the rule sequence.

  * This is also possible not only for agents like `(int n)`, but also other constructor agents such as `Cons(x,xs)`, `S(x)`. The following is a part of rules for insertion sort:

    ```
    isort(ret) >< x:xs => insert(ret, x)~cnt, isort(cnt)~xs;
    ```
    When the `xs` connects to an `Cons(y,ys)` agent, then the computation is also realised by the loop operation because the `isort(cnt)~xs` can be regarded as `isort(cnt)~y:ys`, whose agents have the same IDs of the active pair. So, by introducing a conditional branch whether the `xs` connects to a `Cons` agent or not, this rule computation is also realised by the loop operation.
  
  * In this version, this optimisation will be triggered when such the connection is placed at the tail of a sequence of connections.



### v0.7.2-1 (released on 12 February 2022)

#### Bug Fix:
* **Bytecode generation**: A bytecode sequence for `EQI src fixint dest` was generated as `EQI src int dest`, so it was fixed.
* **Bytecode optimisation**:  Blocks for scopes of Copy Propagation optimisation were not specified for each guard expression. It was fixed and works well.




### v0.7.2 (released on 9 February 2022)

#### Polished:
* **Bytecodes for global names**: To obtain a global name whose name is `sym` on a `dest` register, the following bytecode is executed: `MKGNAME dest sym` where the type of `sym` is `char*`.  Every symbol for agents and global names is assigned to the unique ID number managed by `IdTable`, so by introducing the ID number `id` for the `sym`, the bytecode is changed into `MKGNAME id dest`.
* **Separation of source codes of NameTable**: The `NameTable` is used to lookup ID numbers for symbol chars in compilation and interpreter execution. By changing the bytecode of `MKGNAME`, there becomes no need to be used in virtual machine execution directly, so the source codes for the `NameTable` is separated from `src/inpla.y`. This contributes quite a little speed-up at most 1%.



### v0.7.1 (released on 4 February 2022)
#### Polished:
* **Bytecodes**: Bytecodes of virtual machines are expressed by three address codes ordered as `op dest src1 src2`. The order is changed to the ordinary one `op src1 src2 dest`. 

* **Bytecode optimisation**: The following is introduced:

  - A sequence `OP_EQI_RO reg` `OP_JMPEQ0_R0 pc` is optimised into a code `JMPNEQ0 reg pc`.
  - By introducing a bytecode `OP_INC src dest`, a code `OP_ADDI src $1 dest` and a code`OP_ADDI $1 src dest` are optimised into `OP_INC src dest`. 
  - By introducing a bytecode `OP_DEC src dest`, a code `OP_SUBI src $1 dest` is optimised into `OP_DEC src dest`.

* **Intermediate code for blocks**: To show scope of blocks, an intermediate code `OP_BEGIN_BLOCK` is introduced. Copy Propagation for `OP_LOAD` and `OP_LOADI` is performed until the next `OP_BEGIN_BLOCK` occurs.

  

### v0.7.0 (released on 30 January 2022)
#### New Features:
* **Logical operators on integers**: Not `!` (`not`), And `&&` (`and`)  and Or `||` (`or`) are available.  Only `0` is regarded as False and these operators return `1` for Truth, `0` for False.

* **Bytecode optimisations**: Bytecodes are optimised by Copy propagation, Dead code elimination methods. In addition, Register0 is used to store comparison results, and conditional branches are performed according to the value of Register0. To prevent those optimisation, comment out the following definition `OPTIMISE_IMCODE` in `src/inpla.y`:

  ```
  #define OPTIMISE_IMCODE    // Optimise the intermediate codes
  ```

  

### v0.6.2 (released on 20 January 2022)
#### New Features:
* **Retaining the big ring buffer**:  The new expandable buffer for agents and names require extra costs sometimes, so the old one, that is the big ring buffer, is embedded into programs sources. Comment out the following definition `EXPANDABLE_HEAP` in `src/inpla.y` when the old one is needed:

  ```
  #define EXPANDABLE_HEAP    // Expandable heaps for agents and names
  ```

  


### v0.6.1 (released on 12 January 2022)
#### New Features:
* **Introduced automatically expandable equation stacks**: Stacks for equations are automatically expanded when the stacks overflow. The unit size is 256, so each stack size in virtual machines starts from 256, and these will be twice (256), triple (768) and so on. The unit size is specified by the execution option `-e`. For instance, Inpla invoked with `-e 1024` assigns a 1024-size equation stack for each thread. As for the global equation stack, it is also automatically expandable, but the initial size is specified as `(the number of threads) * 8` in the `main` function as follows, so change it to improve the execution performance if it is needed:

  ```
  GlobalEQStack_Init(MaxThreadsNum*8);
  ```

  


### v0.6.0 (released on 9 January 2022)

#### New Features:
* **Introduced new data structure for ring buffers for agents and names**: The ring buffers are automatically expanded when all elements of these are used up. Each size starts from 2^18 (=262144), and it will be twice, triple and so on automatically. To adjust the unit size, change the following definition in `src/inpla.y`:

  ```
  #define HOOP_SIZE (1 << 18)
  ```

* **Deleted the execution option `-c` that specifies the size of these ring buffers**: This execution option is deleted because these buffers are expanded as needed.



### v0.5.6 (released on 6 January 2022)
#### Bug Fix:
* The index of the ring buffer for agents had not been correctly initialised. It was fixed the same as the way of the ring buffer for  names.



### Logo of Inpla (released on 27 December 2021)
* A logo is released as an idea:

  ![inpla-logo](pic/inpla-logo.png)





### v0.5.5 (released on 19 December 2021)
#### Bug Fix (minor):
* The name `x` in a connection `x~s` should be substituted if the `x` occurs on a term in other connections, but it should be done if the `x` is specified by `int` modification. But every name had been a target of the substitution, so it was fixed.



### v0.5.4 (released on 18 November 2021)
#### Bug Fix (minor):
* When there is a connection `x~s` in nets or rules, the other occurrence of the name `x` will be replaced with the `s`, as one of optimisations. It had been done only when the other is just a name, that is, not a subterm, so it was fixed now.



### v0.5.3 (released on 14 November 2021)
#### New Features (for constants):
* Constants are also specified by an execution option switch `-d` in the format *NAME*=*i*. For instance, when Inpla is invoked with `-d ELEM=1000`, then the `ELEM` is replaced with `1000` during the execution.

* Constants are defined as immutable, so these values cannot be changed. When a file specified by the `-f` option has constant names specified by the `-d` options, these names are bound to the values given by the `-d` options.



### v0.5.2 (released on 10 November 2021)
#### Bug Fix (minor):
* `Free` command did not work for integer numbers, due to the change by v0.5.1, and it was fixed.



### v0.5.1 (released on 2 November 2021)
#### Bug Fix:
* Terms in which the same name occurs twice, such as `A(x,x)`, can be freed safely by the `free` command.



### v0.5.0 (released on 28 October 2021)
#### New Features:
* **Abbreviation notation**: An abbreviation notation `<<` is introduced. The following description:

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

* **Merger agent that merges two lists into one**: Merger agent is implemented, such that it has two principal ports for the two lists, and whose interactions are performed as soon as one of the principal ports is ready for the interaction, that is to say, connected to a list. So, the merged result is decided non-deterministically, especially in multi-threaded execution.
  
  ![merger](pic/merger.png)
  
  We overload `<<` in order to use the Merger agent naturally as follows:

  ```
  ret << Merger(alist, blist)
  ```

* **Built-in rules for arithmetic operations between two agents**: These are implemented, and these operations are managed agents `Sub`, `Mul`, `Div`, `Mod`:

  ```
  >>> r1 << Add(3,5), r2 << Sub(r1,2);
  >>> ifce;      // put all interface (living names) and connected nets.
  r2
  
  Connections:
  r2 ->6
  
  >>>
  ```


### v0.4.2 (released on 16 October 2021)
#### Improved:
* Line edit was improved to support multi-line paste, according to the following suggestion: https://github.com/antirez/linenoise/issues/43
* History in Line edit becomes available.

#### Bug Fix:
* Long length lists are printed out as abbreviation of 14-length lists.



### v0.4.1 (released on 24 September 2021)
#### Improved:
* Line edit is improved so that history can be handled by linenoise:
  https://github.com/antirez/linenoise

* The priority of rules are changed so that user defined rules can be taken before built-in rules.

#### Bug Fix:
* Constants, which cannot be deleted, had been deleted when they are referred to. It was fixed to be kept.



### v0.4.0 (released on 17 September 2021)
#### New Features: 
* Nested guards are supported. As shown in below, nested guards are supported now:

  ```
  A(r)><B(int a, int b)
  | a==1 =>
         | b==0 => r~10
         | _    =>
                 | a+b>10 => r~20
  	       | _      => r~2000
  | _ => r~100;
  ```

* Strings that have brackets, such as `inc(x)`, are recognised as agents even if these starts from a not capital letter.


* Built-in rules that match each element for the same built-in agents are implemented. For instance, the following rules are realised as built-in:

  ```
  a:b >< x:y => a~x, b~y;
  [] >< [] =>;
  (a,b) >< (x,y) => a~x, b~y; 
  ```



### v0.3.2 (released on 3 August 2021)
#### New Features: 
* WHNF strategy is supported with -w option. Weak Head Normal Form strategy is available when the Inpla is invoked with -w option. The following is an execution log:

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

  

### v0.3.1 (released on 7 May 2021)
#### New Features: 
* New notation for the built-in `Cons` agent, `h:t`. The built-in Cons agent is also written as `h:t`, besides `[h|t]`. For instance, a reverse list operation is written as follows:

  ```
  Rev(ret, acc) >< [] => ret ~ acc;
  Rev(ret, acc) >< h:t => Rev(ret, h:acc) ~ t;
  
  Rev(ret,[]) ~ [1,3,5,8];
  ret; // -> [8,5,3,1]
  ```

* The built-in agent for integer numbers is introduced. Integer numbers are recognised as agents. In addition:

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

* Append for two lists is implemented as built-in as follows:

  ```
  Append(r,[1,2,3])~[7,8,9];
  r; // it should be [7,8,9,1,2,3]
  ```

  
