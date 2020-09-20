import from "../../../src/crusty/src/"
import actions
import animations
import bus
import gobjs
import maps
import objutils

private var Player = InvalidObject

enum PlayStates:
   WaitingForInput, Stepping

private var PlayerState = WaitingForInput
private var TurnTime = TurnSpan{0.0, 0.0} // Valid when PlayerState == Stepping
private var GameTime : float = 0    // Abs game time.  (ie, total time stepping, not waiting for input)
private var TimeScaling = 2.0

def game_time() -> float:
   return GameTime

def player_init():
   Player = gobjs_spawn(ObjectKind_Player, xy_i{4, 1}, East)
   animations_turn_begin()

enum HandleInputResult:
   Good, ExitMainLoop

// For player actions, don't scale the time of the action - the time of the
// action will be the span that all other actions will need to scale to.
private let FakeTurnSpan = TurnSpan{0.0, 999999999990.0}

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
               let f, p = pos(Player)
               let f1, diri = direction(Player)

               let r, act = move_action(FakeTurnSpan, GameTime, Player, p, p + all_dirs[diri])
               if act:
                  TurnTime = TurnSpan{GameTime, GameTime + act.duration}
                  execute(act)
                  PlayerState = Stepping
                  process_callbacks(TurnTime, TurnTime.end)
                  animations_turn_finalize(TurnTime)
               else:
                  warn(): "Can\'t move " + string(r)

            elif gl_button("a") == 1:
               let f, dir = direction(Player)
               let diri = Directions(cycle_left(dir, length(dir_angles)))
               let r, act = turn_action(FakeTurnSpan, GameTime, Player, dir, diri)

               if act:
                  TurnTime = TurnSpan{GameTime, GameTime + act.duration}
                  execute(act)
                  PlayerState = Stepping
                  process_callbacks(TurnTime, TurnTime.end)
                  animations_turn_finalize(TurnTime)
               else:
                  warn(): "Can\'t turn: " + string(r)

            elif gl_button("d") == 1:
               let f, a = direction(Player)
               let diri = Directions(cycle_right(a, length(dir_angles)))
               let r, act = turn_action(FakeTurnSpan, GameTime, Player, a, diri)

               if act:
                  TurnTime = TurnSpan{GameTime, GameTime + act.duration}
                  execute(act)
                  PlayerState = Stepping
                  process_callbacks(TurnTime, TurnTime.end)
                  animations_turn_finalize(TurnTime)
               else:
                  warn(): "Can\'t turn: " + string(r)


         case Stepping:
            let dT = gl_delta_time() * animations_time_scale()

            GameTime = min(TurnTime.end, GameTime + dT)

            if GameTime == TurnTime.end:
               PlayerState = WaitingForInput
               animations_turn_begin()


        // process_callbacks(now)
   return rv
