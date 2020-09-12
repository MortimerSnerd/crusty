# What is it
Just a test project where I'm playing around with lobster and scheduling
mechanisms for a turn based game.  Instead of an energy based system like
angband, this has a setup where npc think() calls are scheduled in a priority queue.  

ie: When Pirate Bob gets a think() call, and decides to unload a pistol at you,
the code calls functions to perform that action, and then Pirate Bob schedules
another call to his think() function at time_to_shoot_pistol() + now.

Eventually, a speed stat would influence how long it takes to perform an action, 
with action times being specified in seconds.  Move animations can use these 
times as guidlines and scale them, etc...

Haven't gotten far enough to really think through it yet.

Pros so far:
  - a little more straightforward to see the turn order, if you want to expose
    that to the user, as the new xcoms, and temple of elemental evil did

Cons so far:
  - lacks the simplicity of the angband implementation.
    
## Other architecture details.

The different modules are uncoupled, so there aren't references to things 
going all over the place.

This is all experimental stuff.  My current feeling is it's a little more 
heavyweight than I like, but not where it will be a problem.  I find decoupling
systems with what amounts to message passing can be attractive when you can 
afford it.

So there's a "gobj" module that handles the position and orientation of any
small movable objects.  The positions and angles are actually linear 
interpolations, so you don't ask for the position of Bob the Pirate, you
ask for his position at time t.

There are a couple of mechanisms that decouple the modules so they don't 
need to be aware of each other.  (or cause import recursion)

### ObjId

Instead of references to object, there's an ObjId which uniquely identifies
an object by a (module id, some id/index) pair.  The meaning of the id/index
is up to the module.  For the simplistic gobj module right now, it's just 
an index into an array of instance info.  Users of the ObjId's don't need
to know.

### The events module
The events module defines events that are gameplay events, or a little lower
level.  Any modules that care about events have some module_handle_events()
function that the code in the player module will will when a turn is being run.

 There's currently just a TurnEvent and a MoveEvent, but there are other
planned events like a ObjDeleted{} event that will let all interested modules
know a particular ObjId is going away, and that if you have any references to
that ObjId, you should clean them out in a way that makes sense.  Eventually 
there will be a SoundEvent that says "this sound happened here at this volume".
And a future sound module would look at the position relative to the user, and
how much is between them and calculate perceived volume and play the sound.

The events are also intended to be useful for AI.  If Bob the Pirate sees a 
sound event that's close enough and loud enough where he detects it, the AI
can kick him into gear to investigate, etc...

As a more concrete example, when the player moves, the player module creates 
a MoveEvent saying "move this ObjId from a to b, taking 1/2 second".  The gobj
module will see the event, and will update the instance state for the player 
ObjId so the position will lerp.

## The bus module
Sometimes you don't just want to react to things going on, but actually make
a query.  The bus module gives you way to do that.  Modules register a 
handler object with the bus module, and which uses virtual dispatch for the 
implemented methods.

A module can just call bus.pos(SomeObjId, someTime) to get the position of
SomeObjId, and bus will get the answer for the right place.  Some of these
functions are broadcast to the systems: 

    forObjectsIntersecting(time, rect) objId: do_something(objId)

A more interesting but not implemented example would be:

    forMovementBlockingObjects(xy_i{12, 21}) obj: ...

In that case, there might be a hit from a wall in a playfield module, from another
living npc or a closed door from gobj, etc...  

# TODO
- action objects that describe an action, and can tell whether the action
  is valid or not.  And can be executed(), which queues up events, etc...
  Keeping actions in objects made it so it was easy to iterate possible actions. 

- For gobjs, there's no indirection for the id, it's just an index into 
  an array. Need to figure out what to do for the delete case.  Before
  an object is deleted, need to send out an event so all systems will know
  to scrub any references to that ObjId before it gets deleted.
