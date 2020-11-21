// Stat based calculations, just put into a separate module for convenience, 
// opposed to being spread out through the actions modules.
import from "../../../src/crusty/src/"
import bus
import config
import config_generated
import engrish
import objutils
import logging

private struct SkillPair:
   atk: GameStats
   defend: GameStats

private struct SkillSyn:
   skill: GameStats
   modified_by: GameStats
   plus: int
   num: int
   denom: int

private let Oppose: [SkillPair] = []
private let Synergies: [SkillSyn] = []
 
class StatDesc:
   st: GameStats
   name: string

let GameStatsPresent = ["strength", 
                        "speed",
                        "will", 
                        "wit",
                        "hp",
                        "melee",
                        "defence",
                        "dodge"]
private def mksd(s):
   return StatDesc{s, capitalize(GameStatsPresent[s])}

let AllAtts = [
   mksd(GameStats_Str),
   mksd(GameStats_Speed),
   mksd(GameStats_Will),
   mksd(GameStats_Wit)
]


private class DefVerb:
   skill: GameStats
   verb: string

private let DefenceVerbs = [
   DefVerb{GameStats_Defence, "block"},
   DefVerb{GameStats_Dodge, "dodge"}
]

def stats_init():
   let root = cur_config()

   for(root.opposing_length()) i:
      let op = root.opposing(i)

      push(Oppose, SkillPair{atk: op.atk(), defend: op.defend()})

   for(root.synergies_length()) i:
      let s = root.synergies(i)

      push(Synergies, SkillSyn{skill: s.skill(), modified_by: s.modified_by(),
                               plus: s.plus(),  num: s.numerator(), 
                               denom: s.denominator()})

// Returns a + or - bonus, with 10 being the 
// midpoint with a bonus of 0.
private def stat_bonus(val: int) -> int:
   return (val - 10) / 2

private def for_skill_synergies(skill: GameStats, body):
   for(Synergies) s:
      if s.skill == skill:
         body(s)

private def calc_synergies_dv(stats, stat, now) -> int:
   var dv = 0

   statlog(): "calc synergies for " + stat
   for_skill_synergies(stat) syn:
      let v = value(stats, now, syn.modified_by, false)
      dv += (v + syn.plus) * syn.num / syn.denom
      statlog(): "    synergy with " + syn.modified_by + " (" + v + "+" + syn.plus + 
                 ")*" + syn.num + "/" + syn.denom + "  (" + dv + ")"

   return dv

// Location that can receive damage.
class BodyLoc:
   // Subset of ItemSlot for armor pieces.
   slot: ItemSlot
   dmg_factor: float = 1.0

// Return a body part name.
def present(loc: BodyLoc) -> string:
   switch loc.slot:
      case ItemSlot_Head:
         return "head"
      case ItemSlot_Chest:
         return "chest"
      case ItemSlot_Feet:
         return "foot"
      case ItemSlot_None, ItemSlot_Melee:
         return "body"

   error(): "Unknown body loc " + loc.slot
   return "body"

def pick_random_body_part(obj: ObjId) -> BodyLoc:
   //TODO actually pick.
   return BodyLoc{ItemSlot_Chest}

def dt_for(arm: ArmorValue?, dmg_type: DmgType) -> int:
   if arm:
      if arm.dmg() == dmg_type:
         return range_roll(arm.dt())
      else:
         return 0
   else:
      return 0

// Calculates the damage reduction and body part bonuses, and applies them 
// to the damage.
def apply_armor_to_dmg(target: ObjId, loc: BodyLoc, dmg_type: DmgType, dmg: int) -> int:
   var eff_dt = 0
   let spec = object_spec(target)

   // Get innate armor.
   for(spec.armor_length()) i:
      eff_dt += dt_for(spec.armor(i), dmg_type)

   // Get any armor for that body part.
   let part_armor = equipment_at(target, loc.slot)

   if part_armor:
      let aspec = object_spec(part_armor)

      for(aspec.armor_length()) i:
         eff_dt += dt_for(aspec.armor(i), dmg_type)

   statlog(): to_string(target) + " dt at " + loc + " = " + eff_dt
   let remaining_dmg = max(0, dmg - eff_dt)

   // Apply the body part factor to any damage that made it
   // through.
   return int(remaining_dmg * loc.dmg_factor)
   
