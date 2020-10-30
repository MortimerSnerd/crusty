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

class ObjId : EmbeddedDLinks<ObjId>
   system: ObjectSystem
   id: int = 0 // TODO: this is only currently used as a unique field to sort
               //       by in the animations module.

// Sentinel for no object.
let InvalidObject: ObjId? = nil

def to_string(o: ObjId) -> string:
   return "{" + o.system + ":" + o.id + "}"

// Where a component of a stat comes from.
enum StatEntSource: 
   Base,               // The base stat.
   Equipment           //  From some equipment.
   Condition           // Some sort of temporary condition.

// Part of a stat for the stat named `name`.  The stats for an object
// are summed over multiple stat ents, so base stats are kept separate from 
// stat modifiers.
struct StatEnt:
   name: LivingStats
   val: float
   src: StatEntSource
   life: float  = 0.0   // If src == Condition, time when this condition ends.

// Calculates a value for a particular stat.
def value(stats: [StatEnt], now: float, stat: LivingStats) -> float:
   var rv = 0.0
   for(stats) se:
      if se.name == stat:
         if se.src != Condition or now >= se.life:
            rv += se.val

   return rv

// Returns base value of a stat, without any modifiers.
def base_value(stats: StatEnt, stat: LivingStats) -> float:
   for(stats) se:
      if se.name == stat and se.src == Base:
         return se.val
   error(): "No base stat found for " + stat
   return 0.0

// Create concrete stats for a (presumably new) object.
def generate_stats(os: ObjectSpec) -> [StatEnt]:
   // While the stats are floats, we presume that 
   // base stats are rounded, while modifiers might add
   // fractional bits.  
   def mkstat(sr: StatRange?) -> float:
      if sr:
         let r = sr.hi - sr.lo

         assert r >= 0
         let v = rnd_float() * r + sr.lo
         return round(v)
      else:
         return 1.0

   let tmpl = stat_template(os)

   if tmpl:
      let rv = vector_reserve(typeof return, LivingStats_NumStats)

      push(rv, StatEnt{name: LivingStats_Str, val: mkstat(tmpl.str()), src: Base})
      push(rv, StatEnt{name: LivingStats_Ag, val: mkstat(tmpl.ag()), src: Base})
      push(rv, StatEnt{name: LivingStats_Dex, val: mkstat(tmpl.dex()), src: Base})
      push(rv, StatEnt{name: LivingStats_Will, val: mkstat(tmpl.will()), src: Base})
      push(rv, StatEnt{name: LivingStats_Wit, val: mkstat(tmpl.wit()), src: Base})
      push(rv, StatEnt{name: LivingStats_Per, val: mkstat(tmpl.per()), src: Base})

      assert length(rv) == LivingStats_NumStats  // Catch drift in defined stats.
      return rv
   else:
      return []
      
private class ObjGroup:
   name: string
   grouped: [ObjId] = []

private class ObjSection:
   name: string
   items: [ObjGroup] = []

enum_flags ObjListOptions:
   olNone = 0, 
   olGroup = 1,     // Group together objects with the same name in sections.
   olAddChoiceLetter // Prefix the displayed name with a letter choice.

enum DisplayListStatus:
   dlsOk, 
   dlsCancel

private let DummyListEnt = repeat_string(" ", 50)

