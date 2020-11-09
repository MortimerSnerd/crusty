// Define actions so they can be validated or introspected.
import from "../../../src/crusty/src/"
import bus
import config
import engrish
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

   // Returns a user presentable string describing the successful
   // action.  Or "" if this isn't really worth logging.
   def success_msg() -> string:
      return ""

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
   arCanNotEquip, 
   arNotEquipped, 
   arNoMeleeWeapon

class ActionResult:
   kind: ActionResultKinds
   other: ObjId? = nil

   // Loggable message that describes why an action
   // was impossible.  Or "" if there's nothing useful that could be said.
   def failure_msg(who: ObjId) -> string:
      def othername():
         if other:
            return article(who) + " " + oname(other)
         else:
            return "it"

      switch kind:
         case arOk:
            return ""

         case arBlocked:
            return sentence([pronoun(who), "can not go that way."])

         case arNotOpenable:
            return sentence([pronoun(who), "can not open", othername()])

         case arAlreadyOpen:
            return sentence([othername(), "is already opened"])

         case arAlreadyClosed:
            return sentence([othername(), "is already closed"])

         case arCanNotReach:
            return sentence([pronoun(who), "can not reach", othername()])

         case arCanNotTakeAnything:
            return sentence(["Nothing to take here"])

         case arCanNotTake:
            return sentence([pronoun(who), "can not take", othername()])

         case arCanNotPut:
            return sentence([pronoun(who), "can not put", othername(), "there"])

         case arAlreadyEquipped:
            return sentence([othername(), "is already equipped"])

         case arCanNotEquip:
            return sentence([othername(), "can not be equipped"])

         case arNotEquipped:
            return sentence([othername(), "is not equipped"])

         case arNoMeleeWeapon:
            return sentence([pronoun(who), "have no melee weapon equipped."])

      return ""


let GoodResult = ActionResult{kind: arOk, other: InvalidObject}

private def oname(obj):
   return object_spec(obj).short_name

private def equipverb(what):
   switch object_spec(what).slot():
      case ItemSlot_Melee:
         return "wield"
      default: 
         return "wear"

private def remove_verb(what):
   switch object_spec(what).slot():
      case ItemSlot_Melee:
         return "sheathe"
      default: 
         return "remove"

private def weaponverb(what: ObjId):
   let ws = object_spec(what).weapon_stats()

   if ws:
      switch ws.kind:
         case DmgType_Slashing:
            return "cut"

         case DmgType_Stabbing:
            return "stab"

         case DmgType_Impact:
            return "crush"

   return "hit"

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

   def success_msg() -> string:
      let v = if opening: "open" else: "close"
      return sentence([pronoun(who), verb(who, v), article(who), 
                        object_spec(what).short_name])

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

   def success_msg() -> string:
      if where:
         return sentence([pronoun(who), verb(who, "take"), article(who), 
                         oname(what), "from", article(who), 
                         oname(where)])
      else:
         return sentence([pronoun(who), verb(who, "take"), article(who), 
                         oname(what), "from the ground"])

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

   def success_msg() -> string:
      if where:
         return sentence([pronoun(who), verb(who, "put"), article(who), 
                          oname(what), "in", article(who), 
                          oname(where)])
      else:
         return sentence([pronoun(who), verb(who, "drop"), article(who), 
                          oname(what), "on the ground"])

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

   def success_msg() -> string:
      return sentence([pronoun(who), verb(who, equipverb(what)), 
         article(who), oname(what)])

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
   
class RemoveEquipment : ActionBase
   what: ObjId

   def success_msg() -> string:
      return sentence([pronoun(who), verb(who, remove_verb(what)), 
         article(who), oname(what)])

   def execute():
      unequip(who, what)


def unequip_action(span: TurnSpan, now: float, who: ObjId, what: ObjId) -> ActionResult, RemoveEquipment?:
   let slot = equip_slot(what)

   if item_is_equipped(what) and equipment_at(who, slot) == what:
      return GoodResult, RemoveEquipment{
         who: who, time: now, what: what, 
         duration: equip_time_for(who, what, now)
      }
   else:
      return ActionResult{kind: arNotEquipped, other: what}, nil

