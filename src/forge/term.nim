import std/[
  math, sequtils, strutils, terminal
]

import hwylterm
export hwylterm

proc columns*(items: seq[string]): string =
  ## return a list of items as equally spaced columns
  let
    maxWidth = max(items.mapIt(it.len))
    nColumns = floor((terminalWidth() + 1) / (maxWidth + 1)).int
  result = (items.mapIt(it.alignLeft(maxWidth + 1)))
    .distribute((items.len / nColumns).int + 1)
    .mapIt(it.join(""))
    .join("\n")

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

template `!`*(cond: bool, msg: string) =
  if not cond: errQuit msg


