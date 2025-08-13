version       = "2024.1005"
author        = "Daylin Morgan"
description   = "build nim binaries for all the platforms"
license       = "MIT"
srcDir        = "src"
bin           = @["forge"]
binDir        = "bin"


requires "nim >= 2.0.0"
requires "https://github.com/daylinmorgan/hwylterm#07770fbd"
requires "https://github.com/usu-dev/usu-nim"
