import std/[
  json, macros, os, osproc,
  strformat, strscans, strutils, sequtils,
  sugar
]
import term

proc getForgeBackend*(default = "cc"): string =
  result = getEnv("FORGE_BACKEND", default)
  if result == "cpp":
    result = "c++"

type Triple* = object
  cpu: string
  os: string
  libc: string

proc parseTriple*(s: string): Triple =
  let parts = s.split("-")
  let ok = parts.len == 3
  ok!("expected 3 parts separated by -, got: " & s)
  result.cpu = parts[0]
  result.os = parts[1]
  result.libc = parts[2]

proc `$`*(t: Triple): string =
  fmt"{t.cpu}-{t.os}-{t.libc}"

proc columns*(items: seq[Triple]): string =
  items.mapIt($it).columns()

proc zigTargets(): seq[Triple] =
  # andrew's dogfooding forced me to parse zon >:(
  let (targets, _ ) = execCmdEx "zig targets"
  let (ok, _, libcBlock,_)  = scanTuple(targets, "$*.libc = .{$*}$*$.")

  ok!"failed to extract libc block from `zig targets`"
  for line in libcBlock.strip().splitLines():
    let (ok, triple) = scanTuple(line.strip(),"\"$*\",")
    ok!("failed to parse triple from `zig targets`: " & line)
    result.add triple.parseTriple()

proc checkTargets*(targets: varargs[string]) =
  let knownTargets = zigTargets()
  var unknownTargets: seq[Triple]
  for target in targets:
    let triple = parseTriple(target)
    if triple notin knownTargets:
      unknownTargets.add triple

  if unknownTargets.len != 0:
    err &"unknown target(s): " & unknownTargets.join(", ")
    info "must be one of:"
    stderr.writeLine knownTargets.columns
    quit 1

macro addFlag*(arg: untyped): untyped =
  let
    flag = "--" & arg.strVal & ":"
    inferProc = newCall("infer" & arg.strVal, newIdentNode("triplet"))

  quote:
    if not any(args, (f: string) => f.startsWith(`flag`)):
      let selected = `inferProc`
      if selected != "":
        result.add `flag` & selected

proc inferOs*(t: Triple): string =
  # Available options are:
  #  DOS, Windows, OS2, Linux, MorphOS, SkyOS, Solaris, Irix, NetBSD, FreeBSD, OpenBSD,
  #  DragonFly, CROSSOS, AIX, PalmOS, QNX, Amiga, Atari, Netware, MacOS, MacOSX, iOS, Haiku, Android, VxWorks,
  #  Genode, JS, NimVM, Standalone, NintendoSwitch, FreeRTOS, Zephyr, NuttX, Any
  #
  # there is no way most of those actualy compile with Nim 2
  case t.os
  of "windows", "linux":
    t.os.capitalizeAscii()
  of "macos":
    "MacOSX"
  of "wasm":
    "Linux"
  of "openbsd":
    "OpenBSD"
  of "netbsd":
    "NetBSD"
  else:
    ""

proc inferCpu*(t: Triple): string =
  # Available options are:
  #  i386, m68k, alpha, powerpc, powerpc64, powerpc64el, sparc,
  #  vm, hppa, ia64, amd64, mips, mipsel, arm, arm64, js,
  #  nimvm, avr, msp430, sparc64, mips64, mips64el, riscv32,
  #  riscv64, esp, wasm32, e2k, loongarch64

  # NOTE: I don't know what the _be eb means but if nim
  # can't handle them then maybe an err would be better
  result =
    case t.cpu
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
    of "m68k", "mips64el", "mipsel", "mips", "powerpc", "powerpc64", "riscv64", "sparc",
        "sparc64", "wasm32":
      t.cpu
    else:
      ""


proc getTargets*(os: seq[string] = @[], cpu: seq[string] = @[]): seq[Triple] =
  let targets = zigTargets()
  if os.len == 0 and cpu.len == 0: return targets
  for t in targets:
    if os.len > 0 and t.inferOs() notin os:
      continue
    if cpu.len > 0 and t.inferCpu() notin cpu:
      continue
    result.add t


proc zigExists*() =
  let ok = findExe("zig") != ""
  ok!($bb"[red]zig not found" & "\n" &  """
forge requires a working installation of zig
see: https://ziglang.org/download/""".indent(2)
  )

proc callZig*(params: varargs[string]): int  =
  zigExists()
  let process = startProcess(
    "zig", args = params, options = {poUsePath, poParentStreams}
  )
  result = process.waitForExit()
  close process

