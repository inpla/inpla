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


validation [] = True
validation (x:xs) = validation_cons x xs
validation_cons x [] = True
validation_cons x (y:ys) =
  if x<=y then validation_cons y ys
  else False


main = do
  list <- randomList 20000
  let sorted = isort list
  print (validation sorted)
