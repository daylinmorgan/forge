## fetch the macos sdk for cross-compiling

#[
  essentially automate this config.nims snippet (from grabnim) with flags

  const
    macos_sdk {.strdefine.} = "./assets/zig-build-macos-sdk"
    macos_lib = &"{macos_sdk}/lib"
    macos_include = &"{macos_sdk}/include"
    macos_frameworks = &"{macos_sdk}/Frameworks"

  switch("passC", &"-I{macos_include} -F{macos_frameworks} -L{macos_lib}")
  switch("passL", &"-I{macos_include} -F{macos_frameworks} -L{macos_lib}")
]#

import std/[os, osproc, strformat, paths]
import term, zig

# Almost all non-Windows platforms that need either an SDK or use the OS source code as a sysroot
#  will need these passed to the compiler and linker; separated for readability
const SDK_COMPILER_ARGS = "-I/include -L/lib"
const SDK_LINKER_ARGS = "-I/include -L/lib"

proc fetchSdk*(sdk: SDK, force: bool = false) =
  if dirExists($sdk.dir):
    if force: removeDir($sdk.dir)
    else: return
  info fmt"cloning {sdk.os} sdk to: " & $sdk.dir
  createDir($sdk.dir.parentDir)
  let (output, code) = execCmdEx(fmt"git clone {sdk.url} {quoteShell($sdk.dir)}")
  if code != 0:
    err "git clone failed:\n" & output
    quit code

proc sdkFlags*(sdk: SDK): seq[string] =
  result.add fmt"--passC:--sysroot={sdk.dir} {SDK_COMPILER_ARGS} {sdk.cflags}"
  result.add &"--passL:--sysroot={sdk.dir} {SDK_LINKER_ARGS} {sdk.lflags}"
