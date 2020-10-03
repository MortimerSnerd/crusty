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

// Returns the grid position of `what`.
def pos(b:: BusEndpoint, what: ObjId) -> bool, xy_i:
   return false, xy_i{0,0}

// Returns the animation position of `what` at time `now`.
def anim_pos(b:: BusEndpoint, what: ObjId, now: float) -> xy_f:
   return xy_0

// Returns the current tile at the given time.  Returns 0 for
// objects that don't have tiles.
def anim_tile(b:: BusEndpoint, what: ObjId, now: float) -> int:
   return 0

// Returns the tile for the current game state.  (ie, not animation
// state).  Returns 0 if there is none.
def tile(b::BusEndpoint, what: ObjId) -> int:
   return 0

// Returns the animation angle of `what` at time t.
def anim_angle(b:: BusEndpoint, what: ObjId, now: float) -> float:
   return 0

// Base method for returning the facing angle of an object.
def direction(b:: BusEndpoint, what: ObjId) -> bool, Directions:
   return false, East

// Base method. Calls `body(ObjId, obj rectf)` for all objects that intersect
// rectangle `r`.
def for_objects_intersecting(b:: BusEndpoint, now: float, r: Rectf, body):
   noop()

// Base method. Calls `body(ObjId, obj rectf)` for all objects that are at
// `p`.
def for_objects_at(b:: BusEndpoint, p: xy_i, body):
   return

// Returns true, if `o` should be allowed to move to `wdestPos`.
def move_is_allowed(b:: BusEndpoint, now: float, o: ObjId, destPos: xy_i) -> bool:
   return true

// Returns false to block a turn from being made.
def turn_is_allowed(b:: BusEndpoint, now: float, o: ObjId, destDir: Directions) -> bool:
   return true

// If there's an ObjectSpect for an object, bodyfn will be executed with it.
def object_spec(b:: BusEndpoint, o: ObjId) -> ObjectSpec?:
   return nil

// Should be called by actions that move objects, to notify
// any interested systems.  Gets called for all systems, not
// just the owner.
def notify_moving(b:: BusEndpoint, o: ObjId, startT: float, endT: float, start: xy_i, end: xy_i):
   return

// Should be called by actions that change the tiles on objects, 
// to notify any interested systems.  
def notify_tile_change(b: BusEndpoint, o: ObjId, startT: float, startTile: int, endTile: int):
   return

// Should be called by actions that turn/rotate objects, to notify
// any interested systems.  Gets called for all systems, not just
// the owner of the object.
def notify_turning(b:: BusEndpoint, o: ObjId, startT: float, endT: float, startDir: Directions, endDir: Directions):
   return

// Notifys that `o` is going away on the next frame.
def notify_deleting(b:: BusEndpoint, o: ObjId) -> void:
   return

// Should be called by actions that play a sound effect for an object, 
// to notify any interested systems.
def notify_sfx(e: BusEndpoint, o: ObjId, startT: float, sfx: string, vol: float):
   return

// Changes the tile of an object.
def change_tile(b:: BusEndpoint, o: ObjId, tile: TileName):
   return

// Called when an object is spawned.  If parent != InvalidObject, then
// the spawned object is "contained" in that object.  Otherwise, the 
// pos field is a world position for the object.  All systems get this
// notification.
def notify_spawn(b:: BusEndpoint, o: ObjId, parent: ObjId?, pos: xy_i):
   return

// Called when `who` takes `what` off the map.
// It's assumed that who is on top of or adjacent to 
// `what`.
def notify_take(b:: BusEndpoint, who: ObjId, what: ObjId):
   return

// Base method
// Called to give an object to make an action.  Think calls are
// scheduled one-shot calls.  If `who` wants to be called again
// it needs to call schedule_callback() itself.
def think(b:: BusEndpoint, span: TurnSpan, who: ObjId, now: float):
   error(): "Unimplemented think call for " + to_string(who)
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

// Returns the grid position of the given object.
def pos(what: ObjId) -> bool, xy_i:
   let ep = endpointForSystem(what.system)

   if ep:
      let found, p = ep.pos(what)
      return found, p
   else:
      return false, xy_i{0,0}

