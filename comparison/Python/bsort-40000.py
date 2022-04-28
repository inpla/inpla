# http://www.geekviewpoint.com/python/sorting/bubblesort
import random

def bubblesort(A):
    for i in range(len(A)):
        for k in range(len(A)-1, i, -1):
                if (A[k] < A[k-1]):
                        tmp = A[k]
                        A[k] = A[k-1]
                        A[k-1] = tmp

                                
def mkRandList(n):
    a=[]
    for i in range(1,n+1):
	    a.insert(0, random.randint(0,10000))
    return a


def validation(alist):
    for i in range(len(alist)-1):
        if (alist[i] > alist[i+1]):
            return False

    return True



a=mkRandList(40000)
bubblesort(a)
print(validation(a))
