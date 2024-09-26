import std/[strformat, strutils]

task build, "build":
  exec "nim c --outdir:bin src/forge.nim"

task release, "build release assets":
  version = (gorgeEx "git describe --tags --always --match 'v*'").output
  exec fmt"forge release -v {version} -V"

task bundle, "package build assets":
  withDir "dist":
    for dir in listDirs("."):
      let cmd =
        if "windows" in dir: fmt"7z a {dir}.zip {dir}"
        else: fmt"tar czf {dir}.tar.gz {dir}"
      cpFile("../README.md", fmt"{dir}/README.md")
      exec cmd


# begin Nimble config (version 2)
--noNimblePath
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config
