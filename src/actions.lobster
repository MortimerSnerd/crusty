// Define actions so they can be validated or introspected.
import from "../../../src/crusty/src/"
import bus
import logging
import objutils

// Returns (start, end) animation time where astart and aend are moved and/or
// scaled to fit within the TurnSpan.
def adjusted_animation_time(span: TurnSpan, astart: float, aend: float) -> float, float:
   let spanlen = mag(span)
   let alen = aend - astart
   var rstart = astart
   var rend = aend

   assert alen >= 0
   if alen > spanlen:
      // No fitting this one, just make it match the turn span.
      rstart = span.start
      rend = span.end
   elif astart < span.start:
      // We know it can fit, so just move it.
      let d = span.start - astart
      rstart = astart + d
      rend = aend + d
      
   if aend > span.end: 
      // We know it can fit, so just move it.
      let d = aend - span.end
      rstart = astart - d
      rend = aend - d

   return rstart, rend

class ActionBase:
   who: ObjId
   time: float
   duration: float

class MoveAction : ActionBase
   start: xy_f
   end: xy_f

enum ActionResultKinds:
   arOk, 
   arBlocked 

struct ActionResult:
   kind: ActionResultKinds
   other: ObjId

let GoodResult = ActionResult{kind: arOk, other: InvalidObject}

def execute(a:: ActionBase):
   error(): "exectute no implemented for " + string(a)
   assert false

// If the move validates, returns an action that can execute the move.
// Otherwise, the ActionResult has the reason for the action failing.
def move_action(span: TurnSpan, now: float, who: ObjId, start: xy_f, end: xy_f) -> ActionResult, ActionBase?:
   //TODO for now, there's not a lot that can block a movement, since 
   // there's no map.
   let gr = gridRect(end)
   if not move_is_allowed(now, who, end):
      return ActionResult{kind: arBlocked, other: InvalidObject}, nil

   let as, ae = adjusted_animation_time(span, now, now + 0.5)
   return GoodResult, MoveAction{who: who, time: as, start: start, end: end, 
                                 duration: ae-as}  //TODO calc duration based on stats.

def execute(a:: MoveAction):
   notify_moving(who, time, time + duration, start, end)

class TurnAction : ActionBase
   start: float
   end: float

def turn_action(span: TurnSpan, now: float, who: ObjId, start: float, end: float) -> ActionResult, TurnAction:
   // Not anything that can stop a turn for now.
   let as, ae = adjusted_animation_time(span, now, now + 0.2)
   return GoodResult, TurnAction{who: who, time: as, start: start, end: end, duration: ae-as}

def execute(a:: TurnAction):
   notify_turning(who, time, time + duration, start, end)

// Calls bodyfn() for each legal action that can currently be
// performed by `who`.
def for_possible_actions(span: TurnSpan, who: ObjId, now: float, bodyfn):
   let spec = who.object_spec

   if spec:
      let found_pos, wpos = anim_pos(who, now)
      let found_ang, ang = angle(who, now)

      // Can we turn?
      if found_ang:
         let dir_left = cycle_left(dir_angles.closest_to(ang), length(dir_angles))
         let rl, lact = turn_action(span, now, who, ang, dir_angles[dir_left])

         if rl.kind == arOk:
            bodyfn(lact)

         let dir_right = cycle_right(dir_angles.closest_to(ang), length(dir_angles))
         let rr, ract = turn_action(span, now, who, ang, dir_angles[dir_right])

         if rr.kind == arOk:
            bodyfn(ract)

      if found_pos:
         // Movement.
         let gpos = worldToGrid(wpos)
         for(all_dirs) d:
            let targ = gridToWorld(gpos + xy_i{int(d.x), int(d.y)})
            let rl, act = move_action(span, now, who, wpos, targ)

            if act:
               bodyfn(act)

