// Code for ui.  Split out from player module, as it was starting to get
// messy.
import from "../../../src/crusty/src/"
import actions
import algs
import bus
import color
import config_generated
import imgui
import objlist
import objutils


// A base class for data a client can attach to a handler.
// Also gives the client a way to pass back arbitrary data from
// a dialog.
class UserData:
   title: string

enum InteractionStatus:
   Working, Finished, Cancelled

// Function that renders the UI and deals with input.
// It's expected this function will return Finished|Cancelled
// when it is done.
def InteractionHandler(data: UserData?) -> InteractionStatus

// A handler that controls a ui interation with the user.  
// Interactions can correspond with dialogs, and can be nested.
class Interaction:
   data: UserData?
   handler: InteractionHandler
   status: InteractionStatus = Working // Status of the interaction.

// Stack of active interactions.
private var Acts: Interaction? = nil

def start_interaction(data: UserData?, handler: InteractionHandler, 
                      initialStatus: InteractionStatus = Working):
   assert Acts == nil
   Acts = Interaction{data: data, handler: handler, status: initialStatus}

def interaction_active():
   return Acts != nil 

// Should be called in a im_frame from the main render loop.
def uitools_render():
   if Acts:
      if Acts.status == Working:
         let h = Acts.handler
         Acts.status = h(Acts.data)

// Allows the client to poll for a finished interaction.
// If there is one, it is returned, otherwise nil is returned.
def finished_interaction() -> Interaction?:
   if Acts and Acts.status != Working:
      let rv = Acts
      Acts = nil
      return rv
   else:
      return nil

//
// Utility functions for building up ObjLists used by UI tools.
//

def is_open_container(o: ObjId):
   return object_spec(o).flags & ItemFlags_Container and (object_state(o) & StateFlags_Open)

def is_closed_container(o: ObjId):
   return object_spec(o).flags & ItemFlags_Container and not (object_state(o) & StateFlags_Open)

def closed_containers_at(p: xy_i) -> ObjList:
   let rv = ObjList{options: olAddChoiceLetter}

   add_section(rv, "What have we here?")
   for_objects_at(p) o:
      //TODO instead of flag test, should we check with close action, so we always use the
      //    same criteria?
      if o and is_closed_container(o):
         add_object(rv, o)

   return rv

def opened_containers_at(p: xy_i) -> ObjList:
   let rv = ObjList{options: olAddChoiceLetter}

   for_objects_at(p) o:
      //TODO instead of flag test, should we check with open action, so we always use the
      //    same criteria?
      if o and is_open_container(o):
         add_object(rv, o)

   return rv

private let AllSlots = [ItemSlot_Melee, ItemSlot_Head, ItemSlot_Chest, 
                        ItemSlot_Feet]
private let SlotHeading = ["In hand", "On head", "On chest", "On feet"]


// If any item in inventory is equippable, returns it.
// Mainly used for player action hints.
def equippable_sample(who: ObjId) -> ObjId?:
   for_objects_in(who) o:
      let ar, act = equip_action(FakeTurnSpan, 0, who, o)

      if act:
         return o

   return nil

// Populates two lists, (equipped objects, equippable objects)
// Equippable objects are just the items in inventory right now.
def equipment_for(who: ObjId, equipped: ObjList, equippable: ObjList):
   for(AllSlots) slot, si:
      add_section(equipped, SlotHeading[si])
      for_objects_in(who) o:
         if item_is_equipped(o) and equip_slot(o) == slot:
            add_object(equipped, o)

   add_section(equippable, "In inventory")

   for_objects_in(who) o:
      if not item_is_equipped(o) and equip_slot(o) != ItemSlot_None:
         add_object(equippable, o)

// Adds a section for any items inside of a container `o` to `list`.
private def add_container_objects(player: ObjId, list: ObjList, o: ObjId):
   add_section(list, "In " + object_spec(o).short_name)
   for_objects_in(o) io:
      let r0, act0 = take_action(FakeTurnSpan, 0, player, io, o)

      if act0:
         add_object(list, io)

private let GroundSection = "On ground"

