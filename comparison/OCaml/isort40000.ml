open Format

let rec insert x ylist =
  match ylist with
    [] -> [x]
  | y::ys -> if x<=y
    then x::y::ys
    else y::(insert x ys);;


let rec isort (alist : int list) =
  match alist with
    [] -> []
  | x::xs -> insert x (isort xs);;

  
    
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


let () = print_bool (validation (isort (mkRandList 40000)));;

