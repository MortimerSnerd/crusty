// Simple logging, with logging functions that delay message string creation
// in a function, so strings are only created when the message needs to 
// be logged.
enum LogLevel:
   None, 
   Error, 
   Warning, 
   Debug

var LoggingLevel = Warning

def warn(f):
   if LoggingLevel >= Warning:
      print("WARN: " + f())

def error(f):
   if LoggingLevel >= Error:
      print("ERROR: " + f())

def debug(f):
   if LoggingLevel >= Debug:
      print("DEBUG: " + f())

