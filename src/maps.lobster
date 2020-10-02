// Keeps up with the current map, and the items on it.
import from "../../../src/crusty/src/"
import algs
import bus
import config_generated
import grids
import logging
import objutils
import std
import texture
import tileing

//TODO: port over lighting and shadowing calcs.

// Sparse grid of living object positions on the map.
// For now, no two objects at the same position.
private let Living = mkSparseGrid(InvalidObject)

// Sparse grid of objects on the map.  There can be
// more than one item at a given position, as long
// as other game rules allow it.
private let Objects = mkSparseGrid(InvalidObject)

enum LayerName:
   WallLayer

// Grids for layers, one for each LayerName
private let Layers = [mkSparseGrid(0)]

class MapEndpoint : BusEndpoint

// Returns true if moving start -> end cuts across a wall
// diagonally.  Assumes start and end are only one step away.
def crosses_wall_diagonal(start: xy_i, end: xy_i) -> bool:
   let v = end - start
   let di = find(all_dirs) x: x == v
   let dir = Directions(di)
   
   if is_diagonal(v):
      let vr = all_dirs[turned_right(dir)]
      let vl = all_dirs[turned_left(dir)]

      if get(Layers[WallLayer], start + vr) != 0:
         return true
      
      if get(Layers[WallLayer], start + vl) != 0:
         return true

   return false

def move_is_allowed(ep: MapEndpoint, now: float, o: ObjId, destPos: xy_i) -> bool:
   let spec = object_spec(o)

   if spec:
      if get(Layers[WallLayer], destPos) != 0:
         return false

      let found, cpos = pos(o)

      if found and crosses_wall_diagonal(cpos, destPos):
         return false

      let liv = get(Living, destPos)

      if spec.flags & ItemFlags_Living:
         if liv != InvalidObject:
            return false

         let blocked = any_items_at(Objects, destPos) it: 
            if it:
               let ispec = it.object_spec
               ispec and ispec.flags & ItemFlags_BlocksLiving
            else:
               false

         if blocked:
            return false
      elif spec.flags & ItemFlags_BlocksLiving:
         if liv != InvalidObject:
            return false

   return true

def notify_deleting(b: MapEndpoint, what: ObjId):
   // Calling pos() won't necessarily work at this point, 
   // so discard the items directly from our grids.
   debug(): "Maps: removing " + to_string(what)
   discard(Objects) x: x == what
   discard(Living) x: x == what


def notify_take(b: MapEndpoint, who: ObjId, what: ObjId):
   let wf, wpos = pos(who)
   let r = Rectf{gridToWorld(wpos - xy_i{1,1}), gridToWorld(wpos + xy_i{1,1})}

   for_items_within(Objects, r) p, oid:
      if oid == what:
         remove_item(Objects, p, oid)
         return

   assert "could not find object to take" == ""

def notify_spawn(ep: MapEndpoint, o: ObjId, parent: ObjId?, pos: xy_i):
   if not parent:
      // Not contained by another object, so this is on a map.
      let spec = o.object_spec
      
      if spec:
         if spec.flags & ItemFlags_Living:
            assert get(Living, pos) == InvalidObject
            set(Living, pos, o)
         else:
            print("har har " + to_string(o))
            add(Objects, pos, o)

def notify_moving(ep: MapEndpoint, o: ObjId, startT: float, endT: float, 
                  start: xy_i, end: xy_i):
   let spec = o.object_spec

   if spec:
      if spec.flags & ItemFlags_Living:
         remove_item(Living, start, o)
         assert get(Living, end) == InvalidObject
         set(Living, end, o)
      else:
         remove_item(Objects, start, o)
         add(Objects, end, o)

def for_objects_at(b:: MapEndpoint, p: xy_i, body):
   for_items_at(Objects, p) o:
      body(o)

   let lv = get(Living, p)
   if lv != InvalidObject:
      body(lv)

def maps_init():
   bus_register_endpoint(MapEndpoint{system: MapSystem})
   // debuggery
   modifying(Layers[WallLayer]):
      for(50) i:
         set(Layers[WallLayer], worldToGrid(xy_rnd() * 30) - xy_i{15, 15}, TileName_Wally)

// Called once per frame.
def maps_frame():
   // Cleanup and reindex our changing grids if needed.
   end_changes(Living)
   end_changes(Objects)

// Assumes projection is already set.
def map_render(gtt: GridTiledTexture, wview: Rectf):
   gl_set_shader("textured_alpha_cut")
   gl_blend(blend_alpha)

   //TODO for static layers, we'll generate a mesh and just
   // render it rather than doing N draw calls here.
   // This is just for testing and debugging.
   let gtl = worldToGrid(wview.topLeft - xy_1)
   let gbr = worldToGrid(wview.bottomRight + xy_1)
   let grect = Rect{topLeft: gtl, bottomRight: gbr}

   for_items_within(Layers[WallLayer], grect) pos, ti:
      // Reminder - we don't use gridToWorld here, because that adds
      // an offset so sprites/etc are centered on the grid when pos = (1, 1).
      let fpos = xy_f{float(pos.x), float(pos.y) + 1.0}
      gl_translate(fpos):
         withTexCoords(gtt, ti) t0, t1, t2, t3:
            gl_rect_tc_col(xy_f{1.0, -1.0}, t0, t2-t0, [])

// Assumes the shader is already set to color.
def map_render_debug(wview: Rectf, thickness: float):
   def ex(p: xy_i):
      let pf = xy_f{p.x, p.y}
      gl_line(pf, pf + xy_1, thickness)
      gl_line(xy_f{pf.x + 1, pf.y}, xy_f{pf.x, pf.y + 1}, thickness)

   end_changes(Living)
   end_changes(Objects)

   let gview = worldToGrid(wview)
   gl_color(xyzw_f{0.0, 0.0, 1.0, 1.0}):
      for_items_within(Living, gview) pos, x:
         ex(pos)

   gl_color(xyzw_f{0.0, 1.0, 0.0, 1.0}):
      for_items_within(Objects, gview) pos, x:
         ex(pos)


//notify_moving
