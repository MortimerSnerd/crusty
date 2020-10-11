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
import gobjs
import imgui
import player
import std
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

class Bullet : ObjId
   graphic: ObjId

let Bullets = EmbeddedCircList<Bullet>{head: nil}
let Groundhogs = EmbeddedCircList<GroundhogRec>{head: nil}

var Carrying = InvalidObject

let SwerdFeeshSystem = UserSystem1

class SwerdFeesh : BusEndpoint

private def maybe_pickup_sword(pickUpTime: float):
   if Carrying == InvalidObject:
      let pf, ppos = pos(Player)
      let po, pdir = direction(Player)

      for_objects_at(ppos) oid:
         if oid:
            let spec = oid.object_spec

            if spec and spec.kind == ObjectKind_Sword:
               Carrying = oid
               notify_sfx(Player, pickUpTime, "dist/yoink.wav", 1.0)
               return

private def maybe_sword_groundhog(gh: ObjId, p: xy_i, now: float):
   if gh is GroundhogRec:
      if Carrying != InvalidObject and not gh.dead:
         let cc, cpos = pos(Carrying)

         if cpos == p:
            let fx = rnd_pick(["dist/ouch1.wav", "dist/ouch2.wav", "dist/ouch3.wav"])
            notify_sfx(gh.graphic, now, fx, 1.0)
            gh.dead = true
            notify_tile_change(gh.graphic, now, tile(gh.graphic), TileName_DeadGroundhog)
            change_tile(gh.graphic, TileName_DeadGroundhog)

private def maybe_sword_groundhog(now: float):
   if Carrying != InvalidObject:
      dl_foreach(Groundhogs) gh:
         if not gh.dead:
            let f, gpos = pos(gh.graphic)
            maybe_sword_groundhog(gh, gpos, now)

def notify_deleting(s: SwerdFeesh, o: ObjId) -> void:
   debug(): "SwerdFeesh: removing " + to_string(o)
   if o.system == GObjSystem:
      let bi = dl_find(Bullets) x: x.graphic == o

      if bi:
         // Delete associated bullet object.
         dl_remove(Bullets, bi)

   elif o is Bullet:
      // Delegate to the arm above that cleans up bullets whose
      // graphics have disappeared.
      notify_deleting(o.graphic)

def notify_moving(s: SwerdFeesh, o: ObjId, startT: float, endT: float, start: xy_i, end: xy_i) -> void:
   if Player and o == Player:
      let pdf, pdir = direction(Player)

      maybe_pickup_sword((startT + endT) / 2)
      if Carrying:
         let op, opos = pos(Carrying)
         notify_moving(Carrying, startT, endT, opos, end + all_dirs[pdir])
         maybe_sword_groundhog(endT)

def notify_turning(s: SwerdFeesh, o: ObjId, startT: float, endT: float, startDir: Directions, endDir: Directions):
   if o == Player:
      if Carrying and Player:
         let pf, ppos = pos(Player)

         maybe_pickup_sword(startT)
         notify_moving(Carrying, startT, endT, ppos + all_dirs[startDir], ppos + all_dirs[endDir])
         notify_turning(Carrying, startT, endT, startDir, endDir)
         maybe_sword_groundhog(endT)

def move_is_allowed(s: SwerdFeesh, now: float, o: ObjId, destPos: xy_i) -> bool:
   if Player and o == Player and Carrying:
      // Don't allow sword to go through walls
      let pf, pdir = direction(Player)

      let sword_dest = destPos + all_dirs[pdir]

      return move_is_allowed(now, Carrying, sword_dest)

   return true

def turn_is_allowed(s: SwerdFeesh, now: float, o: ObjId, destDir: Directions) -> bool:
   if o == Player:
      if Player and Carrying:
         let pf, ppos = pos(Player)
         let sword_dest = ppos + all_dirs[destDir]

         return move_is_allowed(now, Carrying, sword_dest)
      else:
         return true
   else:
      return true

private var BulletCount = 0
let BulletIdOffset = 100
def make_bullet(now: float, bpos: xy_i, dir: Directions): 
   let graphic = gobjs_spawn(ObjectKind_Bullet, bpos, dir)

   ++BulletCount
   let bul = Bullet{system: SwerdFeeshSystem, graphic: graphic}
   dl_add(Bullets, bul)
   schedule_callback(bul, now)
   
def think(sf: SwerdFeesh, span: TurnSpan, who: ObjId, now: float):
   // Wander aimlessly.
   if who is Bullet and Player:
      let df, dir = direction(who.graphic)
      let pf, bpos = pos(who.graphic)
      let pp, player_pos = pos(Player) 
      
      if bpos == player_pos:
         PlayerAboutToDie = true
         notify_sfx(Player, now, "dist/pdead.wav", 1.0)

      let ar, act = move_action(span, now, who.graphic, bpos, bpos + all_dirs[dir])
      if act:
         execute(act)
         if bpos + all_dirs[dir] == player_pos:
            PlayerAboutToDie = true
            notify_sfx(Player, now, "dist/pdead.wav", 1.0)
         schedule_callback(who, now + act.duration)
         return
      else:
         notify_deleting(who)
         return
   
   elif who is GroundhogRec:
      if not who.dead:
         if rnd_float() < 0.05 and Bullets.count < 100:
            let pf, ppos = pos(who.graphic)
            let df, dir = direction(who.graphic)

            make_bullet(now, ppos, opposite_dir[dir])
            schedule_callback(who, now + 1.0)
            return

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
   assert im_add_font("data/fonts/Droid_Sans/DroidSans.ttf", 12.0)
   bus_register_endpoint(SwerdFeesh{system: SwerdFeeshSystem})

   load_map("dist/testmap.json")

   let spawn = map_feature_named("spawn")

   if spawn:
      Player = gobjs_spawn(ObjectKind_Player, spawn.pos, East)
      gobjs_spawn(ObjectKind_Sword, spawn.pos + xy_i{1, 0}, North)
      maps_update_viz(spawn.pos, true)
   else:
      error(): "No spawn found."

   //maps_load_debug_level(MapTexture, ppos)
   bind("space", "Decompose gracefully") player, now: 
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

   dl_foreach(Groundhogs) o: 
      if not o.dead:
         ++live
      else:
         ++dead

   return live, dead

def living_at(p: xy_i) -> bool:
   for_objects_at(p) o:
      if o:
         let spec = o.object_spec
         
         if spec and spec.flags & ItemFlags_Living:
            return true
   return false

def game_frame(do_debug) -> bool, Rectf:
   let wsz = gl_window_size()
   let fwsz = xy{float(wsz.x), float(wsz.y)}
   let hwsz = wsz/2
   let now = game_time()

   if Player:
      let rv = if PlayerDead: Good else: player_handle_input(Player)
      let view_rect = set_map_projection(anim_pos(Player, now), tile_size, fwsz)
      
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
                                           system: SwerdFeeshSystem}
                     dl_add(Groundhogs, gh)
                     schedule_callback(gh, now)

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
                 im_treenode("Possible Moves"):
                    for_player_actions(Player, now) key, desc:
                       im_text(key + " - " + desc)


               if do_debug:
                  im_window("Realtime Debugger", im_window_always_autoresize):
                      im_show_engine_stats()
                      im_show_vars()
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
   dl_clear(Bullets)
   dl_clear(Groundhogs)
   gobjs_shutdown()