// A list of objects, optionally divided into sections, and
// with duplicates optionally grouped together within a section.
// When there are sections, can be rendered as a tree, with each 
// section as a treenode.
class ObjList:
   sects: [ObjSection] = []
   options: ObjListOptions = olNone
   highlighted_section: int = -1
   highlight_color: color = color_yellow

   // Returns section count, item count
   def count_all() -> int, int:
      var nitems = 0

      for(sects) s:
         nitems += length(s.items)

      return length(sects), nitems

   // Returns number of items in the list, not
   // counting sections.
   def count() -> int:
      let ns, ni = count_all()

      return ni

   // Removes an item from the given location, and
   // returns an ObjId.  Returns nil if there's nothing
   // there.
   def remove_obj(sectno: int, itemno: int) -> ObjId?:
      if sectno < length(sects):
         let sect = sects[sectno]
         let grp = sect.items[itemno]

         if length(grp.grouped) > 0:
            return pop(grp.grouped)

      return nil

   def rename_section(sectno: int, name: string):
      sects[sectno].name = name

   // Returns first item from ObjList.  Should only be called
   // if count() > 0!
   def first() -> ObjId:
      for(sects) sect:
         for(sect.items) item:
            if length(item.grouped) > 0:
               return item.grouped[0]

      fatal_exit("first called without checking count()")

   // Adds a section header for the object list.
   def add_section(sname: string):
      push(sects, ObjSection{name: sname})

   private def find_in_cur_section(pred):
      let lasti = length(sects) - 1

      if lasti >= 0:
         return find(sects[lasti].items, pred)
      else:
         return -1

   private def atleast_one_section():
      if length(sects) == 0:
         push(sects, ObjSection{name: ""})

   // Adds a object to the list, to the last section added.  
   def add_object(obj: ObjId):
      def add_it():
         push(sects[length(sects)-1].items, 
              ObjGroup{name: object_spec(obj).short_name, grouped: [obj]})

      atleast_one_section()
      if olGroup & options:
         let match = object_spec(obj).short_name
         let i = find_in_cur_section() g: g.name == match

         if i >= 0:
            push(sects[length(sects)-1].items[i].grouped, obj)
         else:
            add_it()
      else:
         add_it()

   // Returns (index of section, index of item) for item in `sectno`
   // matching the predicate.  If not found, returns (-1, -1)
   private def find_in_section(sectno: int, pred):
      for(sects) sect, si:
         for(sect.items) item, ii:
            if sectno == si and pred(item):
               return si, ii
            elif si  > sectno:
               break

      return -1, -1

   // Adds an item to an existing section.  Used more for changing
   // an existing list than building a new one, use add_object(ol, item)
   // for building a new list section by section.
   def add_object(item: ObjId, sectno: int):
      def insert_at(name: string, sno: int):
         push(sects[sno].items, ObjGroup{name: name, grouped: [item]})

      if olGroup & options:
         let match = object_spec(item).short_name
         let si, ii = find_in_section(sectno) x: x.name == match

         if ii >= 0:
            push(sects[si].items[ii].grouped, item)
         else:
            insert_at(match, sectno)

      else:
         insert_at(object_spec(item).short_name, sectno)

   // Displays the list via im_gui, returning any object that was chosen.
   // Expects a im_window or some other container has already been opened.
   // Returns status, picked_obj_or_nil, section_index, item_index
   def display_list(min_items: int = 26) -> DisplayListStatus, ObjId?, int, int:
      var item_index = 0

      //TODO this is not right
      def plural(s: string): return s+"s"

      def item_name(si, ii) -> string:
         let grp = sects[si].items[ii]
         var rv = grp.name

         if length(grp.grouped) == 0:
            // Leave an empty space for items where the
            // group has been emptied, so the choice letters 
            // won't change for everything coming after it.
            rv = ""
         else:
            if length(grp.grouped) > 1:
               rv = string(length(grp.grouped)) + " " + plural(rv)

            if options & olAddChoiceLetter:
               rv = choice_letter(item_index) + ")  " + rv

         return "    " + rv  // More indent

      var picked: ObjId? = nil
      var picked_si = -1
      var picked_ii = -1

      for(sects) sect, si:
         var open = true

         if sect.name != "": 
            im_set_next_item_open(true, im_cond_always)
            open = im_treenode_start(sect.name) 
            if si == highlighted_section:
               let pmin = im_get_item_rect_min() - xy_1
               let pmax = im_get_item_rect_max() + xy_1

               im_drawlist_add_rect(0, pmin, pmax, highlight_color, 
                                    1.0, im_draw_corner_all, 1.0)

         for(sect.items) item, ii:
            if open:
               im_group(string(si) + "_" + string(ii)):
                  if im_selectable(item_name(si, ii), false, 
                                   im_selectable_none, xy_0):
                     if length(item.grouped) > 0:
                        picked = item.grouped[length(item.grouped)-1]
                        picked_si = si
                        picked_ii = ii
            ++item_index

         if sect.name != "":
            im_treenode_end()

      while item_index < min_items:
         // imgui::spacing might be better?
         // But this also helps force a column size if there are no items
         // in this list.
         im_text(DummyListEnt)
         ++item_index

      var status = dlsOk
      if not picked:
         // Check for key inputs.
         if gl_button("escape") == 1:
            status = dlsCancel
         elif options & olAddChoiceLetter:
            item_index = 0
            for(sects) sect, si:
               for(sect.items) item, ii:
                  if length(item.grouped) > 0:
                     if gl_button(choice_letter(item_index)) == 1:
                        picked = item.grouped[length(item.grouped)-1]
                        picked_si = si
                        picked_ii = ii
                        break

                  ++item_index

               if picked:
                  break


      return status, picked, picked_si, picked_ii


