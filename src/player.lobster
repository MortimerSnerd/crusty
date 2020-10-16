import from "../../../src/crusty/src/"
import actions
import animations
import bus
import gobjs
import imgui
import maps
import objutils


enum PlayStates:
   WaitingForInput, Stepping

def PromptAction(o: ObjId) -> void

class PromptState:
   action: PromptAction
   objs: ObjList = ObjList{options: olAddChoiceLetter}
   title: string = ""
   result: ActionBase? = nil
   done: bool = false
   player: ObjId

private var CurPrompt: PromptState? = nil
private var PlayerState = WaitingForInput
private var TurnTime = TurnSpan{0.0, 0.0} // Valid when PlayerState == Stepping
private var GameTime : float = 0    // Abs game time.  (ie, total time stepping, not waiting for input)


private def prompt_handler():
   var rv = dlsOk

   if CurPrompt:
      let ws = gl_window_size().to_f * xy_f{0.4, 0.5} 
      im_set_next_window_pos(ws, im_cond_first_use_ever, xy_f{0.5, 0.5})
      im_window(CurPrompt.title, 0):
         let status, picked = display_list(CurPrompt.objs)

         if status == dlsCancel:
            rv = status
         elif picked:
            let act = CurPrompt.action
            act(picked)

   return rv

private def prompt_for_object(player: ObjId, title: string, choices: ObjList, skip_one: bool, action: PromptAction):
   assert CurPrompt == nil
   if count(choices) > 0:
      CurPrompt = PromptState{action: action, 
                              objs: choices, 
                              title: title, 
                              player: player}
      if skip_one and count(choices) == 1:
         let o = first(choices)

         if o:
            action(o)

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
      add_section(rv, "In " + object_spec(o).short_name)
      for_objects_in(o) io:
         let r0, act0 = take_action(FakeTurnSpan, GameTime, player, io)

         if act0:
            add_object(rv, io)

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
         prompt_for_object(player, "Open what?", cands, true) o:
            if CurPrompt: 
               let r, act = open_action(FakeTurnSpan, GameTime, CurPrompt.player, o)
               CurPrompt.result = act
               CurPrompt.done = true
      nil

   bind("c", "Close") player, now:
      let f, p = pos(player)
      let cands = opened_containers_at(p)

      if count(cands) > 0:
         prompt_for_object(player, "Close what?", cands, true) o:
            if CurPrompt:
               let r, act = close_action(FakeTurnSpan, GameTime, CurPrompt.player, o)
               CurPrompt.result = act
               CurPrompt.done = true
      nil


   bind("g", "Take") player, now:
      let f, p = pos(player)
      let cands = grabbable_objs_at(player, p)

      if count(cands) > 0:
         prompt_for_object(player, "Take what?", cands, false) o:
            if CurPrompt:
               let r, act = take_action(FakeTurnSpan, GameTime, CurPrompt.player, o)
               CurPrompt.result = act
               CurPrompt.done = true
      nil

   bind("i", "Inventory") player, now: 
      let cands = held_objects(player)

      if count(cands) > 0:
         prompt_for_object(player, "Inventory", cands, false) o:
            if CurPrompt:
               CurPrompt.done = true
      nil

   animations_turn_begin()

// Iterates through possible player actions.
// Not based on the actions.for_possible_actions,
// because that requires more logic to get from an 
// action to the possible key bindings.  (esp since
// the actions are subclasses of ActionBase rather than
// being a case object like in previous Nim impl.
def for_player_actions(player: ObjId, now: float, body):
   let saved = CurPrompt

   CurPrompt = nil
   for(Bindings) b:
      let ff = b.afn
      let act = ff(player, now)

      if act:
         body(b.key, b.desc)
      elif CurPrompt:
         // Well, close enough they need to prompt.
         body(b.key, b.desc)
         CurPrompt = nil

   CurPrompt = saved

enum HandleInputResult:
   Good, GoodSteppingEnded, GoodTurnBegins, ExitMainLoop

def player_handle_input(player: ObjId):
   var rv = Good

   def check_prompted_action():
      if CurPrompt and CurPrompt.done:
         if CurPrompt.result:
            perform_action(CurPrompt.result)
            rv = GoodTurnBegins
         else:
            print("BAD ACTION")

         CurPrompt = nil
         return true
      elif CurPrompt:
         return true
      else:
         return false

   maps_frame()
   if not CurPrompt and gl_button("escape") == 1:
      rv = ExitMainLoop
   else:
      switch PlayerState:
         case WaitingForInput:
            if not check_prompted_action():
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
   if prompt_handler() == dlsCancel:
      CurPrompt = nil
