import from "../../../src/crusty/src/"
import algs
import bus
import config
import config_generated
import events
import logging
import objutils
import std
import texture
import tileing

class GOInst:
   kind_idx: int // index into OSpecs for ObjectKind
   loc: LERP<xy_f>
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

private def handle_event(now: float, ev: BaseEvent):
   let inst = GOInstances[ev.who.id]

   if ev is MoveEvent:
      inst.loc = mkLERP(ev.startT, ev.endT, ev.startPos, ev.endPos)

def gobjs_handle_events(now: float):
  forQueuedEvents() ev: 
     print("chicken " + string(ev) + " (" + string(gobj_short_name(ev.who)) + ")")
     if ev.startT <= now:
        if ev.who.system == GObjSystem:
           handle_event(now, ev)
     else:
        return

def gobjs_draw(now: float, view: Rectf):
   if ObjTx:
      for(GOInstances) o:
         let p = eval(o.loc, now)
         if contains(view, p):
            renderSprite(ObjTx, o.curTile, xyz_f{p.x, p.y, 3}, xy_1)
                  
def gobjs_spawn(okind: ObjectKind, pos: xy_f) -> ObjId:
   let found, ki = binary_search_by_key(OSpecs, int(okind)) a, b:
      int(a.kind) - b

   if found:
      let id = length(GOInstances)
      push(GOInstances, 
           GOInst{loc: mkConstLERP(pos), 
                  curTile: OSpecs[ki].static_tile, 
                  kind_idx: ki})
      return mkObjId(GObjSystem, id)
   else:
      error(): "No OSpec for " + string(okind)
      assert false
                            
def gobjs_tests():
   gobjs_spawn(ObjectKind_Sword, xy_0)

// Bus endpoint implementation.
class GobjEndpoint : BusEndpoint

def pos(ep:: GobjEndpoint, what: ObjId, now: float) -> bool, xy_f:
   if what.system == GObjSystem:
      return true, eval(GOInstances[what.id].loc, now)
   else:
      return false, xy_0

def forObjectsIntersecting(ep:: GobjEndpoint, now: float, r: Rectf, body):
   for(GOInstances) ob, i:
      let p = eval(ob.loc, now)
      let bb = mkRectfRel(p - xy_h, xy_1)

      if bb.overlaps(r):
         body(mkObjId(PlayerSystem, i), bb)

def think(ep:: GobjEndpoint, who: ObjId, now: float):
   //DEBUGGERY - just for testing.
   let go = GOInstances[who.id]

   let endT = now + 0.5
   let p = eval(go.loc, now)
   let diff = rnd_pick(cardinal_directions)
   let pT = xy_f{p.x + float(diff.x), p.y + float(diff.y)}

   move_event(who, now, endT, p, pT)
   schedule_callback(who, endT)

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
   registerBusEndpoint(GobjEndpoint{system: GObjSystem})

