version       = "2024.1003"
author        = "Daylin Morgan"
description   = "build nim binaries for all the platforms"
license       = "MIT"
srcDir        = "src"
bin           = @["forge", "forgecc"]
binDir        = "bin"


requires "nim >= 2.0.0"
requires "https://github.com/daylinmorgan/hwylterm#748f7e"
