import algs
import std
import color
import grids
import vec
import imgui
import texture
import tileing

def go():
   fatal(gl_window("Eat a crap", 640, 400))
   gl_set_font_name("dist/fonty.ttf")
   gl_set_font_size(12)

   im_init(false)
   assert im_add_font("data/fonts/Droid_Sans/DroidSans.ttf", 20.0)

   let txtur = gl_load_texture("dist/texty.png", 
                               texture_format_nearest_mag or texture_format_nearest_min)

   var do_debug = false
   var do_tests = false

   for(command_line_arguments()) a:
      if a == "--test":
         do_tests = true
      elif a == "--debug":
         do_debug = true
      else:
         print("unknown argument " + a + ", ignoring.")

   if do_tests:
      algs_tests()
      grids_tests()

   if txtur == nil:
      print("barf")
   else:
      print("texture size " + gl_texture_size(txtur))
      let gtt = mkGridTiledTexture(txtur, xy_i{16, 16})
      let pts = [xyz{1.0, 0.0, 0.0}, xyz{100.0, 0.0, 0.0}, xyz{100.0, 100.0, 0.0}]
      let tcs = [xy{0.0, 0.0}, xy{1.0, 0.0}, xy{1.0, 1.0}]
      let indices = [0, 1, 2]

      for(20) y:
         for(20) x:
            addTileQuad(gtt, 500 + rnd(5), xyz{float(x)*50.0, float(y)*50, -0.2}, xy{50.0, 50.0}, 
                        pts, indices, tcs)

      addTileQuad(gtt, 0, xyz_f{100, 100, 0}, xy_f{50, 50}, pts, indices, tcs)

      let mesh = gl_new_mesh("PT", pts, [], [], tcs, [], indices)
      var ang = 0.0
      let sprites = []
      var spidx = 0

      while gl_frame():
         if gl_button("escape") == 1: return
         gl_window_title("Eat a crap: " + 1/gl_delta_time())
         gl_clear(color_black)
         let wsz = gl_window_size()
         let fwsz = xy{float(wsz.x), float(wsz.y)}
         let hwsz = wsz/2

         if length(sprites) == 0:
            for(500) i:
               let p = xy_rnd() * fwsz
               push(sprites, xyz{p.x, p.y, 2.0})

         gl_ortho3d(xyz_f{hwsz.x, hwsz.y, 0}, xyz_f{hwsz.x, hwsz.y, 10})
         gl_set_shader("textured")
         gl_set_primitive_texture(0, txtur)
         gl_render_mesh(mesh)
         ang += 20.0 * gl_delta_time()
         renderSprite(gtt, 500, xyz{100.0, 100.0, 1}, xy{64.0, 64.0}, sincos(ang))
         renderSprite(gtt, 409, xyz{100.0, 100.0, 2}, xy{64.0, 64.0})
         gl_translate(xyz_f{132, 132, 0}):
           gl_rect(xy_f{64, -64})

         spidx = (spidx + 1) % 700
         for(sprites) p, i:
            renderSprite(gtt, spidx + i, p, xy{18.0, 16.0} * float((i % 4) + 1))

         gl_ortho()
         gl_set_shader("color")
         let p = xy_rnd()
         gl_color(color_white)
         gl_translate(xy {p.x * float(wsz.x), p.y * float(wsz.y)}):
            gl_text("Barf")


         im_frame():
            //im_window("Holy craps", im_window_no_titlebar | im_window_always_autoresize):
            //   im_button("jeebus"): print("saves sinners for valuable cash and prizes.")
            //   im_button("cronkles"): print("saves sinners for valuable cash and prizes.")
            //
            if do_debug:
               im_window("Realtime Debugger", im_window_always_autoresize):
                   im_show_engine_stats()
                   im_show_vars()


go()
