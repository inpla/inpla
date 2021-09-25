# Inpla: Interaction nets as a programming language



## What is Inpla

Inpla is a multi-threaded parallel interpreter of interaction nets. Once you write programs for sequential execution, it works also in multi-threaded parallel execution. Each thread is managed on each CPU-core with POSIX-thread library.

![speedup-ratio](pic/benchmark_reuse.png)


### Feature of Version 0.4.1
- Integer numbers can be written the same as one of the first-class objects.
- Interaction rules can re-allocate heaps of the rule agents to agents in nets. This re-allocation is specified by modifications such as (\*L), (\*R), called reuse annotation [1], to agents in nets. This re-allocation can improve execution performance in parallel.
- Wead Head Normal Form reduction strategy is supported. It turns on by invoked with ```-w``` option.
- Nested guards in conditional rules are supporeted.
- Comparison with other interpreters: Standard ML v110.74 (SML) and Python v3.8.5 (Python) in execution time. (We are planing to have benchmark of Haskell, C, as well in future.)
  - Execution time in second  (Linux PC, Core i7-9700 (8 threads, no Hyper-threading), 16GB memory).
  - Inpla*n*  and Inpla*n*_**r** mean *n* threads without/with reuse-annotated execution, respectively. 
  - `ack(3,6)` is computation of Ackermann function with (3,6), though its execution time is too short. Python cannot  calculate the case of (3,7) due to stack size limitation, so anyway we include it in the comparison table.

|        | SML | Python | Inpla1 | Inpla1_r | Inpla3 | Inpla3_r | Inpla7 | Inpla7_r |
| ---    | :-: | :-:    | :-:     | :-:     | :-:    | :-:     | :-:   | :-:     |
|ack(3,6)  (too short)|0.05|0.04|0.11|0.11|0.11|0.11|0.11|0.11|
|ack(3,11)|**0.41**|-|4.76|4.36|1.65|1.49|0.98|0.88|
|fibonacci 38|**0.26**|8.49|3.59|3.56|1.24|1.23|0.56|0.54|
|bsort 40000|11.17|76.72| 22.85  | 18.40   | 8.07   | 6.34    | 5.53   | **2.94** |
|isort 40000|2.97|36.63| 10.59  | 8.74    | 3.91   | 3.04    | 2.59   | **1.43** |
|qsort 800000|1.16|97.30| 1.85   | 1.55    | 0.84   | 0.65    | 0.76   | **0.41** |
|msort 800000|1.00|98.27| 1.18   | 1.34    | 0.61   | 0.57    | 0.65   | **0.49** |



## Getting started
- Requirement  
  - gcc (>= 4.0), flex, bison

- Build  
  - Single-thread version: Use `make` command as follows (the symbol `$` means a shell prompt):
```
$ make
```

  - Multi-thread version: Use `make` with `thread` option (it may also need `make clear` before that):  
```
$ make thread
```



## How to execute

### Interactive mode (single-thread version)
- Inpla starts in the interactive mode by typing the following command:
	
	```
	$ ./inpla
	Inpla 0.4.1 : Interaction nets as a programming language [built: 21 Sept. 2021]
	>>> 
	```


- The symbol `>>>` is a prompt of this system. After the prompt you can write rules and nets as follows (`//` is a comment):

  ```
  >>> inc(ret)><(int i) => ret~(i+1);   // a rule for inc >< (int i)
  >>> inc(r)~10;                        // a net
  (1 interactions, 0.16 sec)
  >>> r;                                // show a connected net from the r
  11
  >>> 
  ```

- To quit this system, use `exit` command:

  ```
  >>> exit;
  ```

### Interactive mode (multi-thread version)
- There is an execution option `-t` in order to specify the number of threads in a thread pool. For instance, by invoking with `-t 4` Inpla starts with 4 threads in the pool:

  ```
  $ ./inpla -t 4
  ```



### Batch mode and sample files

- Inpla has also the batch mode in which a file is evaluated. This is available when invoked with an execution option `-f`  *filename*. There are sample files in the `sample` folder. Here we introduce some of ones:

