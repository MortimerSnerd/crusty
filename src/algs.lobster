import std
import vec

// We define our own rather than build off cardinal_directions and 
// diagonal_directions, so they can be in clockwise order rather
// than interleaved.

// Indexes into all_dirs
enum Directions:
   East, SouthEast, South, SouthWest, West, NorthWest, North, NorthEast

// Vectors for all grid directions, in the order of the `Directions` enum.
let all_dirs = [xy_i{1, 0}, xy_i{1, 1}, xy_i{0, 1}, xy_i{-1, 1}, xy_i{-1, 0}, 
                xy_i{-1, -1}, xy_i{0, -1}, xy_i{1, -1}]

let all_dirs_f = [xy_f{1, 0}, xy_f{1, 1}, xy_f{0, 1}, xy_f{-1, 1}, xy_f{-1, 0}, 
                  xy_f{-1, -1}, xy_f{0, -1}, xy_f{1, -1}]

let opposite_dir = [West, NorthWest, North, NorthEast, East, SouthEast, 
                    South, SouthWest]

// Angle in degrees for all directions in all_dirs.
let dir_angles = map(all_dirs) d: normalize_angle(atan2(xy_f{float(d.x), float(d.y)}))

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

def turned_left(d: Directions) -> Directions:
   return Directions(cycle_left(d, length(all_dirs)))

def turned_right(d: Directions) -> Directions:
   return Directions(cycle_right(d, length(all_dirs)))

def turned_right_90deg(v: xy_i) -> xy_i:
   return xy_i{-v.y, v.x} 

def turned_left_90deg(v: xy_i) -> xy_i:
   return xy_i{v.y, -v.x}

def turned_left_90deg(v: xy_f) -> xy_f:
   return xy_f{v.y, -v.x}

def is_diagonal(v: xy_i) -> bool:
   return v.x != 0 and v.y != 0

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

def scale_time(l, f: float):
   l.startT *= f
   l.endT *= f

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
   let eps = 2.220446049250313080847e-16
   return Rectf{topLeft, xy_f{topLeft.x + dims.x - eps, topLeft.y + dims.y - eps}}

def gridToWorld(p:: xy_i) -> xy_f:
   return xy_f{x: float(x) + 0.5, y: float(y) + 0.5}

def worldToGrid(p:: xy_f) -> xy_i:
   return xy_i{x: int(x - 0.5), y: int(y - 0.5)}

def gridRect(p: xy_f) -> Rectf:
   let gc = worldToGrid(p)
   return mkRectfRel(xy_f{float(gc.x), float(gc.y)}, xy_1)

def gridRect(p: xy_i) -> Rectf:
   let gc = worldToGrid(xy_f{p.x, p.y})
   return mkRectfRel(xy_f{float(gc.x), float(gc.y)}, xy_1)


// Converts a world rect to a grid rect.
def worldToGrid(r: Rectf) -> Rect:
   return Rect{worldToGrid(r.topLeft), worldToGrid(r.bottomRight)}

def render(r:: Rectf, thickness):
   gl_line(topLeft, xy_f{bottomRight.x, topLeft.y}, thickness)
   gl_line(xy_f{bottomRight.x, topLeft.y}, bottomRight, thickness)
   gl_line(bottomRight, xy_f{topLeft.x, bottomRight.y}, thickness)
   gl_line(xy_f{topLeft.x, bottomRight.y}, topLeft, thickness)

// Removes an item by swapping in the last item, rather
// than shifting the array.  If the array was ordered before, 
// it probably isn't now.
def unordered_remove(xs, i):
   let lasti = length(xs) - 1

   if i == lasti:
      pop(xs)
   else:
      xs[i] = xs[lasti]
      pop(xs)

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
            print("could not find " + x + ", should go to " + i)
            break

def stopwatch(body) -> float:
   let t0 = seconds_elapsed()
   body()
   let t1 = seconds_elapsed()

   return t1 - t0

