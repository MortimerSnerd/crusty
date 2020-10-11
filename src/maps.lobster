// Keeps up with the current map, and the items on it.
import from "../../../src/crusty/src/"
import algs
import bus
import config_generated
import consts
import grids
import logging
import objutils
import std
import texture
import tileing
import tilekit_generated

//TODO: port over lighting and shadowing calcs.

// Sparse grid of living object positions on the map.
// For now, no two objects at the same position.
private let Living = mkSparseGrid(InvalidObject)

// Sparse grid of objects on the map.  There can be
// more than one item at a given position, as long
// as other game rules allow it.
private let Objects = mkSparseGrid(InvalidObject)

// Grids for layers, one for each LayerName
private var WallLayer = mkSparseGrid(0)
private var FloorLayer = mk_dense_grid<TileName>(xy_i{100, 100}, TileName_Floor0)
private var LevelMesh: resource? = nil
var PlayerViz: VizSet? = nil
private var MTileMap: GridTiledTexture? = nil
private var StippleTexture: resource? = nil

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

      if get(WallLayer, start + vr) != 0:
         return true
      
      if get(WallLayer, start + vl) != 0:
         return true

   return false

def move_is_allowed(ep: MapEndpoint, now: float, o: ObjId, destPos: xy_i) -> bool:
   if not FloorLayer.contains(destPos):
      return false

   let spec = object_spec(o)

   if spec:
      if get(WallLayer, destPos) != 0:
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

private def create_level_mesh(estSize: int = 100):
   let ps = vector_reserve(typeof [xyz_f], estSize * 4)  
   let tcs = vector_reserve(typeof [xy_f], estSize * 4)  
   let indices = vector_reserve(typeof [int], estSize * 6)

   if MTileMap:
      def add_rect(p: xy_f, ti: int, z: float):
         let base = length(ps)

         withTexCoords(MTileMap, ti) t0, t1, t2, t3:
            push(ps, xyz_f{p.x + 0, p.y + 0, z}) ; push(tcs, t0)
            push(ps, xyz_f{p.x + 1, p.y + 0, z}) ; push(tcs, t1)
            push(ps, xyz_f{p.x + 1, p.y + 1, z}) ; push(tcs, t2)
            push(ps, xyz_f{p.x + 0, p.y + 1, z}) ; push(tcs, t3)

         push(indices, base + 1) ; push(indices, base + 3) ; push(indices, base + 0)
         push(indices, base + 2) ; push(indices, base + 3) ; push(indices, base + 1)
      
      // We'll use the explicit size of the FloorLayer as
      // the rect to pull items out of the wall sparse grid.
      let all = Rect{topLeft: xy_i{0,0}, bottomRight: FloorLayer.dims}

      for_items_within(WallLayer, all) p, ti:
         add_rect(xy_f{float(p.x), float(p.y)}, ti, WallZ)

      for_items_within(FloorLayer, all) p, ti:
         add_rect(xy_f{float(p.x), float(p.y)}, ti, FloorZ)

      return gl_new_mesh("PT", ps, [], [], tcs, [], indices)
   else:
      return nil

def maps_init():
   bus_register_endpoint(MapEndpoint{system: MapSystem})
   StippleTexture = gl_load_texture("dist/stipple.png", 
                                    texture_format_nearest_mag or texture_format_nearest_min)

// Should be called before a turn starts animating, 
// to update off the latest game state.
def maps_update_viz(player_pos: xy_i, clear_viz: bool):
   if PlayerViz:
      update_lights(PlayerViz, clear_viz)

      let t = stopwatch():
         // Can always see yourself.
         mark(PlayerViz, player_pos, vfVisible | vfSeen)
         walk_visible_tiles(player_pos, Rect{xy_i{0,0}, FloorLayer.dims-xy_i{1,1}}) pos:
            // Is opaque at pos?
            get(WallLayer, pos) != 0
         fn(pos):
            var flags = vfVisible
            
            if has(PlayerViz, pos, vfLit):
               flags |= vfSeen

            mark(PlayerViz, pos, flags)

      timing(): "update viz: " + t

def maps_load_debug_level(gtt: GridTiledTexture, player_pos: xy_i):
   // debuggery
   MTileMap = gtt
   modifying(WallLayer):
      for(50) i:
         set(WallLayer, worldToGrid(xy_rnd() * 20), TileName_Wally)

   let lm = create_level_mesh(200)

   if lm:
      LevelMesh = lm
      PlayerViz = mk_viz_set(FloorLayer.dims)
      maps_update_viz(player_pos, true)
   else:
      error(): "Didn\'t create level mesh?"


// One impedance mismatch with tilekit maps and our rep is
// that tilekit has one layer, and we have a separate wall layer
// from the floor layer.  This halps us partition the tiles to 
// the right layer.
private def is_wall_tile(map: Map, n: int) -> bool:
   return n != TileName_Floor0

