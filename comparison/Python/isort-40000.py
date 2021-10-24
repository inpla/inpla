import random

def insert_sort(arr):
    for i in range(1, len(arr)):
        j = i - 1
        ele = arr[i]
        while arr[j] > ele and j >= 0:
            arr[j + 1] = arr[j]
            j -= 1
        arr[j + 1] = ele
    return arr


def mkRandList(n):
    a=[]
    for i in range(1,n+1):
        a.insert(0, random.randint(0,10000))
    return a

a = mkRandList(40000)
insert_sort(a)
#print(a)

        
