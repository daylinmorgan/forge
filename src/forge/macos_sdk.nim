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

let SDK_DIR =  appdirs.getDataDir() / Path("forge/macos_sdk")
const SDK_REPO_URL = "https://github.com/mitchellh/zig-build-macos-sdk"

proc fetchSdk*(force: bool = false) =
  if dirExists($SDK_DIR):
    if force: removeDir($SDK_DIR)
    else: return
  echo "fetching zig sdk" # TODO: logging + debug logging
  createDir($SDK_DIR.parentDir)
  let (output, code) =
    execCmdEx(fmt"git clone {SDK_REPO_URL} {SDK_DIR}")
  if code != 0: quit output # todo error handling

proc sdkFlags*(): seq[string] =
  let
    macos_lib = &"{SDK_DIR}/lib"
    macos_include = &"{SDK_DIR}/include"
    macos_frameworks = &"{SDK_DIR}/Frameworks"

  result.add &"--passC:-I{macos_include} -F{macos_frameworks} -L{macos_lib}"
  result.add &"--passL:-I{macos_include} -F{macos_frameworks} -L{macos_lib}"

when isMainModule:
  fetchSdk()
