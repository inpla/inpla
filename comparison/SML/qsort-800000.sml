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
    
    
(* mkRandList *)
local 
    val nextInt = Random.randRange(1,10000);
    val r = Random.rand(1,1);
in
  fun mkRandList 0 = []
    | mkRandList n = (nextInt r)::(mkRandList (n-1))
end;
    
quicksort (mkRandList 800000);
