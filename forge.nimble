version       = "2023.1002"
author        = "Daylin Morgan"
description   = "build nim binaries for all the platforms"
license       = "MIT"
srcDir        = "src"
bin           = @["forge", "forgecc"]
binDir        = "bin"


requires "nim >= 2.0.0"
requires "cligen"
requires "https://github.com/daylinmorgan/hwylterm#HEAD"


