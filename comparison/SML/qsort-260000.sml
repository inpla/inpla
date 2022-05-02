fun quicksort nil = nil
  | quicksort (pivot :: rest) =
    let
        fun split(nil) = (nil,nil)
          | split(x :: xs) =
          let
            val (below, above) = split(xs)
          in
            if x < pivot then (x :: below, above) 
            else (below, x :: above)
          end;
          val (below, above) = split(rest)
    in
        quicksort below @ [pivot] @ quicksort above
    end;
    
    
(* Creates a random list *)
local 
    val nextInt = Random.randRange(1,10000);
    val r = Random.rand(1,1);
in
  fun mkRandList 0 = []
    | mkRandList n = (nextInt r)::(mkRandList (n-1))
end;


(* Validation checks *)
fun validation [] = true
  | validation (x::xs) =
    let fun validation_cons x [] = true
	  | validation_cons x (y::ys) =
	    if x<=y then validation_cons y ys
	    else false
    in
	validation_cons x xs
    end;


(* Main *)
validation(quicksort(mkRandList 260000));