// Calculates a value for a particular stat.
// Will remove any expired conditions in passing.
def value(stats: [StatEnt], now: float, stat: GameStats, apply_syns: bool = true) -> int:
   var i = 0
   var rv = 0

   //TODO bonuses for certain attributes applied to some skills, based on table.
   statlog(): "Lookup " + stat + " @" + now
   while i < length(stats):
      let se = stats[i]

      if se.src >= Condition and now > se.life:
         statlog(): "    expire " + se
         unordered_remove(stats, i)
      elif se.name == stat:
         if se.src < Condition or now <= se.life:
            statlog(): "    include " + se
            rv += se.val
         ++i
      else:
         ++i

   if apply_syns:
         rv += calc_synergies_dv(stats, stat, now)
      
   statlog(): "  = " + rv
   return rv

// Returns base value of a stat, without any modifiers.
def base_value(stats: [StatEnt], stat: GameStats, apply_synergies = false, 
               now = 0.0) -> int:
   let i = find(stats) x: x.name == stat and x.src == Base
   if i >= 0:
      var dv = 0

      if apply_synergies:
         dv = calc_synergies_dv(stats, stat, now)

      return stats[i].val + dv
   else:
      error(): "No base stat found for " + stat
      return 0

// 10 considered average for all stats.
private let AvgStatVal = 10.0

// Defines a line from (stat value 0, val0) to (stat value 1, val1)
// that `stx` is evaluated against.
private def linear(st0, v0, st1, v1, stx) -> float:
   let d = st1 - st0
   let f = (stx - st0) / d
   let rv = lerp(v0, v1, f)

   return rv

// Returns a float multiplier - the larger ag, the
// larger the speed factor.
private def speed_factor(ag: float) -> float:
   return linear(0, 0.1, 
                 AvgStatVal, 1.0, 
                 ag)

// Returns the duration for `who` to move distance, based
// on stats, encumberence.  Moves are one grid at a time, so 
// dist will usually be 1.0 or sqrt(2). 
def move_action_duration(who: ObjId, now: float, dist: float) -> float:
   let avg_s_per_m = 1.0/3.0  // Assume grids are 1x1m
   let st = object_stats(who)

   if length(st) > 0:
      let ag = value(st, now, GameStats_Speed)

      //TODO encumberance, etc...
      let dur =  (avg_s_per_m / speed_factor(ag)) * dist
      return dur
   else:
      warn(): "No stats for " + who
      return 1.0 * dist

private let SkillDie = 20

// Keep skills in range, no negative skills.
def clamp_skill(s: int) -> int:
   return max(0, s)

// Rolls for success of skill a, 
// and returns the margin of success (> 0) or 
// error (<= 0).
def roll_vs_skill(a: int) -> int:
   return clamp_skill(a) - rnd(SkillDie)

// Rolls for skill a being opposed by skill b.  
// Returns margin of success (> 0) or failure
// (< 0).  This works in a way that it still gives a 
// useful result if one or both of the skills are > SkillDie 
def opposed_skill_check(askill: GameStats, a: int, bskill: GameStats, b: int) -> int:
   let rv = rnd(clamp_skill(a)) - rnd(clamp_skill(b))

   statlog(): "Check " + askill + ":" + a + " vs " + bskill + ":" + b + " = " + rv
   return rv

def damage_roll_range(name: DieSpec) -> int:
   switch name:
      case DieSpec_Low2D6:
         return min(rnd(6) + 1, rnd(6) + 1)

      case DieSpec_Hi2D6:
         return max(rnd(6) + 1, rnd(6) + 1)

      case DieSpec_D6:
         return rnd(6)

      case DieSpec_NoDie:
         return 0

   error(): "Unknown range name " + name
   return 1

// Table of names for DmgType
let DmgTypePresent = ["Slashing", "Stabbing", "Impact"]
let ItemSlotPresent = ["none", "melee", "headgear", "chestpiece", "footwear"]

private def die_present_string(d: DieSpec) -> string:
   switch d:
      case DieSpec_Low2D6:
         return "least of 2d6"

      case DieSpec_Hi2D6:
         return "highest of 2d6"

      case DieSpec_D6:
         return "1d6"

      case DieSpec_NoDie:
         return ""

   return "oof"

// Make user presentable string for a damae range.
def present(r: DieRange) -> string:
   let fst = die_present_string(r.range())
   let mod = r.plus()

   if mod == 0:
      return fst
   elif mod < 0:
      return fst + " - " + (-mod)
   else:
      return fst + " + " + mod

def present(eb: EquipBonus) -> string:
   return modifier_str(eb.modifier()) + " to " + GameStatsPresent[eb.skill()]

// Removes an integral measure of tot/dv from tot, and
// returns (amount left, measure)
private def divmeas(tot: float, dv: float) -> float, int:
   let m = floor(tot/dv)
   let act = dv * m

   return tot - act, m

