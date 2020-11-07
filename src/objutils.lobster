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

