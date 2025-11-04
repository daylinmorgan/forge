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

import std/[appdirs, os, osproc, strformat, paths]
import ./term

let SDK_DIR =  appdirs.getDataDir() / Path("forge/macos_sdk")
const SDK_REPO_URL = "https://github.com/mitchellh/zig-build-macos-sdk"
var SDK_COMPILER_ARGS = &"--sysroot={SDK_DIR} -I/include -L/lib"
var SDK_LINKER_ARGS = &"--sysroot={SDK_DIR} -I/include -L/lib"

proc fetchSdk*(force: bool = false) =
  if dirExists($SDK_DIR):
    if force: removeDir($SDK_DIR)
    else: return
  info "cloning macos sdk to: " & $SDK_DIR
  createDir($SDK_DIR.parentDir)
  let (output, code) = execCmdEx(fmt"git clone {SDK_REPO_URL} {quoteShell($SDK_DIR)}")
  if code != 0:
    err "git clone failed:\n" & output
    quit code

proc sdkFlags*(): seq[string] =
  result.add &"--passC:{SDK_COMPILER_ARGS} -F/Frameworks"
  result.add &"--passL:{SDK_LINKER_ARGS} -F/Frameworks"
