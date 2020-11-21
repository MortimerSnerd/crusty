import from "../../../src/crusty/src/"
import actions
import actionlog
import animations
import bus
import gobjs
import imgui
import maps
import objutils
import uitools

enum PlayStates:
   WaitingForInput, Stepping

private var PlayerState = WaitingForInput
private var TurnTime = TurnSpan{0.0, 0.0} // Valid when PlayerState == Stepping
private var GameTime : float = 0    // Abs game time.  (ie, total time stepping, not waiting for input)

def game_time() -> float:
   return GameTime

private def perform_action(act):
   if act:
      debug(): "Player turn execute"
      animations_turn_begin()
      TurnTime = TurnSpan{GameTime, GameTime + act.duration}
      execute(act)

      actionlog_present(present(act.who, act, nil))

      PlayerState = Stepping
      let t0 = seconds_elapsed()
      process_callbacks(TurnTime, TurnTime.end)
      let t1 = seconds_elapsed()
      debug(): "Callbacks seconds: " + (t1-t0)
      animations_turn_finalize(TurnTime)
   else:
      warn(): "Can\'t move "

// `prompt` - if false, the action should pick an item to make an 
//            action for.  Mainly used to check for valid player actions.
def PlayerAction(player: ObjId, now: float, mouse_pos: xy_i, prompt: bool) -> ActionBase?

class Binding:
   key: string
   desc: string
   afn: PlayerAction

private let Bindings: [Binding] = []
private let ContextActionDesc = "Context Action"

def bind(key, desc, afn): push(Bindings, Binding{key: key, desc: desc, afn: afn})

def maybe_bump_attack(player: ObjId, ppos: xy_i, facing: Directions, orig_ar: ActionResult) -> ActionResult, ActionBase?:
   let fwdp = ppos + all_dirs[facing]
   let target = living_thing_at(fwdp)

   if target:
     return melee_attack_action(FakeTurnSpan, GameTime, player, target) 
   else:
      return orig_ar, nil