private def load_tilemap(map: Map, basename: string) -> bool:
   let txt = gl_load_texture("dist/" + basename, 
                              texture_format_nearest_mag or texture_format_nearest_min)

   if txt:
      MTileMap = mkGridTiledTexture(txt, xy_i{map.tile_w(), map.tile_h()})
      if MTileMap:
         return true

   return false

def load_map_object(root: MapRoot) -> bool:
   let mappy = root.map()

   if mappy:
      WallLayer = mkSparseGrid(0)
      FloorLayer = mk_dense_grid<TileName>(xy_i{mappy.w(), mappy.h()}, TileName_Floor0)
      PlayerViz = mk_viz_set(FloorLayer.dims)
      if load_tilemap(mappy, mappy.image_filename()):
         var yc = 0
         var idx = 0

         while yc < mappy.h():
            var xc = 0
            while xc < mappy.w():
               // tilekit makes 0 a blank tile, so 
               // -1 to get real tile index.
               let t = mappy.data(idx) - 1

               if is_wall_tile(mappy, t) and t > 0:
                  set(WallLayer, xy_i{xc, yc}, t)
               else:
                  set(FloorLayer, xy_i{xc, yc}, TileName(t))

               ++idx
               ++xc
            ++yc

         end_changes(WallLayer)
         LevelMesh = create_level_mesh()
      else:
         return false

   return false

def load_map(name: string) -> bool:
   let schema = read_file("dist/tilekit.fbs")
   assert schema
   let data = read_file(name)
   assert data

   let fb, err = flatbuffers_json_to_binary(schema, data, [])

   if err:
      error(): err
      assert not err
   else:
      if fb:
         return load_map_object(GetRootAsMapRoot(fb))
      else:
         return false

// Called once per frame.
def maps_frame():
   // Cleanup and reindex our changing grids if needed.
   end_changes(Living)
   end_changes(Objects)


private def render_viz_mask(wview: Rectf):
   if PlayerViz:
      let t = stopwatch():
         let tl = worldToGrid(wview.topLeft - xy_1)
         let br = worldToGrid(wview.bottomRight + xy_1)
         let ps: [xyz_f] = vector_reserve(typeof return, 4 * 50)
         let indices: [int] = vector_reserve(typeof return, 6 * 50)
         let seen_ps: [xyz_f] = vector_reserve(typeof return, 4 * 50)
         let seen_tc: [xy_f] = vector_reserve(typeof return, 4 * 50)
         let seen_indices: [int] = vector_reserve(typeof return, 6 * 50)

         def add_rect(xx: int, yy: int,  z: float):
            let base = length(ps)

            let x = float(xx)
            let y = float(yy)

            push(ps, xyz_f{x + 0, y + 0, z})
            push(ps, xyz_f{x + 1, y + 0, z})
            push(ps, xyz_f{x + 1, y + 1, z})
            push(ps, xyz_f{x + 0, y + 1, z})

            push(indices, base + 1) ; push(indices, base + 3) ; push(indices, base + 0)
            push(indices, base + 2) ; push(indices, base + 3) ; push(indices, base + 1)

         def add_seen_rect(xx: int, yy: int,  z: float):
            let base = length(seen_ps)

            let x = float(xx)
            let y = float(yy)

            push(seen_ps, xyz_f{x + 0, y + 0, z}) ; push(seen_tc, xy_0)
            push(seen_ps, xyz_f{x + 1, y + 0, z}) ; push(seen_tc, xy_x)
            push(seen_ps, xyz_f{x + 1, y + 1, z}) ; push(seen_tc, xy_1)
            push(seen_ps, xyz_f{x + 0, y + 1, z}) ; push(seen_tc, xy_y)

            push(seen_indices, base + 1) ; push(seen_indices, base + 3) ; push(seen_indices, base + 0)
            push(seen_indices, base + 2) ; push(seen_indices, base + 3) ; push(seen_indices, base + 1)

         var y = tl.y
         
         while y <= br.y:
            var x = tl.x
            while x <= br.x:
               let p = xy_i{x, y}
               let vflags = get(PlayerViz, p)

               if vflags & (vfVisible|vfLit) != (vfVisible|vfLit):
                  if vflags & vfSeen:
                     add_seen_rect(x, y, MaskZ)
                  else:
                     add_rect(x, y, MaskZ)

               ++x
            ++y

         let meh = gl_new_mesh("P", ps, [], [], [], [], indices)

         gl_set_shader("color")
         gl_color(color_black):
            gl_render_mesh(meh)

         if StippleTexture and length(seen_ps) > 0:
            let sm = gl_new_mesh("PT", seen_ps, [], [], seen_tc, [], seen_indices)

            gl_set_shader("textured_alpha_cut")
            gl_set_primitive_texture(0, StippleTexture)
            gl_render_mesh(sm)

      timing(): "render mask " + t

// Assumes projection is already set.
def map_render(wview: Rectf):
   render_viz_mask(wview)
   if MTileMap:
      gl_set_primitive_texture(0, MTileMap.texture) 
      gl_set_shader("textured_alpha_cut")
      gl_blend(blend_alpha)

      if LevelMesh:
         gl_render_mesh(LevelMesh)

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
