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

import std/[appdirs, os, osproc, strformat, paths, strutils]
import ./term

when (NimMajor, NimMinor, NimPatch) <= (2, 2, 0):
  template `$`*(x: Path): string =
    string(x)

let SDK_CACHE =  appdirs.getDataDir() / Path("forge/macos_sdk")
const SDK_REPO_URL = "https://github.com/mitchellh/zig-build-macos-sdk"

proc fetchSdk*(force: bool = false) =
  if dirExists($SDK_CACHE):
    if force: removeDir($SDK_CACHE)
    else: return
  # info "cloning macos sdk to: " & $SDK_CACHE
  createDir($SDK_CACHE.parentDir)
  let (output, code) = execCmdEx(fmt"git clone {SDK_REPO_URL} {quoteShell($SDK_CACHE)}")
  if code != 0:
    err "git clone failed:\n" & output
    quit code

proc getMacSdkFlags*(): string =
  when defined(macosx):
    # macos should have it's own sdk's
    let (sysroot, code) = execCmdEx("xcrun --show-sdk-path")
    if code != 0:
      err "failed to get sysroot"
      warn "linking may fail"
      return
    let
      sdkDir = sysroot.strip()
      macos_lib = quoteShell(&"{sdkDir}/usr/lib")
      macos_include = quoteShell(&"{sdkDir}/usr/include")
      macos_frameworks = quoteShell(&"{sdkDir}/system/Library/Frameworks")
    result = &"-I{macos_include} -F{macos_frameworks} -L{macos_lib}"
  else:
    let
      sdkDir = $SDK_CACHE
      macos_lib = quoteShell(&"{sdkDir}/lib")
      macos_include = quoteShell(&"{sdkDir}/include")
      macos_frameworks = quoteShell(&"{sdkDir}/Frameworks")
    result = &"-I{macos_include} -F{macos_frameworks} -L{macos_lib}"

proc sdkPassFlags*(): seq[string] =
  let flags = getMacSdkFlags()
  if flags != "":
    result.add &"--passC:{flags}"
    result.add &"--passL:{flags}"
