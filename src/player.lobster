import from "../../../src/crusty/src/"
import actions
import animations
import bus
import gobjs
import imgui
import maps
import objutils
import uitools

enum PlayStates:
   WaitingForInput, Stepping

def PromptHandler() -> DisplayListStatus
                                    
def PromptAction(data: UserData) -> ActionBase?

class ObjPromptData : UserData
   objs: ObjList = ObjList{options: olAddChoiceLetter}
   player: ObjId
   action: PromptAction
   picked: ObjId? = nil

// Stack of prompt states.  Topmost is active.
private var PlayerState = WaitingForInput
private var TurnTime = TurnSpan{0.0, 0.0} // Valid when PlayerState == Stepping
private var GameTime : float = 0    // Abs game time.  (ie, total time stepping, not waiting for input)

private def obj_prompt_handler(data: UserData?) -> InteractionStatus:
   var rv = Working

   if data and data is ObjPromptData:
      let ws = gl_window_size().to_f * xy_f{0.4, 0.5} 
      im_set_next_window_pos(ws, im_cond_first_use_ever, xy_f{0.5, 0.5})
      im_window(data.title, 0):
         let status, picked = display_list(data.objs)

         if status == dlsCancel:
            rv = Cancelled
         elif picked:
            data.picked = picked
            rv = Finished

   return rv
   
def prompt_for_object(player: ObjId, title: string, cands: ObjList, skip_one: bool, action):
   let data = ObjPromptData{title: title, objs: cands, player: player, action: action}  

   if skip_one and count(cands) == 1:
      // Just one, so perform the action without a prompt.
      data.picked = first(cands)
      start_interaction(data, (fn(a: UserData?): obj_prompt_handler(a)), Finished)
   else:
      start_interaction(data, (fn(a: UserData?): obj_prompt_handler(a)))

def game_time() -> float:
   return GameTime

//TODO player object pieces should go in game module.  
//     code for dealing with turns should stay.  And input
//     mapping here?

// For player actions, don't scale the time of the action - the time of the
// action will be the span that all other actions will need to scale to.
let FakeTurnSpan = TurnSpan{0.0, 999999999990.0}

private def perform_action(act):
   if act:
      debug(): "Player turn execute"
      animations_turn_begin()
      TurnTime = TurnSpan{GameTime, GameTime + act.duration}
      execute(act)
      PlayerState = Stepping
      let t0 = seconds_elapsed()
      process_callbacks(TurnTime, TurnTime.end)
      let t1 = seconds_elapsed()
      debug(): "Callbacks seconds: " + (t1-t0)
      animations_turn_finalize(TurnTime)
   else:
      warn(): "Can\'t move "

def PlayerAction(player: ObjId, now: float) -> ActionBase?

class Binding:
   key: string
   desc: string
   afn: PlayerAction

private let Bindings: [Binding] = []

private let pl_fwd_action = fn(player: ObjId, now: float) -> ActionBase?:
   let f, p = pos(player)
   let f1, diri = direction(player)

   let r, act = move_action(FakeTurnSpan, GameTime, player, p, p + all_dirs[diri])
   act

def bind(key, desc, afn): push(Bindings, Binding{key: key, desc: desc, afn: afn})

private def closed_containers_at(p: xy_i) -> ObjList:
   let rv = ObjList{options: olAddChoiceLetter}

   add_section(rv, "What have we here?")
   for_objects_at(p) o:
      //TODO instead of flag test, should we check with close action, so we always use the
      //    same criteria?
      if o and object_spec(o).flags & ItemFlags_Container and not (object_state(o) & StateFlags_Open):
         add_object(rv, o)

   return rv

private def opened_containers_at(p: xy_i) -> ObjList:
   let rv = ObjList{options: olAddChoiceLetter}

   for_objects_at(p) o:
      //TODO instead of flag test, should we check with open action, so we always use the
      //    same criteria?
      if o and object_spec(o).flags & ItemFlags_Container and (object_state(o) & StateFlags_Open):
         add_object(rv, o)

   return rv

// Adds a section for any items inside of a container `o` to `list`.
private def add_container_objects(player: ObjId, list: ObjList, o: ObjId):
   add_section(list, "In " + object_spec(o).short_name)
   for_objects_in(o) io:
      let r0, act0 = take_action(FakeTurnSpan, GameTime, player, io)

      if act0:
         add_object(list, io)

