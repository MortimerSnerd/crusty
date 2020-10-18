// Allows functions to be called for ObjIds without the callers needing to 
// know where or how the owner of the ObjId is implemented. In practice, prevents
// accidental creation of import cycles.
import from "../../../src/crusty/src/"
import algs
import config
import config_generated
import logging
import objutils
import vec

// Base class for system specific callback objects.
class BusEndpoint:
   system: ObjectSystem
   // Returns the grid position of `what`.
   def pos(what: ObjId) -> bool, xy_i:
      return false, xy_i{0,0}

   // Returns the animation position of `what` at time `now`.
   def anim_pos(what: ObjId, now: float) -> xy_f:
      return xy_0

   // Plays animation named `name` for `obj` immediately.
   def play_animation(obj: ObjId, name: string):
      return

   // Returns the current tile at the given time.  Returns 0 for
   // objects that don't have tiles.
   def anim_tile(what: ObjId, now: float) -> int:
      return 0

   // Returns the tile for the current game state.  (ie, not animation
   // state).  Returns 0 if there is none.
   def tile(what: ObjId) -> int:
      return 0
      
   // Returns the object that contains `what` or nil if it's on the map
   // and not in a container.
   def container_of(what: ObjId) -> ObjId?:
      return nil

   // Returns the state flags for the given Object. See StateFlags
   // in config.fbs.
   def object_state(what: ObjId) -> StateFlags:
      return StateFlags(0)

   // Passes in the current state to body, and updates it with
   // whatever body returns.
   def modify_object_state(what: ObjId, body):
      return

   // Returns the animation angle of `what` at time t.
   def anim_angle(what: ObjId, now: float) -> float:
      return 0

   // Base method for returning the facing angle of an object.
   def direction(what: ObjId) -> bool, Directions:
      return false, East

   // Base method. Calls `body(ObjId, obj rectf)` for all objects that intersect
   // rectangle `r`.
   def for_objects_intersecting(now: float, r: Rectf, body):
      return

   // Calls body for each object inside of `what`
   def for_objects_in(what: ObjId, body):
      return

   // Calls body(ObjId, ObjectSpec) for all lights that are on the
   // map and that are turned on.
   def for_all_enabled_lights(body):
      return

   // Base method. Calls `body(ObjId, obj rectf)` for all objects that are at
   // `p`.
   def for_objects_at(p: xy_i, body):
      return

   // Returns true, if `o` should be allowed to move to `wdestPos`.
   def move_is_allowed(now: float, o: ObjId, destPos: xy_i) -> bool:
      return true

   // Returns false to block a turn from being made.
   def turn_is_allowed(now: float, o: ObjId, destDir: Directions) -> bool:
      return true

   // If there's an ObjectSpect for an object, bodyfn will be executed with it.
   def object_spec(o: ObjId) -> ObjectSpec:
      return EmptyObjectSpec

   // Should be called by actions that move objects, to notify
   // any interested systems.  Gets called for all systems, not
   // just the owner.
   def notify_moving(o: ObjId, startT: float, endT: float, start: xy_i, end: xy_i) -> void:
      return

   // Should be called by actions that change the tiles on objects, 
   // to notify any interested systems.  
   def notify_tile_change(o: ObjId, startT: float, startTile: int, endTile: int):
      return

   // Should be called by actions that turn/rotate objects, to notify
   // any interested systems.  Gets called for all systems, not just
   // the owner of the object.
   def notify_turning(o: ObjId, startT: float, endT: float, startDir: Directions, endDir: Directions):
      return

   // Notifys that `o` is going away on the next frame.
   def notify_deleting(o: ObjId) -> void:
      return

   // Should be called by actions that play a sound effect for an object, 
   // to notify any interested systems.
   def notify_sfx(o: ObjId, startT: float, sfx: string, vol: float):
      return

   // Should be called by actions that start an animation at a 
   // certain point in the turn.
   def notify_animation(o: ObjId, startT: float, name: string):
      return

   // Changes the tile of an object.
   def change_tile(o: ObjId, tile: TileName):
      return

   // Called when an object is spawned.  If parent != InvalidObject, then
   // the spawned object is "contained" in that object.  Otherwise, the 
   // pos field is a world position for the object.  All systems get this
   // notification.
   def notify_spawn(o: ObjId, parent: ObjId?, pos: xy_i):
      return

   // Called when `who` takes `what` off the map.
   // It's assumed that who is on top of or adjacent to 
   // `what`.
   def notify_take(who: ObjId, what: ObjId):
      return

   // Base method
   // Called to give an object to make an action.  Think calls are
   // scheduled one-shot calls.  If `who` wants to be called again
   // it needs to call schedule_callback() itself.
   def think(span: TurnSpan, who: ObjId, now: float):
      error(): "Unimplemented think call for " + to_string(who)
      noop()

