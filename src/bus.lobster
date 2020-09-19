// Allows functions to be called for ObjIds without the callers needing to 
// know where or how the owner of the ObjId is implemented. In practice, prevents
// accidental creation of import cycles.
import from "../../../src/crusty/src/"
import algs
import config_generated
import logging
import objutils
import vec

// Base class for system specific callback objects.
class BusEndpoint:
   system: ObjectSystem

// Registered busses.
private let Endpoints:[BusEndpoint] = []

// Base method for returning the center animation position of an object.
def anim_pos(b:: BusEndpoint, what: ObjId, t: float) -> bool, xy_f:
   return false, xy_0

// Returns the grid position of `what`.
def pos(b:: BusEndpoint, what: ObjId) -> bool, xy_i:
   return false, xy_i{0,0}

// Base method for returning the facing angle of an object.
def angle(b:: BusEndpoint, what: ObjId, t: float) -> bool, float:
   return false, 0

// Base method. Calls `body(ObjId, obj rectf)` for all objects that intersect
// rectangle `r`.
def for_objects_intersecting(b:: BusEndpoint, now: float, r: Rectf, body):
   noop()

// Returns true, if `o` should be allowed to move to `wdestPos`.
def move_is_allowed(b:: BusEndpoint, now: float, o: ObjId, wdestPos: xy_f) -> bool:
   return true

// If there's an ObjectSpect for an object, bodyfn will be executed with it.
def object_spec(b:: BusEndpoint, o: ObjId) -> ObjectSpec?:
   return nil

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
def think(b:: BusEndpoint, span: TurnSpan, who: ObjId, now: float):
   error(): "Unimplemented think call for " + string(who)
   noop()

private def endpointForSystem(s: ObjectSystem) -> BusEndpoint?:
   let i = find(Endpoints) ep: ep.system == s

   if i < 0:
      return nil
   else:
      return Endpoints[i]

// Should be call for all systems that own ObjId's.  
def bus_register_endpoint(ep: BusEndpoint):
   assert ep.system != InvalidSystem
   let existing = endpointForSystem(ep.system)

   assert not existing
   push(Endpoints, ep)

// Returns the animation position of the given object.
def anim_pos(what: ObjId, now: float) -> bool, xy_f:
   let ep = endpointForSystem(what.system)

   if ep:
      let found, p = ep.anim_pos(what, now)
      return found, p
   else:
      return false, xy_0

// Returns the grid position of the given object.
def pos(what: ObjId) -> bool, xy_f:
   let ep = endpointForSystem(what.system)

   if ep:
      let found, p = ep.pos(what)
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
def for_objects_intersecting(now: float, r: Rectf, body):
   for(Endpoints) ep:
      ep.for_objects_intersecting(now, r, body)

// Called to give an object to make an action.  Think calls are
// scheduled one-shot calls.  If `who` wants to be called again
// it needs to call schedule_callback() itself.
def think(span: TurnSpan, who: ObjId, now: float):
   let ep = endpointForSystem(who.system)

   if ep:
      ep.think(span, who, now)
   else:
      error(): "No endpoint registered for system " + string(who.system) + " " + string(who.id)

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

// Returns true, x if `o` should be allowed to move to `wdestPos`.
// Returns false, nameOfBlockingSystem if the move should not be allowed.
def move_is_allowed(now: float, o: ObjId, wdestPos: xy_f) -> bool:
   for(Endpoints) ep:
      let allowed = ep.move_is_allowed(now, o, wdestPos)

      if not allowed:
         return false

   return true

// If there's an ObjectSpect for an object, bodyfn will be executed with it.
def object_spec(o: ObjId) -> ObjectSpec?:
   let ep = endpointForSystem(o.system)

   if ep:
      return ep.object_spec(o)
   else:
      return nil
