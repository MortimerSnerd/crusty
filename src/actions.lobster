// Define actions so they can be validated or introspected.
import from "../../../src/crusty/src/"
import bus
import logging
import objutils

class ActionBase:
   who: ObjId
   time: float
   duration: float

class MoveAction : ActionBase
   start: xy_i
   end: xy_i

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
def move_action(span: TurnSpan, now: float, who: ObjId, start: xy_i, end: xy_i) -> ActionResult, ActionBase?:
   //TODO for now, there's not a lot that can block a movement, since 
   // there's no map.
   let gr = gridRect(end)
   if not move_is_allowed(now, who, end):
      return ActionResult{kind: arBlocked, other: InvalidObject}, nil

   return GoodResult, MoveAction{who: who, time: now, start: start, end: end, 
                                 duration: 0.5}  //TODO calc duration based on stats.

def execute(a:: MoveAction):
   notify_moving(who, time, time + duration, start, end)

class TurnAction : ActionBase
   start: Directions
   end: Directions

def turn_action(span: TurnSpan, now: float, who: ObjId, start: Directions, end: Directions) -> ActionResult, TurnAction:
   // Not anything that can stop a turn for now.
   return GoodResult, TurnAction{who: who, time: now, start: start, end: end, duration: 0.2}

def execute(a:: TurnAction):
   notify_turning(who, time, time + duration, start, end)

// Calls bodyfn() for each legal action that can currently be
// performed by `who`.
def for_possible_actions(span: TurnSpan, who: ObjId, now: float, bodyfn):
   let spec = who.object_spec

   if spec:
      let found_pos, gpos = pos(who)
      let found_dir, dir = direction(who)

      // Can we turn?
      if found_dir:
         let dir_left = turned_left(dir)
         let rl, lact = turn_action(span, now, who, dir, dir_left)

         if rl.kind == arOk:
            bodyfn(lact)

         let dir_right = turned_right(dir)
         let rr, ract = turn_action(span, now, who, dir, dir_right)

         if rr.kind == arOk:
            bodyfn(ract)

      if found_pos:
         // Movement.
         let wpos = gridToWorld(gpos)
         for(all_dirs) d:
            let targ = gpos + xy_i{int(d.x), int(d.y)}
            let rl, act = move_action(span, now, who, gpos, targ)

            if act:
               bodyfn(act)

