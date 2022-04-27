# Quicksort
import random

# https://stackoverflow.com/questions/23767787/python-implementation-of-quicksort-fails-to-sort-the-entire-array
def quickSort(arr):
    less = []
    pivotList = []
    more = []
    if len(arr) <= 1:
        return arr
    else:
        pivot = arr[0]
        for i in arr:
            if i < pivot:
                less.append(i)
            elif i > pivot:
                more.append(i)
            else:
                pivotList.append(i)
                
        less = quickSort(less)
        more = quickSort(more)
        return less + pivotList + more

def mkRandList ( n ):
    a=[]
    for i in range(1,n+1):
        a.insert(0, random.randint(0,10000))
    return a

a = mkRandList(800000)
b = quickSort(a)
#print(b)
