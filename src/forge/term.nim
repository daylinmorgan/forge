import std/strutils

import hwylterm
export hwylterm

let prefix = $"[bold magenta]forge[/] [cyan]||[/] ".bb
let errPrefix = $"[red]error ||[/] ".bb
let warnPrefix = $"[yellow]warning ||[/] ".bb

template info*(args: varargs[string | BbString, `$`]) =
  stderr.writeLine prefix, args.join(" ")

template warn*(args: varargs[string | BBString, `$`]) =
  stderr.writeLine prefix, warnPrefix, args.join(" ")

template err*(args: varargs[string | BbString, `$`]) =
  stderr.writeLine prefix, errPrefix, args.join(" ")

template errQuit*(args: varargs[string | BbString, `$`]) =
  err args
  quit 1

