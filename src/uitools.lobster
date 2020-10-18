// Code for ui.  Split out from player module, as it was starting to get
// messy.
import from "../../../src/crusty/src/"
import actions
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


//
// Simple object prompt
//
def PromptHandler() -> DisplayListStatus
                                    
def PromptAction(data: UserData) -> ActionBase?

class ObjPromptData : UserData
   objs: ObjList = ObjList{options: olAddChoiceLetter}
   player: ObjId
   action: PromptAction
   picked: ObjId? = nil

   def balls(op: ObjPromptData):
      print(op.player.id)

private def obj_prompt_handler(data: UserData?) -> InteractionStatus:
   var rv = Working

   if data and data is ObjPromptData:
      let ws = gl_window_size().to_f * xy_f{0.4, 0.5} 
      im_set_next_window_pos(ws, im_cond_first_use_ever, xy_f{0.5, 0.5})
      im_window(data.title, 0):
         let status, picked, si, ii = display_list(data.objs)

         if status == dlsCancel:
            rv = Cancelled
         elif picked:
            data.picked = picked
            rv = Finished

   return rv

// Starts an object prompt.  Poll with finished_interaction() to find out
// when it is complete.
def prompt_for_object(player: ObjId, title: string, cands: ObjList, skip_one: bool, action):
   let data = ObjPromptData{title: title, objs: cands, player: player, action: action}  

   if skip_one and count(cands) == 1:
      // Just one, so perform the action without a prompt.
      data.picked = first(cands)
      start_interaction(data, (fn(a: UserData?): obj_prompt_handler(a)), Finished)
   else:
      start_interaction(data, (fn(a: UserData?): obj_prompt_handler(a)))


//
// Item interaction dialog.
//


