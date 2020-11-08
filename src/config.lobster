import from "../../../src/crusty/src/"
import config_generated
import flatbuffers
import logging

private var CfgRoot: ConfigRoot? = nil
private var CfgFB: string = ""

def config_init():
   //TODO reload when changed on disk?
   //TODO fall back to binary version of data if JSON version does not exist.
   let schema = read_file("dist/config.fbs")
   assert schema
   let data = read_file("dist/config.json")
   assert data

   let fb, err = flatbuffers_json_to_binary(schema, data, [])

   if err:
      error(): err
      assert not err
   else:
      CfgRoot = GetRootAsConfigRoot(fb)
      CfgFB = fb

def cur_config() -> ConfigRoot:
   if CfgRoot:
      return CfgRoot
   else:
      error(): "No config?"
      assert false

private def mk_empty():
   let b = flatbuffers_builder{}
   let bob = ObjectSpecBuilder{b_: b}
   let nm = b.CreateString("")
   
   bob.start()
   bob.add_kind(ObjectKind_Invalid).add_short_name(nm)
   bob.add_static_tile(TileName_None).add_weight(0.0).add_flags(ItemFlags(0))
   bob.add_right_rotation(0.0).add_light_radius(0).add_dir_offset(0.0)
   bob.add_initial_state(StateFlags(0))
   let fb = bob.end()

   b.Finish(fb)
   return GetRootAsObjectSpec(b.SizedCopy())

// Empty object.  Can be used as a sentinel for 
let EmptyObjectSpec:ObjectSpec = mk_empty()

def rand_hurt_sound(ss: ObjectSounds) -> SfxSpec?:
   if ss.hurt_length() > 0:
      let i = rnd(ss.hurt_length())

      return ss.hurt(i)
   else:
      return nil

   