def direction(what: ObjId) -> bool, Directions:
   let ep = endpointForSystem(what.system)

   if ep:
      let found, p = ep.direction(what)
      return found, p
   else:
      return false, East

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
      debug(): "think " + to_string(who) + "@" + string(now)
      ep.think(span, who, now)
   else:
      error(): "No endpoint registered for system " + who.system + " " + who.id

// Should be called by actions that move objects, to notify
// any interested systems.  Gets called for all systems, not just
// the owner of the object.
def notify_moving(o: ObjId, startT: float, endT: float, start: xy_i, end: xy_i) -> void:
   for(Endpoints) ep:
      ep.notify_moving(o, startT, endT, start, end)

// Should be called by actions that turn/rotate objects, to notify
// any interested systems.  Gets called for all systems, not just
// the owner of the object.
def notify_turning(o: ObjId, startT: float, endT: float, startDir: Directions, endDir: Directions) -> void:
   for(Endpoints) ep:
      ep.notify_turning(o, startT, endT, startDir, endDir)

// Called when an object is spawned.  If parent != InvalidObject, then
// the spawned object is "contained" in that object.  Otherwise, the 
// pos field is a world position for the object.
def notify_spawn(o: ObjId, parent: ObjId?, pos: xy_i):
   for(Endpoints) ep:
      ep.notify_spawn(o, parent, pos)

// Called when `who` takes `what` off the map.
// It's assumed that who is on top of or adjacent to 
// `what`.
def notify_take(who: ObjId, what: ObjId):
   for(Endpoints) ep:
      ep.notify_take(who, what)

// Returns true, x if `o` should be allowed to move to `destPos`.
// Returns false if one of the systems says the move should not be allowed.
def move_is_allowed(now: float, o: ObjId, destPos: xy_i) -> bool:
   for(Endpoints) ep:
      let allowed = ep.move_is_allowed(now, o, destPos)

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

// Returns the animation position of `what` at time `now`.
def anim_pos(what: ObjId, now: float) -> xy_f:
   let ep = endpointForSystem(AnimationSystem)

   if ep:
      return ep.anim_pos(what, now)
   else:
      return xy_0

// Returns the animation position of `what` at time `now`.
def anim_angle(what: ObjId, now: float) -> float:
   let ep = endpointForSystem(AnimationSystem)

   if ep:
      return ep.anim_angle(what, now)
   else:
      return 0

// Base method. Calls `body(ObjId, obj rectf)` for all objects that intersect
// rectangle `r`.
def for_objects_at(p: xy_i, body):
   for(Endpoints) ep:
      ep.for_objects_at(p, body)

def change_tile(o: ObjId, tile: TileName):
   let ep = endpointForSystem(o.system)

   if ep:
      ep.change_tile(o, tile)

// Returns false to block a turn from being made.
def turn_is_allowed(now: float, o: ObjId, destDir: Directions) -> bool:
   for(Endpoints) ep:
      if not ep.turn_is_allowed(now, o, destDir):
         return false

   return true

// Returns the current tile at the given time.  Returns 0 for
// objects that don't have tiles.
def anim_tile(what: ObjId, now: float) -> int:
   for(Endpoints) ep:
      let rv = ep.anim_tile(what, now)

      if rv > 0:
         return rv

   return 0


// Returns the tile for the current game state.  (ie, not animation
// state).  Returns 0 if there is none.
def tile(what: ObjId) -> int:
   let ep = endpointForSystem(what.system)

   if ep:
      return ep.tile(what)
   else:
      return 0
   

// Notifys that `o` is going away on the next frame.
def notify_deleting(o: ObjId) -> void:
   for(Endpoints) ep:
      ep.notify_deleting(o)

// Should be called by actions that change the tiles on objects, 
// to notify any interested systems.  
def notify_tile_change(o: ObjId, startT: float, startTile: int, endTile: int):
   for(Endpoints) ep:
      ep.notify_tile_change(o, startT, startTile, endTile)

// Should be called by actions that play a sound effect for an object, 
// to notify any interested systems.
def notify_sfx(o: ObjId, startT: float, sfx: string, vol: float):
   for(Endpoints) ep:
      ep.notify_sfx(o, startT, sfx, vol)
