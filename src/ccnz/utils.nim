import std/[json, macros, math, os, osproc, strutils, terminal, sequtils]

proc errQuit*(msg: varargs[string]) =
  stderr.write msg.join("\n") & "\n"
  quit 1

# based on https://github.com/enthus1ast/zigcc
template callZig*(zigCmd: string) =
  # Set the zig compiler to call and append args
  var args = @[zigCmd]
  args &= commandLineParams()
  # Start process
  let process = startProcess(
    "zig",
    args = args,
    options = {poStdErrToStdOut, poUsePath, poParentStreams}
  )
  # Get the code so we can carry across the exit code
  let exitCode = process.waitForExit()
  # Clean up
  close process
  quit exitCode

proc zigExists*() =
  if (findExe "zig") == "":
    errQuit "zig not found",
      "ccnz requires a working installation of zig",
      "see: https://ziglang.org/download/"

proc zigTargets*(): seq[string] =
  let (output, _) = execCmdEx "zig targets"
  parseJson(output)["libc"].to(seq[string])

macro addFlag*(arg: untyped): untyped =
  let
    flag = "--" & arg.strVal & ":"
    inferProc = newCall("infer" & arg.strVal, newIdentNode("target"))

  quote do:
    if `flag` notin args:
      let selected = `inferProc`
      if selected != "":
        result.add `flag` & selected


proc inferOs*(target: string): string =
  if "windows" in target:
    "Windows"
  elif "macos" in target:
    "MacOSX"
  elif "linux" in target:
    "Linux"
  elif "wasm" in target:
    "Linux"
  else:
    ""

proc inferCpu*(target: string): string =
  # Available options are:
  # i386, m68k, alpha, powerpc, powerpc64, powerpc64el, sparc,
  # vm, hppa, ia64, amd64, mips, mipsel, arm, arm64, js,
  # nimvm, avr, msp430, sparc64, mips64, mips64el, riscv32,
  # riscv64, esp, wasm32, e2k, loongarch64
  #
  let candidate = target.split("-")[0]
  # NOTE: I don't know what the _be eb means but if nim
  # can't handle them then maybe an error would be better
  result =
    case candidate:
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
        "sparc", "sparc64", "wasm32":
      candidate
    else:
      ""

# s390x-linux-gnu
# s390x-linux-musl
# sparc-linux-gnu
# sparc64-linux-gnu
# wasm32-freestanding-musl
# wasm32-wasi-musl
# x86_64-linux-gnu
# x86_64-linux-gnux32
# x86_64-linux-musl
# x86_64-windows-gnu
# x86_64-macos-none
# x86_64-macos-none
# x86_64-macos-none
#
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



