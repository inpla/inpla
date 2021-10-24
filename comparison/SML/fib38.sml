fun fib 0 = 0
| fib 1 = 1
| fib n = (fib (n-1)) + (fib (n-2));



(* ex *)
(* prnat(Ack (mknat 2) (mknat 3)); *)
fib 38;
