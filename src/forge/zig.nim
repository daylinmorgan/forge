import std/[json, os, osproc, terminal]

import term

proc zigTargets*(): seq[string] =
  let (output, _) = execCmdEx "zig targets"
  parseJson(output)["libc"].to(seq[string])

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
    termErr "zig not found"
    termErr "  forge requires a working installation of zig"
    termErr "  see: https://ziglang.org/download/"
    quit 1


