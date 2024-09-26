import std/strutils

import hwylterm

let prefix = "[bold magenta]forge[/] [yellow]||[/] ".bb

template termEcho*(args: varargs[string | BbString, `$`]) =
  stderr.writeLine $prefix, args.join(" ")

template termErr*(args: varargs[string | BbString, `$`]) =
  stderr.writeLine $prefix, $"[red]error ||[/] ".bb, args.join(" ")

template termErrQuit*(args: varargs[string | BbString, `$`]) =
  termErr args
  quit 1

export hwylterm
