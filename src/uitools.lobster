// Code for ui.  Split out from player module, as it was starting to get
// messy.
import from "../../../src/crusty/src/"
import actions
import algs
import bus
import color
import config_generated
import engrish
import imgui
import objlist
import objutils

// For keeping up with what the mouse is hovering over.
private var HoverGridCoord = xy_i{0,0}
private var TimeHovering = 0.0

// Should be called per-frame to update the hover state.
def hover_sample_mouse(view: Rectf, tile_size: float):
   let mp = world_mouse_pos(view, tile_size)
   let gp = xy_i{floor(mp.x), floor(mp.y)}

   if gp == HoverGridCoord:
      TimeHovering += gl_delta_time()
   else:
      TimeHovering = 0.0
      HoverGridCoord = gp

// If the mouse has been hovering over
// a grid long enough, returns (true, gridcoord).
// Otherwise, returns (false, x)
def hovering_coord() -> bool, xy_i:
   if TimeHovering > 0.5:
      return true, HoverGridCoord
   else:
      return false, xy_i{0,0}

// Should be called for times we don't want hovers.
def inhibit_map_mouse_hover():
   TimeHovering = 0.0

// State used for column alignment helpers.
class ColAlignState:
   cur_edge_x: float = 0
   cols_added: bool = false

private let AlignState: [ColAlignState] = []

// Starts a row of items aligned in fixed columns.
// x_offset is the pixel offset from the current position
// to start in.  Useful for fixed tables, or being able
// to nest sets of columns.  (unlike the ImGui col support)
def aligned_row(x_offset: float, body):
   push(AlignState, ColAlignState{cur_edge_x: x_offset + im_get_cursor_pos().x})
   body()
   pop(AlignState)

// Starts a column of the given width.  
// Only callable from within a aligned_row() call.
// Does an implicit im_widget_group() so you don't 
// have to in the body.
def aligned_col(width: float, body):
   assert width > 0
   let s = AlignState[length(AlignState)-1]

   if s.cols_added:
      im_same_line()

   im_set_cursor_pos(xy_f{s.cur_edge_x, im_get_cursor_pos().y})
   im_widget_group():
      body()

   s.cur_edge_x += width
   s.cols_added = true

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

// If there's an interaction going on, returns the UserData
// for it.  Returns nil otherwise.
def current_interaction_data() -> UserData?:
   if Acts:
      return Acts.data
   else:
      return nil

//
// Utility functions for building up ObjLists used by UI tools.
//
def melee_opponents_in_range(who: ObjId, now: float) -> [ObjId]:
   let rv = []
   let pf, p = pos(who)
   let df, face = direction(who)

   if pf and df:
      for([face, turned_left(face), turned_right(face)]) tfac:
         let front = p + all_dirs[tfac]
         let o = living_thing_at(front)
         
         if o:
            let ar, act = melee_attack_action(FakeTurnSpan, now, who, o, false)

            if act:
               push(rv, o)

   return rv

def is_open_container(o: ObjId):
   return is_open_container(object_spec(o), object_state(o))

def is_closed_container(o: ObjId):
   return object_spec(o).flags & ItemFlags_Container and not (object_state(o) & StateFlags_Open)

def closed_containers_at(p: xy_i) -> ObjList:
   let rv = ObjList{options: olAddChoiceLetter}

   add_section(rv, "Containers")
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

def unequippable_sample(who: ObjId) -> ObjId?:
   for_objects_in(who) o:
      let ar, act = unequip_action(FakeTurnSpan, 0, who, o)

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
   add_section(list, "In " + pretty_name(o, 1))
   for_objects_in(o) io:
      let r0, act0 = take_action(FakeTurnSpan, 0, player, io, o)

      if act0:
         add_object(list, io)

private let GroundSection = "On ground"

def all_ground_objects(p: xy_i) -> ObjList:
   let rv = ObjList{options: olGroup}

   add_section(rv, GroundSection)

   for_objects_at(p) o:
      if o:
         let sp = object_spec(o)
         let fl = object_state(o)

         if sp.flags & ItemFlags_Living == 0 or fl & StateFlags_Dead:
            add_object(rv, o)            

   return rv

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

   inhibit_map_mouse_hover()
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

   inhibit_map_mouse_hover()
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
   iiEquip,
   iiExamine

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

      case iiExamine:
         return olAddChoiceLetter|olGroup

   return olNone