def heapcheck():
   let hcmp = fn(a: int, b: int) -> bool:
      a <= b

   for (400) iter:
      let hp = []
      for(1000) i: heap_add(hp, rnd(500), hcmp)
      let check = copy(hp)
      assert length(hp) == 1000
      qsort_in_place(check) a, b: a < b
      let hsorted = []
      while length(hp) > 0:
         push(hsorted, heap_pop(hp, hcmp))

      if not equal(hsorted, check):
         print("HSORTED " + hsorted)
         print("CHECK   " + check)
         assert false

def qsort_in_place(keys, vals, lt):
    def rec(s, e) -> void:
        let l = e - s
        if l > 1:
            let pivot = keys[s]
            let pivotval = vals[s]
            var sp = s + 1
            var ep = e
            while sp < ep:
                let c = keys[sp]
                if lt(c, pivot):
                    keys[sp - 1] = keys[sp]
                    vals[sp - 1] = vals[sp]
                    sp++
                else:
                    let v = vals[sp]
                    keys[sp] = keys[--ep]
                    vals[sp] = vals[ep]
                    keys[ep] = c
                    vals[ep] = v
            
            keys[--sp] = pivot
            vals[sp] = pivotval
            rec(s, sp)
            rec(ep, e)

    rec(0, keys.length)

// The absolute start and end times of a player turn.
// Animations are scaled and possibly moved within this
// duration so at the end of the turn, objects animation positions
// matches up with the actual positions of the objects on the grid.
// Without this, you can get into hard to read situations, where a 
// object moves towards the end of the turn, so visually it appears
// that they're still in the starting grid, but effectively they're already
// on grid location over.
struct TurnSpan:
   start: float
   end: float

def mag(t:: TurnSpan) -> float:
   assert t.end >= t.start
   return end - start

// Embedded links class to inherit from.
class EmbeddedDLinks<T>:
   dl_next: T? = nil
   dl_prev: T? = nil

// Reference to a circular doubly linked list.
class EmbeddedCircList<T>:
   head: T?
   count: int = 0

// Adds an item to the list.  Not valid if the
// item is already in a list.
def dl_add<T>(list: EmbeddedCircList<T>, item: T):
   assert item.dl_next == nil
   assert item.dl_prev == nil

   if list.head:
      item.dl_next = list.head
      item.dl_prev = list.head.dl_prev
      if item.dl_prev:
         item.dl_prev.dl_next = item
      item.dl_next.dl_prev = item
   else:
      item.dl_next = item
      item.dl_prev = item
      list.head = item

   ++list.count

// Removes an item from a doubly linked circular list.
def dl_remove<T>(list: EmbeddedCircList<T>, item: T):
   if item.dl_prev:
      item.dl_prev.dl_next = item.dl_next
   if item.dl_next:
      item.dl_next.dl_prev = item.dl_prev

   if list.head and list.head == item:
      if item.dl_next == item:
         // last item in circular list.
         list.head = nil
      else:
         list.head = item.dl_next

   item.dl_next = nil
   item.dl_prev = nil
   --list.count

// Removes all entries.  If this isn't done
// before you're done with a list, you'll get
// a memory leak report because of the cycles.
def dl_clear<T>(list: EmbeddedCircList<T>):
   let fst = list.head

   if fst:
      var cur:T? = fst
      repeat():
         let nxt = cur.dl_next
         cur.dl_next = nil
         cur.dl_prev = nil
         cur = nxt
      fn():
         cur != fst

      list.head = nil

// repeat() until type of loop.
//     repeat():
//       print('hi')
//       --x
//     fn():
//       x > 0
// Probably not useful, just verifying I can do it
// and seeing how it works out.
def repeat(body, whilecond):
   body()

   while whilecond():
      body()

def dl_foreach<T>(list: EmbeddedCircList<T>, body):
   if list.head:
      var o: T? = list.head

      repeat():
         if o:  // Should always be true, but we must check.
            body(o)
            o = o.dl_next
      fn():
         o != list.head

def dl_find<T>(list: EmbeddedCircList<T>, predfn) -> T?:
   dl_foreach(list) i:
      if predfn(i):
         return i

   return nil

