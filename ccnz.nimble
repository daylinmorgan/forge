version       = "2023.1001"
author        = "Daylin Morgan"
description   = "ccnz compiles nim w/zig"
license       = "MIT"
srcDir        = "src"
bin           = @["ccnz", "ccnzcc"]
binDir        = "bin"


requires "nim >= 2.0.0",
         "cligen"



import strformat
const targets = [
    "x86_64-linux-gnu",
    "x86_64-linux-musl",
    "x86_64-macos-none",
    "x86_64-windows-gnu"
  ]

task release, "build release assets":
  mkdir "dist"
  for target in targets:
    let ext = if target == "x86_64-windows-gnu": ".cmd" else: ""
    for app in @["ccnz", "ccnzcc"]:
      let outdir = &"dist/{target}/"
      exec &"ccnz cc --target {target} --nimble -- --out:{outdir}{app}{ext} -d:release src/{app}"

task bundle, "package build assets":
  cd "dist"
  for target in targets:
    let 
      app = projectName()
      cmd = 
        if target == "x86_64-windows-gnu":
          &"7z a {app}_{target}.zip {target}"
        else:
          &"tar czf {app}_{target}.tar.gz {target}"

    cpFile("../README.md", &"{target}/README.md")
    exec cmd



