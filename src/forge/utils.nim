import std/[json, macros, math, os, strutils, strformat]

import term

template parseArgs*(args: seq[string]): seq[string] =
  if args.len == 0:
    args
  elif args[0] == "c":
    args[1 ..^ 1]
  else:
    args

proc formatDirName*(
    formatstr: string, name: string, version: string, target: string
): string =
  var vsn = version
  if ("v$version" in formatstr or "v${version}" in formatstr) and vsn.startsWith("v"):
    vsn = vsn[1 ..^ 1]
  try:
    result = formatstr % ["name", name, "version", vsn, "target", target]
  except ValueError as e:
    errQuit e.msg

  if result == "":
    errQuit &"err processing formatstr: {formatstr}"
