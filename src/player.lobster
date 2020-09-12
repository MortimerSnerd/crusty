import from "../../../src/crusty/src/"
import bus
import gobjs
import objutils

private var Player = InvalidObject

enum PlayStates:
   WaitingForInput, Stepping

private var PlayerState = WaitingForInput
private var EndStepTime: float  = 0 // Valid when PlayerState == Stepping
private var GameTime : float = 0    // Abs game time.  (ie, total time stepping, not waiting for input)
private var TimeScaling = 2.0

def game_time() -> float:
   return GameTime

def player_init():
   Player = gobjs_spawn(ObjectKind_Player, xy_0)

enum HandleInputResult:
   Good, ExitMainLoop

def player_handle_input():
   var rv = Good

   if gl_button("escape") == 1:
      rv = ExitMainLoop
   else:
      switch PlayerState:
         case WaitingForInput:
            if gl_button("w") == 1:
               //TODO move_action to check for valid request
               let f, p = pos(Player, GameTime)

               move_event(Player, GameTime, GameTime + 0.5, p, p + xy_x)
               PlayerState = Stepping
               EndStepTime = GameTime + 0.5
            elif gl_button("a") == 1:
               let f, a = angle(Player, GameTime)
               let diri = cycle_left(dir_angles.closest_to(a), length(dir_angles))

               turn_event(Player, GameTime, GameTime + 0.5, a, dir_angles[diri])
               PlayerState = Stepping
               EndStepTime = GameTime + 0.5
            elif gl_button("d") == 1:
               let f, a = angle(Player, GameTime)
               let diri = cycle_right(dir_angles.closest_to(a), length(dir_angles))

               turn_event(Player, GameTime, GameTime + 0.5, a, dir_angles[diri])
               PlayerState = Stepping
               EndStepTime = GameTime + 0.5


         case Stepping:
            let dT = gl_delta_time() * TimeScaling

            events_begin_frame(GameTime)
            GameTime = min(EndStepTime, GameTime + dT)
            process_callbacks(GameTime)
            gobjs_handle_events(GameTime)

            if GameTime == EndStepTime:
               PlayerState = WaitingForInput


        // process_callbacks(now)
   return rv
