version       = "2025.1008"
author        = "Daylin Morgan"
description   = "build nim binaries for all the platforms"
license       = "MIT"
srcDir        = "src"
bin           = @["forge"]
binDir        = "bin"


requires "nim >= 2.0.0"
requires "https://github.com/daylinmorgan/hwylterm#8c3f459"
requires "https://github.com/usu-dev/usu-nim"