#### Greatest common divisor

  - Sample file: `sample/gcd.in`

    ```
    // def gcd(a: Int, b: Int): Int =
    //   if (b==0) a else gcd(b, a%b)
    
    // Rules
    gcd(ret) >< (int a, int b)
    | b==0 => ret ~ a
    | _ => gcd(ret) ~ (b, a%b);
    
    // Nets
    gcd(r) ~ (14,21);
    r; // it should be 7
    ```

  - Execution:

    ```
    $ ./inpla -f sample/gcd.in
    Inpla 0.4.1 : Interaction nets as a programming language [built: 21 Sept. 2021]
    (4 interactions, 0.00 sec)
    7
    
    $
    ```

  

#### Insertion sort

  - Sample file: `sample/isort.in`

    ```
    // Rules
    isort(ret) >< [] => ret~[];
    isort(ret) >< x:xs => insert(ret, x)~cnt, isort(cnt)~xs;
    
    insert(ret, int x) >< [] => ret~[x];
    insert(ret, int x) >< (int y):ys
    | x<=y => ret~(x:y:ys)
    | _    => ret~(y:cnt), insert(cnt, x)~ys;
    
    // Nets
    isort(r)~[3,6,1,9,2];
    r;
    ```

  - Execution:

    ```
    $ ./inpla -f sample/isort.in
    Inpla 0.4.1 : Interaction nets as a programming language [built: 21 Sept. 2021]
    (16 interactions, 0.00 sec)
    [1,2,3,6,9]
    
    $
    ```


