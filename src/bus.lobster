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

   // Returns true if there is a wall at the given coordinate.
   def is_wall_at_impl(pos: xy_i):
      return false

   // Returns true if the given coordinate is both lit
   // and visible.
   def is_lit_and_visible_impl(pos: xy_i) -> bool:
      return true

   // Returns the living thing at `pos` or nil if 
   // there is none.
   def living_thing_at_impl(pos: xy_i) -> ObjId?:
      return nil
   
   // Returns the sound set associated with `o`.
   def object_sounds_impl(o: ObjId) -> ObjectSounds?:
      return nil

   // Returns true if `what` is equipped somewhere.
   def item_is_equipped_impl(what: ObjId) -> bool:
      return false

   // Returns the item slot the object can be equipped in.
   // ItemSlot_None if it is not equippable.
   def equip_slot_impl(what: ObjId) -> ItemSlot:
      return ItemSlot_None

   // Equips `what` on `who` at it's default item slot.  
   // It's an error to equip an item whose slot is already full.
   def equip_impl(who: ObjId, what: ObjId):
      return 

   // Unequips an item that is equipped.
   def unequip_impl(who: ObjId, what: ObjId):
      return

   // Returns the grid position of `what`.
   def pos_impl(what: ObjId) -> bool, xy_i:
      return false, xy_i{0,0}

   // Returns the animation position of `what` at time `now`.
   def anim_pos_impl(what: ObjId, now: float) -> xy_f:
      return xy_0

   // Plays animation named `name` for `obj` immediately.
   def play_animation_impl(obj: ObjId, name: string):
      return

   // Returns the current tile at the given time.  Returns 0 for
   // objects that don't have tiles.
   def anim_tile_impl(what: ObjId, now: float) -> int:
      return 0

   // Returns the tile for the current game state.  (ie, not animation
   // state).  Returns 0 if there is none.
   def tile_impl(what: ObjId) -> int:
      return 0
      
   // Returns the object that contains `what` or nil if it's on the map
   // and not in a container.
   def container_of_impl(what: ObjId) -> ObjId?:
      return nil

   // Returns the state flags for the given Object. See StateFlags
   // in config.fbs.
   def object_state_impl(what: ObjId) -> StateFlags:
      return StateFlags(0)

   // Returns [StatEnt] for the object.  Will be empty if the object
   // doesn't have stats.
   def object_stats_impl(what: ObjId) -> [StatEnt]:
      return []

   // Passes in the current state to body, and updates it with
   // whatever body returns.
   def modify_object_state_impl(what: ObjId, body):
      return

   // Returns the animation angle of `what` at time t.
   def anim_angle_impl(what: ObjId, now: float) -> float:
      return 0

   // Base method for returning the facing angle of an object.
   def direction_impl(what: ObjId) -> bool, Directions:
      return false, East

   // Base method. Calls `body(ObjId, obj rectf)` for all objects that intersect
   // rectangle `r`.
   def for_objects_intersecting_impl(now: float, r: Rectf, body):
      return

   // Calls body for each object inside of `what`
   def for_objects_in_impl(what: ObjId, body):
      return

   // Returns the object equipped at `where`, or nil if there is
   // none.
   def equipment_at_impl(who: ObjId, where: ItemSlot) -> ObjId?:
      return nil

   // You can return false to make a position block light even 
   // if there is no wall there.
   def passes_light_impl(pos: xy_i) -> bool:
      return true

   // Calls body(ObjId, ObjectSpec) for all lights that are on the
   // map and that are turned on.
   def for_all_enabled_lights_impl(body):
      return

   // Base method. Calls `body(ObjId, obj rectf)` for all objects that are at
   // `p`.
   def for_objects_at_impl(p: xy_i, body):
      return

   // Returns true, if `o` should be allowed to move to `wdestPos`.
   def move_is_allowed_impl(now: float, o: ObjId, destPos: xy_i) -> bool:
      return true

   // Returns false to block a turn from being made.
   def turn_is_allowed_impl(now: float, o: ObjId, destDir: Directions) -> bool:
      return true

   // If there's an ObjectSpect for an object, bodyfn will be executed with it.
   def object_spec_impl(o: ObjId) -> ObjectSpec:
      return EmptyObjectSpec

   // Called when it's detected a living thing has died.
   def notify_death_impl(o: ObjId, now: float):
      return

   // Should be called by actions that move objects, to notify
   // any interested systems.  Gets called for all systems, not
   // just the owner.
   def notify_moving_impl(o: ObjId, startT: float, endT: float, start: xy_i, end: xy_i) -> void:
      return

   // Called when `who` drops `what` on the ground at `where`.
   def notify_drop_impl(startT: float, who: ObjId, what: ObjId, where: xy_i):
      return

   // Called by actions where an actor puts an object into another object.
   def notify_put_impl(startT: float, who: ObjId, what: ObjId, where: ObjId):
      return

   // Called by actions that take an item out of a container.  Not to be
   // used for taking items off the ground.
   def notify_take_out_impl(startT: float, who: ObjId, what: ObjId, from_where:ObjId):
      return

   // Should be called by actions that change the tiles on objects, 
   // to notify any interested systems.  
   def notify_tile_change_impl(o: ObjId, startT: float, startTile: int, endTile: int):
      return

   // Should be called by actions that turn/rotate objects, to notify
   // any interested systems.  Gets called for all systems, not just
   // the owner of the object.
   def notify_turning_impl(o: ObjId, startT: float, endT: float, startDir: Directions, endDir: Directions):
      return

   // Notifys that `o` is going away on the next frame.
   def notify_deleting_impl(o: ObjId) -> void:
      return

   // Should be called by actions that play a sound effect for an object, 
   // to notify any interested systems.
   def notify_sfx_impl(o: ObjId, startT: float, sfx: string, vol: float):
      return

   // Should be called by actions that start an animation at a 
   // certain point in the turn.
   def notify_animation_impl(o: ObjId, startT: float, name: string):
      return

   // Changes the tile of an object.
   def change_tile_impl(o: ObjId, tile: TileName):
      return

   // Called when an object is spawned.  If parent != InvalidObject, then
   // the spawned object is "contained" in that object.  Otherwise, the 
   // pos field is a world position for the object.  All systems get this
   // notification.
   def notify_spawn_impl(o: ObjId, parent: ObjId?, pos: xy_i):
      return

   // Called when `who` takes `what` off the map.
   // It's assumed that who is on top of or adjacent to 
   // `what`.  This should not be used for taking things out
   // of a container.
   def notify_take_impl(who: ObjId, what: ObjId):
      return

   // Base method
   // Called to give an object to make an action.  Think calls are
   // scheduled one-shot calls.  If `who` wants to be called again
   // it needs to call schedule_callback() itself.
   def think_impl(span: TurnSpan, who: ObjId, now: float):
      error(): "Unimplemented think call for " + who
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
   return Endpoints[what.system].pos_impl(what)