class MeleeAttackAction : ActionBase
   target: ObjId
   weapon: ObjId
   hit: bool
   total_dmg: int
   act_dmg: int
   defended: GameStats = GameStats_Hp  // Only valid if hit == false.

   def success_msg() -> string:
      if hit:
         if act_dmg == 0:
            return sentence([pronoun(who), verb(who, weaponverb(weapon)),
                             otherliving(target), 
                             "but it does no damage"])
         else:
            var s = [pronoun(who), verb(who, weaponverb(weapon)), 
                     otherliving(target), "for", string(act_dmg)]

            if act_dmg < total_dmg:
               s = append(s, ["(", string(total_dmg - act_dmg), "absorbed )"])

            return sentence(s)
      else:
         return sentence([otherliving(target, false), verb(target, defence_verb(defended)), 
                         posessive_pronoun(who), weaponverb(weapon)])

   def execute():
      //TODO other notifications...
      let ws = object_spec(weapon).weapon_stats()

      assert ws
      if hit:
         let died = apply_damage(target, time, act_dmg)
         notify_sfx(who, time, ws.hit_sound, 0.5)

         if act_dmg > 0 and not died:
            let ss = object_sounds(target)

            if ss:
               notify_sfx_spec(target, time, rand_hurt_sound(ss))
      else:
         notify_sfx(who, time, ws.miss_sound, 0.5)
         let st = object_stats(target)
         add_use_debuff(st, defended, 3, 
                        time + use_debuff_dur(st, defended, total_dmg, time))

def melee_attack_action(span: TurnSpan, now: float, who: ObjId, what: ObjId,
                        calc: bool = true) -> ActionResult, MeleeAttackAction?:
   let weapon = equipment_at(who, ItemSlot_Melee)

   if weapon:
      let fa, atk_pos = pos(who)
      let da, atk_dir = direction(who)
      let fb, vic_pos = pos(what)
      let wstats = object_spec(weapon).weapon_stats()

      if wstats:
         if fa and fb:
            let dist = gridDistance(atk_pos, vic_pos)

            if within_melee_range(wstats, dist):
               if calc:
                  let st_target = object_stats(what)
                  let st_attacker = object_stats(who)
                  let dir_mal = melee_facing_malus(atk_pos, atk_dir, vic_pos)
                  let atk_skill = wstats.skill()
                  let atk_val = value(st_attacker, now, atk_skill) + dir_mal
                  let def_skill, def_val = find_largest_opposing_skill(st_target, 
                                                                       atk_skill,
                                                                       now)
                  let roll = opposed_skill_check(atk_skill, atk_val, 
                                                 def_skill, def_val)

                  //TODO facing check and bonus/malus
                  //TODO armor calcs
                  let hit = roll > 0
                  let wdmg = damage_roll(wstats.dmg())  // Calc dmg, even when missed.
                  let act_dmg = wdmg

                  return GoodResult, 
                     MeleeAttackAction{who: who, time: now, 
                                       target: what, weapon: weapon, 
                                       hit: hit, 
                                       act_dmg: act_dmg, total_dmg: wdmg,
                                       defended: def_skill, 
                                       duration: attack_duration(who, now, wstats)}
               else:
                  // With calc=false, we just return a generic action.
                  // The caller is probably the legal move checking for
                  // the player, and this saves a lot of debugging noise
                  // for calculating statistics.
                  return GoodResult, 
                     MeleeAttackAction{who: who, time: now, 
                                       target: what, weapon: weapon, 
                                       hit: false, 
                                       act_dmg: 0, total_dmg: 0,
                                       defended: GameStats_Defence, 
                                       duration: attack_duration(who, now, wstats)}


            else:
               return ActionResult{kind: arCanNotReach, other: what}, nil
         else:
            return ActionResult{kind: arCanNotReach, other: what}, nil
      else:
         error(): "Weirdness: no weapon stats for " + object_spec(weapon).short_name
         return ActionResult{kind: arNoMeleeWeapon}, nil         
   else:
      //TODO no fisticuffs, must have weapon.
      return ActionResult{kind: arNoMeleeWeapon}, nil         

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

// Converts an action result and an action
// into a loggable message.  Returns an empty
// string if the message shouldn't be visible to 
// the player, or if it's just something too common
// to be logged.
def present(who: ObjId, act: ActionBase?, ar: ActionResult?) -> string:
   if not ar or ar.kind == arOk:
      if act:
         return act.success_msg()
      else:
         return ""
   else:
      //TODO error messages for player actions that are not possible.
      // where can these happen?
      if ar:
         return ar.failure_msg(who)
      else:
         return ""

