{-
(* http://www.codecodex.com/wiki/Insertion_sort#Standard_ML *)
-}
import System.Random

qsort [] = []
qsort [x] = [x]
qsort (x:xs) = (qsort left) ++ [x] ++ (qsort right)
  where (left, right) = part x xs

part pivot [] = ([], [])
part pivot (x:xs)
  | x<pivot = (x:below, above)
  | otherwise = (below, x:above)
  where
    (below, above) = part pivot xs


{-
main = print $ qsort [3,2,8,5]
-}


randomList :: Int -> IO([Int])
randomList 0 = return []
randomList n = do
  r  <- randomRIO (1,10000)
  rs <- randomList (n-1)
  return (r:rs)


validation [] = True
validation (x:xs) = validation_cons x xs
validation_cons x [] = True
validation_cons x (y:ys) =
  if x<=y then validation_cons y ys
  else False


main = do
  list <- randomList 800000
  let sorted = qsort list
  print (validation sorted)
