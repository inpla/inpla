# Changelog



## v0.4.1 (24 September 2021)

### Improved

- Line edit is improved so that history can be handled by linenoise:
  https://github.com/antirez/linenoise

- The priority of rules are changed so that user defined rules can be taken before built-in rules.

### Bug Fix

- Constants were consumed when they are referred to, but these should be kept and it was fixed as so.

- A global name that has evaluated and occurred twice already was able to be defined. Now it is prevented.

- A global name that has evaluated and occurred twice already was able to be defined. Now it is prevented.



## v0.4.0 (17 September 2021)

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



## v0.3.2 (3 August 2021)

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

  

## v0.3.1 (7 May 2021)

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

  
