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
var PlayerDead = false

class DecomposeAction : ActionBase

def decompose_action(span: TurnSpan, now: float, who: ObjId) -> ActionResult, ActionBase?:
   if who == Player and PlayerDead:
      return GoodResult, DecomposeAction{who: who, time: now, duration: 1.0}
   else:
      return ActionResult{kind: arBlocked, other: InvalidObject}, nil

class GroundhogRec:
   graphic: ObjId
   dead: bool

struct Bullet:
   name: ObjId
   graphic: ObjId

let Bullets = mk_objid_map<Bullet>()

let Groundhogs = mk_objid_map<GroundhogRec>()

var MapTexture : GridTiledTexture? = nil
var Carrying = InvalidObject

let SwerdFeeshSystem = UserSystem1

class SwerdFeesh : BusEndpoint

private def maybe_pickup_sword(now: float):
   if Carrying == InvalidObject:
      let pf, ppos = pos(Player)
      let po, pdir = direction(Player)

      for_objects_at(ppos) oid:
         let spec = oid.object_spec

         if spec and spec.kind == ObjectKind_Sword:
            Carrying = oid
            play_wav("dist/yoink.wav")
            return

private def maybe_sword_groundhog(gh: ObjId, p: xy_i):
   let gi = find(Groundhogs, gh)

   if Carrying != InvalidObject and gi >= 0 and not Groundhogs.vals[gi].dead:
      let cc, cpos = pos(Carrying)

      if cpos == p:
         play_wav(rnd_pick(["dist/ouch1.wav", "dist/ouch2.wav", "dist/ouch3.wav"]))
         Groundhogs.vals[gi].dead = true
         change_tile(Groundhogs.vals[gi].graphic, TileName_DeadGroundhog)

private def maybe_sword_groundhog():
   if Carrying != InvalidObject:
      for(Groundhogs.vals) gh, i:
         if not gh.dead:
            let f, gpos = pos(gh.graphic)
            maybe_sword_groundhog(Groundhogs.keys[i], gpos)

def notify_deleting(s: SwerdFeesh, o: ObjId) -> void:
   debug(): "SwerdFeesh: removing " + to_string(o)
   if o.system == GObjSystem:
      let bi = find(Bullets.vals) x: x.graphic == o

      if bi >= 0:
         // Delete associated bullet object.
         remove_index(Bullets, bi)

   elif o.system == SwerdFeeshSystem:
      let bi = find(Bullets, o)

      if bi >= 0:
         // Delegate to the arm above that cleans up bullets whose
         // graphics have disappeared.
         let bul = Bullets.vals[bi]
         notify_deleting(bul.graphic)

def notify_moving(s: SwerdFeesh, o: ObjId, startT: float, endT: float, start: xy_i, end: xy_i) -> void:
   if o == Player:
      let pdf, pdir = direction(Player)

      maybe_pickup_sword(startT)
      if Carrying != InvalidObject:
         let op, opos = pos(Carrying)
         notify_moving(Carrying, startT, endT, opos, end + all_dirs[pdir])
         maybe_sword_groundhog()

def notify_turning(s: SwerdFeesh, o: ObjId, startT: float, endT: float, startDir: Directions, endDir: Directions):
   if o == Player:
      if Carrying != InvalidObject:
         let pf, ppos = pos(Player)

         maybe_pickup_sword(startT)
         notify_moving(Carrying, startT, endT, ppos + all_dirs[startDir], ppos + all_dirs[endDir])
         notify_turning(Carrying, startT, endT, startDir, endDir)
         maybe_sword_groundhog()

def move_is_allowed(s: SwerdFeesh, now: float, o: ObjId, destPos: xy_i) -> bool:
   // Keep everyone in an invisible playfield.
   if not (destPos.x >= 0 and destPos.x <= 20 and destPos.y >=0 and destPos.y < 20):
      return false

   if o == Player and Carrying != InvalidObject:
      // Don't allow sword to go through walls
      let pf, pdir = direction(Player)

      let sword_dest = destPos + all_dirs[pdir]

      return move_is_allowed(now, Carrying, sword_dest)

   return true

def turn_is_allowed(s: SwerdFeesh, now: float, o: ObjId, destDir: Directions) -> bool:
   if o == Player:
      if Carrying == InvalidObject:
         return true
      else:
         let pf, ppos = pos(Player)
         let sword_dest = ppos + all_dirs[destDir]

         return move_is_allowed(now, Carrying, sword_dest)
   else:
      return true

private var BulletCount = 0
let BulletIdOffset = 100
def make_bullet(now: float, bpos: xy_i, dir: Directions): 
   let oid = mkObjId(SwerdFeeshSystem, BulletIdOffset + BulletCount)
   let graphic = gobjs_spawn(ObjectKind_Bullet, bpos, dir)

   ++BulletCount
   add_item(Bullets, oid, Bullet{name: oid, graphic: graphic})
   schedule_callback(oid, now)
   
