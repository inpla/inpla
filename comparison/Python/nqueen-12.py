def threat(k, m, alist):
    if alist == []:
        return False
    else:
        x = alist[0]        
        if (k == x-m) or (k == m-x):
            return True
        else:
            return threat(k+1, m, alist[1:])
        
def queen1(m, b, n):
    if m == 0:
        return []
    else:
        if (m in b) or threat(1, m, b):
            return queen1(m-1, b, n)
        elif len(b) == n-1:
            return [[m]+b] + (queen1(m-1, b, n))
        else:
            return queen1(n, [m]+b, n) + (queen1(m-1, b, n))


def queen(n):
    return queen1(n,[],n)

n=12
print(len(queen(12)))
