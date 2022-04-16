(*
let rec insert x ylist =
  match ylist with
    [] -> [x]
  | y::ys when x<=y -> x::y::ys
  | y::ys           -> y::(insert x ys);;
*)

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

let main = isort (mkRandList 40000);;