def think(sf: SwerdFeesh, span: TurnSpan, who: ObjId, now: float):
   // Wander aimlessly.
   let bi = find(Bullets, who)

   if bi >= 0:
      // this is a bullet.
      let bul = Bullets.vals[bi]
      let df, dir = direction(bul.graphic)
      let pf, bpos = pos(bul.graphic)
      let pp, player_pos = pos(Player) 
      
      if bpos == player_pos:
         PlayerDead = true
         play_wav("dist/pdead.wav")

      let ar, act = move_action(span, now, bul.graphic, bpos, bpos + all_dirs[dir])
      if act:
         execute(act)
         if bpos + all_dirs[dir] == player_pos:
            PlayerDead = true
            play_wav("dist/pdead.wav")
         schedule_callback(who, now + act.duration)
         return
      else:
         notify_deleting(who)
         return
   
   else:
      let gi = find(Groundhogs, who)

      if gi >= 0 and not Groundhogs.vals[gi].dead:
         if rnd_float() < 0.05 and num_items(Bullets) < 100:
            let pf, ppos = pos(Groundhogs.vals[gi].graphic)
            let df, dir = direction(Groundhogs.vals[gi].graphic)

            make_bullet(now, ppos, opposite_dir[dir])
            schedule_callback(who, now + 1.0)
            return

         if rnd_float() < 0.45:
            for_possible_actions(span, Groundhogs.vals[gi].graphic, now, acMoveFwd) act:
               act.duration *= 0.5
               execute(act)
               schedule_callback(who, now + act.duration)
               return

         // Can't or didn't go forward, try turns, backward.
         for_possible_actions(span, Groundhogs.vals[gi].graphic, now, acMoveFwd | acMoveBkwd | acTurn) act:
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
   gl_load_materials("dist/crusty.materials")
   im_init(false)
   assert im_add_font("data/fonts/Droid_Sans/DroidSans.ttf", 12.0)
   bus_register_endpoint(SwerdFeesh{system: SwerdFeeshSystem})

   gobjs_spawn(ObjectKind_Sword, xy_i{4,2}, North)

   let test_txtur = gl_load_texture("dist/tiles.png", 
                                    texture_format_nearest_mag or texture_format_nearest_min)
   if test_txtur:
      MapTexture = mkGridTiledTexture(test_txtur, xy_i{32, 32})

   Player = gobjs_spawn(ObjectKind_Player, xy_i{4, 1}, East)

   bind("space", "Decompose gracefully") player, now: 
      let r, act = decompose_action(FakeTurnSpan, now, player)
      act

   rnd_seed(product(date_time()))

   //play_wav("dist/ouch1.wav")

def draw_game_frame(now: float, windowsz: xy_f, view_rect: Rectf):
   gl_set_shader("textured_alpha_cut")
   if MapTexture:
      gl_set_primitive_texture(0, MapTexture.texture)
      gobjs_draw(now, view_rect)
      map_render(MapTexture, view_rect) 

def num_live_groundhogs() -> int:
   return length(filter(Groundhogs.vals) g: not g.dead)

def living_at(p: xy_i) -> bool:
   for_objects_at(p) o:
      let spec = o.object_spec
      
      if spec and spec.flags & ItemFlags_Living:
         return true
   return false

def game_frame(do_debug) -> bool, Rectf:
   let wsz = gl_window_size()
   let fwsz = xy{float(wsz.x), float(wsz.y)}
   let hwsz = wsz/2
   let now = game_time()
   let rv = if PlayerDead: Good else: player_handle_input(Player)
   let view_rect = set_map_projection(anim_pos(Player, now), tile_size, fwsz)
   
   //TODO player needs to be split too? Or part of the game module?
   switch rv:
      case ExitMainLoop:
         return false, view_rect

      case Good:
         if num_live_groundhogs() == 0:
            play_wav("dist/yoink.wav")
            for(12) i:
               let pos = xy_rndi(20)
               if not living_at(pos):
                  let gid = mkObjId(SwerdFeeshSystem, length(Groundhogs.vals))
                  add_item(Groundhogs, gid, GroundhogRec{graphic: gobjs_spawn(ObjectKind_Groundhog, 
                                                                     pos, East),
                                                         dead: false})
                  schedule_callback(gid, now)

         gl_window_title("Penalty Box: " + 1/gl_delta_time())
         gl_clear(color_black)
         draw_game_frame(now, fwsz, view_rect)

         gl_set_shader("color")

         let playfield = Rectf{topLeft:xy_0, bottomRight:xy_f{21.0, 21.0}}

         gl_color(color_white):
            render(playfield, 1.0/32.0)

         gl_ortho()
         im_frame():
            let num_live = num_live_groundhogs()
            im_window("HARARRRRRR", im_window_no_titlebar):
              im_text("# left in wave: " + num_live)
              im_text("# groundhogs stabbed: " + (length(Groundhogs.vals) - num_live))
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


