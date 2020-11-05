// Implements action log that can be shown on the screen.
import from "../../../src/crusty/src/"
import imgui
import vec

private class LogMsg:
   count: int = 1
   msg: string

private def to_string(lm:: LogMsg):
   if count > 1:
      return "(x" + count + ") " + msg
   else:
      return msg

private let CircBufSz = 32
private var Msgs: [LogMsg] = [LogMsg{count: 3, msg: "Eat a crap"}]
private var Start = 0

private def circ_index(i):
   return (Start + i) % length(Msgs)

private def for_all_messages(body):
   let nm = length(Msgs)
   for(nm) i:
      body(Msgs[circ_index(i)])

// Logs a message which may be displayed on 
// the user's screen.
def actionlog_present(msg: string):
   if length(Msgs) > 0:
      let lasti = (Start + length(Msgs)) % length(Msgs)
      if lasti >= 0 and Msgs[lasti].msg == msg:
         ++Msgs[lasti].count
      else:
         if length(Msgs) >= CircBufSz:
            Msgs[Start] = LogMsg{msg: msg}
            Start = (Start + 1) % length(Msgs)
         else:
            push(Msgs, LogMsg{msg: msg})
   else:
      push(Msgs, LogMsg{msg: msg})

// Clears the message log.
def actionlog_clear():
   Msgs = []
   Start = 0


// Should be called in an im_frame.
def actionlog_render():
   let sz = gl_window_size()
   let dims = xy_f{sz.x / 3.0, sz.y / 5.0}
   im_set_next_window_size(dims, im_cond_first_use_ever)
   im_set_next_window_pos(xy_f{0, sz.y - dims.y}, im_cond_first_use_ever, xy_0)
   im_window("Actions", im_window_no_titlebar):
      for_all_messages() m:
         im_text(to_string(m))
      im_set_scroll_here_y(1.0)
      

