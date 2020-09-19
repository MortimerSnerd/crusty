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
   anim_pos: LERP<xy_f>
   pos: xy_i // Grid position.
   angle: AngleLERP
   curTile: int

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
      for(GOInstances) o:
         let p = eval(o.anim_pos, now)
         if contains(view, p):
            let a = eval(o.angle, now) + OSpecs[o.kind_idx].right_rotation
            renderSprite(ObjTx, o.curTile, xyz_f{p.x, p.y, 3}, xy_1, sincos(a))
                  
def gobjs_spawn(okind: ObjectKind, pos: xy_f) -> ObjId:
   let found, ki = binary_search_by_key(OSpecs, int(okind)) a, b:
      int(a.kind) - b

   //TODO test to see if it can be placed at pos.
   if found:
      let id = length(GOInstances)
      push(GOInstances, 
           GOInst{anim_pos: mkConstLERP(pos), 
                  pos: worldToGrid(pos),
                  angle: mkConstAngleLERP(0.0),
                  curTile: OSpecs[ki].static_tile, 
                  kind_idx: ki})

      let oid = mkObjId(GObjSystem, id)
      notify_spawn(oid, InvalidObject, pos)
      return oid
   else:
      error(): "No OSpec for " + string(okind)
      assert false
                            
def gobjs_tests():
   gobjs_spawn(ObjectKind_Sword, xy_0)

// Bus endpoint implementation.
class GobjEndpoint : BusEndpoint

// Returns the animation position of the given object.
def anim_pos(ep: GobjEndpoint, what: ObjId, now: float) -> bool, xy_f:
   if what.system == GObjSystem:
      return true, eval(GOInstances[what.id].anim_pos, now)
   else:
      return false, xy_0

def pos(ep:: GobjEndpoint, what: ObjId) -> bool, xy_i:
   if what.system == GObjSystem:
      return true, GOInstances[what.id].pos
   else:
      return false, xy_0

def angle(ep:: GobjEndpoint, what: ObjId, now: float) -> bool, float:
   if what.system == GObjSystem:
      return true, eval(GOInstances[what.id].angle, now)
   else:
      return false, 0

def for_objects_intersecting(ep:: GobjEndpoint, now: float, r: Rectf, body):
   for(GOInstances) ob, i:
      let p = gridToWorld(ob.pos)
      let bb = mkRectfRel(p - xy_h, xy_1)

      if bb.overlaps(r):
         body(mkObjId(GObjSystem, i), bb)

def think(ep:: GobjEndpoint, who: ObjId, now: float):
   //DEBUGGERY - just for testing.
   for_possible_actions(who, now) act:
      if rnd_float() < 0.10:
         execute(act)
         schedule_callback(who, now + act.duration)
         return

   // Try again shortly.
   schedule_callback(who, now + 0.1)


def notify_moving(ep:: GobjEndpoint, o: ObjId, startT: float, endT: float, wstart: xy_f, wend: xy_f):
   if o.system == GObjSystem:
      GOInstances[o.id].anim_pos = mkLERP(startT, endT, wstart, wend)
      GOInstances[o.id].pos = worldToGrid(wend)

def notify_turning(ep:: GobjEndpoint, o: ObjId, startT: float, endT: float, startAng: float, endAng: float):
   if o.system == GObjSystem:
      GOInstances[o.id].angle = mkAngleLERP(startT, endT, startAng, endAng)

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