private def rhs_options(m: IIModes):
   return switch m:
      case iiGet:
          olAddChoiceLetter|olGroup

      case iiPut:
          olGroup

      case iiEquip:
         return olAddChoiceLetter|olGroup|olOnlyOne

      case iiExamine:
         return olNone

      default:
         return olNone

private def mode_label(m: IIModes):
   return switch m:
      case iiGet:
         "< Get <"
      
      case iiPut:
         "> Put >"

      case iiEquip:
         "< Equip >"

      case iiExamine:
         " Examine "

      default:
         return "<>"

private def mode_button_label(m: IIModes):
   return switch m:
      case iiGet:
         "Get [F1]"

      case iiPut:
         "Put [F2]"

      case iiEquip:
         "Equip/Remove [F3]"

      case iiExamine:
         "Examine [F4]"

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

   // Object selected for examination.
   examining: ObjId? = nil

   // Action for player module to execute.  While this is non-nil, 
   // we ignore input.  It will be set back to nil once the player
   // module has executed the action, and the turn is finished.
   player_action: ActionBase? = nil
   player_action_result: ActionResult = GoodResult
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
            rename_section(rhs, i, sect_name(i, pretty_name(loc.obj, 1)))
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

         case iiExamine:
            "Examine details of equipment."

         default: 
            ""

   def examine_item_ui():
      if examining:
         let spec = object_spec(examining)
         let col_width = 200

         if last_window_width > 0:
            im_text_wrap(last_window_width - 40):
               aligned_row(0):
                  aligned_col(80):
                     im_text("picsha")

                  aligned_col(col_width*2):
                     im_text(pretty_name(examining, 1))
                     im_text(spec.desc())

               for(2): im_spacing()
               im_text("Weighs " + present_weight(spec.weight()))

               let ws = spec.weapon_stats()

               if ws:
                  //TODO extract out this repeated crap for fake columns into
                  // a function.
                  im_spacing()
                  im_text(capitalize(ItemSlotPresent[spec.slot()]) + " weapon")

                  aligned_row(25):
                     aligned_col(col_width):
                        im_text("Damage")

                     let weapdam  = ws.dmg()

                     if weapdam:
                        aligned_col(col_width):
                           im_text(present(weapdam) + " " + DmgTypePresent[ws.kind()])

                  aligned_row(25):
                     aligned_col(col_width):   
                        im_text("Weapon speed")

                     aligned_col(col_width):
                         im_text(string(ws.speed()))

               if spec.slot() != ItemSlot_None:
                  let bon = []

                  for(spec.equip_bonuses_length()) i:
                     let eb = spec.equip_bonuses(i)

                     if eb.modifier() != 0:
                        push(bon, present(eb))

                  if length(bon) > 0:
                     im_spacing()
                     im_text(sentence(append(["Grants"], comma_list(bon))))


      else:
         im_text("Select an item to examine.")

   private def init_mode(new_mode: IIModes):
      mode = new_mode
      lhs_locs = []
      rhs_locs = []
      rhs_cur_section = -1


      inhibit_map_mouse_hover()
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

         case iiExamine:
            lhs = held_objects(player, lhs_options(mode))
            lhs_locs = []
            rhs_locs = []
            examining = nil

            for(AllSlots) slot, sli:
               let eq = equipment_at(player, slot)

               if eq: 
                  add_section(lhs, SlotHeading[sli])
                  add_object(lhs, eq)
   
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
            let obj = remove_obj(data.rhs, right_sect, right_item)

            if obj:
               add_object(data.lhs, obj, left_sect)

         else:
            // Removing from left.
            let obj = remove_obj(data.lhs, left_sect, left_item)

            if obj:
               add_object(data.rhs, obj, right_sect)

      case iiExamine:
         pass()


private def waiting_for_action(data: IIData):
   return data.player_action != nil or data.player_action_result.kind != arOk

