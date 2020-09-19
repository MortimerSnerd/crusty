import from "../../../src/crusty/src/"
import actions
import bus
import gobjs
import maps
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
   Player = gobjs_spawn(ObjectKind_Player, gridToWorld(xy_i{4, 1}))

enum HandleInputResult:
   Good, ExitMainLoop

def player_handle_input():
   var rv = Good

   maps_frame()
   if gl_button("escape") == 1:
      rv = ExitMainLoop
   else:
      switch PlayerState:
         case WaitingForInput:
            if gl_button("w") == 1:
               //TODO move_action to check for valid request
               let f, p = pos(Player, GameTime)
               let f1, a = angle(Player, GameTime)
               let diri = dir_angles.closest_to(a)

               let r, act = move_action(GameTime, Player, p, p + all_dirs[diri])
               if act:
                  execute(act)
                  PlayerState = Stepping
                  EndStepTime = GameTime + act.duration
               else:
                  warn(): "Can\'t move " + string(r)

            elif gl_button("a") == 1:
               let f, a = angle(Player, GameTime)
               let diri = cycle_left(dir_angles.closest_to(a), length(dir_angles))
               let r, act = turn_action(GameTime, Player, a, dir_angles[diri])

               if act:
                  execute(act)
                  PlayerState = Stepping
                  EndStepTime = GameTime + act.duration
               else:
                  warn(): "Can\'t turn: " + string(r)

            elif gl_button("d") == 1:
               let f, a = angle(Player, GameTime)
               let diri = cycle_right(dir_angles.closest_to(a), length(dir_angles))
               let r, act = turn_action(GameTime, Player, a, dir_angles[diri])

               if act:
                  execute(act)
                  PlayerState = Stepping
                  EndStepTime = GameTime + act.duration
               else:
                  warn(): "Can\'t turn: " + string(r)


         case Stepping:
            let dT = gl_delta_time() * TimeScaling

            GameTime = min(EndStepTime, GameTime + dT)
            process_callbacks(GameTime)

            if GameTime == EndStepTime:
               PlayerState = WaitingForInput


        // process_callbacks(now)
   return rv