#### Other samples
- Evaluation of a lambda term `245II` in [YALE encoding](http://dl.acm.org/citation.cfm?id=289434), where `2 4 5` mean church numbers of lambda terms respectively and  `I` is a lambda term $\lambda x.x$:
  
      $ ./inpla -f sample/245II.in


- Samples of linear systemT encoding (see [our paper](http://link.springer.com/chapter/10.1007%2F978-3-319-29604-3_6) presented at [FLOPS 2016](http://www.info.kochi-tech.ac.jp/FLOPS2016/)).
  
      $ ./inpla -f sample/linear-systemT.in
  
  

### Execution Options

- When invoking Inpla, you can specify the following options:
```
$ ./inpla -h
Usage: inpla [options]

Options:
 -f <filename>    Set input file name          (Defalut is    STDIN)
 -c <number>      Set the size of term cells   (Defalut is   100000)
 -x <number>      Set the size of the AP stack (Default is    10000)
 -t <number>      Set the number of threads    (Default is        1)
 -w               Enable Weak Head Normal Form strategy (Default: false)
 -h               Print this help message
```
(The option ```-t``` is available for the multi-thread version that is compiled by ```make thread```.)





# Introduction to programming in Inpla
Inpla evaluates *nets*, which are built by *connections between terms*. First, we learn about terms and connections.

## Terms
**Terms** are built on *names* and *agents* as follows:

```
<term> ::= <name> | <agent>
<name> ::= <nameID>
<agent> ::= <agentID>
          | <agentID> [( <term> , ... , <term> )]     
```
- **Name**: It works a buffer between terms. The ```<nameID>``` is defined as strings start with a small letter, e.g. ```x``` and ```y```. 

- **Agent**: It works constructors and de-constructors (defined functions). The ```<agentID>``` is defined as strings start with a capital letter, e.g. ```A``` and ```Succ```, and also strings the same as  ```<nameID>``` when it is followed by a open curry bracket```(```. So, ```foo(x)``` is recognised as an agent.



## Connections

A **connection** is a relation between two terms, and it is expressed with the symbol `~`. For instance, a connection between a name `x` and an agent `A` is denoted as `x~A`. 

- Connections between a name and an agent, such as `x~A`, evaluated that the `A` is connected from the `x`.   
- Connections between agents are evaluated according to `interaction rules` explained later. 

Here, as an example, type `x~A` with the termination symbol `;` as follows:

```
>>> x~A;
(0 interactions, 0.00 sec)
>>>
```

To show the connected terms from the name x, type just `x`:  
```
>>> x;
A
>>>
```

To dispose the name `x` and anything connceted from the `x`, use `free` command:
```
>>> free x;
>>> x;
<NON-DEFINED>
>>>
```

One more connections are also evaluated. For instance, `x~A, x~y` is evaluated as `y~A`. **We note** that the `x` is disposed because it is consumed (used) by this re-connection:
```
>>> x~A, x~y;
(0 interactions, 0.00 sec)
>>> y;
A
>>> x;        // x has been consumed and displosed by the re-connection of x~A and x~y.
<NON-DEFINED>
>>>
```

Just in case for other examples, let the `y` disposed:

```
>>> free y;
>>> y;
<NON-DEFINED>
>>>
```



## Interaction rules

Connections between agents are re-written according to **interaction rules**:

```
<interaction-rule> ::= <rule-agent> >< <rule-agent> => <connections> ;
<rule-agent> ::= <agentID>
               | <agentID> ( <name>, ... , <name> )
```
  where

  - each name of the ```<name>``` must be **distinct**, and must **occur once** in the ```<connections>```.

Something complicated? No problem! Let's us learn how to define the rules with some example!

### Example: Operations on unary natural numbers.

Unary natural numbers are built by Z and S. For instance, 0, 1, 2, 3 are expressed as Z, S(Z), S(S(Z)), S(S(S(Z))). Here, let's think about an increment operation `inc` such that inc(n) = S(n). This is written as rules for Z and S(x) as follows:

```
>>> inc(result) >< Z => result~S(Z);
>>> inc(result) >< S(x) => result~S(S(x));
```

In the first rule, the name `result` occurs in its `<connection>` part once, so it satisfies the rule proviso. In the second rule, the `result` and `x` satisfies also because these are distinct and occur once in its `<connections>` part. 

When agents can be separated into constructors and de-constructors, then it could be good to use strings of all small letters for de-constructors like `inc` , and ones start from a capital letter for constructors like `Z` and `S`.

Let's have a result of the increment operation for `S(S(Z))`:

```
>>> inc(r)~S(S(Z));
(1 interactions, 0.01 sec)
>>> r;
S(S(S(Z))
>>>
```

Good! We get the result  `S(S(S(Z)))` of incrementation of  `S(S(Z))` .

To show the result as a natural number, use `prnat` command:

```
>>> prnat result;
3
>>>
```

Let's clean the result in case it could be used anywhere:

```
>>> free r;
>>>
```

- Exercise: Addition on unary natural numbers.

  It is defined recursively as follows:

  - add(x, Z) = x,  
  - add(x, S(y)) = add(S(x), y),

We note that `Add` is already used as a built-in rule, so use `add`.

```
>>> add(result, x) >< Z => result~x;
>>> add(result, x) >< S(y) => add(result, S(x))~y;
>>> add(r,S(Z))~S(S(Z));
(3 interactions, 0.00 sec)
>>> r;
S(S(S(Z)))
>>> prnat result;
3
>>> free r;
>>>
```



## Built-in agents
Inpla has built-in agents:

### Tuples

- `Tuple0`,  `Tuple2(x1,x2)`,  `Tuple3(x1,x2,x2)`,  `Tuple4(x1,x2,x3,x4)`,  `Tuple5(x1,x2,x3,x4,x5)`, 
  are written as  
  `()`,  `(x1,x2)`,  `(x1,x2,x3)`, `(x1,x2,x3,x4)`, `(x1,x2,x3,x4,x5)`.
  
- There is no Tuple1, and so `(x)` is evaluated as just `x`.


### Lists

- `Nil`, `Cons(x,xs)`  
  are written as  
  `[]` and `x:xs`, respectively. 
- A nested `Cons` that terminated at `Nil` is written as a list notation using brackets `[` and `]`.  For instance,  
  `x1 : x2: x3 : Nil`  
  is written as  
  `[x1,x2,x3]` .  



### Built-in rules for tuples and lists

For pairs of the same built-in agents there are built-in rules that match and connect each element such that:

```
(x1,x2)><(y1,y2) => x1~y1, x2~y2 // This is already defined as a built-in rule.
```

With respect to lists, we also have a built-in agent `Append` to append two lists as shown in the following pseudo code:

```
Append(r, alist) ~ blist --> r~ (blist @ alist)  // pseudo code
```

- The following is an example of built-in agents:

```
>>> x~(Z, S(Z));
(0 interactions, 0.00 sec)
>>> (x1,x2)~x;
>>> x1 x2;
Z S(Z)
>>> y~[Z, S(Z), S(S(Z))];
(0 interactions, 0.00 sec)
>>> [y1, y2, y3]~y;
>>> y1 y2 y3;
Z S(Z) S(S(Z))
>>> Append(r, [Z, S(Z)]) ~ [A,B,C];
>>> r;
[A,B,C,Z,S(Z)]
>>> free x1 x2 y1 y2 y3 r;
>>>
```



## Attributes (integers)

Agents can have integers as arguments. These integers are called attributes. 

- For instance, `A(100)` is evaluated as an agent `A` that holds an attribute of an integer 100.

```
>>> x~A(100);
(0 interactions, 0.01 sec)
>>> x;
A(100);
>>> free x;
>>>
```
It is possible to use integers the same as agents, but these are recognised as attributes of an anonymous built-in agent in Inpla:
```
>>> x~100;
(0 interactions, 0.00 sec)
>>> x;
100
>>> free x;
>>>
```



### Arithmetic expressions on attributes
Attributes can be given as the results of arithmetic operation using `where` statement after connections:  

```
<connections-with-expressions> ::= 
                         <connections> 
                       | <connections> where <let-clause>* ;
                       
<let-clause> ::= <name> = <arithmetic expression>
```

The symbol of addition, subtraction, multiplication, division and modulo are `+`, `-`, `*`, `/` and `%`, respectively.

- For instance, the following is an expression using `where`:

```
>>> x~A(a) where a=3+5;
(0 interactions, 0.00 sec)
>>> x;
A(8)
>>> free x;
>>>
```

- Arithmetic expressions can be written in arguments directly without using `where`:

```
>>> x~A(3+5);
(0 interactions, 0.00 sec)
>>> x;
A(8)
>>> free x;
>>>
```

- Arithmetic expressions are also available for the anonymous agent:

```
>>> x~(3+5);  // this is also written without brackets as x~3+5;
(0 interactions, 0.00 sec)
>>> x;
8
>>> free x;
>>>
```



### Interaction rules with expressions on attributes
In interaction rules, attributes can be managed by using a modifier `int`. 
- Example: Incrementor on an attribute:
```
>>> inc(result) >< (int a) => result~(a+1);
>>> inc(r)~10;
(1 interactions, 0.00 sec)
>>> r;
11
>>> free r;
>>>
```



### Built-in rules of attributes in the anonymous agents

There is a built-in rule for attributes on the two anonymous agents. This could be required to calculate attributes obtained as evaluation results of two nets. In this version, we have the following rules as built-in:

```
Add(result, y)><(int x) => Addn(result, x)~y;
Addn(result, int x)><(int y) => result~(x+y);
```

- Example:

```
>>> Add(r, 3)~5;   // Add is already defined as a bulit-in
>>> r;
8
>>>
```




### Interaction rules with conditions on attributes
In interaction rules, conditional rewritings on attributes are available. The following is a general form:  

```
<rule-with-conditions> ::= 
  <agent> '><' <agent>
  '|' <condition-on-attributes> '=>' <connections-with-expressions>
  '|' <condition-on-attributes> '=>' <connections-with-expressions>
      ...  
  '|' '_'  '=>' <connections-with-expressions> ';'
  
<condition-on-attributes> is an expression on attributes specified in the two <agent>.
```

The sequence of `<condition-on-attributes> ` must be finished with the otherwise case `_`.

- Example: The following shows rules to obtain a list that contains only even numbers:
```
// Rules (because it is long definition, so copy and paste is recommended)
evenList(result) >< [] => r~[];
evenList(result) >< (int x):xs
| x%2==0 => result~(x:r1), evenList(r1)~xs
| _      => evenList(result)~xs;
```

```
>>> evenList(r)~[1,3,7,5,3,4,9,10];
>>> r;
[4,10]
>>> free r;
>>>
```

- Example: Fibonacci number:
```
fib(result) >< (int n)
| n == 0 => result~0
| n == 1 => result~1
| _ => fib(r1)~(n-1), fib(r2)~(n-1), Add(result, r2)~r1;

// * We cannot write result~(r1+r2)
// because r1 and r2 are not recognised as attributes.
// Therefore, we have to apply those to the built-in rule Add(r, int x)><(int y).
```

```
>>> fib(r)~39;
>>> r;
63245986
>>> free r;
>>>
```



## Commands

- Inpla has the following commands:
  - `free` *name_1* ... *name_n* `;`     
  Terms connected from the *name_1* ... *name_n* and itself are disposed.
  - *name_1* ... *name_n* `;`  
  Put terms connected from the *name_1* ... *name_n*.
  - `prnat`*name*`;`    
  Put a term connected from the *name* as a natural number.
  - `use` `"`filename`";`  
  Read the file named as "filename". 
  - `ifce;`       
  Put all live names and connections from these name. The living name list is called *interface*, and the `ifce` is an abbreviation of Interface.
  - `exit;`            
  Quit the system.

- Inpla has the following macro:
  - `const` *NAME*`=` *i* `;`  
    The *NAME*  is replaced with the integer value *i* in nets and interaction rules.



## Extensions in Version 0.4

### Reuse annotations

In interaction rule definitions, we can specify which agent is reused in the nets again by annotations `(*L)` and `(*R)`,  which means the left-hand side and the right-hand side agents in the rule. This annotations promote in-place computing, and as the result performance in parallel execution can be improved well.

- For instance, in the rule `gcd(ret) >< (int a, int b)`, we can reuse the `gcd` and `Tuple2` in nets as follows:

  ```
  gcd(ret) >< (int a, int b)
  | b==0 => ret ~ a
  | _ => (*L)gcd(ret) ~ (*R)(b, a%b);
  ```



### Weak Head Normal Form reduction strategy

In this reduction strategy, only connections that have living names are re-written by interaction rules. This is taken for non-terminate computation such as fixed point combinator and process networks.

- Example: We have a sample net in `sample/processnet1.in` that keep producing natural numbers from 1 and output these to the port `r`:

  ```
  // Rules
  dup(a1,a2) >< (int i):xs => a1~(i:xs1), a2~(i:xs2), dup(xs1,xs2)~xs;
  dup(a1,a2) >< []         => a1~[], a2~[];
  
  inc(r) >< (int i):xs => r~(i+1):w, inc(w)~xs;
  inc(r) >< []         => r~[];
  
  // Nets
  dup(r,w)~r1, inc(r1) ~ 0:w;
  
  //       +-----+       +-----+        +---+
  // r ----|     |  r1   |     |        |   |
  //       | dup |--->---| inc |---><---| 0 |----+
  //   +---|     |       |     |        |   |    |
  //   |   +-----+       +-----+        +---+    |
  //   |                                         |
  //   +-----------------------------------------+
  //             w
  ```

  This is executable in this reduction strategy as follows:

  ```
  $ ./inpla -w
  Inpla 0.4.1 : Interaction nets as a programming language [built: 21 Sept. 2021]
  >>> use "sample/processnet1.in";
  (2 interactions, 0.00 sec)
  >>> ifce;
  r 
  
  Connections:
  r ->[1,<a1>...    // this means a list of 1 and something.
  
  >>> a:b ~ r;
  (2 interactions, 0.00 sec)
  >>> ifce;
  a b 
  
  Connections:
  a ->1
  b ->[2,<b1>...  
  
  >>>
  ```
  
  



# Publications
- [1] Ian Mackie, Shinya Sato, 
[*In-place Graph Rewriting with Interaction Nets*](https://arxiv.org/abs/1609.03641), TERMGRAPH 2016, EPTCS 225, pp.15-24, 2016.
- [2] Shinya Sato,
[*Design and implementation of a low-level language for interaction nets*](http://sro.sussex.ac.uk/54469/),
PhD Thesis, University of Sussex, September 2014. 
- [3] Abubakar Hassan, Ian Mackie and Shinya Sato,
[*An implementation model for interaction nets*](http://arxiv.org/abs/1505.07164),
Proceedings 8th International Workshop on Computing with Terms and Graphs, TERMGRAPH 2014, EPTCS 183, May 2015. 
- [4] Ian Mackie and Shinya Sato,
[*Parallel Evaluation of Interaction Nets: Case Studies and Experiments*](http://journal.ub.tu-berlin.de/eceasst/article/view/1034),
Electronic Communications of the EASST, Volume 73: Graph Computation Models - Selected Revised Papers from GCM 2015, March 2016. 



# Related works

- [HINet: Interaction Nets in Haskell](http://www.cas.mcmaster.ca/~kahl/Haskell/HINet/)



# License

Copyright (c) 2021 [Shinya SATO](http://satolab.com/)  
 Released under the MIT license  
 http://opensource.org/licenses/mit-license.php
