import std/terminal

# TODO support NO_COLOR for these
let prefix = ansiForegroundColorCode(fgMagenta, bright = true) & "forge" &
    ansiResetCode & ansiForegroundColorCode(fgYellow) & " || " & ansiResetCode

template termEcho*(args: varargs[untyped]) =
  stderr.styledWriteLine(prefix, args)

template termErr*(args: varargs[untyped]) =
  stderr.styledWriteLine(prefix, fgRed, "error ", fgDefault, args)

template termErrQuit*(args: varargs[untyped]) =
  termErr(args)
  quit 1


