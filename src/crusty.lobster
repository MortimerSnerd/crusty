import from "../../../src/crusty/src/"
import algs
import animations
import bus
import callbacks
import std
import color
import config
import game
import gobjs
import grids
import imgui
import maps
import player
import texture
import tileing
import vec

def go():
   config_init()
   game_create_window()
   gobjs_init()
   player_init()
   maps_init()
   animations_init()
   game_init()
    
   var do_debug = false
   var do_tests = false
   var do_debug_rects = false

   for(command_line_arguments()) a:
      if a == "--test":
         do_tests = true
      elif a == "--debug":
         do_debug = true
      elif a == "--debug-rects":
         do_debug_rects = true
      else:
         print("unknown argument " + a + ", ignoring.")

   if do_tests:
      algs_tests()
      grids_tests()
      gobjs_tests()

   while gl_frame():
      let keepgoing, view_rect = game_frame(do_debug)

      if not keepgoing:
         break

      gl_set_shader("color")

      if do_debug_rects:
         gl_color(xyzw_f{1.0, 1.0, 1.0, 1.0}):
            render(view_rect, 1.0/tile_size)
            for_objects_intersecting(game_time(), view_rect) o:
               let p = anim_pos(o, game_time())
               let r = mkRectfRel(p-xy_1*0.5, xy_1)
               render(r, 1.0/tile_size)

            map_render_debug(view_rect, 1.0/tile_size)

go()
