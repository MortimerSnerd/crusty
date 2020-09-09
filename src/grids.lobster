// 2d grids representing discrete map elements.
import std
import algs

let EmptyLocIndex = -1

private struct SGLoc:
   pos: xy_i
   loc: int

// Grid of integers, with a representation that's efficient for sparse grids.
class SparseGrid:
   missingVal: int  // What a location returns if there isn't an entry in `locs`.
   dims: xy_i
   locs: [SGLoc] // Indices into information about the map location.  -1 sentinel for Empty
   newlocs: [SGLoc] // Unordered locs added by `set`.
   
// Modifications to the grid should be done within
// `f`.  Allows pre and post processing to be done.
def modifying(g::SparseGrid, f):
   f()
   // Order so we can lookup based on y.
   // We rig the compare function to make any entries
   // with the `missingVal` percolate to the back of the
   // array, where we can pop them off.
   locs = append(locs, newlocs)
   newlocs = []
   qsort_in_place(locs) a, b:
      if a.loc == missingVal:
         false
      elif b.loc == missingVal:
         true
      else:
         a.pos.y < b.pos.y

   // Goodbye default entries.
   while length(locs) > 0 and locs[length(locs)-1].loc == missingVal:
      pop(locs)

// Calls bodyfn(pos, index) for all non-missing items
// within the given rectangle.
def forItemsWithin(g::SparseGrid, r: Rect, bodyfn):
   assert length(newlocs) == 0 // No changes outside of modify, right?
   var found, idx = binary_search_by_key(g.locs, r.topLeft.y) sgl, k: 
                      k = sgl.pos.y - k

   while idx < length(locs) and locs[idx].pos.y <= r.bottomRight.y:
      let lx = locs[idx].pos.x

      if lx >= r.topLeft.x and lx <= r.bottomRight.x:
         bodyfn(locs[idx].pos, locs[idx].loc)
      ++idx

private def withPosLoc(g::SparseGrid, pos: xy_i, bodyfn):
   // Check unordered batch adds first.
   var found = false

   for(newlocs) l, i:
      if l.pos == pos:
         found = true
         bodyfn(newlocs, i)
         break

   if not found:
      let bsfound, ix = binary_search_by_key(locs, pos.y) sgl, k: k = sgl.pos.y - k
      
      if bsfound:
         var p = ix

         while p < length(locs) and locs[p].pos.y == pos.y and locs[p].pos.x != pos.x:
            ++p

         if p < length(locs) and pos == locs[p].pos:
            found = true
            bodyfn(locs, p)
               
   return found


// Sets the item at grid location `pos` to `index`
def set(g::SparseGrid, pos: xy_i, index: int):
   //NB We allow setting an existing item to missingVal, 
   //   because we know the post step of modifying() will
   //   take care of those when things are reordered.
   //   But we never add a entry for a missing val to 
   //   newlocs.
   let found = withPosLoc(g, pos) arr, ix:
      arr[ix] = SGLoc{pos: pos, loc: index}
   
   if not found and index != missingVal:
      push(newlocs, SGLoc{pos: pos, loc: index})

// Returns the index set at `pos`, or the default 
// value if no index was set there.
def get(g::SparseGrid, pos: xy_i) -> int:
   withPosLoc(g, pos) arr, ix:
      return arr[ix].loc

   return missingVal

// 


def grids_tests():
   let rv = SparseGrid{missingVal: 0, dims: xy_i{50, 50}, locs: [], newlocs: []}

   modifying(rv):
      set(rv, xy_i{23, 11}, 32)
      set(rv, xy_i{23, 10}, 99)
      set(rv, xy_i{1, 2}, 20)
      set(rv, xy_i{24, 10}, 99)
      set(rv, xy_i{100, 100}, -2)
      set(rv, xy_i{100, 0}, 123)

   modifying(rv):
      set(rv, xy_i{23, 10}, 666)
      set(rv, xy_i{100,100}, 0)  // Setting to missing val should remove the item
      set(rv, xy_i{100, 0}, 0)   // ""

   assert get(rv, xy_i{0,0}) == 0
   assert get(rv, xy_i{100,100}) == 0
   assert get(rv, xy_i{23,10}) == 666
   assert not (withPosLoc(rv, xy_i{100,100}) arr, ix: noop())
   assert not (withPosLoc(rv, xy_i{100,0}) arr, ix: noop())
   assert get(rv, xy_i{23,11}) == 32
   assert get(rv, xy_i{1,2}) == 20
   assert get(rv, xy_i{24,10}) == 99

   return rv

