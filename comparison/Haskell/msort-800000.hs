{-
https://stackoverflow.com/questions/25839939/understanding-merge-sort-in-ml
-}
import System.Random

mysplit [] = ([], [])
mysplit [a] = ([a], [])
mysplit (a:b:cs) = (a:m, b:n)
  where
    (m,n) = mysplit cs
    
merge ([], ys) = ys
merge (xs, []) = xs
merge (x:xs, y:ys)
  | x<y = x:merge(xs, y:ys)
  | otherwise = y:merge(x:xs, ys)

msort [] = []
msort [a] = [a]
msort [a,b]
  | a<b = [a,b]
  | otherwise = [b,a]
msort xs = merge (msort m, msort n)
  where
    (m,n) = mysplit xs

{-
main = print $ msort [3,2,8,5]
-}

randomList :: Int -> IO([Int])
randomList 0 = return []
randomList n = do
  r  <- randomRIO (1,10000)
  rs <- randomList (n-1)
  return (r:rs)



main = do
  list <- randomList 800000
  let sorted = msort list
  print (take 10 sorted)


