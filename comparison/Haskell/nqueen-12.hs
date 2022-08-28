member x [] = False
member x (y:ys)
  | x==y = True
  | otherwise = member x ys

threat k m [] = False
threat k m (x:xs)
  | (k == x-m) || (k == m-x) = True
  | otherwise = threat (k+1) m xs


queen1 0 b n = []
queen1 m b n
  | (member m b) || (threat 1 m b) = (queen1 (m-1) b n)
  | (length b) == (n-1) = [m:b] ++ (queen1 (m-1) b n)
  | otherwise = (queen1 n (m:b) n) ++ (queen1 (m-1) b n)

queen n = queen1 n [] n

n=12
main = print $ (length (queen n))
