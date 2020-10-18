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
   state: StateFlags = StateFlags(0)

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
private let GOInstances = EmbeddedCircList<GOInst>{head: nil}

def to_string(o: GOInst) -> string:
   if o.kind_idx < 0:
      return "{InvalidGObj}"
   else:
      return "{" + OSpecs[o.kind_idx].kind() + ":" + o.id + "}"

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
   dl_foreach(GOInstances) o:
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

def gobjs_draw(now: float, view: Rectf):
   if ObjTx:
      gl_set_primitive_texture(0, ObjTx.texture)
      gl_blend(blend_alpha)
      dl_foreach(GOInstances) o:
         if not o.parent:
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

private var IdCounter = 1
                  
def gobjs_spawn(okind: ObjectKind, pos: xy_i, dir: Directions, parent: ObjId? = nil) -> ObjId:
   let found, ki = binary_search_by_key(OSpecs, int(okind)) a, b:
      int(a.kind) - b

   //TODO test to see if it can be placed at pos.
   if found:
      let rv = GOInst{system: GObjSystem,
                      id: IdCounter,
                      pos: pos,
                      dir: dir, 
                      curTile: OSpecs[ki].static_tile, 
                      kind_idx: ki, 
                      parent: parent, 
                      state: OSpecs[ki].initial_state}
      ++IdCounter
      dl_add(GOInstances, rv)
      notify_spawn(rv, nil, pos)

      return rv
   else:
      error(): "No OSpec for " + okind
      assert false
                            
def gobjs_tests():
   gobjs_spawn(ObjectKind_Sword, xy_i{0,0}, North)

// Bus endpoint implementation.
class GobjEndpoint : BusEndpoint
   def for_all_enabled_lights(body):
      dl_foreach(GOInstances) o:
         if not o.parent and OSpecs[o.kind_idx].flags & ItemFlags_EmitsLight:
            body(o, OSpecs[o.kind_idx])

   def tile(what: ObjId) -> int:
      if what is GOInst:
         return what.curTile
      else:
         return 0

   def change_tile(o: ObjId, tile: TileName):
      if o is GOInst:
         o.curTile = tile
         // If a tile is set manually, cancel animation.
         o.playing_anim = -1

   def pos(what: ObjId) -> bool, xy_i:
      if what is GOInst:
         return true, what.pos
      else:
         return false, xy_i{0,0}

   def direction(what: ObjId) -> bool, Directions:
      if what is GOInst:
         return true, what.dir
      else:
         return false, East

   def for_objects_intersecting(now: float, r: Rectf, body):
      dl_foreach(GOInstances) ob:
         let p = gridToWorld(ob.pos)
         let bb = mkRectfRel(p - xy_h, xy_1)

         if bb.overlaps(r):
            body(ob, bb)

   def think(span: TurnSpan, who: ObjId, now: float):
      // We should't have any calls scheduled.
      return

   def notify_moving(o: ObjId, startT: float, endT: float, start: xy_i, end: xy_i) -> void:
      if o is GOInst:
         o.pos = end

   def play_animation(obj: ObjId, name: string):
      if obj is GOInst:
         let ai = find_animation(name)

         if ai >= 0:
            obj.playing_anim = ai
            obj.frame_idx = 0
            obj.frame_left = Animations[ai].frames[0].duration
            obj.curTile = Animations[ai].frames[0].frame
         else:
            warn(): "animation not found: " + name

   def object_state(what: ObjId) -> StateFlags:
      if what is GOInst:
         return what.state
      else:
         return StateFlags(0)

   def modify_object_state(what: ObjId, body):
      if what is GOInst:
         what.state = body(what.state)

   def for_objects_in(what: ObjId, body):
      dl_foreach(GOInstances) o:
         if o.parent == what:
            body(o)

   def container_of(what: ObjId) -> ObjId?:
      if what is GOInst:
         return what.parent
      else:
         return nil

   def notify_deleting(o: ObjId):
      if o and o is GOInst:
         debug(): "GObjSystem removing " + to_string(o)
         dl_remove(GOInstances, o) 

      remove_callbacks_for(o)

   def notify_take(who: ObjId, what: ObjId):
      if what is GOInst and who != what:
         debug(): "GObjSystem " + to_string(who) + " taking " + to_string(what)
         what.parent = who

   def notify_turning(o: ObjId, startT: float, endT: float, startDir: Directions, endDir: Directions):
      if o is GOInst:
         o.dir = endDir

   def object_spec(o: ObjId) -> ObjectSpec:
      if o is GOInst:
         return OSpecs[o.kind_idx]
      else:
         return EmptyObjectSpec
   
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

   for(cur_config().animations_length()) i:
      let a = cur_config().animations(i)
      let anim = GOAnim{name: a.name(), 
                        kind: a.kind, 
                        frames: vector_reserve(typeof return, a.frames_length())}
      for(a.frames_length()) j:
         let fr = a.frames(j)
         push(anim.frames, GOFrame{frame: fr.frame, duration: fr.duration})

      push(Animations, anim)

   qsort_in_place(Animations) a, b: a.name < b.name

def gobjs_shutdown():
   dl_clear(GOInstances)
