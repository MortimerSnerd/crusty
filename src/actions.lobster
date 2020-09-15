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
   start: xy_f
   end: xy_f

enum ActionResultKinds:
   arOk, 
   arBlockedByWall, 
   arBlockedByObject

struct ActionResult:
   kind: ActionResultKinds
   other: ObjId

private let GoodResult = ActionResult{kind: arOk, other: InvalidObject}

def execute(a:: ActionBase):
   error(): "exectute no implemented for " + string(a)
   assert false

// If the move validates, returns an action that can execute the move.
// Otherwise, the ActionResult has the reason for the action failing.
def move_action(now: float, who: ObjId, start: xy_f, end: xy_f) -> ActionResult, ActionBase?:
   //TODO for now, there's not a lot that can block a movement, since 
   // there's no map.
   let gr = gridRect(end)
   //TODO this is also not right, objects could end up in same destination.
   //     will only be right once there's a map that immediately occupies
   //     a grid once a move has been executed.
   forObjectsIntersecting(now, gridRect(end)) o:
      if o != who and blocksLiving(o):
         return ActionResult{kind: arBlockedByObject, other: o}, nil

   return GoodResult, MoveAction{who: who, time: now, start: start, end: end, 
                                 duration: 0.5}  //TODO calc duration based on stats.

def execute(a:: MoveAction):
   notify_moving(who, time, time + duration, start, end)

class TurnAction : ActionBase
   start: float
   end: float

def turn_action(now: float, who: ObjId, start: float, end: float) -> ActionResult, TurnAction:
   // Not anything that can stop a turn for now.
   return GoodResult, TurnAction{who: who, time: now, start: start, end: end, duration: 0.2}

def execute(a:: TurnAction):
   notify_turning(who, time, time + duration, start, end)