// Registered busses.
private let Endpoints:[BusEndpoint] = []


// Should be call for all systems that own ObjId's.  
def bus_register_endpoint(ep: BusEndpoint):
   if length(Endpoints) == 0:
      for(NumSystemSentinel) i:
         push(Endpoints, BusEndpoint{system: InvalidSystem})

   assert ep.system != InvalidSystem
   Endpoints[ep.system] = ep

// Returns the grid position of the given object.
def pos(what: ObjId) -> bool, xy_i:
   return Endpoints[what.system].pos(what)

def direction(what: ObjId) -> bool, Directions:
   return Endpoints[what.system].direction(what)

// Calls `body(ObjId, obj rectf)` for all objects that intersect
// rectangle `r`.
def for_objects_intersecting(now: float, r: Rectf, body):
   for(Endpoints) ep:
      if ep.system != InvalidSystem: ep.for_objects_intersecting(now, r, body)

// Called to give an object to make an action.  Think calls are
// scheduled one-shot calls.  If `who` wants to be called again
// it needs to call schedule_callback() itself.
def think(span: TurnSpan, who: ObjId, now: float):
   let ep = Endpoints[who.system]

   debug(): "think " + to_string(who) + "@" + string(now)
   ep.think(span, who, now)

// Should be called by actions that move objects, to notify
// any interested systems.  Gets called for all systems, not just
// the owner of the object.
def notify_moving(o: ObjId, startT: float, endT: float, start: xy_i, end: xy_i) -> void:
   for(Endpoints) ep:
      if ep.system != InvalidSystem: ep.notify_moving(o, startT, endT, start, end)

// Should be called by actions that turn/rotate objects, to notify
// any interested systems.  Gets called for all systems, not just
// the owner of the object.
def notify_turning(o: ObjId, startT: float, endT: float, startDir: Directions, endDir: Directions) -> void:
   for(Endpoints) ep:
      if ep.system != InvalidSystem: ep.notify_turning(o, startT, endT, startDir, endDir)

// Called when an object is spawned.  If parent != InvalidObject, then
// the spawned object is "contained" in that object.  Otherwise, the 
// pos field is a world position for the object.
def notify_spawn(o: ObjId, parent: ObjId?, pos: xy_i):
   for(Endpoints) ep:
      if ep.system != InvalidSystem: ep.notify_spawn(o, parent, pos)

// Called when `who` takes `what` off the map.
// It's assumed that who is on top of or adjacent to 
// `what`.
def notify_take(who: ObjId, what: ObjId):
   for(Endpoints) ep:
      if ep.system != InvalidSystem: ep.notify_take(who, what)

// Returns true, x if `o` should be allowed to move to `destPos`.
// Returns false if one of the systems says the move should not be allowed.
def move_is_allowed(now: float, o: ObjId, destPos: xy_i) -> bool:
   for(Endpoints) ep:
      if ep.system != InvalidSystem:
         let allowed = ep.move_is_allowed(now, o, destPos)

         if not allowed:
            return false

   return true

