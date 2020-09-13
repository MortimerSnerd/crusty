import from "../../../src/crusty/src/"
import algs
import bus
import std
import color
import config
import events
import gobjs
import grids
import imgui
import player
import texture
import tileing
import vec

var tile_size = 32
var world_view_center = xy_0

def set_map_projection(center: xy_f, tile_pixel_sz: int, view_area: xy_f) -> Rectf:
   let hview = view_area*0.5
   let viewsz = hview / tile_pixel_sz
   gl_ortho3d(xyz_f{center.x, center.y, 0}, 
              xyz_f{viewsz.x, viewsz.y, 10})
   return Rectf{center - viewsz*0.5, center + viewsz*0.5}

def draw_game_frame(now: float, windowsz: xy_f, gtt, txtur: resource, view_rect: Rectf):
   gl_set_shader("textured_alpha_cut")
   gl_set_primitive_texture(0, txtur)
   renderSprite(gtt, 500, xyz{100.0, 100.0, 1}, xy{64.0, 64.0}, sincos(gl_delta_time()))
   renderSprite(gtt, 409, xyz{100.0, 100.0, 2}, xy{64.0, 64.0})
   gl_translate(xyz_f{132, 132, 0}):
     gl_rect(xy_f{64, -64})

   gobjs_draw(now, view_rect)

def go():
   config_init()
   fatal(gl_window("Penalty Box", 640, 400))
   gl_set_font_name("dist/fonty.ttf")
   gl_set_font_size(12)
   gl_load_materials("dist/crusty.materials")
   im_init(false)
   assert im_add_font("data/fonts/Droid_Sans/DroidSans.ttf", 20.0)

   var do_debug = false
   var do_tests = false

   for(command_line_arguments()) a:
      if a == "--test":
         do_tests = true
      elif a == "--debug":
         do_debug = true
      else:
         print("unknown argument " + a + ", ignoring.")

   gobjs_init()
   player_init()
   
   if do_tests:
      algs_tests()
      grids_tests()
      events_tests()
      gobjs_tests()

   let test_txtur = gl_load_texture("dist/texty.png", 
                                    texture_format_nearest_mag or texture_format_nearest_min)
   if test_txtur:
      let gtt = mkGridTiledTexture(test_txtur, xy_i{16, 16})

      let pts = [xyz{1.0, 0.0, 0.0}, xyz{100.0, 0.0, 0.0}, xyz{100.0, 100.0, 0.0}]
      let tcs = [xy{0.0, 0.0}, xy{1.0, 0.0}, xy{1.0, 1.0}]
      let indices = [0, 1, 2]

      for(20) y:
         for(20) x:
            addTileQuad(gtt, 500 + rnd(5), xyz{float(x)*50.0, float(y)*50, -0.2}, xy{50.0, 50.0}, 
                        pts, indices, tcs)

      addTileQuad(gtt, 0, xyz_f{100, 100, 0}, xy_f{50, 50}, pts, indices, tcs)

      for(10) i:
         let idy = gobjs_spawn(ObjectKind_Sword, gridToWorld(xy_i{rnd(20) - 10, rnd(20) - 10}))
         schedule_callback(idy, float(i) + rnd_float())

      while gl_frame():
         let wsz = gl_window_size()
         let fwsz = xy{float(wsz.x), float(wsz.y)}
         let hwsz = wsz/2
         let now = game_time()
         let rv = player_handle_input()
         
         switch rv:
            case ExitMainLoop:
               break

            case Good:
               //TODO something is wrong with view_rect or tests, does not cover
               //     entire screen.
               let view_rect = set_map_projection(world_view_center, tile_size, fwsz)
               gl_window_title("Penalty Box: " + 1/gl_delta_time())
               gl_clear(color_black)
               draw_game_frame(now, fwsz, gtt, test_txtur, view_rect)

               // Debug
               //gl_set_shader("color")
               //gl_color(xyzw_f{1.0, 1.0, 1.0, 1.0}):
               //   forObjectsIntersecting(now, view_rect) o:
               //      let f, p = pos(o, now)
               //
               //      if f:
               //         let r = gridRect(p)
               //         render(r, 1.0/tile_size)


               gl_ortho()
               gl_set_shader("color")

               im_frame():
                  //im_window("Holy craps", im_window_no_titlebar | im_window_always_autoresize):
                  //   im_button("one"): print("one msg")
                  //   im_button("two"): print("two msg")
                  //
                  if do_debug:
                     im_window("Realtime Debugger", im_window_always_autoresize):
                         im_show_engine_stats()
                         im_show_vars()


go()
