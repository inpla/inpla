{-
http://www.codecodex.com/wiki/Insertion_sort#Standard_ML
-}
import System.Random

isort [] = []
isort (x:xs) = insert x (isort xs)

insert x [] = [x]
insert x (y:ys) =
  if x<=y then x:y:ys
  else y:(insert x ys)
  

{-
main = print $ isort [3,2,8,5]
-}


randomList :: Int -> IO([Int])
randomList 0 = return []
randomList n = do
  r  <- randomRIO (1,10000)
  rs <- randomList (n-1)
  return (r:rs)


main = do
  list <- randomList 40000
  let sorted = isort list
  print (take 10 sorted)
