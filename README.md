# TODO
- action objects that describe an action, and can tell whether the action
  is valid or not.  And can be executed(), which queues up events, etc...
  Keeping actions in objects made it so it was easy to iterate possible actions. 

- For gobjs, there's no indirection for the id, it's just an index into 
  an array. Need to figure out what to do for the delete case.  Before
  an object is deleted, need to send out an event so all systems will know
  to scrub any references to that ObjId before it gets deleted.
