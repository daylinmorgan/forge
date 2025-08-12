import std/[json, os, osproc, strscans, strutils]
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

# based on https://github.com/enthus1ast/zigcc
template callZig*(zigCmd: string) =
  zigExists()
  # Set the zig compiler to call and append args
  var args = @[zigCmd]
  args &= commandLineParams()
  # Start process
  let process = startProcess(
    "zig", args = args, options = {poStdErrToStdOut, poUsePath, poParentStreams}
  )
  # Get the code so we can carry across the exit code
  let exitCode = process.waitForExit()
  # Clean up
  close process
  quit exitCode

proc zigExists*() =
  if (findExe "zig") == "":
    termErr "[red]zig not found".bb
    termErr "  forge requires a working installation of zig"
    termErr "  see: https://ziglang.org/download/"
    quit 1
