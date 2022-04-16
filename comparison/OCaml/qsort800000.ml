let rec split pivot (alist : int list) =
  match alist with
    [] -> ([], [])
  | (x::xs) ->
    let (below, above) = split pivot xs in
    if x<pivot then (x::below, above)
    else (below, x::above) ;;

let rec qsort (alist : int list) =
  match alist with
    [] -> []
  | pivot::rest ->
    let (below, above) = split pivot rest
    in (qsort below) @ [pivot] @ (qsort above) ;;




let rec mkRandList n =
  match n with
    0 -> []
  | n -> (Random.int 10000)::(mkRandList (n-1)) ;;

let main = qsort (mkRandList 800000) ;;

(* 
The following error arises:

Stack overflow during evaluation (looping recursion?).
*)