// If there's an ObjectSpect for an object, bodyfn will be executed with it.
def object_spec(o: ObjId) -> ObjectSpec:
   return Endpoints[o.system].object_spec(o)

// Returns the animation position of `what` at time `now`.
def anim_pos(what: ObjId, now: float) -> xy_f:
   return Endpoints[AnimationSystem].anim_pos(what, now)

// Returns the animation position of `what` at time `now`.
def anim_angle(what: ObjId, now: float) -> float:
   return Endpoints[AnimationSystem].anim_angle(what, now)

// Base method. Calls `body(ObjId, obj rectf)` for all objects that intersect
// rectangle `r`.
def for_objects_at(p: xy_i, body):
   for(Endpoints) ep:
      if ep.system != InvalidSystem: ep.for_objects_at(p, body)

def change_tile(o: ObjId, tile: TileName):
   Endpoints[o.system].change_tile(o, tile)

// Returns false to block a turn from being made.
def turn_is_allowed(now: float, o: ObjId, destDir: Directions) -> bool:
   for(Endpoints) ep:
      if not ep.turn_is_allowed(now, o, destDir):
         return false

   return true

// Returns the current tile at the given time.  Returns 0 for
// objects that don't have tiles.
def anim_tile(what: ObjId, now: float) -> int:
   let ep = Endpoints[AnimationSystem]

   return ep.anim_tile(what, now)


// Returns the tile for the current game state.  (ie, not animation
// state).  Returns 0 if there is none.
def tile(what: ObjId) -> int:
   return Endpoints[what.system].tile(what)
   
// Notifys that `o` is going away on the next frame.
def notify_deleting(o: ObjId) -> void:
   for(Endpoints) ep:
      if ep.system != InvalidSystem:
         ep.notify_deleting(o)

// Should be called by actions that change the tiles on objects, 
// to notify any interested systems.  
def notify_tile_change(o: ObjId, startT: float, startTile: int, endTile: int):
   for(Endpoints) ep:
      if ep.system != InvalidSystem:
         ep.notify_tile_change(o, startT, startTile, endTile)

// Should be called by actions that play a sound effect for an object, 
// to notify any interested systems.
def notify_sfx(o: ObjId, startT: float, sfx: string, vol: float):
   for(Endpoints) ep:
      if ep.system != InvalidSystem:
         ep.notify_sfx(o, startT, sfx, vol)

// Calls body(ObjId, ObjectSpec) for all lights that are on the
// map and that are turned on.
def for_all_enabled_lights(body):
   for(Endpoints) ep:
      ep.for_all_enabled_lights(body)

// Plays animation named `name` for `obj` immediately.
def play_animation(obj: ObjId, name: string):
   Endpoints[GObjSystem].play_animation(obj, name)

// Should be called by actions that start an animation at a 
// certain point in the turn.
def notify_animation(o: ObjId, startT: float, name: string):
   for(Endpoints) ep:
      if ep.system != InvalidSystem:
         ep.notify_animation(o, startT, name)

// Returns the state flags for the given Object. See StateFlags
// in config.fbs.
def object_state(what: ObjId) -> StateFlags:
   return Endpoints[what.system].object_state(what)

// Passes in the current state to body, and updates it with
// whatever body returns.
def modify_object_state(what: ObjId, body):
   return Endpoints[what.system].modify_object_state(what, body)

// Helper function that returns an array of objects at `p`
// that pass `predfn`.
def collect_objects_at(p: xy_i, predfn) -> [ObjId]:
   let rv = []
   for_objects_at(p) o:
      if o and predfn(o):
         push(rv, o)

   return rv

// Calls body for each object inside of `what`
def for_objects_in(what: ObjId, body):
   Endpoints[what.system].for_objects_in(what, body)

// Returns the object that contains `what` or nil if it's on the map
// and not in a container.
def container_of(what: ObjId) -> ObjId?:
   for(Endpoints) ep:
      let o = ep.container_of(what)

      if o:
         return o

   return nil