// Populate `rv` with the objects on the floor at `p`.  Returns 
// any open container objects as an array.
private def get_floor_objs(rv: ObjList, player: ObjId, p: xy_i):
   let containers = [] 
   add_section(rv, GroundSection)
   for_objects_at(p) o:
      if o:
         let r, act = take_action(FakeTurnSpan, 0, player, o)

         if act:
            add_object(rv, o)
         elif is_open_container(o):
            push(containers, o)

   return containers

def grabbable_objs_at(player: ObjId, p: xy_i, options: ObjListOptions = olAddChoiceLetter) -> ObjList:
   let rv = ObjList{options: options}
   let containers = get_floor_objs(rv, player, p)

   for(containers) o:
      add_container_objects(player, rv, o)

   return rv

// Inventory objects, excluding worn and wielded objects.
def held_objects(player: ObjId, options: ObjListOptions = olAddChoiceLetter|olGroup) -> ObjList:
   let rv = ObjList{options: options}

   add_section(rv, "In inventory")
   for_objects_in(player) o:
      if not item_is_equipped(o):
         add_object(rv, o)

   return rv

//
// Simple object prompt
//
def PromptHandler() -> DisplayListStatus
                                    
def PromptAction(data: UserData) -> ActionBase?

class ObjPromptData : UserData
   objs: ObjList = ObjList{options: olAddChoiceLetter}
   player: ObjId
   action: PromptAction
   picked: ObjId? = nil

private def obj_prompt_handler(data: UserData?) -> InteractionStatus:
   var rv = Working

   if data and data is ObjPromptData:
      let ws = gl_window_size().to_f * xy_f{0.4, 0.5} 
      im_set_next_window_pos(ws, im_cond_first_use_ever, xy_f{0.5, 0.5})
      im_window(data.title, 0):
         let status, picked, si, ii = display_list(data.objs)

         if status == dlsCancel:
            rv = Cancelled
         elif picked:
            data.picked = picked
            rv = Finished

   return rv

// Starts an object prompt.  Poll with finished_interaction() to find out
// when it is complete.
def prompt_for_object(player: ObjId, title: string, cands: ObjList, skip_one: bool, action):
   let data = ObjPromptData{title: title, objs: cands, player: player, action: action}  

   if skip_one and count(cands) == 1:
      // Just one, so perform the action without a prompt.
      data.picked = first(cands)
      start_interaction(data, (fn(a: UserData?): obj_prompt_handler(a)), Finished)
   else:
      start_interaction(data, (fn(a: UserData?): obj_prompt_handler(a)))


//
// Item interaction dialog.
//

// Represents pairs of item sources and/or destinations.
enum IIModes:
   iiGet, 
   iiPut,
   iiEquip

// Represents the location that a ObjList or ObjList section
// is populated from.
enum LocationKind:
   PlayerInventory,   
   Ground,           
   Container, 
   EquipSlot

private class Location:
   kind: LocationKind
   // Container object for kind=Container
   obj: ObjId? = nil       
   slot: ItemSlot = ItemSlot_None


private def lhs_options(m: IIModes):
   switch m:
      case iiGet: 
         return olGroup

      case iiPut:
         return olAddChoiceLetter|olGroup

      case iiEquip:
         return olAddChoiceLetter|olGroup

   return olNone

private def rhs_options(m: IIModes):
   return switch m:
      case iiGet:
          olAddChoiceLetter|olGroup

      case iiPut:
          olGroup

      case iiEquip:
         return olAddChoiceLetter|olGroup

      default:
         return olNone

private def mode_label(m: IIModes):
   return switch m:
      case iiGet:
         "< Get <"
      
      case iiPut:
         "> Put >"

      case iiEquip:
         "< Equip <"

      default:
         return "<>"

private def mode_button_label(m: IIModes):
   return switch m:
      case iiGet:
         "Get [F1]"

      case iiPut:
         "Put [F2]"

      case iiEquip:
         "Equip [F3]"

      default:
         ""
// Encapsulates the data to perform additions and removals to an ObjList
class ListUpdate:
   left_sect: int = -1
   left_item: int = -1
   right_sect: int = -1
   right_item: int = -1

