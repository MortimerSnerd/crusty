import from "../../../src/crusty/src/"
import algs
import color
import config
import config_generated
import imgui
import logging

enum ObjectSystem:
   InvalidSystem, PlayerSystem, GObjSystem, MapSystem, AnimationSystem, 
   // Systems for use in game specific code.  Provided with generic names so
   // in theory this file doesn't need to be changed.
   UserSystem1, UserSystem2, UserSystem3, NumSystemSentinel

class ObjId:
   system: ObjectSystem
   id: int = 0 

// Sentinel for no object.
let InvalidObject: ObjId? = nil

// Where a component of a stat comes from.
enum StatEntSource: 
   Base,               // The base stat.
   Equipment           //  From some equipment.
   Condition           // Some sort of temporary condition.

// Part of a stat for the stat named `name`.  The stats for an object
// are summed over multiple stat ents, so base stats are kept separate from 
// stat modifiers.
struct StatEnt:
   name: GameStats
   val: int
   src: StatEntSource
   life: float  = 0.0   // If src == Condition, time when this condition ends.

// Calculates a value for a particular stat.
def value(stats: [StatEnt], now: float, stat: GameStats) -> int:
   var rv = 0
   for(stats) se:
      if se.name == stat:
         if se.src != Condition or now >= se.life:
            rv += se.val

   return rv

// Returns base value of a stat, without any modifiers.
def base_value(stats: StatEnt, stat: GameStats) -> int:
   let i = find(stats) x: x.name == stat and x.src == Base
   if i >= 0:
      return stats[i].val
   else:
      error(): "No base stat found for " + stat
      return 0

