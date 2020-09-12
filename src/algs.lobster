import std
import vec

// We define our own rather than build off cardinal_directions and 
// diagonal_directions, so they can be in clockwise order rather
// than interleaved.

// Indexes into all_dirs
enum Directions:
   East, SouthEast, South, SouthWest, West, NorthWest, North, NorthEast

// Vectors for all grid directions, in the order of the `Directions` enum.
let all_dirs = [xy_f{1, 0}, xy_f{1, 1}, xy_f{0, 1}, xy_f{-1, 1}, xy_f{-1, 0}, 
                xy_f{-1, -1}, xy_f{0, -1}, xy_f{1, -1}]

// Angle in degrees for all directions in all_dirs.
let dir_angles = map(all_dirs) d: normalize_angle(atan2(d))

// For an array of numbers, returns the index of the entry
// closest to x.  Returns -1 for an empty array.
def closest_to(arr, x):
   var closest = -1

   for(arr) n, i:
      if closest < 0 or abs(x - n) < abs(x - arr[closest]):
         closest = i

   return closest


// If i ranges from 0..num-1, returns
// the previous i, cycling around to the 
// end of the range when i == 0
def cycle_left(i: int, num: int) -> int:
   if i <= 0:
      return num - 1
   else:
      return i - 1

// If i ranges from 0..num-1, returns
// the next i, cycling around to the 
// end of the range when i == num-1
def cycle_right(i: int, num: int) -> int:
   if i >= num-1:
      return 0
   else:
      return i + 1

// Treating arrays as binary heaps.
private def lchild(i: int) -> int:
   return 2*i + 1

private def rchild(i: int) -> int:
   return 2*i + 2

private def parent(i:int) -> int:
   assert i != 0
   return (i-1)/2 // Assume: division floored.

def heap_swap<T>(arr: [T], ai: int, bi: int):
   let t = arr[ai]
   arr[ai] = arr[bi]
   arr[bi] = t

def heap_bubble_up<T>(arr: [T], i: int, cmpfn):
   var pos = i

   while pos > 0 and not cmpfn(arr[parent(pos)], arr[pos]):
      heap_swap(arr, parent(pos), pos)
      pos = parent(pos)

def heap_bubble_down<T>(arr: [T], i: int, cmpfn):
   var pos = i
   var inplace = false

   while not inplace and pos < length(arr)-1:
      let li = lchild(pos)
      let ri = li + 1
      let li_exists = li < length(arr)
      let ri_exists = ri < length(arr)

      if (not li_exists or cmpfn(arr[pos], arr[li])) and (not ri_exists or cmpfn(arr[pos], arr[ri])):
         inplace = true
      else:
         if li_exists and ri_exists:
            if cmpfn(arr[li], arr[ri]):
               heap_swap(arr, pos, li)
               pos = li
            else:
               heap_swap(arr, pos, ri)
               pos = ri
         else:
            // One child is not present.
            if li_exists:
               heap_swap(arr, pos, li)
               pos = li
            else:
               heap_swap(arr, pos, ri)
               pos = ri

// Treats `arr` like a binary heap, and adds
// item to the proper place in the tree.  
// cmpfn can be <= for a min heap, or >= for a max
// heap.  
def heap_add<T>(arr: [T], item: T, cmpfn):
   let i = length(arr)
   push(arr, item)
   heap_bubble_up(arr, i, cmpfn)

def heap_pop<T>(arr: [T], cmpfn) -> T:
   let rv = arr[0]

   if length(arr) == 0:
      pop(arr)
   else:
      arr[0] = arr[length(arr)-1]
      pop(arr)
      heap_bubble_down(arr, 0, cmpfn)

   return rv

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

// Represents a linear interpolation happening in a distinct
// time interval.
class LERP<T>:
   startT: float
   endT: float
   start: T
   end: T

def mkLERP<T>(startTime: float, endTime: float, start: T, end: T) -> LERP<T>:
   assert endTime > startTime
   return LERP<T>{startT: startTime, endT: endTime, start: start, end: end}

def mkConstLERP<T>(v: T) -> LERP<T>:
   return mkLERP(0.0, 0.1, v, v)

def eval<T>(l::LERP<T>, t: float):
   let f = clamp((t - startT) / (endT - startT), 0.0, 1.0)

   return lerp(start, end, f)

// Specialized LERP for angles.
class AngleLERP:
   startT: float
   endT: float
   start: float
   end: float

def normalize_angle(f: float) -> float:
   var rv = f

   while rv < 0:
      rv += 360

   while rv > 360:
      rv -= 360

   return rv % 360.0

// Makes a LERP between angles, following the shortest path.
// (ie, 10 to 350 only goes 20 degrees.)
def mkAngleLERP(startTime: float, endTime: float, start: float, end: float) -> AngleLERP:
   assert endTime > startTime

   let sa = normalize_angle(start)
   let ea = normalize_angle(end)
   let plen = abs(ea - sa)
   let nlen = min(ea, sa) + 360 - max(ea, sa)

   if plen < nlen:
      return AngleLERP{startT: startTime, endT: endTime, start: sa, end: ea}
   else:
      if ea < sa:
         return AngleLERP{startT: startTime, endT: endTime, start: sa, end: ea + 360}
      else:
         return AngleLERP{startT: startTime, endT: endTime, start: sa + 360, end: ea}


