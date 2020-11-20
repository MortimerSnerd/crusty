// Module that sets up the specific game logic and deals with frame.
// Put in a separate module to minimise game specific changes to the 
// base systems.
import from "../../../src/crusty/src/"
import actions
import algs
import bus
import callbacks
import config
import config_generated
import engrish
import gobjs
import imgui
import player
import stats
import std
import uitools
import vec

let tile_size = 64

var Player = InvalidObject
var PlayerAboutToDie = false
var PlayerDead = false

class DecomposeAction : ActionBase

def decompose_action(span: TurnSpan, now: float, who: ObjId) -> ActionResult, ActionBase?:
   if who == Player and PlayerDead:
      return GoodResult, DecomposeAction{who: who, time: now, duration: 1.0}
   else:
      return ActionResult{kind: arBlocked, other: InvalidObject}, nil

class GroundhogRec : ObjId
   graphic: ObjId
   dead: bool

let Groundhogs: [GroundhogRec?] = []

let SwerdFeeshSystem = UserSystem1

class SwerdFeesh : BusEndpoint

private def groundhog_with_graphic(obj: ObjId) -> int:
   for(Groundhogs) gh,i:
      if gh and gh.graphic == obj:
         return i

   return -1

def think_impl(sf: SwerdFeesh, span: TurnSpan, who: ObjId, now: float):
   // Wander aimlessly.
   if who is GroundhogRec:
      if not who.dead:
         if rnd_float() < 0.45:
            for_possible_actions(span, who.graphic, now, acMoveFwd) act:
               act.duration *= 0.5
               execute(act)
               schedule_callback(who, now + act.duration)
               return

         // Can't or didn't go forward, try turns, backward.
         for_possible_actions(span, who.graphic, now, acMoveFwd | acMoveBkwd | acTurn) act:
            if rnd_float() < 0.10:
               act.duration *= 0.5
               execute(act)
               schedule_callback(who, now + act.duration)
               return

         // Maybe try back later.
         schedule_callback(who, now + 0.2)

def notify_death_impl(sf: SwerdFeesh, obj: ObjId, now: float):
   let i = groundhog_with_graphic(obj)

   if i >= 0:
      let gh = Groundhogs[i]

      if gh:
         gh.dead = true

def game_create_window():
   fatal(gl_window("Penalty Box", 640, 400))

def set_map_projection(center: xy_f, tile_pixel_sz: int, view_area: xy_f) -> Rectf:
   let hview = view_area*0.5
   let viewsz = hview / tile_pixel_sz
   gl_ortho3d(xyz_f{center.x, center.y, 0}, 
              xyz_f{viewsz.x, viewsz.y, 10})
   return Rectf{center - viewsz, center + viewsz}

def game_init():
   rnd_seed(product(date_time()))
   gl_load_materials("dist/crusty.materials")
   im_init(false)
   assert im_add_font("data/fonts/Zapato/greensboro.ttf", 16.0)
   bus_register_endpoint(SwerdFeesh{system: SwerdFeeshSystem})

   load_map("dist/testmap.json")

   let spawn = map_feature_named("spawn")

   if spawn:
      Player = gobjs_spawn(ObjectKind_Player, spawn.pos, East)
      engrish_init(Player)
      play_animation(Player, "player_idle")
      gobjs_spawn(ObjectKind_Sword, spawn.pos + xy_i{1, 0}, North)
      maps_update_viz(spawn.pos, true)
      gobjs_spawn(ObjectKind_Bullet, spawn.pos, North)
      //DEBUGGERY
      let pst = object_stats(Player)
      add_use_debuff(pst, GameStats_Str, 3, 4.0)
      apply_damage(Player, 0.0, 4)

   else:
      error(): "No spawn found."

   // Mainly for testing, a more principled way should be used to 
   // do this.
   for_map_features_named("Dresser") dloc:
      let d = gobjs_spawn(ObjectKind_Dresser, dloc.pos, dloc.orientation)
      gobjs_spawn(ObjectKind_FalseTeeth, xy_i{0, 0}, North, d)

   for_map_features_named("Cheese") dloc:
      gobjs_spawn(ObjectKind_Cheese, dloc.pos, North)
      gobjs_spawn(ObjectKind_FalseTeeth, dloc.pos, North)

   for_map_features_named("ndoor") dloc:
      gobjs_spawn_door(ObjectKind_GenHDoor, dloc.pos, North, false)
   for_map_features_named("sdoor") dloc:
      gobjs_spawn_door(ObjectKind_GenHDoor, dloc.pos, South, false)
   for_map_features_named("edoor") dloc:
      gobjs_spawn_door(ObjectKind_GenHDoor, dloc.pos, East, false)
   for_map_features_named("wdoor") dloc:
      gobjs_spawn_door(ObjectKind_GenHDoor, dloc.pos, West, false)
   for_map_features_named("testhog") dloc:
      let gh = GroundhogRec{graphic: gobjs_spawn(ObjectKind_Groundhog,
                                                           dloc.pos, North),
                            dead: false,
                            system: SwerdFeeshSystem, 
                            id: length(Groundhogs)}
      push(Groundhogs, gh)
      schedule_callback(gh, 0)
      play_animation(gh.graphic, "groundhog_idle")

   //maps_load_debug_level(MapTexture, ppos)
   bind("space", "Decompose gracefully") player, now, _, prompt: 
      let r, act = decompose_action(FakeTurnSpan, now, player)
      act

   //play_wav("dist/ouch1.wav")
