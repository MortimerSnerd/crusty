// Define actions so they can be validated or introspected.
import from "../../../src/crusty/src/"
import bus
import config
import logging
import objutils
import stats

class ActionBase:
   who: ObjId
   time: float
   duration: float

   def execute():
      error(): "exectute no implemented for " + this
      assert false

enum ActionResultKinds:
   arOk, 
   arBlocked, 
   arNotOpenable, 
   arAlreadyOpen,
   arAlreadyClosed,
   arCanNotReach, 
   arCanNotTakeAnything, 
   arCanNotTake, 
   arCanNotPut, 
   arAlreadyEquipped, 
   arCanNotEquip

class ActionResult:
   kind: ActionResultKinds
   other: ObjId? = nil

let GoodResult = ActionResult{kind: arOk, other: InvalidObject}

class MoveAction : ActionBase
   start: xy_i
   end: xy_i

   def execute():
      notify_moving(who, time, time + duration, start, end)

// If the move validates, returns an action that can execute the move.
// Otherwise, the ActionResult has the reason for the action failing.
def move_action(span: TurnSpan, now: float, who: ObjId, start: xy_i, end: xy_i) -> ActionResult, ActionBase?:
   let gr = gridRect(end)
   if not move_is_allowed(now, who, end):
      return ActionResult{kind: arBlocked, other: InvalidObject}, nil

   let dist = magnitude(xy_f{end.x - start.x, end.y - start.y})

   return GoodResult, MoveAction{who: who, time: now, start: start, end: end, 
                                 duration: move_action_duration(who, now, dist)}  //TODO calc duration based on stats.

class TurnAction : ActionBase
   start: Directions
   end: Directions

   def execute():
      notify_turning(who, time, time + duration, start, end)

def turn_action(span: TurnSpan, now: float, who: ObjId, start: Directions, end: Directions) -> ActionResult, TurnAction?:
   if not turn_is_allowed(now, who, end):
      return ActionResult{kind: arBlocked, other: InvalidObject}, nil
   else:
      return GoodResult, TurnAction{who: who, time: now, start: start, end: end, duration: 0.2}

class OpenAction : ActionBase
   what: ObjId
   opening: bool

   def execute():
      if opening:
         modify_object_state(what) st: st | StateFlags_Open
         notify_animation(what, time, open_close_animation_name("open", what))
      else:
         modify_object_state(what) st: st & ~StateFlags_Open
         notify_animation(what, time, open_close_animation_name("close", what))


private def at_same_location(a: ObjId, b: ObjId) -> bool:
   let f0, p0 = pos(a)
   let f1, p1 = pos(b)

   return f0 and f1 and p0 == p1

def open_action(span: TurnSpan, now: float, who: ObjId, what: ObjId) -> ActionResult, OpenAction?:
   if at_same_location(who, what):
      if object_spec(what).flags & ItemFlags_Container:
         let st = object_state(what)

         if st & StateFlags_Open:
            return ActionResult{kind: arAlreadyOpen, other: what}, nil
         else:
            return GoodResult, OpenAction{who: who, time: now, what: what, duration: 0.1, 
                                          opening: true}

      else:
         return ActionResult{kind: arNotOpenable, other: what}, nil
   else:
      return ActionResult{kind: arCanNotReach, other: what}, nil

def close_action(span: TurnSpan, now: float, who: ObjId, what: ObjId) -> ActionResult, OpenAction?:
   if at_same_location(who, what):
      if object_spec(what).flags & ItemFlags_Container:
         let st = object_state(what)

         if not st & StateFlags_Open:
            return ActionResult{kind: arAlreadyClosed, other: what}, nil
         else:
            return GoodResult, OpenAction{who: who, time: now, what: what, duration: 0.1, 
                                          opening: false}

      else:
         return ActionResult{kind: arNotOpenable, other: what}, nil
   else:
      return ActionResult{kind: arCanNotReach, other: what}, nil

// Naming convention for container open and close animations.
private def open_close_animation_name(action: string, what: ObjId):
   return action + "_" + object_spec(what).kind

