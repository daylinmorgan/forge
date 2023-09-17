import std/[json, macros, math, os, sequtils, strutils, strformat, terminal]

import term
from zig import zigTargets

proc columns*(items: seq[string]): string =
  ## return a list of items as equally spaced columns
  let
    maxWidth = max(items.mapIt(it.len))
    nColumns = floor((terminalWidth() + 1) / (maxWidth + 1)).int
  result = (
      items.mapIt(it.alignLeft(maxWidth + 1))
    ).distribute(
      (items.len / nColumns).int + 1
    ).mapIt(it.join("")).join("\n")

template parseArgs*(args: seq[string]): seq[string] =
  if args.len == 0:
    args
  elif args[0] == "c":
    args[1..^1]
  else:
    args

type
  Triplet* = object
    cpu: string
    os: string
    libc: string

proc `$`*(t: Triplet): string = &"{t.cpu}-{t.os}-{t.libc}"

proc checkTargets*(targets: seq[string]) =
  let knownTargets = zigTargets()
  var unknownTargets: seq[string]
  for target in targets:
    if target notin knowntargets:
      unknownTargets.add target

  if unknownTargets.len != 0:
    termErr &"unknown target(s): " & unknownTargets.join(", ")
    termEcho "must be one of:"
    stderr.writeLine knownTargets.columns
    quit 1

proc parseTriplet*(s: string): Triplet =
  let parts = s.split("-")
  result.cpu = parts[0]
  result.os = parts[1]
  result.libc = parts[2]

macro addFlag*(arg: untyped): untyped =
  let
    flag = "--" & arg.strVal & ":"
    inferProc = newCall("infer" & arg.strVal, newIdentNode("triplet"))

  quote do:
    if `flag` notin args:
      let selected = `inferProc`
      if selected != "":
        result.add `flag` & selected


proc inferOs*(t: Triplet): string =
  case t.os:
    of "windows", "linux": t.os.capitalizeAscii()
    of "macos": "MacOSX"
    of "wasm": "Linux"
    else: ""

proc inferCpu*(t: Triplet): string =
  # Available options are:
  # i386, m68k, alpha, powerpc, powerpc64, powerpc64el, sparc,
  # vm, hppa, ia64, amd64, mips, mipsel, arm, arm64, js,
  # nimvm, avr, msp430, sparc64, mips64, mips64el, riscv32,
  # riscv64, esp, wasm32, e2k, loongarch64

  # NOTE: I don't know what the _be eb means but if nim
  # can't handle them then maybe an error would be better
  result =
    case t.cpu:
    of "x86_64":
      "amd64"
    of "aarch64", "aarch64_be":
      "arm64"
    of "arm", "armeb":
      "arm"
    of "x86":
      "i386"
    of "powerpc64el":
      "powerpc64le"
    # remain the same
    of "m68k", "mips64el", "mipsel", "mips", "powerpc", "powerpc64", "riscv64",
        "sparc", "sparc64", "wasm32": t.cpu
    else:
      ""

proc formatDirName*(formatstr: string, name: string, version: string,
    target: string): string =
  var vsn = version
  if ("v$version" in formatstr or "v${version}" in formatstr) and
      vsn.startsWith("v"):
    vsn = vsn[1..^1]
  try:
    result = formatstr % ["name", name, "version", vsn, "target", target]
  except ValueError as e:
    termErrQuit e.msg

  if result == "":
    termErrQuit &"error processing formatstr: {formatstr}"