def draw_game_frame(now: float, windowsz: xy_f, view_rect: Rectf):
   gl_set_shader("textured_alpha_cut")
   anim_render_move_lines(now)
   map_render(view_rect) 
   gobjs_draw(now, view_rect)


def num_live_groundhogs() -> int, int:
   var live = 0
   var dead = 0

   for(Groundhogs) o: 
      if o:
         if not o.dead:
            ++live
         else:
            ++dead

   return live, dead

def living_at(p: xy_i) -> bool:
   return living_thing_at(p) != nil

def game_frame(do_debug) -> bool, Rectf:
   let wsz = gl_window_size()
   let fwsz = xy{float(wsz.x), float(wsz.y)}
   let hwsz = wsz/2
   let now = game_time()

   gobjs_update()

   if Player:
      let view_rect = set_map_projection(anim_pos(Player, now), tile_size, fwsz)
      let wmouse = world_mouse_pos(view_rect, tile_size)
      let gmouse = xy_i{floor(wmouse.x), floor(wmouse.y)}
      let rv = if PlayerDead: Good else: player_handle_input(Player, gmouse)
      
      //TODO player needs to be split too? Or part of the game module?
      switch rv:
         case ExitMainLoop:
            return false, view_rect

         case Good, GoodSteppingEnded, GoodTurnBegins:
            // Two step process, so animation for turn that killed the 
            // player can play out.
            let ppfound, ppos = pos(Player)
            if PlayerAboutToDie and rv == GoodSteppingEnded: 
               PlayerDead = true
               PlayerAboutToDie = false
            elif rv == GoodTurnBegins:
               // Update, while leaving current visibility intact.
               maps_update_viz(ppos, false)
            elif rv == GoodSteppingEnded:
               // Update again, now clearing out any areas we can't
               // see, after possibly moving.
               maps_update_viz(ppos, true)

            let live, dead = num_live_groundhogs()
            if live == 0:
               play_wav("dist/yoink.wav")
               for(12) i:
                  let pos = xy_rndi(20)
                  if not living_at(pos):
                     let gh = GroundhogRec{graphic: gobjs_spawn(ObjectKind_Groundhog,
                                                                          pos, East),
                                           dead: false,
                                           system: SwerdFeeshSystem, 
                                           id: length(Groundhogs)}
                     push(Groundhogs, gh)
                     schedule_callback(gh, now)
                     play_animation(gh.graphic, "groundhog_idle")

            gl_window_title("Penalty Box: " + 1/gl_delta_time())
            gl_clear(color_black)
            draw_game_frame(now, fwsz, view_rect)

            gl_set_shader("color")

            let playfield = Rectf{topLeft:xy_0, bottomRight:xy_f{21.0, 21.0}}

            gl_color(color_white):
               render(playfield, 1.0/32.0)

            gl_ortho()
            im_frame():
               let num_live, num_dead = num_live_groundhogs()
               im_window("HARARRRRRR", im_window_no_titlebar):
                 im_text("# left in wave: " + num_live)
                 im_text("# groundhogs stabbed: " + num_dead)
                 im_set_next_item_open(true, im_cond_once)
                 im_treenode("Possible Moves"):
                    im_columns(3, "moves", false):
                       for_player_actions(Player, now, gmouse) key, desc, dur:
                          im_column():
                             im_text(key+")")
                             im_set_column_width(-1, im_get_cursor_pos().x + 20)
                          im_column():
                             im_text(desc)
                          im_column():
                             set_print_decimals(1)
                             im_text(string(dur)+"s")
                             set_print_decimals(-1)

               if do_debug:
                  im_window("Realtime Debugger", im_window_always_autoresize):
                      im_show_engine_stats()
                      im_show_vars()

               player_handle_ui(Player, view_rect, float(tile_size))
               uitools_render()

               //im_window("Holy craps", im_window_no_titlebar | im_window_always_autoresize):
               //   im_button("one"): print("one msg")
               //   im_button("two"): print("two msg")
               //

            if PlayerDead:
               gl_set_font_name("data/fonts/Zapato/greensboro.ttf")
               gl_set_font_size(48)

               let msg = "Thou Art Dead"
               let msgsz = gl_text_size(msg)

               gl_color(color_red):
                  gl_translate(fwsz*0.5 - xy_f{float(msgsz.x), float(msgsz).y}*0.5):
                     gl_text(msg)

               if gl_button("escape") == 1:
                  return false, view_rect
                  
      return true, view_rect

   else:
      return false, Rectf{xy_0, xy_0} 
   
def game_shutdown():
   gobjs_shutdown()
