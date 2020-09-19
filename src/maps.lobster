// Keeps up with the current map, and the items on it.
import from "../../../src/crusty/src/"
import algs
import bus
import config_generated
import grids
import objutils
import std
import texture
import tileing

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

def move_is_allowed(ep: MapEndpoint, now: float, o: ObjId, wdestPos: xy_f) -> bool:
   let spec = object_spec(o)

   if spec:
      let gdestPos = worldToGrid(wdestPos)
      if get(Layers[WallLayer], gdestPos) != 0:
         return false

      if spec.flags & ItemFlags_Living and get(Living, gdestPos) != InvalidObject:
         return false

      // If spec.flags & BlocksLiving, make sure there are living at the dest too.
      for_items_at(Objects, gdestPos) it:
         let ospec = it.object_spec

         if ospec:
            if ospec.flags & ItemFlags_BlocksLiving:
               return false

   return true

def notify_spawn(ep: MapEndpoint, o: ObjId, parent: ObjId, wpos: xy_f):
   if parent == InvalidObject:
      // Not contained by another object, so this is on a map.
      let spec = o.object_spec
      
      if spec:
         let gpos = worldToGrid(wpos)
         if spec.flags & ItemFlags_Living:
            assert get(Living, gpos) == InvalidObject
            set(Living, gpos, o)
         else:
            add(Objects, gpos, o)

def notify_moving(ep: MapEndpoint, o: ObjId, startT: float, endT: float, 
                  wstart: xy_f, wend: xy_f):
   let spec = o.object_spec

   if spec:
      let gstart = worldToGrid(wstart)
      let gend = worldToGrid(wend)

      if spec.flags & ItemFlags_Living:
         remove_item(Living, gstart, o)
         assert get(Living, gend) == InvalidObject
         set(Living, gend, o)
      else:
         remove_item(Objects, gstart, o)
         add(Objects, gend, o)

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
