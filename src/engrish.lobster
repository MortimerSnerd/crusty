// Some common helpers for writing messages in english.
import from "../../../src/crusty/src/"
import bus
import config_generated
import objutils
import std

private class EnglishCtx:
   player: ObjId
   

private var Ctx: EnglishCtx? = nil

// Call this whenever the player object changes.
def engrish_init(player: ObjId): 
   Ctx = EnglishCtx{player: player}


// your, his, her, its
def posessive_pronoun(actor: ObjId) -> string:
   if Ctx and Ctx.player == actor:
      return "your"
   else:
      switch object_spec(actor).gender:
         case GenderSpec_It:
            return "its"
         case GenderSpec_He:
            return "his"
         case GenderSpec_She:
            return "her"

      return "its"

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
def otherliving(other: ObjId, use_article: bool = true) -> string:
   if Ctx and Ctx.player == other:
      return "you"
   else:
      if use_article:
         return article(other) + " " + object_spec(other).short_name
      else:
         return object_spec(other).short_name

def comma_list(args: [string]) -> [string]:
   let rv = []

   for(args) a:
      if length(rv) > 0:
         push(rv, ",")
      push(rv, a)

   return rv

// The name of an object, with modifications for object states
// like open, lit, etc...
def pretty_name(o: ObjId, use_article = false) -> string:
   let spec = object_spec(o)
   let state = object_state(o)
   let adjs = []

   if state & StateFlags_Dead:
      push(adjs, "deceased")

   if spec.flags & ItemFlags_Container:
      if state & StateFlags_Open:
         push(adjs, "open")
      else:
         push(adjs, "closed")

   if spec.flags & ItemFlags_EmitsLight:
      push(adjs, "lit")

   var rv = []
   if Ctx and Ctx.player == o:
      if length(adjs) > 0:
         rv = ["you", "("] 
         rv = append(rv, comma_list(adjs)) 
         push(rv, ")")
      else:
         rv = ["you"]
   else:
      if use_article:
         rv = [article(o)] 
      rv = append(rv, comma_list(adjs))
      push(rv, spec.short_name)

   return sentence(rv)
      
