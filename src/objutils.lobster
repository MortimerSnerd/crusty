import algs

enum ObjectSystem:
   InvalidSystem, PlayerSystem, GObjSystem, MapSystem, AnimationSystem, 
   // Systems for use in game specific code.  Provided with generic names so
   // in theory this file doesn't need to be changed.
   UserSystem1, UserSystem2, UserSystem3

class ObjId : EmbeddedDLinks<ObjId>
   system: ObjectSystem
   id: int = 0 // TODO: this is only currently used as a unique field to sort
               //       by in the animations module.

// Sentinel for no object.
let InvalidObject: ObjId? = nil

def to_string(o: ObjId) -> string:
   return "{" + o.system + ":" + o.id + "}"

class ObjIdList:
   ptr: ObjId?
