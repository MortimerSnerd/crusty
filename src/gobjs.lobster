import from "../../../src/crusty/src/"
import actions
import algs
import bus
import callbacks
import config
import consts
import config_generated
import logging
import maps
import objutils
import std
import texture
import tileing

class GOInst : ObjId
   kind_idx: int // index into OSpecs for ObjectKind
   pos: xy_i // Grid position.
   dir: Directions
   curTile: int
   parent: ObjId?
   playing_anim: int = -1
   frame_idx: int = 0 
   frame_left: float = 0.0
   state: int = 0
   stats: [StatEnt] = []  // Not all objects can have stats, but we take the small cost anyway.

struct GOFrame:
   frame: TileName
   duration: float

class GOAnim:
   name: string
   kind: AnimationKind
   frames: [GOFrame]

// For now we just use the flatbuffer instance.  Hooray laziness.
private let OSpecs : [ObjectSpec] = []
private var ObjTx : GridTiledTexture? = nil
private let Animations: [GOAnim] = []

// Array of instances, indexed by ObjId.id.  
// Can be nil if an instance with that id was
// deleted.
private let GOInstances: [GOInst?] = []

// For now, just do a naive scan. 
// Expands the array if there are no free objects.
private def find_free_id() -> int:
   for(GOInstances) obj, i:
      if obj == nil:
         return i

   // Add a slot.
   push(GOInstances, nil)
   return length(GOInstances) - 1

// Indexed by StatTemplateName
private let BaseStats : [[StatEnt]] = []

// Call to work with item stats.  Will generate them if they
// don't already exist.
private def object_stats_private(o: GOInst) -> [StatEnt]:
   let os = OSpecs[o.kind_idx]

   if os.stat_base == StatTemplateName_NoStats:
      return []
   else:
      if length(o.stats) == 0:
         o.stats = copy(BaseStats[os.stat_base])

      return o.stats

def gobj_short_name(o: GOInst?) -> string:
   if o:
      return OSpecs[o.kind_idx].short_name
   else:
      return "Wot"

private def render_offset(os: ObjectSpec, facing: Directions) -> xyz_f:
   if os.flags & ItemFlags_AbutsWall:
      let fv = all_dirs_f[facing] * os.dir_offset
      return xyz_f{fv.x, fv.y, AboveWallZ - OnFloorZ}
   else:
      return xyz_0

private def find_animation(name: string):
   return find(Animations) x: x.name == name

def gobjs_update():
   let dT = gl_delta_time()
   for(GOInstances) o:
      if o:
         if o.playing_anim >= 0:
            let anim = Animations[o.playing_anim]
            o.frame_left -= dT
            if o.frame_left <= 0:
               o.frame_idx += 1
               if o.frame_idx >= length(anim.frames):
                  switch anim.kind:
                     case AnimationKind_OneShot:
                        o.playing_anim = -1
                     case AnimationKind_Loop:
                        o.frame_idx = 0
                        o.frame_left += anim.frames[0].duration
                        o.curTile = anim.frames[0].frame
               else:
                  o.frame_left += anim.frames[o.frame_idx].duration
                  o.curTile = anim.frames[o.frame_idx].frame

private def equipped_as_melee(o: GOInst) -> bool:
   if o.parent:
      let sp = OSpecs[o.kind_idx]
      let ws = sp.weapon_stats()

      return o.state & StateFlags_Equipped and ws and sp.slot() == ItemSlot_Melee
   else:
      return false

private def center_pos_of(o: GOInst, now: float, spec: ObjectSpec, z: float) -> xy_f, xyz_f:
   let p = anim_pos(o, now)
   return p, xyz_f{p.x, p.y, z} + render_offset(spec, o.dir)

