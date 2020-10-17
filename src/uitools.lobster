// Code for ui.  Split out from player module, as it was starting to get
// messy.
import algs
import bus
import config_generated
import imgui
import objutils


// A base class for data a client can attach to a handler.
// Also gives the client a way to pass back arbitrary data from
// a dialog.
class UserData:
   title: string

enum InteractionStatus:
   Working, Finished, Cancelled

// Function that renders the UI and deals with input.
// It's expected this function will return Finished|Cancelled
// when it is done.
def InteractionHandler(data: UserData?) -> InteractionStatus

// A handler that controls a ui interation with the user.  
// Interactions can correspond with dialogs, and can be nested.
class Interaction:
   data: UserData?
   handler: InteractionHandler
   status: InteractionStatus = Working // Status of the interaction.

// Stack of active interactions.
private var Acts: Interaction? = nil

def start_interaction(data: UserData?, handler: InteractionHandler, 
                      initialStatus: InteractionStatus = Working):
   assert Acts == nil
   Acts = Interaction{data: data, handler: handler, status: initialStatus}

def interaction_active():
   return Acts != nil 

// Should be called in a im_frame from the main render loop.
def uitools_render():
   if Acts:
      if Acts.status == Working:
         let h = Acts.handler
         Acts.status = h(Acts.data)

// Allows the client to poll for a finished interaction.
// If there is one, it is returned, otherwise nil is returned.
def finished_interaction() -> Interaction?:
   if Acts and Acts.status != Working:
      let rv = Acts
      Acts = nil
      return rv
   else:
      return nil


// Prompting to pick an object
//

