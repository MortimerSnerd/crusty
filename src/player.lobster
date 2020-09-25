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

def player_init():
   animations_turn_begin()

enum HandleInputResult:
   Good, ExitMainLoop

// For player actions, don't scale the time of the action - the time of the
// action will be the span that all other actions will need to scale to.
private let FakeTurnSpan = TurnSpan{0.0, 999999999990.0}

def player_handle_input(player: ObjId):
   var rv = Good

   def perform_action(r, act):
      if act:
         TurnTime = TurnSpan{GameTime, GameTime + act.duration}
         execute(act)
         PlayerState = Stepping
         process_callbacks(TurnTime, TurnTime.end)
         animations_turn_finalize(TurnTime)
      else:
         warn(): "Can\'t move " + string(r)


   maps_frame()
   if gl_button("escape") == 1:
      rv = ExitMainLoop
   else:
      switch PlayerState:
         case WaitingForInput:
            if gl_button("w") == 1:
               let f, p = pos(player)
               let f1, diri = direction(player)

               let r, act = move_action(FakeTurnSpan, GameTime, player, p, p + all_dirs[diri])

               perform_action(r, act)

            if gl_button("q") == 1:
               play_wav("dist/ouch3.wav")

            if gl_button("s") == 1:
               let f, p = pos(player)
               let f1, diri = direction(player)

               let r, act = move_action(FakeTurnSpan, GameTime, player, p, p + all_dirs[diri]*-1)

               perform_action(r, act)

            elif gl_button("a") == 1:
               let f, dir = direction(player)
               let diri = turned_left(dir)
               let r, act = turn_action(FakeTurnSpan, GameTime, player, dir, diri)

               perform_action(r, act)

            elif gl_button("d") == 1:
               let f, a = direction(player)
               let diri = turned_right(a)
               let r, act = turn_action(FakeTurnSpan, GameTime, player, a, diri)

               perform_action(r, act)


         case Stepping:
            let dT = gl_delta_time() * animations_time_scale()

            GameTime = min(TurnTime.end, GameTime + dT)

            if GameTime == TurnTime.end:
               PlayerState = WaitingForInput
               animations_turn_begin()


        // process_callbacks(now)
   return rv