def gobjs_draw(now: float, view: Rectf):
   if ObjTx:
      gl_set_primitive_texture(0, ObjTx.texture)
      gl_blend(blend_alpha)
      for(GOInstances) o:
         if o:
            if o.parent and o.parent is GOInst:
               if equipped_as_melee(o):
                  let parspec = OSpecs[o.parent.kind_idx]
                  let apos, par_center = center_pos_of(o.parent, now, 
                                                 parspec, UnderLivingZ)

                  if contains(view, apos):
                     let a = anim_angle(o.parent, now) + parspec.right_rotation
                     let sc = sincos(a)
                     let avec = rotate_around_origin(normalize(xy_f{parspec.wield_offset_x(),
                                                                    parspec.wield_offset_y()}), 
                                                     sc) * 0.5
                                      
                     renderSprite(ObjTx, OSpecs[o.kind_idx].static_tile(),
                                  xyz_f{par_center.x + avec.x,
                                        par_center.y + avec.y,
                                        par_center.z}, xy_1, sc)

            else:
               let p = anim_pos(o, now)
               
               if contains(view, p):
                  let oflags = OSpecs[o.kind_idx].flags

                  // Only immobile objects like furniture are drawn when they 
                  // occupy a grid that is not visible.
                  if not PlayerViz or oflags & ItemFlags_Immobile != 0 or test(PlayerViz, o.pos, vfVisible|vfLit):
                     let a = anim_angle(o, now) + OSpecs[o.kind_idx].right_rotation
                     let ti = anim_tile(o, now)
                     let z = if oflags & ItemFlags_Living: LivingZ else: OnFloorZ
                     let dpos = xyz_f{p.x, p.y, z} + render_offset(OSpecs[o.kind_idx], o.dir)
                     
                     renderSprite(ObjTx, ti, dpos, xy_1, sincos(a))

def gobjs_spawn(okind: ObjectKind, pos: xy_i, dir: Directions, parent: ObjId? = nil) -> ObjId:
   let found, ki = binary_search_by_key(OSpecs, int(okind)) a, b:
      int(a.kind) - b

   //TODO test to see if it can be placed at pos.
   if found:
      let rv = GOInst{system: GObjSystem,
                      id: find_free_id(),
                      pos: pos,
                      dir: dir, 
                      curTile: OSpecs[ki].static_tile, 
                      kind_idx: ki, 
                      parent: parent, 
                      state: OSpecs[ki].initial_state}
      GOInstances[rv.id] = rv
      notify_spawn(rv, nil, pos)

      return rv
   else:
      error(): "No OSpec for " + okind
      assert false
                            
def gobjs_tests():
   gobjs_spawn(ObjectKind_Sword, xy_i{0,0}, North)

