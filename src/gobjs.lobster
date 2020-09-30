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
   name: ObjId
   kind_idx: int // index into OSpecs for ObjectKind
   pos: xy_i // Grid position.
   dir: Directions
   curTile: int
   parent: ObjId

// For now we just use the flatbuffer instance.  Hooray laziness.
private let OSpecs : [ObjectSpec] = []
private var ObjTx : GridTiledTexture? = nil

private let GOInstances = mk_objid_map<GOInst>()

def find_obj(name: ObjId):
   return find(GOInstances, name)

def gobj_short_name(oid: ObjId) -> string:
   if oid.system == GObjSystem:
      let i = find_obj(oid)

      if i >= 0:
         return OSpecs[GOInstances.vals[i].kind_idx].short_name
      else:
         return "Wot"
   else:
      return "Notta Gobj"

def gobjs_draw(now: float, view: Rectf):
   if ObjTx:
      gl_blend(blend_alpha)
      for(GOInstances.vals) o:
         if o.parent == InvalidObject:
            let p = anim_pos(o.name, now)
            if contains(view, p):
               let a = anim_angle(o.name, now) + OSpecs[o.kind_idx].right_rotation
               renderSprite(ObjTx, o.curTile, xyz_f{p.x, p.y, 3}, xy_1, sincos(a))
                  
private var GoId = 1

def gobjs_spawn(okind: ObjectKind, pos: xy_i, dir: Directions) -> ObjId:
   let found, ki = binary_search_by_key(OSpecs, int(okind)) a, b:
      int(a.kind) - b

   //TODO test to see if it can be placed at pos.
   if found:
      let id = GoId
      let oid = mkObjId(GObjSystem, id)

      ++GoId
      add_item(GOInstances, 
               oid, 
               GOInst{name: oid, 
                      pos: pos,
                      dir: dir, 
                      curTile: OSpecs[ki].static_tile, 
                      kind_idx: ki, 
                      parent: InvalidObject})

      notify_spawn(oid, InvalidObject, pos)
      return oid
   else:
      error(): "No OSpec for " + string(okind)
      assert false
                            
def gobjs_tests():
   gobjs_spawn(ObjectKind_Sword, xy_i{0,0}, North)

// Bus endpoint implementation.
class GobjEndpoint : BusEndpoint

def change_tile(b:: GobjEndpoint, o: ObjId, tile: TileName):
   let i = find_obj(o)

   if i >= 0:
      GOInstances.vals[i].curTile = tile

def pos(ep:: GobjEndpoint, what: ObjId) -> bool, xy_i:
   if what.system == GObjSystem:
      let i = find_obj(what)

      if i >= 0:
         return true, GOInstances.vals[i].pos
      else:
         return false, xy_i{0,0}
   else:
      return false, xy_i{0,0}

def direction(ep:: GobjEndpoint, what: ObjId) -> bool, Directions:
   if what.system == GObjSystem:
      let i = find_obj(what)
      if i >= 0:
         return true, GOInstances.vals[i].dir
      else:
         return false, East
   else:
      return false, East

def for_objects_intersecting(ep:: GobjEndpoint, now: float, r: Rectf, body):
   for(GOInstances.vals) ob, i:
      let p = gridToWorld(ob.pos)
      let bb = mkRectfRel(p - xy_h, xy_1)

      if bb.overlaps(r):
         body(GOInstances.keys[i], bb)

def think(ep:: GobjEndpoint, span: TurnSpan, who: ObjId, now: float):
   // We should't have any calls scheduled.
   return

def notify_moving(ep:: GobjEndpoint, o: ObjId, startT: float, endT: float, start: xy_i, end: xy_i):
   if o.system == GObjSystem:
      let i = find_obj(o)

      if i >= 0:
         GOInstances.vals[i].pos = end

def notify_deleting(ep: GobjEndpoint, o: ObjId):
   if o.system == GObjSystem:
      debug(): "GObjSystem removing " + to_string(o)
      remove_item(GOInstances, o) 

   remove_callbacks_for(o)

def notify_turning(ep:: GobjEndpoint, o: ObjId, startT: float, endT: float, startDir: Directions, endDir: Directions):
   if o.system == GObjSystem:
      let i = find_obj(o)

      if i >= 0:
         GOInstances.vals[i].dir = endDir

def notify_take(ep: GobjEndpoint, who: ObjId, what: ObjId):
   if what.system == GObjSystem:
      let i = find_obj(who)

      if i >= 0:
         GOInstances.vals[i].parent = who

def object_spec(ep:: GobjEndpoint, o: ObjId) -> ObjectSpec?:
   let i = find_obj(o)

   if i >= 0:
      return OSpecs[GOInstances.vals[i].kind_idx]
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

