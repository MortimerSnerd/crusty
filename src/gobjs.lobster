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

def gobjs_draw(now: float, view: Rectf):
   if ObjTx:
      gl_blend(blend_alpha)
      dl_foreach(GOInstances) o:
         if not o.parent:
            let p = anim_pos(o, now)
            if contains(view, p):
               let a = anim_angle(o, now) + OSpecs[o.kind_idx].right_rotation
               renderSprite(ObjTx, o.curTile, xyz_f{p.x, p.y, 3}, xy_1, sincos(a))

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
   let txtfile = "dist/tiles.png"
   let txtur = gl_load_texture(txtfile, 
                               texture_format_nearest_mag or texture_format_nearest_min)

   if txtur:
      ObjTx = mkGridTiledTexture(txtur, xy_i{32,32})
   else:
      error(): "Could not load gobjs texture " + txtfile

   for(cur_config().objtypes_length()) i:
      push(OSpecs, cur_config().objtypes(i))

   qsort_in_place(OSpecs) a, b: int(a.kind) < int(b.kind)
   bus_register_endpoint(GobjEndpoint{system: GObjSystem})

def gobjs_shutdown():
   dl_clear(GOInstances)