private def grabbable_objs_at(player: ObjId, p: xy_i) -> ObjList:
   let rv = ObjList{options: olAddChoiceLetter}
   let containers = []
   add_section(rv, "On ground")
   for_objects_at(p) o:
      if o:
         let r, act = take_action(FakeTurnSpan, GameTime, player, o)

         if act:
            add_object(rv, o)
         elif object_spec(o).flags & ItemFlags_Container:
            push(containers, o)


   for(containers) o:
      add_container_objects(player, rv, o)

   return rv

private def held_objects(player: ObjId) -> ObjList:
   let rv = ObjList{options: olAddChoiceLetter|olGroup}

   add_section(rv, "In inventory")
   for_objects_in(player) o:
      add_object(rv, o)

   return rv

def player_init():
   bind("w", "Move forward") player, now:
      let f, p = pos(player)
      let f1, diri = direction(player)
      let r, act = move_action(FakeTurnSpan, GameTime, player, p, p + all_dirs[diri])
      act

   bind("s", "Move back") player, now:
      let f, p = pos(player)
      let f1, diri = direction(player)
      let r, act = move_action(FakeTurnSpan, GameTime, player, p, p + all_dirs[diri]*-1)
      act

   bind("a", "Turn left") player, now:
      let f, dir = direction(player)
      let diri = turned_left(dir)
      let r, act = turn_action(FakeTurnSpan, GameTime, player, dir, diri)
      act

   bind("d", "Turn right") player, now:
      let f, dir = direction(player)
      let diri = turned_right(dir)
      let r, act = turn_action(FakeTurnSpan, GameTime, player, dir, diri)
      act

   bind("o", "Open") player, now:
      let f, p = pos(player)
      let cands = closed_containers_at(p)

      if count(cands) > 0:
         prompt_for_object(player, "Open what?", cands, true) data:
            if data is ObjPromptData and data.picked:
               let r, act = open_action(FakeTurnSpan, GameTime, data.player, 
                                        data.picked)
               act
            else:
               nil
      nil

   bind("c", "Close") player, now:
      let f, p = pos(player)
      let cands = opened_containers_at(p)

      if count(cands) > 0:
         prompt_for_object(player, "Close what?", cands, true) data:
            if data is ObjPromptData and data.picked:
               let r, act = close_action(FakeTurnSpan, GameTime, data.player, 
                                         data.picked)
               act
            else:
               nil
      nil


   bind("g", "Take") player, now:
      let f, p = pos(player)
      let cands = grabbable_objs_at(player, p)

      if count(cands) > 0:
         prompt_for_object(player, "Take what?", cands, false) data:
            if data is ObjPromptData and data.picked:
               let r, act = take_action(FakeTurnSpan, GameTime, data.player, 
                                        data.picked)
               act
            else:
               nil
      nil

   bind("i", "Inventory") player, now: 
      let cands = held_objects(player)

      if count(cands) > 0:
         prompt_for_object(player, "Inventory", cands, false) data:
            nil
      nil

   animations_turn_begin()

// Iterates through possible player actions.
// Not based on the actions.for_possible_actions,
// because that requires more logic to get from an 
// action to the possible key bindings.  (esp since
// the actions are subclasses of ActionBase rather than
// being a case object like in previous Nim impl.
def for_player_actions(player: ObjId, now: float, body):
   //for(Bindings) b:
      //let ff = b.afn
      //let act = ff(player, now)
      //
      //if act:
      //   body(b.key, b.desc)
      //elif length(CurPrompt) > saved_sz:
      //   // Well, close enough they need to prompt.
      //   body(b.key, b.desc)
      //   restore_prompts()
   body("Escape", "Abandon all hope")


enum HandleInputResult:
   Good, GoodSteppingEnded, GoodTurnBegins, ExitMainLoop

def player_handle_input(player: ObjId):
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
                     let act = mkact(player, GameTime)
                     if act:
                        perform_action(act)
                        rv = GoodTurnBegins
                     else:
                        // Possible there's an immediately answered
                        // prompt.
                        check_prompted_action()
                     break

            if gl_button("Q") == 1:
               play_wav("dist/ouch3.wav")

         case Stepping:
            let dT = gl_delta_time() * animations_time_scale()

            GameTime = min(TurnTime.end, GameTime + dT)

            anim_play_one_shots(GameTime)
            if GameTime == TurnTime.end:
               PlayerState = WaitingForInput
               rv = GoodSteppingEnded


        // process_callbacks(now)
   return rv

// Called when it's ok to do imgui UI drawing.
// The projection is already set up for pixel coords.
def player_handle_ui():
   noop()
