{-
https://gist.github.com/masquerade0324/68f4f3fd3ab897fbe1ad 
http://files.farka.eu/pub/AC21007/lec5.pdf
-}

import System.Random

bs xs 0 = xs
bs (x:y:ys) n =
  if x<y then x:(bs (y:ys) (n-1))
  else y:(bs (x:ys) (n-1))
bs xs n = xs


go xs 0 = xs
go xs n = go (bs xs n) (n-1)

bsort xs = go xs (length xs -1)

{-
main = print $ bsort [3,2,8,5]
-}


randomList :: Int -> IO([Int])
randomList 0 = return []
randomList n = do
  r  <- randomRIO (1,10000)
  rs <- randomList (n-1)
  return (r:rs)


main = do
  list <- randomList 40000
  let sorted = bsort list
  print (take 10 sorted)
