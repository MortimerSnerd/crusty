struct ObjId:
   parts: int  // 32 bit object system + 32 bit index/id

enum ObjectSystem:
   InvalidSystem, PlayerSystem, GObjSystem, MapSystem, AnimationSystem

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