def direction(what: ObjId) -> bool, Directions:
   return Endpoints[what.system].direction_impl(what)

// Calls `body(ObjId, obj rectf)` for all objects that intersect
// rectangle `r`.
def for_objects_intersecting(now: float, r: Rectf, body):
   for(Endpoints) ep:
      if ep.system != InvalidSystem: ep.for_objects_intersecting_impl(now, r, body)

// Called to give an object to make an action.  Think calls are
// scheduled one-shot calls.  If `who` wants to be called again
// it needs to call schedule_callback() itself.
def think(span: TurnSpan, who: ObjId, now: float):
   let ep = Endpoints[who.system]

   debug(): "think " + who + "@" + now
   ep.think_impl(span, who, now)

// Should be called by actions that move objects, to notify
// any interested systems.  Gets called for all systems, not just
// the owner of the object.
def notify_moving(o: ObjId, startT: float, endT: float, start: xy_i, end: xy_i) -> void:
   for(Endpoints) ep:
      if ep.system != InvalidSystem: ep.notify_moving_impl(o, startT, endT, start, end)

// Called by actions where an actor puts an object into another object.
def notify_put(startT: float, who: ObjId, what: ObjId, where: ObjId):
   for(Endpoints) ep:
      if ep.system != InvalidSystem: ep.notify_put_impl(startT, who, what, where)

