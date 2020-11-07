// Simple logging, with logging functions that delay message string creation
// in a function, so strings are only created when the message needs to 
// be logged.
enum_flags LogLevel:
   Error, 
   Warning, 
   Debug, 
   Timings, 
   StatLogs

var LoggingLevel: int = Error

def warn(f):
   if LoggingLevel & Warning:
      print("WARN: " + f())

def error(f):
   if LoggingLevel & Error:
      print("ERROR: " + f())

def debug(f):
   if LoggingLevel & Debug:
      print("DEBUG: " + f())

def timing(f):
   if LoggingLevel & Timings:
      print("TIMING: " + f())

def statlog(f):
   if LoggingLevel & StatLogs:
      print("STAT: " + f())