class IIData : UserData
   player: ObjId
   player_pos: xy_i
   mode: IIModes
   lhs: ObjList = ObjList{options: olNone}
   rhs: ObjList = ObjList{options: olNone}
   // Maps from section number to Location for the ObjLists
   lhs_locs: [Location] = []
   rhs_locs: [Location] = []

   // Index to the current section.
   rhs_cur_section: int = -1 

   // Record of window width from last frame.
   last_window_width: float = -1.0

   // Action for player module to execute.  While this is non-nil, 
   // we ignore input.  It will be set back to nil once the player
   // module has executed the action, and the turn is finished.
   player_action: ActionBase? = nil
   post_action_update: ListUpdate? = nil

   private def sect_name(i, name):
      let next_section = (rhs_cur_section + 1) % length(rhs_locs)
      let prev_section = (rhs_cur_section + 1) % length(rhs_locs)

      if rhs_cur_section < 0:
         return name
      elif i == rhs_cur_section:
         return ">> " + name 
      elif i == next_section:
         return name + " [Tab] [Down]"
      elif i == prev_section:
         return name + " [Up]"
      else:
         return name

   private def set_rhs_section_names():
      for(rhs_locs) loc, i:
         if loc.kind == Ground:
            rename_section(rhs, i, sect_name(i, GroundSection))
         elif loc.obj:
            rename_section(rhs, i, sect_name(i, object_spec(loc.obj).short_name))
         else:
            rename_section(rhs, i, sect_name(i, "in some conatainer?"))

   private def mode_help():
      return switch mode:
         case iiGet:
            "Pick up items from the ground or from containers." 

         case iiPut:
            "Drop items on the ground, or put them in a container." + 
            " A yellow box higlights where the item will go."

         case iiEquip:
            "Equip, wield, or take off equipment."

         default: 
            ""

   private def init_mode(new_mode: IIModes):
      mode = new_mode
      lhs_locs = []
      rhs_locs = []
      rhs_cur_section = -1


      switch mode:
         case iiGet, iiPut:
            lhs = held_objects(player, lhs_options(mode))
            lhs_locs = [Location{kind: PlayerInventory}]

            rhs = ObjList{options: rhs_options(mode)}
            let containers = get_floor_objs(rhs, player, player_pos)
            
            rhs_locs = [Location{kind: Ground}]
            for(containers) c: 
               add_container_objects(player, rhs, c)
               push(rhs_locs, Location{kind: Container, obj: c})

            if mode == iiPut:
               rhs_cur_section = 0
            else:
               rhs_cur_section = -1

            set_rhs_section_names()

         case iiEquip:
            lhs = ObjList{options: lhs_options(mode)} 
            lhs_locs = []
            for(AllSlots) slot:
               push(lhs_locs, Location{kind: EquipSlot, slot: slot})

            rhs = ObjList{options: rhs_options(mode),
                          start_letter: length(AllSlots) + 1}  // Don't overlap letter choices.
            rhs_locs = [Location{kind: PlayerInventory}]

            equipment_for(player, lhs, rhs)
            rhs_cur_section = -1
   
def execute(self:: ListUpdate, data: IIData):
   switch data.mode:
      case iiGet:
         let obj = remove_obj(data.rhs, right_sect, right_item)

         if obj:
            add_object(data.lhs, obj, 0)

      case iiPut:
         let obj = remove_obj(data.lhs, left_sect, left_item)

         if obj:
            add_object(data.rhs, obj, right_sect)

      case iiEquip:
         if left_item == -1:
            // Equipping from right.
            //TODO not right, we want an entry for every slot, and to 
            // put it in the correct slot.
            let obj = remove_obj(data.rhs, right_sect, right_item)

            if obj:
               add_object(data.lhs, obj, left_sect)

private def waiting_for_action(data: IIData):
   return data.player_action != nil

