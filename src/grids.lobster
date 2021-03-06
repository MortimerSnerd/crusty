// 2d grids representing discrete map elements.
import from "../../../src/crusty/src/"
import std
import algs
import bus
import config_generated

private class SGEnt<T>:
   pos: xy_i
   loc: T

// Grid of T, with a representation that's efficient for sparse grids.
// If you can use set() and get(), then each position can have at most
// one entity.  If you use add(), remove_item() and for_items_at(), then there can be multiple
// items at the same position.  The two usages don't mix.
class SparseGrid<T>:
   missingVal: T  // What a location returns if there isn't an entry in `ents`.
   ents: [SGEnt<T>] // Entries at a grid location.
   new_ents: [SGEnt<T>] // Unordered ents added by `set`.
   
   // Can be called at the end of a batch of changes
   // to "reindex" so lookups can be as fast as possible.
   def end_changes():
      if length(new_ents) > 0:
         ents = append(ents, new_ents)
         new_ents = []

         // Order so we can lookup based on y.
         // We rig the compare function to make any entries
         // with the `missingVal` percolate to the back of the
         // array, where we can pop them off.
         qsort_in_place(ents) a, b:
            if a.loc == missingVal:
               false
            elif b.loc == missingVal:
               true
            else:
               a.pos.y < b.pos.y

         // Goodbye default entries.
         while length(ents) > 0 and ents[length(ents)-1].loc == missingVal:
            pop(ents)

   // Modifications to the grid should be done within
   // `f`.  Allows pre and post processing to be done.
   def modifying(f):
      f()
      end_changes()

   // Calls bodyfn(pos, index) for all non-missing items
   // within the given rectangle.
   def for_items_within(r: Rect, bodyfn):
      assert length(new_ents) == 0 // No changes outside of modify, right?
      var found, idx = binary_search_by_key(ents, r.topLeft.y) sgl, k: 
                         k = sgl.pos.y - k

      while idx < length(ents) and ents[idx].pos.y <= r.bottomRight.y:
         let lx = ents[idx].pos.x

         if lx >= r.topLeft.x and lx <= r.bottomRight.x:
            bodyfn(ents[idx].pos, ents[idx].loc)
         ++idx

   // Calls bodyfn(arr, ix) for all entries where the entry pos == pos.
   // There can be more than one if there are duplicates.
   private def withPosLoc(pos: xy_i, bodyfn):
      // Check unordered batch adds first.
      var found = false

      for(new_ents) l, i:
         if l.pos == pos:
            bodyfn(new_ents, i)

      let bsfound, ix = binary_search_by_key(ents, pos.y) sgl, k: k = sgl.pos.y - k
      
      if bsfound:
         var p = ix

         while p < length(ents) and ents[p].pos.y == pos.y:
            if ents[p].pos == pos:
               found = true
               bodyfn(ents, p)
            ++p
                  
      return found

   // Sets the item at grid location `pos` to `index`.
   // Use this and get() if you want to enforce there only
   // being one item possible at a given position.
   def set(pos: xy_i, val: T):
      //NB We allow setting an existing item to missingVal, 
      //   because we know the post step of modifying() will
      //   take care of those when things are reordered.
      //   But we never add a entry for a missing val to 
      //   new_ents.
      let found = withPosLoc(pos) arr, ix:
         arr[ix] = SGEnt<T>{pos: pos, loc: val}
      
      if not found and val != missingVal:
         push(new_ents, SGEnt<T>{pos: pos, loc: val})

   // Returns the index set at `pos`, or the default 
   // value if no index was set there.  Use this and set()
   // if you want to enforce there only being one item possible
   // at a given position.
   def get(pos: xy_i) -> T:
      withPosLoc(pos) arr, ix:
         return arr[ix].loc

      return missingVal

   // Discards any items where predfn(i) == true.
   def discard(predfn):
      new_ents = filter(new_ents) x: not predfn(x.loc)
      ents = filter(ents) x: not predfn(x.loc)

   // If you support multiple items at a single position, this function
   // allows you to call bodyfn(T) with them all
   def for_items_at(pos: xy_i, bodyfn):
      withPosLoc(pos) arr, ix:
         bodyfn(arr[ix].loc)

   def any_items_at(pos: xy_i, predfn) -> bool:
      withPosLoc(pos) arr, ix:
         if predfn(arr[ix].loc):
            return true

      return false

   // Adds a item at the given position, in a way that allows
   // multiple items at the same position.  See for_items_at to get 
   // at the added entries.
   def add(pos: xy_i, v: T):
      push(new_ents, SGEnt<T>{pos: pos, loc: v})

   // For grids where there can more than one item at a location, 
   // this allows you to remove a particular item.  If there are 
   // duplicate values at `pos`, only one gets removed.
   def remove_item(pos: xy_i, v: T):
      withPosLoc(pos) arr, ix:
         if arr[ix].loc == v:
            remove(arr, ix)
            return

