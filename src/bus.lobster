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
   error(): "Unimplemented angle() call for " + string(b)
   return false, 0

// Base method. Calls `body(ObjId, obj rectf)` for all objects that intersect
// rectangle `r`.
def forObjectsIntersecting(b:: BusEndpoint, now: float, r: Rectf, body):
   noop()

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

