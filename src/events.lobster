import from "../../../src/crusty/src/"
import algs
import bus
import std
import objutils

class BaseEvent:
   who: ObjId
   startT: float
   endT: float

class MoveEvent : BaseEvent
   startPos: xy_f
   endPos: xy_f

class TurnEvent : BaseEvent
   startOrient: int
   endOrient: int

private var Events: [BaseEvent] = []
private var EventsUnordered = true

private def update_ordered_flag(t: float):
   return EventsUnordered or (length(Events) > 0 && 
                              Events[length(Events)-1].startT > t)

def move_event(who: ObjId, startTime: float, endTime: float, startPos: xy_f, 
               endPos: xy_f):
   update_ordered_flag(startTime)
   push(Events, MoveEvent{who: who, startT: startTime, endT: endTime, 
        startPos: startPos, endPos: endPos})

def turn_event(who: ObjId, startTime: float, endTime: float, startOrient: int, 
               endOrient: int):
   update_ordered_flag(startTime)
   push(Events, TurnEvent{who: who, startT: startTime, endT: endTime, 
        startOrient: startOrient, endOrient: endOrient})

def forQueuedEvents(body):
   if EventsUnordered:
      qsort_in_place(Events) a, b: a.startT < b.startT
      EventsUnordered = false

   for(Events) e:
      body(e)

def events_begin_frame(now: float):
   Events = filter(Events) e: e.startT >= now

def events_tests():
   move_event(ObjId{parts: 123}, 1.0, 2.0, xy_f{1,2}, xy_f{1, 3})
   turn_event(ObjId{parts: 123}, 0.5, 1.0, 0, 1)
   forQueuedEvents() e:
      print("herp " + string(e))
      if e is MoveEvent:
         print("   extra balls")

struct ThinkCallback:
   time: float
   who: ObjId

// A priority queue implemented as a min-heap, for ordering think callbacks.
// Once a think callback is called, it is dropped off the list.  It's up
// to the callback to re-add the callback for a later time if necessary.
// On additional constraint is the min entry should be motonoically 
// increasing in time - if the last min entry was time=5, everything 
// after that has to be time >= 5.  Otherwise, events could be scheduled
// in the past, which would make for some interesting events.
private let ThinkCbs : [ThinkCallback] = []
private let TMinHeapCmp = fn(a: ThinkCallback, b: ThinkCallback) -> bool:
   a.time <= b.time

def schedule_callback(who: ObjId, time: float):
   heap_add(ThinkCbs, ThinkCallback{time: time, who: who}, TMinHeapCmp)

// Runs through all of the callbacks until the queue 
// is empty, or the next entries' time is > destTime
def process_callbacks(destTime: float):
   while length(ThinkCbs) > 0 and ThinkCbs[0].time < destTime:
      let o = heap_pop(ThinkCbs, TMinHeapCmp)

      print("ccyb " + string(o))
      think(o.who, o.time)

