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

// For now we just use the flatbuffer instance.  Hooray laziness.
private let OSpecs : [ObjectSpec] = []
private var ObjTx : GridTiledTexture? = nil

private let GOInstances = EmbeddedCircList<GOInst>{head: nil}

def gobj_short_name(o: GOInst?) -> string:
   if o:
      return OSpecs[o.kind_idx].short_name
   else:
      return "Wot"

private def render_offset(flags: int, facing: Directions) -> xyz_f:
   if flags & ItemFlags_AbutsWall:
      let fv = all_dirs_f[facing] * 0.30
      return xyz_f{fv.x, fv.y, AboveWallZ - OnFloorZ}
   else:
      return xyz_0


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
                  let dpos = xyz_f{p.x, p.y, z} + render_offset(oflags, o.dir)
                  
                  renderSprite(ObjTx, ti, dpos, xy_1, sincos(a))

private var IdCounter = 1
                  
def gobjs_spawn(okind: ObjectKind, pos: xy_i, dir: Directions) -> ObjId:
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
                      parent: nil}
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

def for_all_enabled_lights(b:: GobjEndpoint, body):
   dl_foreach(GOInstances) o:
      if not o.parent and OSpecs[o.kind_idx].flags & ItemFlags_EmitsLight:
         body(o, OSpecs[o.kind_idx])

def tile(b: GobjEndpoint, what: ObjId) -> int:
   if what is GOInst:
      return what.curTile
   else:
      return 0

def change_tile(b:: GobjEndpoint, o: ObjId, tile: TileName):
   if o is GOInst:
      o.curTile = tile

def pos(ep:: GobjEndpoint, what: ObjId) -> bool, xy_i:
   if what is GOInst:
      return true, what.pos
   else:
      return false, xy_i{0,0}

def direction(ep:: GobjEndpoint, what: ObjId) -> bool, Directions:
   if what is GOInst:
      return true, what.dir
   else:
      return false, East

def for_objects_intersecting(ep:: GobjEndpoint, now: float, r: Rectf, body):
   dl_foreach(GOInstances) ob:
      let p = gridToWorld(ob.pos)
      let bb = mkRectfRel(p - xy_h, xy_1)

      if bb.overlaps(r):
         body(ob, bb)

def think(ep:: GobjEndpoint, span: TurnSpan, who: ObjId, now: float):
   // We should't have any calls scheduled.
   return

def notify_moving(ep:: GobjEndpoint, o: ObjId, startT: float, endT: float, start: xy_i, end: xy_i):
   if o is GOInst:
      o.pos = end

def notify_deleting(ep: GobjEndpoint, o: ObjId):
   if o and o is GOInst:
      debug(): "GObjSystem removing " + to_string(o)
      dl_remove(GOInstances, o) 

   remove_callbacks_for(o)

def notify_turning(ep:: GobjEndpoint, o: ObjId, startT: float, endT: float, startDir: Directions, endDir: Directions):
   if o is GOInst:
      o.dir = endDir

def notify_take(ep: GobjEndpoint, who: ObjId, what: ObjId):
   if what is GOInst:
      what.parent = who

def object_spec(ep:: GobjEndpoint, o: ObjId) -> ObjectSpec?:
   if o is GOInst:
      return OSpecs[o.kind_idx]
   else:
      return nil
   
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

def gobjs_shutdown():
   dl_clear(GOInstances)