// Called by actions that take an item out of a container.  Not to be
// used for taking items off the ground.
def notify_take_out(startT: float, who: ObjId, what: ObjId, from_where:ObjId):
   for(Endpoints) ep:
      if ep.system != InvalidSystem: ep.notify_take_out_impl(startT, who, what, from_where)

// Should be called by actions that turn/rotate objects, to notify
// any interested systems.  Gets called for all systems, not just
// the owner of the object.
def notify_turning(o: ObjId, startT: float, endT: float, startDir: Directions, endDir: Directions) -> void:
   for(Endpoints) ep:
      if ep.system != InvalidSystem: ep.notify_turning_impl(o, startT, endT, startDir, endDir)

// Called when an object is spawned.  If parent != InvalidObject, then
// the spawned object is "contained" in that object.  Otherwise, the 
// pos field is a world position for the object.
def notify_spawn(o: ObjId, parent: ObjId?, pos: xy_i):
   for(Endpoints) ep:
      if ep.system != InvalidSystem: ep.notify_spawn_impl(o, parent, pos)

// Called when `who` takes `what` off the map.
// It's assumed that who is on top of or adjacent to 
// `what`.
def notify_take(who: ObjId, what: ObjId):
   for(Endpoints) ep:
      if ep.system != InvalidSystem: ep.notify_take_impl(who, what)

// Called when `who` drops `what` on the ground at `where`.
def notify_drop(startT: float, who: ObjId, what: ObjId, where: xy_i):
   for(Endpoints) ep:
      if ep.system != InvalidSystem: ep.notify_drop_impl(startT, who, what, where)

// Returns true, x if `o` should be allowed to move to `destPos`.
// Returns false if one of the systems says the move should not be allowed.
def move_is_allowed(now: float, o: ObjId, destPos: xy_i) -> bool:
   for(Endpoints) ep:
      if ep.system != InvalidSystem:
         let allowed = ep.move_is_allowed_impl(now, o, destPos)

         if not allowed:
            return false

   return true

// If there's an ObjectSpect for an object, bodyfn will be executed with it.
def object_spec(o: ObjId) -> ObjectSpec:
   return Endpoints[o.system].object_spec_impl(o)

// Returns the animation position of `what` at time `now`.
def anim_pos(what: ObjId, now: float) -> xy_f:
   return Endpoints[AnimationSystem].anim_pos_impl(what, now)

// Returns the animation position of `what` at time `now`.
def anim_angle(what: ObjId, now: float) -> float:
   return Endpoints[AnimationSystem].anim_angle_impl(what, now)

// Base method. Calls `body(ObjId, obj rectf)` for all objects that intersect
// rectangle `r`.
def for_objects_at(p: xy_i, body):
   for(Endpoints) ep:
      if ep.system != InvalidSystem: ep.for_objects_at_impl(p, body)

def change_tile(o: ObjId, tile: TileName):
   Endpoints[o.system].change_tile_impl(o, tile)

// Returns false to block a turn from being made.
def turn_is_allowed(now: float, o: ObjId, destDir: Directions) -> bool:
   for(Endpoints) ep:
      if not ep.turn_is_allowed_impl(now, o, destDir):
         return false

   return true

// Returns the current tile at the given time.  Returns 0 for
// objects that don't have tiles.
def anim_tile(what: ObjId, now: float) -> int:
   let ep = Endpoints[AnimationSystem]

   return ep.anim_tile_impl(what, now)


// Returns the tile for the current game state.  (ie, not animation
// state).  Returns 0 if there is none.
def tile(what: ObjId) -> int:
   return Endpoints[what.system].tile_impl(what)
   
// Notifys that `o` is going away on the next frame.
def notify_deleting(o: ObjId) -> void:
   for(Endpoints) ep:
      if ep.system != InvalidSystem:
         ep.notify_deleting_impl(o)

// Should be called by actions that change the tiles on objects, 
// to notify any interested systems.  
def notify_tile_change(o: ObjId, startT: float, startTile: int, endTile: int):
   for(Endpoints) ep:
      if ep.system != InvalidSystem:
         ep.notify_tile_change_impl(o, startT, startTile, endTile)

