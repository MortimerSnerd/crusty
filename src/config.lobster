import from "../../../src/crusty/src/"
import config_generated
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

