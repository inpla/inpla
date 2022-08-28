fun member x [] = false
| member x (y::ys) = if x=y then true else (member x ys);

(* check for (0,q) and (k, qpos[col=k]) where k=1... 
http://www.nct9.ne.jp/m_hiroi/func/haskell06.html
    0 1 2    --> 
  *-------------
 1| . . . . . .
 2| . . . -3. .  5 - 3 = 2
 3| . . -2. . .  5 - 2 = 3
 4| . -1. . . .  5 - 1 = 4
 5| Q . . . . .  Q position is 5  
 6| . +1. . . .  5 + 1 = 6
 7| . . +2. . .  5 + 2 = 7
 8| . . . +3. .  5 + 2 = 8
  *-------------
*)
fun threat k m [] = false
  | threat k m (x::xs) =
   if (k = x-m) orelse (k = m-x) then true
    else (threat (k+1) m xs);


fun queen1 0 b n = []
  | queen1 m b n =
    if (member m b) orelse (threat 1 m b) then (queen1 (m-1) b n)
    else if (length b) = (n-1) then [m::b]@(queen1 (m-1) b n)
         else (queen1 n (m::b) n) @ (queen1 (m-1) b n);

fun queen n = queen1 n [] n;

val n = 12;
length (queen n);