def mkSparseGrid<T>(missingVal: T, estEnts = 100):
   return SparseGrid<T>{missingVal: missingVal, 
                        ents: vector_reserve(typeof [SGEnt<T>], estEnts), 
                        new_ents: vector_reserve(typeof [SGEnt<T>], estEnts)}

// Calculates index of (x,y) in elems, with no checks to see 
// if they fall in the dimensions of the grids, since this will
// be called a lot.  Checks need to be done by callers.
private def index(dims: xy_i, x: int, y: int) -> int:
   return x + y*dims.x

// Clips a point to the boundaries of the grid.
private def clip_to_dims(dims: xy_i, p: xy_i) -> xy_i:
   return xy_i{min(max(0, p.x), dims.x - 1),
               min(max(0, p.y), dims.y - 1)}

   
class DenseGrid<T>:
   dims: xy_i    // Have to specify the dimensions.  Implied 0,0 topLeft.
   elems: [T]
   defaultVal: T

   def contains(p: xy_i) -> bool:
      return p.x >= 0 and p.x < dims.x and p.y >= 0 and p.y < dims.y

   // Calls bodyfn(pos, index) for issing items within the given rectangle.
   def for_items_within(r: Rect, bodyfn):
      let tl = clip_to_dims(dims, r.topLeft)
      let br = clip_to_dims(dims, r.bottomRight)
      var y = tl.y

      while y <= br.y:
         var x = tl.x

         while x <= br.x:
            bodyfn(xy_i{x, y}, elems[index(dims, x, y)])
            ++x

         ++y

   // Returns the item at `pos`.  If `pos` is out of bounds, 
   // will return the default value passed into mk_dense_grid.
   def get(pos: xy_i) -> T:
      if this.contains(pos):
         return elems[index(dims, pos.x, pos.y)]
      else:
         return defaultVal

   // Sets the value at `pos`.  Does nothing if `pos` 
   // is out of the grid's bounds.
   def set(pos: xy_i, val: T):
      if this.contains(pos):
         elems[index(dims, pos.x, pos.y)] = val

def mk_dense_grid<T>(dims: xy_i, defaultVal: T) -> DenseGrid<T>:
   assert dims.x > 0 and dims.y > 0
   let rv =  DenseGrid<T>{dims: dims, 
                          elems: vector_reserve(typeof return, dims.x * dims.y), 
                          defaultVal: defaultVal}

   for(dims.x*dims.y) i:
      push(rv.elems, defaultVal)

   return rv

enum_flags VisFlag:
   vfLit,              //  Has light
   vfVisible,          // Visible to player
   vfSeen              // Seen before by player.  May or may not be visible now.

class VizSet:
   dims: xy_i  // Dimensions of grid covered.
   elems: [int] // 3 bit per 64 bit int makes me sad.

   def contains(p: xy_i) -> bool:
      return p.x >= 0 and p.x < dims.x and p.y >= 0 and p.y < dims.y

   // Marks a grid as lit, seen, etc...
   def mark(p: xy_i, flags: VisFlag):
      if this.contains(p):
         let i = index(dims, p.x, p.y)

         elems[i] |= flags

   // Returns true if all the flags in `flags` at `p` 
   // are set.
   def test(p: xy_i, flags: int) -> bool:
      var rv = false

      if this.contains(p):
         let b = elems[index(dims, p.x, p.y)]

         rv = (b & flags) == flags

      return rv

   // Returns true if any the flags in `flags` at `p` 
   // are set.
   def has(p: xy_i, flags: int) -> bool:
      var rv = false

      if this.contains(p):
         let b = elems[index(dims, p.x, p.y)]

         rv = (b & flags) != 0

      return rv

   // Clears the visible and lit flags, leaving
   // vfSeen untouched.
   def clear():
      for(length(elems)) i:
         elems[i] &= ~(vfLit | vfVisible)

   def get(p: xy_i) -> int:
      if this.contains(p):
         return elems[index(dims, p.x, p.y)]
      else:
         return 0

// Creates a set for recording visibility for a grid.
def mk_viz_set(dim: xy_i) -> VizSet:
   assert dim.x > 0 and dim.y > 0
   let num_elems = dim.x * dim.y
   let rv = VizSet{dims: dim, 
                   elems: vector_reserve(typeof return, num_elems)}

   for(num_elems) i:
      push(rv.elems, 0)

   return rv


def grids_tests():
   let rv = mkSparseGrid(0)

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

   let dupg = mkSparseGrid(0.0)

   modifying(dupg):
      add(dupg, xy_i{10, 15}, 5.5)
      add(dupg, xy_i{10, 15}, 5.4)
      add(dupg, xy_i{10, 15}, 5.3)
      add(dupg, xy_i{10, 15}, 5.9)
      remove_item(dupg, xy_i{10, 15}, 5.4)

   modifying(dupg):
      remove_item(dupg, xy_i{10, 15}, 5.9)

   let res: [float] = []

   for_items_at(dupg, xy_i{10, 15}) it:
      push(res, it)

   assert length(res) == 2
   assert (find(res) it: it == 5.5) >= 0
   assert (find(res) it: it == 5.3) >= 0

   


   return rv

