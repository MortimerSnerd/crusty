import from "../../../src/crusty/src/"
import std
import algs
import bus

class AnimEndpoint : BusEndpoint

def anim_pos(ep: AnimEndpoint, what: ObjId, now: float) -> xy_f:
  let found, gpos = pos(what)

  if found:
    return gridToWorld(gpos)
  else:
    return xy_0

def anim_angle(ep: AnimEndpoint, what: ObjId, now: float) -> float:
  let found, dir = direction(what)

  if found:
    return dir_angles[dir]
  else:
    return 0

def animations_init():
  bus_register_endpoint(AnimEndpoint{system: AnimationSystem})

def animations_time_scale() -> float:
   return 200