// Presents a weight in lb/oz/drams, 
def present_weight(f: float) -> string:
   let f0, stones = divmeas(f, 14)
   let f1, lbs = divmeas(f0, 1)
   let f2, oz  = divmeas(f1, 1.0/16.0)
   let f3, dr  = divmeas(f2, 1.0/256.0)
   let rv = []

   if lbs:
      push(rv, lbs + "lb")

   if oz:
      push(rv, oz + "oz")

   if dr:
      push(rv, dr + "dr")
   
   return sentence(comma_list(rv, false))

// Roll for damage for the given damage range.  Damage clamped positive.
def range_roll(r: DieRange?) -> int:
   assert r
   let dd = max(0, damage_roll_range(r.range()) + r.plus())

   statlog(): "Roll " + r.range() + "+" + r.plus() + " = " + dd
   return dd

// How long to put this on.
def equip_time_for(who: ObjId, what: ObjId, now: float) -> float:
   //TODO should be based on equipment
   let st = object_stats(who)

   if length(st) > 0:
      let speed = value(st, now, GameStats_Speed)

      return 1/speed_factor(speed)
   else:
      return 1.0

// Damages a living thing.  Can cause death.   Returns true if  `target` dies.
def apply_damage(target: ObjId, now: float, dmg: int, dur: float = 1.0e12) -> bool:
   var rv = false
   assert dmg >= 0

   if dmg > 0:
      let st = object_stats(target)

      if length(st) > 0:
         push(st, StatEnt{name: GameStats_Hp, val: -dmg, src: Condition, 
                          life: now + dur})

         if value(st, now, GameStats_Hp) <= 0:
            notify_death(target, now)
            rv = true

   return rv

def within_melee_range(ws: WeaponStats, range: float) -> bool:
   // No configurable weapon range yet.
   return range <= sqrt(2)

def attack_duration(who: ObjId, now: float, stats: WeaponStats) -> float:
   //TODO add weapon stat, calc for real.
   let base = 0.5
   let st = object_stats(who)
   
   if length(st) > 0:
      let atk_speed = clamp_skill(value(st, now, GameStats_Speed) + stats.speed())

      return base / speed_factor(atk_speed) 
   else:
      return base

// Finds the largest opposing skill for attack skill atk_skill, and returns
// (skill name, skill value)
def find_largest_opposing_skill(target_stats: [StatEnt], atk_skill: GameStats, now: float) -> GameStats, int:
   var largest = GameStats_Hp
   var largest_val = -1

   for(Oppose) op:
      if op.atk == atk_skill:
         let v = value(target_stats, now, op.defend)

         if v > largest_val:
            largest = op.defend
            largest_val = v

   if largest_val >= 0:
      return largest, largest_val
   else:
      error(): "No skill configured to oppose " + atk_skill
      assert false
      return GameStats_Hp, 0

// Returns a verb for a defense action.
def defence_verb(st: GameStats) -> string:
   let i = find(DefenceVerbs) v: v.skill == st

   if i >= 0:
      return DefenceVerbs[i].verb
   else:
      // Why not.
      return "stymie"

// Adds a presumably short usage debuff to a defense skill after 
// the skill has been used.  Block 3 things in a row, and the 4th 
// block is going to be hard.
def add_use_debuff(st: [StatEnt], skill: GameStats, malus: int, till: float):
   assert malus >= 0
   push(st, StatEnt{name: skill, val: -malus, src: UseDebuff, life: till})

// Recovery from a defence action is improved by the speed
// of the defender, and is reduced by the magnitude of the
// damage that would have been done, for cases where contact
// was made.  (Block as opposed to dodge).
def use_debuff_dur(st: [StatEnt], def_skill: GameStats, total_dmg: int, 
                   now: float) -> float:
   let contact_made = def_skill == GameStats_Defence
   var bonus = stat_bonus(value(st, now, GameStats_Speed))

   if contact_made:
      bonus -= total_dmg / 2

   let dd = max(0.1, 1.0 - bonus/6.0)

   statlog(): "Debuf dur for " + def_skill + " with dmg=" + total_dmg + " is " + dd
   return dd

// Calculates the malus to melee skill for attacks that are not 
// straight ahead.  0 for straight ahead, <0 for other facings.
def melee_facing_malus(atk_pos: xy_i, atk_dir: Directions, targ_pos: xy_i) -> int:
   let d = approx_dir(atk_pos, targ_pos) 

   statlog(): "facing malus " + atk_pos + "->" + targ_pos + " " + d
   let n = abs(dir_diff(atk_dir, d))
   let mal = -2 * n
   
   statlog(): "    = " + mal
   return mal