private def ii_handler(data: UserData?):
   var rv = Working
   if data and data is IIData:
      if data.rhs_cur_section >= 0:
         if  gl_button("tab") == 1 or gl_button("down") == 1:
            data.rhs_cur_section = (data.rhs_cur_section + 1) % length(data.rhs_locs)
            data.set_rhs_section_names()
         elif gl_button("up") == 1: 
            data.rhs_cur_section = (data.rhs_cur_section - 1) % length(data.rhs_locs)
            data.set_rhs_section_names()

      if gl_button("f1") == 1:
         data.init_mode(iiGet)
      elif gl_button("f2") == 1:
         data.init_mode(iiPut)
      elif gl_button("f3") == 1:
         data.init_mode(iiEquip)

      data.rhs.highlighted_section = data.rhs_cur_section

      im_window(data.title, im_window_always_autoresize):
         im_separator()
         im_columns(3, "interact", true):
            im_column():
               let st, oid, si, ii = display_list(data.lhs)

               if not waiting_for_action(data):
                  if st == dlsCancel:
                     rv = Cancelled
                  elif oid:
                     switch data.mode:
                        case iiGet:
                           pass()

                        case iiPut:
                           data.post_action_update = ListUpdate{
                              left_sect: si, 
                              left_item: ii, 
                              right_sect: data.rhs_cur_section
                           }

                           let rloc = data.rhs_locs[data.rhs_cur_section]

                           let ar, act = put_action(FakeTurnSpan, 0, data.player, 
                                                    oid, rloc.obj)
                           //TODO report ar
                           data.player_action = act

                        case iiEquip:
                           //TODO no remove equipment action yet.
                           pass()

            im_column():
               im_set_column_width(-1, 50)
               im_text(mode_label(data.mode))

            im_column():
               let st, oid, si, ii = display_list(data.rhs)

               if not waiting_for_action(data):
                  if st == dlsCancel:
                     rv = Cancelled
                  elif oid:
                     switch data.mode:
                        case iiGet:
                           data.post_action_update = ListUpdate{
                              right_sect: si, 
                              right_item: ii
                           }

                           let rloc = data.rhs_locs[si]

                           let ar, act = take_action(FakeTurnSpan, 0, 
                                                     data.player, oid, rloc.obj)
                           //TODO report ar
                           data.player_action = act

                        case iiPut:
                           pass()

                        case iiEquip:
                           let lsect = find(data.lhs_locs) x: x.slot == equip_slot(oid)

                           data.post_action_update = ListUpdate{
                              left_sect: lsect, 
                              right_sect: si, 
                              right_item: ii
                           }

                           let ar, act = equip_action(FakeTurnSpan, 0, data.player, 
                                                      oid)

                           print("ARF " + ar)
                           data.player_action = act

         im_separator()
         im_spacing()

         if data.last_window_width > 0:
            im_text_wrap(data.last_window_width - 40):
               im_text(data.mode_help())
            im_spacing()

         im_separator()
         im_spacing()

         im_columns(4, "buttons", false):
            im_column():
               if im_button(mode_button_label(iiGet)) and data.mode != iiGet:
                  data.init_mode(iiGet)

            im_column():
               if im_button(mode_button_label(iiPut)) and data.mode != iiPut:
                  data.init_mode(iiPut)

            im_column():
               if im_button(mode_button_label(iiEquip)) and data.mode != iiEquip:
                  data.init_mode(iiEquip)

            im_column():
               if im_button("Dismiss [Esc]"):
                  rv = Cancelled

         // Workaround for autoresize not setting the width correctly for 
         // columns.  The item lists should be a constant height due to 
         // the min_items parameter to display_list(), so we can set
         // the width to a nice proprotion.
         let c0 = im_get_cursor_pos()
         let wrapx = c0.y * 1.618
   
         im_set_cursor_pos(xy_f{wrapx, c0.y})
         data.last_window_width = wrapx

   return rv

def start_item_interaction(player: ObjId, mode: IIModes):
   let f, ppos = pos(player)
   let data = IIData{title: "Interaction", player: player, player_pos: ppos, 
                     mode: mode}
   
   init_mode(data, mode)
   start_interaction(data, 
                     (fn(d: UserData?): ii_handler(d)))


// Returns any action the player module needs to execute
// in response to a command in the item interaction dialog.
def poll_item_interaction_action() -> ActionBase?:
   if Acts and Acts.data is IIData:
      return Acts.data.player_action
   else:
      return nil

// Should be called by the player module when after an action taken 
// from poll_item_interaction_action() has been executed, and the turn
// is done.
def player_action_done():
   if Acts and Acts.data is IIData:
      Acts.data.player_action = nil
      if Acts.data.post_action_update:
         Acts.data.post_action_update.execute(Acts.data)
         Acts.data.post_action_update = nil
