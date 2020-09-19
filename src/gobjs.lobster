import from "../../../src/crusty/src/"
import actions
import algs
import bus
import callbacks
import config
import config_generated
import logging
import objutils
import std
import texture
import tileing

class GOInst:
   kind_idx: int // index into OSpecs for ObjectKind
   pos: xy_i // Grid position.
   dir: Directions
   curTile: int

//TODO make angle anim_angle and separate angle.
// make any code looking up angle based on the animation angle just use
// the actual angle.

// For now we just use the flatbuffer instance.  Hooray laziness.
private let OSpecs : [ObjectSpec] = []
private var ObjTx : GridTiledTexture? = nil

private let GOInstances: [GOInst] = []

def gobj_short_name(oid: ObjId) -> string:
   if oid.system == GObjSystem:
      return OSpecs[GOInstances[oid.id].kind_idx].short_name
   else:
      return "Notta Gobj"

def gobjs_draw(now: float, view: Rectf):
   if ObjTx:
      gl_blend(blend_alpha)
      for(GOInstances) o, idx:
         let id = mkObjId(GObjSystem, idx)
         let p = anim_pos(id, now)
         if contains(view, p):
            let a = anim_angle(id, now) + OSpecs[o.kind_idx].right_rotation
            renderSprite(ObjTx, o.curTile, xyz_f{p.x, p.y, 3}, xy_1, sincos(a))
                  
def gobjs_spawn(okind: ObjectKind, pos: xy_i, dir: Directions) -> ObjId:
   let found, ki = binary_search_by_key(OSpecs, int(okind)) a, b:
      int(a.kind) - b

   //TODO test to see if it can be placed at pos.
   if found:
      let id = length(GOInstances)
      push(GOInstances, 
           GOInst{pos: pos,
                  dir: dir, 
                  curTile: OSpecs[ki].static_tile, 
                  kind_idx: ki})

      let oid = mkObjId(GObjSystem, id)
      notify_spawn(oid, InvalidObject, pos)
      return oid
   else:
      error(): "No OSpec for " + string(okind)
      assert false
                            
def gobjs_tests():
   gobjs_spawn(ObjectKind_Sword, xy_i{0,0}, North)

// Bus endpoint implementation.
class GobjEndpoint : BusEndpoint

def pos(ep:: GobjEndpoint, what: ObjId) -> bool, xy_i:
   if what.system == GObjSystem:
      return true, GOInstances[what.id].pos
   else:
      return false, xy_i{0,0}

def direction(ep:: GobjEndpoint, what: ObjId) -> bool, Directions:
   if what.system == GObjSystem:
      return true, GOInstances[what.id].dir
   else:
      return false, East

def for_objects_intersecting(ep:: GobjEndpoint, now: float, r: Rectf, body):
   for(GOInstances) ob, i:
      let p = gridToWorld(ob.pos)
      let bb = mkRectfRel(p - xy_h, xy_1)

      if bb.overlaps(r):
         body(mkObjId(GObjSystem, i), bb)

def think(ep:: GobjEndpoint, span: TurnSpan, who: ObjId, now: float):
   //DEBUGGERY - just for testing.
   for_possible_actions(span, who, now) act:
      if rnd_float() < 0.10:
         execute(act)
         schedule_callback(who, now + act.duration)
         return

   // Try again shortly.
   schedule_callback(who, now + 0.1)


def notify_moving(ep:: GobjEndpoint, o: ObjId, startT: float, endT: float, start: xy_i, end: xy_i):
   if o.system == GObjSystem:
      GOInstances[o.id].pos = end

def notify_turning(ep:: GobjEndpoint, o: ObjId, startT: float, endT: float, startDir: Directions, endDir: Directions):
   if o.system == GObjSystem:
      GOInstances[o.id].dir = endDir

def object_spec(ep:: GobjEndpoint, o: ObjId) -> ObjectSpec?:
   return OSpecs[GOInstances[o.id].kind_idx]
   
def gobjs_init():
   let txtfile = "dist/texty.png"
   let txtur = gl_load_texture(txtfile, 
                               texture_format_nearest_mag or texture_format_nearest_min)

   if txtur:
      ObjTx = mkGridTiledTexture(txtur, xy_i{16,16})
   else:
      error(): "Could not load gobjs texture " + txtfile

   for(cur_config().objtypes_length()) i:
      push(OSpecs, cur_config().objtypes(i))

   qsort_in_place(OSpecs) a, b: int(a.kind) < int(b.kind)
   bus_register_endpoint(GobjEndpoint{system: GObjSystem})

