const forgePath {.strdefine.} = if buildOs == "windows": "forge.exe" else: "forge"

proc targetTriple(): string =
  const libc {.strdefine.} = ""
  var args = " +triple --cpu:" & hostCpu & " --os:" & hostOs
  if libc != "": args.add " --libc:" & libc
  let (output, code) = gorgeEx(forgePath & args)
  if code != 0: quit "failed to get target triple: " & output
  result = output

const target {.strdefine.} = targetTriple()

switch("cc", "clang")
switch("clang.exe", forgePath)
switch("clang.linkerexe", forgePath)
switch("clang.cpp.exe", forgePath)
switch("clang.cpp.linkerexe", forgePath)

switch("passC", "-target " & target)
switch("passL", "-target " & target)

when hostOs == "macosx" and not defined(noMacosSdk):
  const (flags, code) = gorgeEx(forgePath & " +sdk-flags")
  if code != 0: quit "failed to get sdk flags: " & flags
  switch("passC", flags)
  switch("passL", flags)

