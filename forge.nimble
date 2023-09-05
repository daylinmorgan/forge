version       = "2023.1001"
author        = "Daylin Morgan"
description   = "build nim binaries for all the platforms"
license       = "MIT"
srcDir        = "src"
bin           = @["forge", "forgecc"]
binDir        = "bin"


requires "nim >= 2.0.0",
         "cligen"

import strformat

task release, "build release assets":
  version = (gorgeEx "git describe --tags --always").output
  exec &"forge release -v {version} -V"

task bundle, "package build assets":
  withDir "dist":
    for dir in listDirs("."):
      let cmd = if "windows" in dir:
        &"7z a {dir}.zip {dir}"
      else: 
        &"tar czf {dir}.tar.gz {dir}"
      cpFile("../README.md", &"{dir}/README.md")
      exec cmd



