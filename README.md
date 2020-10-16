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

ObjId used to be a id that could be used to find an object.  This started
to bog down quite a bit when adding lots of objects. 

Switched over to the ObjId being a object reference to a base class, 
that has an embedded links so it can be linked into doubly linked lists.

On the good side, saves a lot of sorting to do lookups on objids.

On the bad side, debugging is uglier, can't just expand an array
to see all of the objects.


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
- Fix Rect and Rectf and assoc fns to use exclusive bounds. I think some usage of those
  already use it that way out of habit.
- Remove TileName from the config?  Was going to be for animations, and
  for testing, but TileKit can do the animations, and tiles can be
  looked up or classified by tags.
- Item info page with summary, and action buttons
- Nested prompting - if you want to drop false teeth, and you have 3, need to 
  prompt for how many... Or prompting a put object for floor, container1, container?
- need to presize some prompt windows?  Need another imgui binding.