// Should be called by actions that play a sound effect for an object, 
// to notify any interested systems.
def notify_sfx(o: ObjId, startT: float, sfx: string, vol: float):
   for(Endpoints) ep:
      if ep.system != InvalidSystem:
         ep.notify_sfx_impl(o, startT, sfx, vol)

// Calls body(ObjId, ObjectSpec) for all lights that are on the
// map and that are turned on.
def for_all_enabled_lights(body):
   for(Endpoints) ep:
      ep.for_all_enabled_lights_impl(body)

// Plays animation named `name` for `obj` immediately.
def play_animation(obj: ObjId, name: string):
   Endpoints[GObjSystem].play_animation_impl(obj, name)

// Should be called by actions that start an animation at a 
// certain point in the turn.
def notify_animation(o: ObjId, startT: float, name: string):
   for(Endpoints) ep:
      if ep.system != InvalidSystem:
         ep.notify_animation_impl(o, startT, name)

// Returns the state flags for the given Object. See StateFlags
// in config.fbs.
def object_state(what: ObjId) -> StateFlags:
   return Endpoints[what.system].object_state_impl(what)

// Passes in the current state to body, and updates it with
// whatever body returns.
def modify_object_state(what: ObjId, body):
   return Endpoints[what.system].modify_object_state_impl(what, body)

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
   Endpoints[what.system].for_objects_in_impl(what, body)

// Returns the object that contains `what` or nil if it's on the map
// and not in a container.
def container_of(what: ObjId) -> ObjId?:
   for(Endpoints) ep:
      let o = ep.container_of_impl(what)

      if o:
         return o

   return nil

// Returns [StatEnt] for the object.  Will be empty if the object
// doesn't have stats.
def object_stats(what: ObjId) -> [StatEnt]:
   return Endpoints[what.system].object_stats_impl(what)

// Returns the object equipped at `where`, or nil if there is
// none.
def equipment_at(who: ObjId, where: ItemSlot) -> ObjId?:
   return Endpoints[who.system].equipment_at_impl(who, where)

// Returns the item slot the object can be equipped in.
// ItemSlot_None if it is not equippable.
def equip_slot(what: ObjId) -> ItemSlot:
   return Endpoints[what.system].equip_slot_impl(what)

// Equips `what` on `who` at it's default item slot.  
// It's an error to equip an item whose slot is already full.
def equip(who: ObjId, what: ObjId):
   Endpoints[what.system].equip_impl(who, what)

// Returns true if `what` is equipped somewhere.
def item_is_equipped(what: ObjId) -> bool:
   return Endpoints[what.system].item_is_equipped_impl(what)

// Unequips an item that is equipped.
def unequip(who: ObjId, what: ObjId):
   Endpoints[what.system].unequip_impl(who, what)

// Called when it's detected a living thing has died.
def notify_death(o: ObjId, now: float):
   for(Endpoints) ep:
      ep.notify_death_impl(o, now)

// Returns the sound set associated with `o`.
def object_sounds(o: ObjId) -> ObjectSounds?:
   return Endpoints[o.system].object_sounds_impl(o)

// Helper for working with config SfxSpecs
def notify_sfx_spec(o: ObjId, startT: float, fx: SfxSpec?):
   if fx:
      notify_sfx(o, startT, fx.sfx(), fx.vol())

// Returns the living thing at `pos` or nil if 
// there is none.
def living_thing_at(pos: xy_i) -> ObjId?:
   return Endpoints[MapSystem].living_thing_at_impl(pos)   

// Returns true if the given coordinate is both lit
// and visible.
def is_lit_and_visible(pos: xy_i) -> bool:
   return Endpoints[MapSystem].is_lit_and_visible_impl(pos)

// Returns true if there is a wall at the given coordinate.
def is_wall_at(pos: xy_i):
   return Endpoints[MapSystem].is_wall_at_impl(pos)

// You can return false to make a position block light even 
// if there is no wall there.
def passes_light(pos: xy_i) -> bool:
   for(Endpoints) ep:
      if not ep.passes_light_impl(pos):
         return false

   return true
