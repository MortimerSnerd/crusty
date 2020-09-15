// Allows functions to be called for ObjIds without the callers needing to 
// know where or how the owner of the ObjId is implemented. In practice, prevents
// accidental creation of import cycles.
import from "../../../src/crusty/src/"
import algs
import logging
import objutils
import vec

// Base class for system specific callback objects.
class BusEndpoint:
   system: ObjectSystem

// Registered busses.
private let Endpoints:[BusEndpoint] = []

// Base method for returning the center position of an object.
def pos(b:: BusEndpoint, what: ObjId, t: float) -> bool, xy_f:
   return false, xy_0

// Base method for returning the facing angle of an object.
def angle(b:: BusEndpoint, what: ObjId, t: float) -> bool, float:
   return false, 0

// Base method. Calls `body(ObjId, obj rectf)` for all objects that intersect
// rectangle `r`.
def forObjectsIntersecting(b:: BusEndpoint, now: float, r: Rectf, body):
   noop()

// Base method, returns true if `o` has the ability
// to block living things from moving to the grid 
// that o occupies.  
def blocksLiving(b:: BusEndpoint, o: ObjId) -> bool:
   return false

// Should be called by actions that move objects, to notify
// any interested systems.  Gets called for all systems, not
// just the owner.
def notify_moving(b:: BusEndpoint, o: ObjId, startT: float, endT: float, wstart: xy_f, wend: xy_f):
   return

// Should be called by actions that turn/rotate objects, to notify
// any interested systems.  Gets called for all systems, not just
// the owner of the object.
def notify_turning(b:: BusEndpoint, o: ObjId, startT: float, endT: float, startAng: float, endAng: float):
   return

// Called when an object is spawned.  If parent != InvalidObject, then
// the spawned object is "contained" in that object.  Otherwise, the 
// pos field is a world position for the object.  All systems get this
// notification.
def notify_spawn(b:: BusEndpoint, o: ObjId, parent: ObjId, wpos: xy_f):
   return

// Base method
// Called to give an object to make an action.  Think calls are
// scheduled one-shot calls.  If `who` wants to be called again
// it needs to call schedule_callback() itself.
def think(b:: BusEndpoint, who: ObjId, now: float):
   error(): "Unimplemented think call for " + string(who)
   noop()

private def endpointForSystem(s: ObjectSystem) -> BusEndpoint?:
   let i = find(Endpoints) ep: ep.system == s

   if i < 0:
      return nil
   else:
      return Endpoints[i]

// Should be call for all systems that own ObjId's.  
def registerBusEndpoint(ep: BusEndpoint):
   assert ep.system != InvalidSystem
   let existing = endpointForSystem(ep.system)

   assert not existing
   push(Endpoints, ep)

// Returns the position of the given object.
def pos(what: ObjId, now: float) -> bool, xy_f:
   let ep = endpointForSystem(what.system)

   if ep:
      let found, p = ep.pos(what, now)
      return found, p
   else:
      return false, xy_0

def angle(what: ObjId, now: float) -> bool, float:
   let ep = endpointForSystem(what.system)

   if ep:
      let found, p = ep.angle(what, now)
      return found, p
   else:
      return false, 0

// Calls `body(ObjId, obj rectf)` for all objects that intersect
// rectangle `r`.
def forObjectsIntersecting(now: float, r: Rectf, body):
   for(Endpoints) ep:
      ep.forObjectsIntersecting(now, r, body)

// Called to give an object to make an action.  Think calls are
// scheduled one-shot calls.  If `who` wants to be called again
// it needs to call schedule_callback() itself.
def think(who: ObjId, now: float):
   let ep = endpointForSystem(who.system)

   if ep:
      ep.think(who, now)
   else:
      error(): "No endpoint registered for system " + string(who.system) + " " + string(who.id)

// Returns true if `o` has the ability
// to block living things from moving to the grid 
// that o occupies.  
def blocksLiving(o: ObjId) -> bool:
   let ep = endpointForSystem(o.system)

   if ep:
      return ep.blocksLiving(o)
   else:
      error(): "No endpoint registered for system " + string(o.system)
      return false

// Should be called by actions that move objects, to notify
// any interested systems.  Gets called for all systems, not just
// the owner of the object.
def notify_moving(o: ObjId, startT: float, endT: float, wstart: xy_f, wend: xy_f):
   for(Endpoints) ep:
      ep.notify_moving(o, startT, endT, wstart, wend)

// Should be called by actions that turn/rotate objects, to notify
// any interested systems.  Gets called for all systems, not just
// the owner of the object.
def notify_turning(o: ObjId, startT: float, endT: float, startAng: float, endAng: float):
   for(Endpoints) ep:
      ep.notify_turning(o, startT, endT, startAng, endAng)

// Called when an object is spawned.  If parent != InvalidObject, then
// the spawned object is "contained" in that object.  Otherwise, the 
// pos field is a world position for the object.
def notify_spawn(o: ObjId, parent: ObjId, wpos: xy_f):
   for(Endpoints) ep:
      ep.notify_spawn(o, parent, wpos)

