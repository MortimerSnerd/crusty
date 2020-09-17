// Keeps up with the current map, and the items on it.
import from "../../../src/crusty/src/"
import algs
import bus
import config_generated
import grids
import objutils
import std

// Sparse grid of living object positions on the map.
// For now, no two objects at the same position.
private var Living = mkSparseGrid(InvalidObject)

// Sparse grid of objects on the map.  There can be
// more than one item at a given position, as long
// as other game rules allow it.
private var Objects = mkSparseGrid(InvalidObject)

class MapEndpoint : BusEndpoint

def move_is_allowed(ep: MapEndpoint, now: float, o: ObjId, wdestPos: xy_f) -> bool:
   let spec = object_spec(o)

   if spec:
      let gdestPos = worldToGrid(wdestPos)
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

//notify_moving