def eval(l::AngleLERP, t: float):
   let f = clamp((t - startT) / (endT - startT), 0.0, 1.0)

   return normalize_angle(lerp(start, end, f))

def mkConstAngleLERP<T>(v: T) -> AngleLERP:

   return mkAngleLERP(0.0, 0.1, v, v)

def noop():
   return

def gridToWorld(p:: xy_i) -> xy_f:
   return xy_f{x: float(x) + 0.5, y: float(y) + 0.5}

def worldToGrid(p:: xy_f) -> xy_i:
   return xy_i{x: int(x - 0.5), y: int(y - 0.5)}

// Rectangle with inclusive bounds. +y is considered down
// as a convention.
struct Rect:
  topLeft: xy_i
  bottomRight: xy_i

struct Rectf:
  topLeft: xy_f
  bottomRight: xy_f

// If rects a & b overlap on the x axis, will
// return loval, hival where hival > loval.  
// hival <= loval means no intersection.
def x_intersection(a, b) -> float, float:
   let lo = max(a.topLeft.x, b.topLeft.x)
   let hi = min(a.bottomRight.x, b.bottomRight.x)

   return lo, hi

// Returns true if rects a & b overlap along the x axis.
def x_overlaps(a, b):
   let lo, hi = x_intersection(a, b)

   return hi > lo

// If rects a & b overlap on the y axis, will
// return loval, hival where hival > loval.  
// hival <= loval means no intersection.
def y_intersection(a, b) -> float, float:
   let lo = max(a.topLeft.y, b.topLeft.y)
   let hi = min(a.bottomRight.y, b.bottomRight.y)

   return lo, hi

// Returns true if rects a & b overlap along the y axis.
def y_overlaps(a, b):
   let lo, hi = y_intersection(a, b)

   return hi > lo

// Returns true if the two rects overlap.
def overlaps(a, b) -> bool:
   return x_overlaps(a, b) and y_overlaps(a, b)

def contains(r::Rect, pos: xy_i) -> bool:
   return (pos.x >= r.topLeft.x and pos.x <= r.bottomRight.x and
      pos.y >= r.topLeft.y and pos.y <= r.bottomRight.y)

def dims(r::Rect) -> xy_i:
   return xy_i{1 + bottomRight.x - topLeft.x, 1 + bottomRight.y - topLeft.y}

def area(r::Rect) -> int:
   let d = r.dims
   return d.x * d.y

def isDegenerate(r::Rect) -> bool:
   return r.area <= 0

def mkRectRel(topLeft: xy_i, dims: xy_i) -> Rect:
   return Rect{topLeft, xy_i{topLeft.x + dims.x - 1, topLeft.y + dims.y - 1}}


def contains(r::Rectf, pos: xy_f) -> bool:
   return (pos.x >= r.topLeft.x and pos.x <= r.bottomRight.x and
      pos.y >= r.topLeft.y and pos.y <= r.bottomRight.y)

def dims(r::Rectf) -> xy_f:
   // This is so cheesy. Technically, there shouldn't be a constant epsilon, but
   // something based on the next representable value given the values of x, y.
   // But probably not important enough to lose sleep over.  Picking a small value
   // that probably won't cause noticable issues. 
   let eps = 2.220446049250313080847e-16
   return xy_f{eps + bottomRight.x - topLeft.x, eps + bottomRight.y - topLeft.y}

def area(r::Rectf) -> float:
   let d = r.dims
   return d.x * d.y

def isDegenerate(r::Rectf) -> bool:
   return r.area <= 0

def mkRectfRel(topLeft: xy_f, dims: xy_f) -> Rectf:
   return Rectf{topLeft, xy_f{topLeft.x + dims.x - 1, topLeft.y + dims.y - 1}}

private def rndcheck():
   for(400) iter:
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

def heapcheck():
   let hcmp = fn(a: int, b: int) -> bool:
      a <= b

   for (400) iter:
      let hp = []
      for(1000) i: heap_add(hp, rnd(500), hcmp)
      if iter == 0:
         print("HEAPUS " + string(hp))
      let check = copy(hp)
      assert length(hp) == 1000
      qsort_in_place(check) a, b: a < b
      let hsorted = []
      while length(hp) > 0:
         push(hsorted, heap_pop(hp, hcmp))

      if not equal(hsorted, check):
         print("HSORTED " + string(hsorted))
         print("CHECK   " + string(check))
         assert false


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

   let ss = mkLERP(1.0, 2.0, 0.0, 100.0)

   assert eval(ss, 0) == 0
   assert eval(ss, 3) == 100
   assert eval(ss, 1) == 0
   assert eval(ss, 2) == 100
   assert eval(ss, 1.5) == 50

   heapcheck()
