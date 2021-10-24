(*
https://gist.github.com/masquerade0324/68f4f3fd3ab897fbe1ad 
*)

fun bs xs 0 = xs
  | bs (x::y::ys) n =
    if (x<y) then x::(bs (y::ys) (n-1))
    else y::(bs (x::ys) (n-1))
  | bs xs _ = xs;

fun go xs 0 = xs
  | go xs n = go (bs xs n) (n-1);


fun bsort xs = go xs (length(xs) - 1);


(* mkRandList *)
local 
    val nextInt = Random.randRange(1,10000);
    val r = Random.rand(1,1);
in
  fun mkRandList 0 = []
    | mkRandList n = (nextInt r)::(mkRandList (n-1))
end;


bsort (mkRandList 40000);


