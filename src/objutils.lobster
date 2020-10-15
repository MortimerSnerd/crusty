import algs
import imgui

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

private class ObjGroup:
   name: string
   grouped: [ObjId] = []
   section: bool = false

enum_flags ObjListOptions:
   olNone = 0, 
   olGroup = 1,     // Group together objects with the same name in sections.
   olAddChoiceLetter // Prefix the displayed name with a letter choice.

// A list of objects, optionally divided into sections, and
// with duplicates optionally grouped together within a section.
// When there are sections, can be rendered as a tree, with each 
// section as a treenode.
class ObjList:
   objs: [ObjGroup] = []
   last_section: int = -1
   options: ObjListOptions = olNone

def count(ol:: ObjList) -> int:
   var rv = 0

   for(objs) o:
      if not o.section:
         ++rv

   return rv

def first(ol:: ObjList) -> ObjId?:
   for(objs) o:
      if not o.section and length(o.grouped) > 0:
         return o.grouped[0]

   return nil

// Adds a section header for the object list.  Empty section
// headers are automatically removed.
def add_section(ol:: ObjList, sname: string):
   if last_section >= 0 and last_section == length(objs)-1:
      // Previous section empty, lose it.
      pop(objs)

   last_section = length(objs)
   push(objs,ObjGroup{name: sname, section: true})

private def find_in_cur_section(ol:: ObjList, pred):
   var i = length(objs) - 1

   while i > last_section:
      if pred(objs[i]):
         return i

      --i

   return -1

// Adds a object to the list.  
def add_object(ol:: ObjList, obj: ObjId):
   def add_it():
      push(objs, ObjGroup{name: object_spec(obj).short_name, grouped: [obj]})

   if olGroup & options:
      let match = object_spec(obj).short_name
      let i = find_in_cur_section() g: g.name == match

      if i >= 0:
         push(objs[i].grouped, obj)
      else:
         add_it()
   else:
      add_it()

enum DisplayListStatus:
   dlsOk, 
   dlsCancel

// Displays the list via im_gui, returning any object that was chosen.
// Expects a im_window or some other container has already been opened.
def display_list(ol:: ObjList) -> DisplayListStatus, ObjId?:
   var item_index = 0

   //TODO this is not right
   def plural(s: string): return s+"s"

   def item_name(x) -> string:
      var rv = objs[x].name

      if length(objs[x].grouped) > 1:
         rv = string(length(objs[x].grouped)) + plural(rv)

      if options & olAddChoiceLetter:
         rv = choice_letter(item_index) + ")  " + rv

      return rv

   var picked: ObjId? = nil
   var in_node = false
   var i = 0

   def maybe_close_node():
      if in_node:
         im_treenode_end()
         in_node = false

   while i < length(objs):
      let g = objs[i]

      if g.section:
         maybe_close_node()
         let open = im_treenode_start(g.name)

         ++i
         if open:
            in_node = true
         else:
            while i < length(objs) and not objs[i].section:
               ++i
               ++item_index
      else:
         im_group(string(i)):
            if im_button(item_name(i)):
               picked = objs[i].grouped[0]

         ++i
         ++item_index

   maybe_close_node()
   var status = dlsOk
   if not picked:
      if gl_button("escape") == 1:
         status = dlsCancel
      else:
         item_index = 0
         for(objs) o:
            if not o.section:
               if gl_button(choice_letter(item_index)) == 1:
                  picked = o.grouped[0]
                  break

               ++item_index

   return status, picked


//TODO: keypress choice
      //if not acted:
      //   for(CurPrompt.objs) o, i:
      //      if gl_button(choice_letter(i)) == 1:
      //         let act = CurPrompt.action
      //         act(o)
