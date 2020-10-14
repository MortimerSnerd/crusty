import from "../../../src/crusty/src/"
import actions
import animations
import bus
import gobjs
import maps
import objutils


enum PlayStates:
   WaitingForInput, Stepping

private var PlayerState = WaitingForInput
private var TurnTime = TurnSpan{0.0, 0.0} // Valid when PlayerState == Stepping
private var GameTime : float = 0    // Abs game time.  (ie, total time stepping, not waiting for input)

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

   animations_turn_begin()

// Iterates through possible player actions.
// Not based on the actions.for_possible_actions,
// because that requires more logic to get from an 
// action to the possible key bindings.  (esp since
// the actions are subclasses of ActionBase rather than
// being a case object like in previous Nim impl.
def for_player_actions(player: ObjId, now: float, body):
   for(Bindings) b:
      let ff = b.afn
      let act = ff(player, now)

      if act:
         body(b.key, b.desc)

enum HandleInputResult:
   Good, GoodSteppingEnded, GoodTurnBegins, ExitMainLoop

def player_handle_input(player: ObjId):
   var rv = Good
   maps_frame()
   if gl_button("escape") == 1:
      rv = ExitMainLoop
   else:
      switch PlayerState:
         case WaitingForInput:
            for(Bindings) b:
               if gl_button(b.key) == 1:
                  let mkact = b.afn
                  let act = mkact(player, GameTime)
                  perform_action(act)
                  rv = GoodTurnBegins
                  break

            if gl_button("q") == 1:
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
