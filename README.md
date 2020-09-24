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

Also as mentioned before, there are methods for "events" that different systems
may be interested in, like notifications an object is moving to a particular
map grid, etc...  These will start with "notify_" as a convention.

### The (defunct) events module

There used to be an events module, where there were MoveEvents, TurnEvents, 
and these objects were queued and inspected by module that were interested.  
(For instance, the gobj module would update sprite LERP state from these events)

It bothered me that there were similarities in fields between the Events and 
the Action objects that represent possible valid options.  Close enough to be
irritating, but any attempt to merge the two would end up being a mess, 
mostly because Actions can trigger multiple events, and there are events that
don't have corresponding actions.  (ie, a SoundEvent).

There were also going to be some problems in how often the event list needed
to be re-traversed so module state would be correct in the face of new events 
created as an object did its think() action.

Instead of merging, I removed events as object, and replaced with with notify_*
calls in the bus module.  

### Action objects

Action objects represent a valid action.  They can only be constructed through
functions in the actions module if the move validates.  The action can be
executed().  

The validity of an action only lasts until the next action is executed.  You 
don't want to create an action, and squirrel away to execute it at a later turn, 
that will probably mess up the game state.

Representing actions as objects makes it easy to iterate through valid actions
for an object.  Helpful for some types of AI.  It can also be handy for context
sensitive help for the player.  (ie, you're next to a closed safe, so you let
the player know they can hit 'o' to open the safe)

# TODO
- For gobjs, there's no indirection for the id, it's just an index into 
  an array. Need to figure out what to do for the delete case.  Before
  an object is deleted, need to send out an event so all systems will know
  to scrub any references to that ObjId before it gets deleted.
- Fix Rect and Rectf and assoc fns to use exclusive bounds. I think some usage of those
  already use it that way out of habit.

- demo
   tiles with sword, groundhog, fish
   grab sword
   sounds
