(* http://www.codecodex.com/wiki/Insertion_sort#Standard_ML *)
fun insertsort [] = []
  | insertsort (x::xs) =
    let fun insert (x, []) = [x]
          | insert (x, y::ys) =
              if x<=y then x::y::ys
              else y::insert(x, ys)
    in insert(x, insertsort xs)
    end;
    
    
(* mkRandList *)
local 
    val nextInt = Random.randRange(1,10000);
    val r = Random.rand(1,1);
in
  fun mkRandList 0 = []
    | mkRandList n = (nextInt r)::(mkRandList (n-1))
end;
    
insertsort (mkRandList 40000);