private def ii_handler(data: UserData?):
   var rv = Working

   inhibit_map_mouse_hover()
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
      elif gl_button("f4") == 1:
         data.init_mode(iiExamine)

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
                           let rloc = data.rhs_locs[data.rhs_cur_section]

                           let ar, act = put_action(FakeTurnSpan, 0, data.player, 
                                                    oid, rloc.obj)
                           data.player_action_result = ar
                           data.player_action = act

                           if act:
                              data.post_action_update = ListUpdate{
                                 left_sect: si, 
                                 left_item: ii, 
                                 right_sect: data.rhs_cur_section
                              }


                        case iiEquip:
                           let ar, act = unequip_action(FakeTurnSpan, 0, data.player, 
                                                        oid)

                           data.player_action_result = ar
                           data.player_action = act
                           if act:
                              data.post_action_update = ListUpdate{
                                 left_sect: si, 
                                 left_item: ii, 
                                 right_sect: 0
                              }

                        case iiExamine:
                           data.examining = oid


            im_column():
               im_set_column_width(-1, 100)
               im_text(mode_label(data.mode))

            im_column():
               if data.mode == iiExamine:
                  data.examine_item_ui()
               else:
                  let st, oid, si, ii = display_list(data.rhs)

                  if not waiting_for_action(data):
                     if st == dlsCancel:
                        rv = Cancelled
                     elif oid:
                        switch data.mode:
                           case iiGet:
                              let rloc = data.rhs_locs[si]

                              let ar, act = take_action(FakeTurnSpan, 0, 
                                                        data.player, oid, rloc.obj)
                              data.player_action = act
                              data.player_action_result = ar
                              if act:
                                 data.post_action_update = ListUpdate{
                                    right_sect: si, 
                                    right_item: ii
                                 }

                           case iiPut:
                              pass()

                           case iiEquip:
                              let lsect = find(data.lhs_locs) x: x.slot == equip_slot(oid)

                              let ar, act = equip_action(FakeTurnSpan, 0, data.player, 
                                                         oid)

                              data.player_action = act
                              data.player_action_result = ar
                              if act:
                                 data.post_action_update = ListUpdate{
                                    left_sect: lsect, 
                                    right_sect: si, 
                                    right_item: ii
                                 }

                           case iiExamine:
                              pass()

         im_separator()
         im_spacing()

         if data.last_window_width > 0:
            im_text_wrap(data.last_window_width - 40):
               im_text(data.mode_help())
            im_spacing()

         im_separator()
         im_spacing()

         im_columns(5, "buttons", false):
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
               if im_button(mode_button_label(iiExamine)) and data.mode != iiExamine:
                  data.init_mode(iiExamine)

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
def poll_item_interaction_action() -> ActionResult, ActionBase?:
   if Acts and Acts.data is IIData:
      return Acts.data.player_action_result, Acts.data.player_action
   else:
      return GoodResult, nil

// Should be called by the player module when after an action taken 
// from poll_item_interaction_action() has been executed, and the turn
// is done.
def player_action_done():
   if Acts and Acts.data is IIData:
      Acts.data.player_action = nil
      if Acts.data.post_action_update:
         Acts.data.post_action_update.execute(Acts.data)
         Acts.data.post_action_update = nil

private def can_see_stats_of(player, other) -> bool:
   return player == other

// For living things, displays information for the mouse hover.
def ui_for_living(player: ObjId, oi: ObjId, now: float):
   let spec = object_spec(oi)
   let wsz = gl_window_size()

   im_push_text_wrap_pos(im_get_cursor_pos().x + wsz.x / 6.0)
   im_text(pretty_name(oi, 1))
   im_text("    " + spec.desc)

   if can_see_stats_of(player, oi):
      let st = object_stats(oi)
      im_separator()
      im_spacing()
      im_spacing()
      im_columns(2, "statdisp", true):
         for(AllAtts) att:
            let bv = base_value(st, att.st)
            let av = value(st, now, att.st)

            im_column():
               im_text(att.name)
            im_column():
               var v = string(av)
               let sd = av - bv

               if sd > 0:
                  v += " (+" + sd + ")"
               elif sd < 0:
                  v += " (" + sd + ")"

               im_text(v)

         // Special handling for HP
         im_column(): im_text("HP")
         im_column():
            let base = base_value(st, GameStats_Hp, true, now)
            let cur = value(st, now, GameStats_Hp)
            im_text(cur + "/" + base)

   let equipped = ObjList{options: olGroup}
   let equippable = ObjList{}

   equipment_for(oi, equipped, equippable)

   if count(equipped) > 0:
      im_separator()
      remove_empty_sections(equipped)
      display_list(equipped, 0)

   im_pop_text_wrap_pos()

def ui_for_objects(objs: ObjList):
   display_list(objs, 0)
