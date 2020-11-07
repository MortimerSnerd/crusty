// Stat based calculations, just put into a separate module for convenience, 
// opposed to being spread out through the actions modules.
import from "../../../src/crusty/src/"
import bus
import config
import config_generated
import objutils
import logging

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
def opposed_skill_check(a: int, b: int) -> int:
   return rnd(clamp_skill(a)) - rnd(clamp_skill(b))

def damage_roll_range(name: DmgRange) -> int:
   switch name:
      case DmgRange_Low2D6:
         return min(rnd(6) + 1, rnd(6) + 1)

      case DmgRange_Hi2D6:
         return max(rnd(6) + 1, rnd(6) + 1)

      case DmgRange_D6:
         return rnd(6)

      default:
         error(): "Unknown range name " + name
         return 1

// Roll for damage for the given damage range.  Damage clamped positive.
def damage_roll(r: DamageRange?) -> int:
   assert r
   return max(0, damage_roll_range(r.range()) + r.plus())

// How long to put this on.
def equip_time_for(who: ObjId, what: ObjId, now: float) -> float:
   //TODO should be based on equipment
   let st = object_stats(who)

   if length(st) > 0:
      let speed = value(st, now, GameStats_Speed)

      return 1/speed_factor(speed)
   else:
      return 1.0

// Calculates the base hitpoints for something with
// the given stats.
def base_hp_for(st: [StatEnt]) -> int:
   return base_value(st, GameStats_Str) + base_value(st, GameStats_Will) / 2

// Damages a living thing.  Can cause death. 
def apply_damage(target: ObjId, now: float, dmg: int, dur: float = 1.0e12):
   assert dmg >= 0

   if dmg > 0:
      let st = object_stats(target)

      if length(st) > 0:
         push(st, StatEnt{name: GameStats_Hp, val: -dmg, src: Condition, 
                          life: now + dur})

         if value(st, now, GameStats_Hp) < 0:
            //TODO - bus event for death.
            print("holy shit, " + object_spec(target).short_name + " is ded")

def within_melee_range(ws: WeaponStats, range: float) -> bool:
   // No configurable weapon range yet.
   return range <= sqrt(2)

def attack_duration(who: ObjId, now: float, stats: WeaponStats) -> float:
   //TODO add weapon stat, calc for real.
   let base = 1.0
   let st = object_stats(who)

   if length(st) > 0:
      let speed = value(st, now, GameStats_Speed)

      return base / speed_factor(speed) 
   else:
      return base

