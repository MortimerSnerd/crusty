import std

// Searches for entry in `xs` where cmpfn(xs[x], key) == 0. 
// `cmpfn(a, b)` should return < 0 if keyof(a) < key.
// Returns (true, index) of found item, or (false, index where the item would be)
// if it is not found.  The returned index is the least bounds index for the
// key.
def binary_search_by_key(xs, key, cmpfn) -> bool, int:
   var rv = 0
   var found = false

                        
   if length(xs) > 0:
      var lo = 0
      var hi = length(xs) -1

      while hi >= lo:
        if lo == hi:
          rv = lo
          if cmpfn(xs[lo], key) == 0:
             found = true
          break
        else:
           rv = lo + (1+hi-lo)/2
           let eq = cmpfn(xs[rv], key)

           if eq == 0:
              found = true
              break
           elif eq < 0:
             lo = rv + 1
           else:
             hi = rv - 1

   // See if there are any duplicates before us
   while rv > 0 and cmpfn(xs[rv-1], key) == 0:
      --rv

   // Special case for key > max(xs)
   if rv == length(xs) - 1 and  cmpfn(xs[rv], key) < 0:
      ++rv

   return found, rv

private def rndcheck():
   for(800) iter:
      let nums = []
      for(1000) i:
         push(nums, rnd(500))

      let sorted = copy(nums)

      qsort_in_place(sorted) a, b: a < b

      for(nums) x:
         let found, i = binary_search_by_key(sorted, x) a, b: a - b

         if not found:
            print(sorted)
            print("could not find " + string(x) + ", should go to " + string(i))
            break

def algs_tests():
   rndcheck()

   var found = false
   var ix = 0

   found, ix = binary_search_by_key([10, 20], 10) a, b: a - b
   assert found
   assert ix == 0

   found, ix = binary_search_by_key([11, 20], 20) a, b: a - b
   assert found
   assert ix == 1

   found, ix = binary_search_by_key([11, 20], 0) a, b: a - b
   assert not found
   assert ix == 0

   found, ix = binary_search_by_key([11, 20], 21) a, b: a - b
   assert not found
   assert ix == 2

def noop():
   return