def player_init():
   // Danger - don't reference the player parameter when 
   // calling this from interactions, that won't be bound 
   // once this goes out of scope.
   def mumble(player: ObjId, act, ar):
      if not act:
         actionlog_present(present(player, act, ar))

   bind("w", "Move forward") player, now, _, prompt:
      let f, p = pos(player)
      let f1, diri = direction(player)
      let r, act = move_action(FakeTurnSpan, GameTime, player, p, p + all_dirs[diri])
      var finact: ActionBase? = act 
       
      if not finact:
         let atk_r, atk_act = maybe_bump_attack(player, p, diri, r)

         if atk_act:
            if prompt: mumble(player, atk_act, atk_r)
            finact = atk_act
         else:
            with_closed_door_at(p + all_dirs[diri]) door:
               let r_o, act_o = open_action(FakeTurnSpan, now, player, door)
               if prompt: mumble(player,act,r)
               finact = act_o
      else:
         if prompt: mumble(player,act,r)

      finact

         

   bind("mouse1", ContextActionDesc) player, now, mouse_pos, prompt:
      // Try context sensitive actions in priority order.
      var act: ActionBase? = nil
      
      let lv = living_thing_at(mouse_pos) 
      if lv:
         let r, a = melee_attack_action(FakeTurnSpan, now, player, lv, prompt)
         act = a

      if not act:
         let cc = closed_containers_at(player, mouse_pos)

         for_all_items(cc) o:
            let r, a = open_action(FakeTurnSpan, now, player, o)

            if a:
               act = a
               false
            else:
               true

      if not act:
         let oc = opened_containers_at(player, mouse_pos)

         for_all_items(oc) o:
            let r, a = close_action(FakeTurnSpan, now, player, o)

            if a:
               act = a
               false
            else:
               true

      act

   bind("s", "Move back") player, now, _, prompt:
      let f, p = pos(player)
      let f1, diri = direction(player)
      let r, act = move_action(FakeTurnSpan, GameTime, player, p, p + all_dirs[diri]*-1)
      if prompt: mumble(player,act,r)
      act

   bind("a", "Turn left") player, now, _, prompt:
      let f, dir = direction(player)
      let diri = turned_left(dir)
      let r, act = turn_action(FakeTurnSpan, GameTime, player, dir, diri)
      if prompt: mumble(player,act,r)
      act

   bind("d", "Turn right") player, now, _, prompt:
      let f, dir = direction(player)
      let diri = turned_right(dir)
      let r, act = turn_action(FakeTurnSpan, GameTime, player, dir, diri)
      if prompt: mumble(player,act,r)
      act


   bind("o", "Open") player, now, _, prompt:
      let f, p = pos(player)
      let cands = closed_containers_at(player, p)
      var rv = nil

      if count(cands) > 0:
         if prompt:
            prompt_for_object(player, "Open what?", cands, true) data:
               if data is ObjPromptData and data.picked:
                  let r, act = open_action(FakeTurnSpan, GameTime, data.player,
                                           data.picked)
                  mumble(data.player,act,r)
                  act
               else:
                  nil
         else:
            let r, act = open_action(FakeTurnSpan, GameTime, player, 
                                     first(cands))
            rv = act
      rv

   bind("z", "Attack") player, now, _, prompt:
      let cands = melee_opponents_in_range(player, GameTime)
      var rv = nil

      if length(cands) > 0:
         if prompt:
            let ol = ObjList{options: olAddChoiceLetter|olHighlightGameobj}

            add_section(ol, "Targets")
            for(cands) c:
               add_object(ol, c)
            
            prompt_for_object(player, "Attack who?", ol, true) data:
               if data is ObjPromptData and data.picked:
                  let ar, act = melee_attack_action(FakeTurnSpan, GameTime, 
                                                    data.player, 
                                                    data.picked)
                  mumble(data.player, act, ar)
                  rv = act
               else:
                  nil
         else:
            let ar, aa = melee_attack_action(FakeTurnSpan, GameTime, player, 
                                             cands[0], false)

            rv = aa
      rv

   bind("c", "Close") player, now, _, prompt:
      let f, p = pos(player)
      let cands = opened_containers_at(player, p)
      var rv = nil

      if count(cands) > 0:
         if prompt:
            prompt_for_object(player, "Close what?", cands, true) data:
               if data is ObjPromptData and data.picked:
                  let r, act = close_action(FakeTurnSpan, GameTime, data.player, 
                                            data.picked)
                  mumble(data.player,act,r)
                  act
               else:
                  nil
         else:
            let r, act = close_action(FakeTurnSpan, GameTime, player, 
                                      first(cands))
            rv = act
      rv

   bind("g", "Take") player, now, _, prompt:
      let f, p = pos(player)
      let cands = grabbable_objs_at(player, p)
      var rv = nil

      if count(cands) > 0:
         if prompt:
            start_item_interaction(player, iiGet)
         else:
            let obj = first(cands)
            let r, act = take_action(FakeTurnSpan, GameTime, player, 
                                     obj, container_of(obj))
            mumble(player,act,r)
            rv = act

      rv

   bind("x", "Drop") player, now, _, prompt:
      let cands = held_objects(player)
      var rv = nil

      if count(cands) > 0:
         if prompt:
            start_item_interaction(player, iiPut)
         else:
            let r, act = put_action(FakeTurnSpan, GameTime, player, 
                                    first(cands), nil)

            rv = act
      rv

   bind("e", "Equip") player, now, _, prompt:
      let item = equippable_sample(player)
      var rv = nil

      if item:
         if prompt:
            start_item_interaction(player, iiEquip)
         else:
            let r, act = equip_action(FakeTurnSpan, GameTime, player, 
                                        item)

            rv = act
      rv

   bind("r", "Remove") player, now, _, prompt:
      let item = unequippable_sample(player)
      var rv = nil

      if item:
         if prompt:
            start_item_interaction(player, iiEquip)
         else:
            let r, act = unequip_action(FakeTurnSpan, GameTime, player, 
                                        item)

            rv = act
      rv

   bind("i", "Inventory") player, now, _, prompt: 
      if prompt:
         start_item_interaction(player, iiExamine)
      nil

   animations_turn_begin()

