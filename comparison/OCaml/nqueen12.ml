let rec member x alist =
  match alist with
    []    -> false
  | y::ys -> if x=y then true else (member x ys);;

let rec threat k m alist =
  match alist with
    []    -> false
  | x::xs ->  if (k = x-m) || (k = m-x) then true
              else (threat (k+1) m xs);;

let rec queen1 m b n =
  match m with
    0 -> []
  | m ->
    if (member m b) || (threat 1 m b) then (queen1 (m-1) b n)
    else if (List.length b) = (n-1) then [m::b]@(queen1 (m-1) b n)
         else (queen1 n (m::b) n) @ (queen1 (m-1) b n);;

let queen n = queen1 n [] n;;

let n = 12;;
let () = print_int (List.length (queen n));
