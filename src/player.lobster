import from "../../../src/crusty/src/"
import bus
import gobjs
import objutils

private var Player = InvalidObject

def player_init():
   Player = gobjs_spawn(ObjectKind_Player, xy_0)


