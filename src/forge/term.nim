import std/strutils

import hwylterm

let prefix = $"[bold magenta]forge[/] [cyan]||[/] ".bb
let errPrefix = $"[red]error ||[/]".bb
let warnPrefix = $"[yellow]warn ||[/]".bb

# why did I write these as tempaltes?
template termWarn(args: varargs[string | BBString, `$`]) =
  stderr.writeLine prefix, warnPrefix, args.join(" ")

template termEcho*(args: varargs[string | BbString, `$`]) =
  stderr.writeLine prefix, args.join(" ")

template termErr*(args: varargs[string | BbString, `$`]) =
  stderr.writeLine prefix, errPrefix, args.join(" ")

template termErrQuit*(args: varargs[string | BbString, `$`]) =
  termErr args
  quit 1

export hwylterm
