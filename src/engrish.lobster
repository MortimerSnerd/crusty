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

def definite_article(actor: ObjId) -> string:
   if Ctx and Ctx.player == actor:
      //definite
      return "your"
   else:
      //indefinite
      return "the"

def plural(word: string, count: int) -> string:
   if count > 1:
      //TODO special cases missing
      if word.ends_with("th"):
         return word
      else:
         return word + "s"
   else:
      return word

def capitalize(s: string) -> string:
   return uppercase(substring(s, 0, 1)) + substring(s, 1, -1)

// Private, because this isn't general.
private def is_punct(b: string) -> bool:
   return b == "," or b == "," or b == ";"

// Put together words for a sentence, adding spaces if needed.
def sentence(arr: [string]) -> string:
   let words = copy(arr)

   if length(words) > 0:
      words[0] = capitalize(words[0])

   let s = fold(words, "") a, b: 
      if is_punct(b): 
         a + b
      else:
         a + " " + b

   return s + "."

// Converts a modified to a number so it will be "+3" or "-2".
def modifier_str(x: int) -> string:
   if x > 0:
      return "+" + x
   else:
      return string(x)

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

// Posessive for another living thing.
// ie:  posessive_otherliving(x) -> "the wombat's"
def possesive_otherliving(other: ObjId) -> string:
   if Ctx and Ctx.player == other:
      return "your"
   else:
      return definite_article(other) + " " + object_spec(other).short_name + "\'s"


def comma_list(args: [string], conjunction: bool = true) -> [string]:
   let rv = []
   for(args) a, i:
      if conjunction and length(args) > 1 and i == length(args)-1:
         push(rv, ", and")
      elif i > 0:
         push(rv, ",")
      push(rv, a)

   return rv

// This is not an exact science.
def is_proper_name(x: string) -> bool:
   if length(x) > 0:
      let c = x[0]
      return c >= 65 and c < 90
   else:
      return false

// The name of an object, with modifications for object states
// like open, lit, etc...
def pretty_name(o: ObjId, count: int) -> string:
   let spec = object_spec(o)
   let state = object_state(o)
   let adjs = []

   if state & StateFlags_Dead:
      push(adjs, "dead")

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
      if count > 1:
         rv = [string(count)]

      rv = append(rv, comma_list(adjs))
      push(rv, plural(spec.short_name, count))

   return sentence(rv)
      
