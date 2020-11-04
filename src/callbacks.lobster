import from "../../../src/crusty/src/"
import actions
import algs
import bus
import std
import objutils

class ThinkCallback:
   time: float
   who: ObjId

// A priority queue implemented as a min-heap, for ordering think callbacks.
// Once a think callback is called, it is dropped off the list.  It's up
// to the callback to re-add the callback for a later time if necessary.
// On additional constraint is the min entry should be motonoically 
// increasing in time - if the last min entry was time=5, everything 
// after that has to be time >= 5.  Otherwise, events could be scheduled
// in the past, which would make for some interesting events.
private var ThinkCbs : [ThinkCallback] = []
private let TMinHeapCmp = fn(a: ThinkCallback, b: ThinkCallback) -> bool:
   a.time <= b.time

def schedule_callback(who: ObjId, time: float):
   debug(): "schedule " + who + " for " + time
   heap_add(ThinkCbs, ThinkCallback{time: time, who: who}, TMinHeapCmp)

// Runs through all of the callbacks until the queue 
// is empty, or the next entries' time is > destTime
def process_callbacks(span: TurnSpan, destTime: float):
   while length(ThinkCbs) > 0 and ThinkCbs[0].time < destTime:
      let o = heap_pop(ThinkCbs, TMinHeapCmp)

      think(span, o.who, o.time)

def remove_callbacks_for(who: ObjId):
   let x = []

   while length(ThinkCbs) > 0:
      let i = heap_pop(ThinkCbs, TMinHeapCmp)
      if i.who != who:
         heap_add(x, i, TMinHeapCmp)

   ThinkCbs = x
   //ThinkCbs = filter(ThinkCbs) x: x.who != who