class TakeAction : ActionBase
   what: ObjId
   // If `what` is being taken from a container instead of the ground, 
   // this field holds it.
   where: ObjId? = nil

   def execute():
      if where:
         notify_take_out(time, who, what, where)
      else:
         notify_take(who, what)

def take_action(span: TurnSpan, now: float, who: ObjId, what: ObjId, from_where: ObjId? = nil) -> ActionResult, TakeAction?:
   if not from_where and at_same_location(who, what):
      let spec = object_spec(what)
      if spec.flags & ItemFlags_Immobile or spec.flags & ItemFlags_Living:
         return ActionResult{kind: arCanNotTake, other: what}, nil
      elif not spec.flags & ItemFlags_Container:
         return ActionResult{kind: arCanNotTakeAnything}, nil
      else:
         return GoodResult, TakeAction{who: who, time: now, what: what, duration: 0.3}
   elif from_where and not container_of(from_where) and at_same_location(who, from_where):
      if object_state(from_where) & StateFlags_Open: 
         return GoodResult, TakeAction{who: who, time: now, what: what, where: from_where, 
                                       duration: 0.3}
      else:
         return ActionResult{kind: arCanNotReach, other: what}, nil
   else:
      return ActionResult{kind: arCanNotReach, other: what}, nil

// Place an item either on the ground, or in a open container 
// at the same location.
class PutAction : ActionBase
   what: ObjId
   where: ObjId? = nil
   // Grid location if `where` is nil.
   loc: xy_i  = xy_i{0,0}  

   def execute():
      if where:
         notify_put(time, who, what, where)
      else:
         notify_drop(time, who, what, loc)

def put_action(span: TurnSpan, now: float, who: ObjId, what: ObjId, where: ObjId? = nil) -> ActionResult, PutAction?:
   if where:
      if at_same_location(who, where):
         let spec = object_spec(where)
         let state = object_state(where)

         if spec.flags & ItemFlags_Container and state & StateFlags_Open:
            //TODO container capactity checks, etc...
            return GoodResult, PutAction{
               who: who, time: now, what: what, where: where, duration: 0.3}
         else:
            return ActionResult{kind: arCanNotPut, other: where}, nil
      else:
         return ActionResult{kind: arCanNotReach, other: where}, nil
   else:
      // Just dropping it on the floor.
      let found, wpos = pos(who)

      if found:
         return GoodResult, PutAction{
            who: who, time: now, what: what, loc: wpos, duration: 0.3}
      else:
         return ActionResult{kind: arCanNotReach}, nil

// Action to put on a piece of equipment, or
// wield a weapon.
class WearEquipment : ActionBase
   what: ObjId

   def execute():
      equip(who, what)

def equip_action(span: TurnSpan, now: float, who: ObjId, what: ObjId) -> ActionResult, WearEquipment?:
   let slot = equip_slot(what)

   if slot == ItemSlot_None:
      return ActionResult{kind: arCanNotEquip, other: what}, nil
   else:
      let cur = equipment_at(who, slot)

      if cur:
         return ActionResult{kind: arCanNotEquip, other: what}, nil
      elif item_is_equipped(what):
         return ActionResult{kind: arAlreadyEquipped, other: what}, nil
      else:
         return GoodResult, WearEquipment{
            who: who, time: now, what: what, 
            duration: equip_time_for(who, what, now)
         }
   
class MeleeAttackAction : ActionBase
   target: ObjId
   weapon: ObjId


enum_flags ActionCategory:
   acTurn, acMoveFwd, acMoveBkwd, acStrafe, acObjectInteractions

let AllCategories = acTurn | acMoveFwd | acMoveBkwd | acStrafe | acObjectInteractions

// Calls bodyfn() for each legal action that can currently be
// performed by `who`.
def for_possible_actions(span: TurnSpan, who: ObjId, now: float, 
                         cats: ActionCategory, bodyfn):
   let spec = who.object_spec
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

   if cats & acObjectInteractions:
      for_objects_at(gpos) o:
         if o:
            let openr, openact = open_action(span, now, who, o)

            if openact:
               bodyfn(openact)

            let closer, closeact = close_action(span, now, who, o)

            if closeact:
               bodyfn(closeact)

            let tr, ta = take_action(span, now, who, o)

            if ta:
               bodyfn(ta)
