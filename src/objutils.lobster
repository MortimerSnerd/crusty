import algs

struct ObjId:
   parts: int  // 32 bit object system + 32 bit index/id

enum ObjectSystem:
   InvalidSystem, PlayerSystem, GObjSystem, MapSystem, AnimationSystem, 
   // Systems for use in game specific code.  Provided with generic names so
   // in theory this file doesn't need to be changed.
   UserSystem1, UserSystem2, UserSystem3

private let IndexMask = 0xFFFFFFFF

// Given a unique id for an object within the system `s`
// returns a unique object id for that object.
def mkObjId(s: ObjectSystem, id: int) -> ObjId:
   assert id & IndexMask == id
   return ObjId{parts: (int(s) << 32) + id}

def system(oid:: ObjId):
   return ObjectSystem(parts >> 32)

def id(oid:: ObjId):
   return parts & IndexMask

// Sentinel for no object.
let InvalidObject = mkObjId(InvalidSystem, 0)

def isValid(oid:: ObjId) -> bool: return oid.system != InvalidSystem

def to_string(o: ObjId) -> string:
   return "{" + o.system + ":" + o.id + "}"

class ObjIdMap<T>:
   keys: [ObjId]
   vals: [T]
   sorted: bool

def add_item<T>(m:: ObjIdMap<T>, key: ObjId, val: T):
   let inorder = length(keys) == 0 or key.parts > keys[length(keys)-1].parts

   sorted = sorted and inorder
   push(keys, key)
   push(vals, val)

def find<T>(m:: ObjIdMap<T>, key: ObjId) -> int:
   if not sorted:
      qsort_in_place(keys, vals) a, b: a.parts <= b.parts
      sorted = true      

   let found, idx = binary_search_by_key(keys, key) a, b: a.parts - b.parts

   if found:
      return idx
   else:
      return -1

def get<T>(m: ObjIdMap<T>, key: ObjId) -> T?:
   let i = find(m, key)

   if i < 0:
      return nil
   else:
      return m.vals[i]

def remove_index<T>(m:: ObjIdMap<T>, idx: int):
   unordered_remove(keys, idx)
   unordered_remove(vals, idx)
   sorted = false

def remove_item<T>(m:: ObjIdMap<T>, key: ObjId):
   let i = find(m, key)

   if i >=0:
      remove_index(m, i)

def mk_objid_map<T>(): 
   return ObjIdMap<T>{keys: [], vals: [], sorted: true}

def num_items<T>(m: ObjIdMap<T>): return length(m.keys)
