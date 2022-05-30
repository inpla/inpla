open Format

let rec bs (alist : int list) n =
  match alist with
    (x::y::ys) ->
    if x<y then x::(bs (y::ys) (n-1))
    else y::(bs (x::ys) (n-1))
  | xs -> xs;;

    
let rec go xs n =
  match n with
    0 -> xs
  | n -> go (bs xs n) (n-1);;

let bsort alist =
  match alist with
    [] -> []
  | xs -> go xs (List.length(xs) - 1);;

		  
let rec mkRandList n =
  match n with
    0 -> []
  | n -> (Random.int 10000)::(mkRandList (n-1));;


let rec validation alist =
  let rec validation_cons x blist =
    match blist with
      [] -> true
    | y::ys -> if x<=y then (validation_cons y ys) else false
  in
  match alist with
    [] -> true
  | x::xs -> validation_cons x xs;;


let () = print_bool (validation (bsort (mkRandList 20000)));;
