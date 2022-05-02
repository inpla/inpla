# Python program for implementation of MergeSort
# https://www.geeksforgeeks.org/merge-sort/
import random

def mergeSort(arr):
    if len(arr) > 1:
 
         # Finding the mid of the array
        mid = len(arr)//2
 
        # Dividing the array elements
        L = arr[:mid]
 
        # into 2 halves
        R = arr[mid:]
 
        # Sorting the first half
        mergeSort(L)
 
        # Sorting the second half
        mergeSort(R)
 
        i = j = k = 0
 
        # Copy data to temp arrays L[] and R[]
        while i < len(L) and j < len(R):
            if L[i] < R[j]:
                arr[k] = L[i]
                i += 1
            else:
                arr[k] = R[j]
                j += 1
            k += 1
 
        # Checking if any element was left
        while i < len(L):
            arr[k] = L[i]
            i += 1
            k += 1
 
        while j < len(R):
            arr[k] = R[j]
            j += 1
            k += 1


def mkRandList ( n ):
    a=[]
    for i in range(1,n+1):
        a.insert(0, random.randint(0,10000))
    return a


def validation(alist):
    for i in range(len(alist)-1):
        if (alist[i] > alist[i+1]):
            return False

    return True


a = mkRandList(10)
mergeSort(a)
print(validation(a))
