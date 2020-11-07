// Some common helpers for writing messages in english.
import from "../../../src/crusty/src/"
import bus
import objutils
import std

private class EnglishCtx:
   player: ObjId
   

private var Ctx: EnglishCtx? = nil

// Call this whenever the player object changes.
def engrish_init(player: ObjId): 
   Ctx = EnglishCtx{player: player}


def pronoun(actor: ObjId) -> string:
   if Ctx and Ctx.player == actor:
      return "you"
   else:
      switch object_spec(actor).gender:
         case GenderSpec_It:
            return "it"
         case GenderSpec_He:
            return "he"
         case GenderSpec_She:
            return "she"

         default:
            return "it"

def verb(actor: ObjId, verb: string) -> string:
   if Ctx and Ctx.player == actor:
      return verb
   else:
      //TODO special cases missing.
      return verb + "s"

def article(actor: ObjId) -> string:
   if Ctx and Ctx.player == actor:
      //definite
      return "the"
   else:
      //indefinite
      return "a"

// Put together words for a sentence, adding spaces if needed.
def sentence(arr: [string]) -> string:
   let words = copy(arr)

   if length(words) > 0:
      words[0] = uppercase(substring(words[0], 0, 1)) + substring(words[0], 1, -1)

   return (fold(words, "") a, b: a + " " + b) + "."

// Reference to another living thing.
// Prevents referring to the player as "the player".
def otherliving(other: ObjId) -> string:
   if Ctx and Ctx.player == other:
      return "you"
   else:
      return article(other) + " " + object_spec(other).short_name