// Multipliers for row, col for the different octants.
def transform_octant(octant: int, row: int, col: int) -> xy_i:
   switch octant:
      case 0: return xy_i{col, -row}
      case 1: return xy_i{row, -col}
      case 2: return xy_i{row, col}
      case 3: return xy_i{col, row}
      case 4: return xy_i{-col, row}
      case 5: return xy_i{-row, col}
      case 6: return xy_i{-row, -col}
      case 7: return xy_i{-col, -row}
   assert false

// Visibility determination via munificent's 
// algorithm:  http://journal.stuffwithstuff.com/2015/09/07/what-the-hero-sees/
//

// `start` and `end` are slopes.
private class Shadow:
   start: float  
   end: float

private class ShadowLine:
   shadows: [Shadow]

private def project_tile(row: int, col: int):
   let fr = float(row)
   let fc = float(col)
   let tl = fc / (fr + 2)
   let br = (fc + 1) / (fr + 1)

   return Shadow{start: tl, end: br}

private def contains_shadow(s:: Shadow, other: Shadow):
   return start <= other.start and end >= other.end

private def is_in_shadow(sl:: ShadowLine, projection: Shadow):
   return exists(shadows) s: s.contains_shadow(projection)

private def add(sl:: ShadowLine, new_shadow: Shadow):
   var idx = 0
   while idx < length(shadows):
      if shadows[idx].start >= new_shadow.start: break
      ++idx

   var ovr_prev: Shadow? = nil
   if idx > 0 and shadows[idx-1].end > new_shadow.start:
      ovr_prev = shadows[idx - 1]

   var ovr_next: Shadow? = nil
   if idx < length(shadows) and shadows[idx].start < new_shadow.end:
      ovr_next = shadows[idx]

   if ovr_next:
      if ovr_prev:
         ovr_prev.end = ovr_next.end
         remove(shadows, idx)
      else:
         ovr_next.start = new_shadow.start
   else:
      if ovr_prev:
         ovr_prev.end = new_shadow.end
      else:
         insert(shadows, idx, new_shadow)

private def is_full_shadow(sl:: ShadowLine):
   return length(shadows) == 1 and shadows[0].start ==0 and shadows[0].end == 1

private def refresh_octant(start_pos: xy_i, octant: int, bounds: Rect, block_test, body):
   let line = ShadowLine{shadows: []}
   var row = 1

   while true:
      var pos = start_pos + transform_octant(octant, row, 0)
      if not bounds.contains(pos): break

      var col = 0
      while col <= row:
         pos = start_pos + transform_octant(octant, row, col)
         if not bounds.contains(pos): break

         let proj = project_tile(row, col)
         let visible = not line.is_in_shadow(proj)
         if visible: 
            body(pos)
            if block_test(pos):
               line.add(proj)
               if line.is_full_shadow(): return
         ++col
      ++row

// Calls body(pos) for all visible tiles from `start_pos`
// block_test should be a functon that takes a grid position and
// returns true if light is blocked at that position.
def walk_visible_tiles(start_pos: xy_i, bounds: Rect, block_test, body):
   for(8) octant:
      refresh_octant(start_pos, octant, bounds, block_test, body)

def to_f(p: xy_i):
   return xy_f{float(p.x), float(p.y)}

// Return a letter choice for a list of choices.  Practically limited to 
// 26 + 10 digits, since we can't do uppercase.
def choice_letter(i: int):
   let rv = " "

   if i >= 0 and i < 25:
      rv.write_int8_le(0, i + 97)
   elif i >= 26 and i < 36:
      rv.write_int8_le(0, i - 26 + 48)
   else:
      assert false //exceeded #choices

   return rv

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

   let r1 = Rectf{xy_f{1.5, 3.5}, xy_f{2.5, 4.5}}
   let r2 = Rectf{xy_f{-10.0, -10.0}, xy_f{10.0, 10.0}}

   assert r1.overlaps(r2)
   assert r2.overlaps(r1)

   heapcheck()
