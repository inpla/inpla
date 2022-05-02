open Format

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


let rec validation alist =
  let rec validation_cons x blist =
    match blist with
      [] -> true
    | y::ys -> if x<=y then (validation_cons y ys) else false
  in
  match alist with
    [] -> true
  | x::xs -> validation_cons x xs;;


let () = print_bool (validation (qsort (mkRandList 260000)));;
