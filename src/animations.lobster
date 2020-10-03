import from "../../../src/crusty/src/"
import std
import algs
import bus

private var Turn = TurnSpan{0,0}

enum AnimKind:
   anMove, anTurn, 
   anTileChange 

//TODO: add optional trails that shows the path an object moved through.

// Represents a single animation for an object.
// Multiple animations for a single object can not
// overlap, they must be sequential.
class AnimStep:
   who: ObjId
   kind: AnimKind
   movLerp: LERP<xy_f> = mkLERP(0, 1, xy_0, xy_0)
   turnLerp: AngleLERP = mkAngleLERP(0, 1, 0.0, 0.0)
   oldTile: int = 0
   newTile: int = 0
   newTileTime: float = 0.0

def startTime(a: AnimStep) -> float:
   switch a.kind:
      case anMove: return a.movLerp.startT
      case anTurn: return a.turnLerp.startT
      case anTileChange: return a.newTileTime
   return 0.0

def endTime(a: AnimStep) -> float:
   switch a.kind:
      case anMove: return a.movLerp.endT
      case anTurn: return a.turnLerp.endT
      case anTileChange: return a.newTileTime
   return 0.0

// Array of all animations for a given turn.
// At the beginning of animation state, these
// are grouped by (objid, start_time), and animations
// are scaled to fit the turn time, so everything visually
// is at the right place at the end of the turn.
private var Lanes: [AnimStep] = []

// Should be called at the beginning of a turn, 
// before any events for moves come in.
def animations_turn_begin():
   Lanes = []

// bodyfn(objid, starti, endi)
private def for_obj_steps(bodyfn):
   var i = 0

   while i < length(Lanes):
     let oid = Lanes[i].who
     var j = i

     while j < length(Lanes) and Lanes[j].who == oid: ++j
     --j

     bodyfn(oid, i, j)
     i = j+1


// Should be called after all moves are made for
// a turn, but before animation begins.  Once this has
// been called, it's safe to call anim_pos, anim_angle, etc...
def animations_turn_finalize(span: TurnSpan):
   Turn = span

   // Group animations by objid so we can recognize and properly
   // scale animations for objects that made more than one move.
   qsort_in_place(Lanes) a, b:
      if a.who == b.who:
         a.startTime < b.startTime
      else:
         a.who.id < b.who.id

   for_obj_steps() oid, i, j:
      let num_steps = 1 + j - i
      var start = Lanes[i].startTime
      var end = Lanes[j].endTime
      let len = end - start

      // Scale length of all object actions
      // to fit the turn length.
      if len > mag(Turn):
         for(num_steps) k:
            scale_time(Lanes[i+k].movLerp, mag(Turn) / len)
            scale_time(Lanes[i+k].turnLerp, mag(Turn) / len)

      start = Lanes[i].startTime
      end = Lanes[j].endTime

      // Shift times to be in turn now that length can fit.
      if start < Turn.start:
         let d = Turn.start - start
         for(num_steps) k:
            Lanes[i+k].movLerp.startT += d
            Lanes[i+k].movLerp.endT += d
            Lanes[i+k].turnLerp.startT += d
            Lanes[i+k].turnLerp.endT += d
            Lanes[i+k].newTileTime += d

      if end > Turn.end:
         let d = Turn.end - end
         for(num_steps) k:
            Lanes[i+k].movLerp.startT += d
            Lanes[i+k].movLerp.endT += d
            Lanes[i+k].turnLerp.startT += d
            Lanes[i+k].turnLerp.endT += d
            Lanes[i+k].newTileTime += d


private def find_obj_lane(obj: ObjId, kind: AnimKind, now: float) -> int:
   var last = -1
   var first = -1

   // Intuition: for times before an obj lerp is active, 
   // we still want to lerp - querying the object direction at this
   // point would return the end value of the lerp.  
   for(Lanes) o, i: 
      if o.who == obj and o.kind == kind:
        if now >= o.startTime:
           last = i
        if first == -1:
           first = i

   // We want to use the animstep lerp if we're before it.
   if last == -1:
      last = first

   return last 

class AnimEndpoint : BusEndpoint

def anim_pos(ep: AnimEndpoint, what: ObjId, now: float) -> xy_f:
   let i = find_obj_lane(what, anMove, now)

   if i >= 0:
      return eval(Lanes[i].movLerp, now)
   else:
     let found, gpos = pos(what)

     if found:
       return gridToWorld(gpos)
     else:
       return xy_0

def anim_tile(ep: AnimEndpoint, what: ObjId, now: float) -> int:
   let i = find_obj_lane(what, anTileChange, now)

   if i >= 0:
      if now >= Lanes[i].newTileTime: 
         return Lanes[i].newTile
      else:
         return Lanes[i].oldTile
   else:
     return tile(what)

def notify_deleting(ep: AnimEndpoint, o: ObjId):
   debug(): "animations removing " + to_string(o)
   Lanes = filter(Lanes) x: x.who != o

def anim_angle(ep: AnimEndpoint, what: ObjId, now: float) -> float:
   let i = find_obj_lane(what, anTurn, now)

   if i >= 0:
      return eval(Lanes[i].turnLerp, now)
   else:
     let found, dir = direction(what)

     if found:
       return dir_angles[dir]
     else:
       return 0

def notify_moving(e: AnimEndpoint, o: ObjId, startT: float, endT: float, start: xy_i, end: xy_i):
   push(Lanes, 
        AnimStep{who: o, 
                 kind: anMove, 
                 movLerp: mkLERP(startT, endT, 
                                 gridToWorld(start), gridToWorld(end))})

def notify_turning(b: AnimEndpoint, o: ObjId, startT: float, endT: float, startDir: Directions, endDir: Directions):
   push(Lanes, 
        AnimStep{who: o, 
                 kind: anTurn, 
                 turnLerp: mkAngleLERP(startT, endT, 
                                       dir_angles[startDir], dir_angles[endDir])})

def notify_tile_change(b: AnimEndpoint, o: ObjId, startT: float, startTile: int, endTile: int):
   push(Lanes, 
        AnimStep{who: o, 
                 kind: anTileChange, 
                 newTileTime: startT, 
                 oldTile: startTile, 
                 newTile: endTile})

def animations_init():
  bus_register_endpoint(AnimEndpoint{system: AnimationSystem})

def animations_time_scale() -> float:
   return 1