// Iterates through possible player actions.
// Not based on the actions.for_possible_actions,
// because that requires more logic to get from an 
// action to the possible key bindings.  (esp since
// the actions are subclasses of ActionBase rather than
// being a case object like in previous Nim impl.
def for_player_actions(player: ObjId, now: float, mouse_pos: xy_i, body):
   for(Bindings) b:
      let ff = b.afn
      let act = ff(player, now, mouse_pos, false)

      if act:
         if b.desc == ContextActionDesc:
            body(b.key, act.short_desc(), act.duration)
         else:
            body(b.key, b.desc, act.duration)

enum HandleInputResult:
   Good, GoodSteppingEnded, GoodTurnBegins, ExitMainLoop

def player_handle_input(player: ObjId, mouse_pos: xy_i):
   var rv = Good

   def check_prompted_action():
      var handled = false
      let intr = finished_interaction()

      if intr and intr.status == Finished:
         if intr.data and intr.data is ObjPromptData:
            let act = intr.data.action

            let uact = act(intr.data)

            if uact:
               perform_action(uact)
               rv = GoodTurnBegins

            handled = true
      else:
         let ar, act = poll_item_interaction_action()

         if act:
            act.time = GameTime  // Patch in right time, ui module doesn't know.
            perform_action(act)
            rv = GoodTurnBegins
            handled = true
         else:
            let msg = present(player, act, ar)

            if length(msg) > 0: actionlog_present(msg)

      return handled

   maps_frame()
   if not interaction_active() and gl_button("escape") == 1:
      rv = ExitMainLoop
   else:
      switch PlayerState:
         case WaitingForInput:
            if not check_prompted_action() and not interaction_active():
               for(Bindings) b:
                  if gl_button(b.key) == 1:
                     let mkact = b.afn
                     let act = mkact(player, GameTime, mouse_pos, true)
                     if act:
                        perform_action(act)
                        rv = GoodTurnBegins
                     else:
                        // Possible there's an immediately answered
                        // prompt.
                        check_prompted_action()
                     break

         case Stepping:
            let dT = gl_delta_time() * animations_time_scale()

            inhibit_map_mouse_hover()
            GameTime = min(TurnTime.end, GameTime + dT)

            anim_play_one_shots(GameTime)
            if GameTime == TurnTime.end:
               PlayerState = WaitingForInput
               rv = GoodSteppingEnded

               // If the last action was for an item interaction dialog, 
               // let the dialog know the deed is done.
               player_action_done()

        // process_callbacks(now)
   return rv


// Called when it's ok to do imgui UI drawing.
// The projection is already set up for pixel coords.
def player_handle_ui(player: ObjId, wview: Rectf, tile_size: float):

   let cid = current_interaction_data()
   
   if cid and cid is ObjPromptData:
      cid.objs.display_object_choices(wview, tile_size, GameTime)

   actionlog_render()
   hover_sample_mouse(wview, tile_size)

   let hovering, hc = hovering_coord()

   if hovering and is_lit_and_visible(hc):
      let lv = living_thing_at(hc)
      let gobjs = all_ground_objects(hc)
      let mp = gl_mouse_pos(0) + xy_i{30, 0}

      if lv or count(gobjs) > 0:
         im_set_next_window_pos(xy_f{mp.x, mp.y}, im_cond_always, xy_0)
         im_window("hoverpop", im_window_no_titlebar | im_window_always_autoresize):
            if lv:
               ui_for_living(player, lv, GameTime)

            if count(gobjs) > 0:
               if lv:
                  im_separator()
               ui_for_objects(gobjs)



