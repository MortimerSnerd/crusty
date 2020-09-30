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
   error(): "exectute no implemented for " + a
   assert false

// If the move validates, returns an action that can execute the move.
// Otherwise, the ActionResult has the reason for the action failing.
def move_action(span: TurnSpan, now: float, who: ObjId, start: xy_i, end: xy_i) -> ActionResult, ActionBase?:
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

def turn_action(span: TurnSpan, now: float, who: ObjId, start: Directions, end: Directions) -> ActionResult, TurnAction?:
   if not turn_is_allowed(now, who, end):
      return ActionResult{kind: arBlocked, other: InvalidObject}, nil
   else:
      return GoodResult, TurnAction{who: who, time: now, start: start, end: end, duration: 0.2}

def execute(a:: TurnAction):
   notify_turning(who, time, time + duration, start, end)


enum_flags ActionCategory:
   acTurn, acMoveFwd, acMoveBkwd, acStrafe

let AllCategories = acTurn | acMoveFwd | acMoveBkwd | acStrafe

// Calls bodyfn() for each legal action that can currently be
// performed by `who`.
def for_possible_actions(span: TurnSpan, who: ObjId, now: float, 
                         cats: ActionCategory, bodyfn):
   let spec = who.object_spec

   if spec:
      let found_pos, gpos = pos(who)
      let found_dir, dir = direction(who)

      // Can we turn?
      if found_dir and cats & acTurn:
         let dir_left = turned_left(dir)
         let rl, lact = turn_action(span, now, who, dir, dir_left)

         if lact:
            bodyfn(lact)

         let dir_right = turned_right(dir)
         let rr, ract = turn_action(span, now, who, dir, dir_right)

         if ract:
            bodyfn(ract)

      if found_pos and found_dir:
         // Movement.
         let wpos = gridToWorld(gpos)
         let curdir = all_dirs[dir]
          
         for(all_dirs) d:
            let targ = gpos + xy_i{int(d.x), int(d.y)}
            let is_fwd_dir = d == curdir
            let is_back_dir = d == curdir*-1

            if cats & acMoveFwd and is_fwd_dir:
               let rl, act = move_action(span, now, who, gpos, targ)

               if act:
                  bodyfn(act)

            elif cats & acMoveBkwd and is_back_dir:
               let rl, act = move_action(span, now, who, gpos, targ)

               if act:
                  bodyfn(act)

            elif cats & acStrafe:
               let rl, act = move_action(span, now, who, gpos, targ)

               if act:
                  bodyfn(act)

