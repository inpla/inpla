let rec split (alist : int list) =
  match alist with
    [] -> ([], [])
  | [a] -> ([a], [])
  | a::b::cs ->
    let (m,n) = split cs in
    (a::m, b::m) ;;

let rec merge (alist : int list) (blist : int list) =
  match alist with
    [] -> blist
  | x::xs ->
    match blist with
      [] -> x::xs
    | y::ys ->
      if x<y then x::(merge xs (y::ys))
      else y::(merge (x::xs) ys) ;;


let rec msort (alist : int list) = 
  match alist with
    [] -> []
  | a::[] -> [a]
  | a::b::[] -> if a<b then [a;b] else [b;a]
  | xs ->
    let (m,n) = split xs
    in merge (msort m) (msort n) ;;
    


let rec mkRandList n =
  match n with
    0 -> []
  | n -> (Random.int 10000)::(mkRandList (n-1)) ;;

let main = msort (mkRandList 800000) ;;


(* 
The following error arises:

Stack overflow during evaluation (looping recursion?).
*)
