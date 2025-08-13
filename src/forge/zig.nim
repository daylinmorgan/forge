import std/[os, osproc, strscans, strutils]
import term

template `!`(cond: bool, msg: string) =
  if not cond:
    quit msg

proc zigTargets*(): seq[string] =
  # andrew's dogfooding forced me to parse zon >:(
  let (targets, _ ) = execCmdEx "zig targets"
  let (ok, _, libcBlock,_)  = scanTuple(targets, "$*.libc = .{$*}$*$.")

  ok!"failed to extract libc block from `zig targets`"
  for line in libcBlock.strip().splitLines():
    let (ok, triple) = scanTuple(line.strip(),"\"$*\",")
    ok!("failed to parse triple from `zig targets`: " & line)
    result.add triple

proc zigExists*() =
  if (findExe "zig") == "":
    err "[red]zig not found".bb
    err "  forge requires a working installation of zig"
    err "  see: https://ziglang.org/download/"
    quit 1

proc callZig*(params: varargs[string]): int  =
  zigExists()
  let process = startProcess(
    "zig", args = params, options = {poStdErrToStdOut, poUsePath, poParentStreams}
  )
  result = process.waitForExit()
  close process