// Bus endpoint implementation.
class GobjEndpoint : BusEndpoint
   def for_all_enabled_lights_impl(body):
      for(GOInstances) o:
         if o and not o.parent and OSpecs[o.kind_idx].flags & ItemFlags_EmitsLight:
            body(o, OSpecs[o.kind_idx])

   def tile_impl(what: ObjId) -> int:
      if what is GOInst:
         return what.curTile
      else:
         return 0

   def object_stats_impl(what: ObjId) -> [StatEnt]:
      if what is GOInst:
         return object_stats_private(what)
      else:
         return []

   def change_tile_impl(o: ObjId, tile: TileName):
      if o is GOInst:
         o.curTile = tile
         // If a tile is set manually, cancel animation.
         o.playing_anim = -1

   def pos_impl(what: ObjId) -> bool, xy_i:
      if what is GOInst:
         return true, what.pos
      else:
         return false, xy_i{0,0}

   def direction_impl(what: ObjId) -> bool, Directions:
      if what is GOInst:
         return true, what.dir
      else:
         return false, East

   def for_objects_intersecting_impl(now: float, r: Rectf, body):
      for(GOInstances) ob:
         if ob:
            let p = gridToWorld(ob.pos)
            let bb = mkRectfRel(p - xy_h, xy_1)

            if bb.overlaps(r):
               body(ob, bb)

   def think_impl(span: TurnSpan, who: ObjId, now: float):
      // We should't have any calls scheduled.
      return

   def notify_moving_impl(o: ObjId, startT: float, endT: float, start: xy_i, end: xy_i) -> void:
      if o is GOInst:
         o.pos = end

   def play_animation_impl(obj: ObjId, name: string):
      if obj is GOInst:
         let ai = find_animation(name)

         if ai >= 0:
            obj.playing_anim = ai
            obj.frame_idx = 0
            obj.frame_left = Animations[ai].frames[0].duration
            obj.curTile = Animations[ai].frames[0].frame
         else:
            warn(): "animation not found: " + name

   def object_state_impl(what: ObjId) -> StateFlags:
      if what is GOInst:
         return StateFlags(what.state)
      else:
         return StateFlags(0)

   def modify_object_state_impl(what: ObjId, body):
      if what is GOInst:
         what.state = body(what.state)

   def for_objects_in_impl(what: ObjId, body):
      for(GOInstances) o:
         if o and o.parent == what:
            body(o)

   def container_of_impl(what: ObjId) -> ObjId?:
      if what is GOInst:
         return what.parent
      else:
         return nil

   def notify_deleting_impl(o: ObjId):
      if o and o is GOInst:
         debug(): "GObjSystem removing " + o
         GOInstances[o.id] = nil

      remove_callbacks_for(o)

   def notify_take_impl(who: ObjId, what: ObjId):
      if what is GOInst and who != what:
         debug(): "GObjSystem " + who + " taking " + what
         // Taking from ground only.
         assert what.parent == nil
         what.parent = who

   def notify_take_out_impl(startT: float, who: ObjId, what: ObjId, from_where:ObjId):
      if what is GOInst and who != what:
         assert what.parent == from_where
         what.parent = who

   def notify_drop_impl(startT: float, who: ObjId, what: ObjId, where: xy_i):
      if what is GOInst:
         what.pos = where
         what.parent = nil

   def notify_put_impl(startT: float, who: ObjId, what: ObjId, where: ObjId):
      if what is GOInst:
         what.parent = where

   def notify_turning_impl(o: ObjId, startT: float, endT: float, startDir: Directions, endDir: Directions):
      if o is GOInst:
         o.dir = endDir

   def object_spec_impl(o: ObjId) -> ObjectSpec:
      if o is GOInst:
         return OSpecs[o.kind_idx]
      else:
         return EmptyObjectSpec

   def equip_slot_impl(what: ObjId) -> ItemSlot:
      if what is GOInst:
         return OSpecs[what.kind_idx].slot()
      else:
         return ItemSlot_None

   def equipment_at_impl(who: ObjId, where: ItemSlot) -> ObjId?:
      for_objects_in_impl(who) o:
         if o and o.state & StateFlags_Equipped and OSpecs[o.kind_idx].slot() == where:
            return o

      return nil
   
   def item_is_equipped_impl(what: ObjId) -> bool:
      if what is GOInst:
         return what.state & StateFlags_Equipped != 0
      else:
         return false

   // Equips `what` on `who` at it's default item slot.  
   // It's an error to equip an item whose slot is already full.
   def equip_impl(who: ObjId, what: ObjId):
      if who is GOInst and what is GOInst:
         let itemloc = OSpecs[what.kind_idx].slot()
         assert what.state & StateFlags_Equipped == 0
         assert equipment_at_impl(who, itemloc) == nil
         what.parent = who
         what.state = what.state | StateFlags_Equipped

   def unequip_impl(who: ObjId, what: ObjId):
      if who is GOInst and what is GOInst:
         assert what.state & StateFlags_Equipped != 0
         assert what.parent == who
         what.state = what.state & ~StateFlags_Equipped

def gobjs_init():
   let txtfile = "dist/sprites.png"
   let txtur = gl_load_texture(txtfile, 
                              texture_format_nearest_mag or texture_format_nearest_min or texture_format_clamp)

   if txtur:
      ObjTx = mkGridTiledTexture(txtur, xy_i{32,32}, 1)
   else:
      error(): "Could not load gobjs texture " + txtfile

   for(cur_config().objtypes_length()) i:
      push(OSpecs, cur_config().objtypes(i))

   qsort_in_place(OSpecs) a, b: int(a.kind) < int(b.kind)
   bus_register_endpoint(GobjEndpoint{system: GObjSystem})

   let cfg = cur_config()
   for(cfg.animations_length()) i:
      let a = cfg.animations(i)
      let anim = GOAnim{name: a.name(), 
                        kind: a.kind, 
                        frames: vector_reserve(typeof return, a.frames_length())}
      for(a.frames_length()) j:
         let fr = a.frames(j)
         push(anim.frames, GOFrame{frame: fr.frame, duration: fr.duration})

      push(Animations, anim)

   qsort_in_place(Animations) a, b: a.name < b.name

   // Read in BaseStats for all of the StatsTemplates.
   for(cfg.stat_templates_length()) i:
      let tmp = cfg.stat_templates(i)
      let barr = []
      
      for(tmp.stats_length()) j:
         let st = tmp.stats(j)
         
         push(barr, StatEnt{name: st.name, val: st.val, src: Base}) 
      
      push(barr, StatEnt{name: GameStats_Hp, val: base_hp_for(barr), src: Base})

      BaseStats.eassign(tmp.name, barr, [])

def gobjs_shutdown():
   pass()
