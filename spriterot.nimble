# Package

version       = "1.0.1"
author        = "Samuele Zolfanelli"
description   = "Command line utility to create spritesheets of rotated sprites."
license       = "MIT"
srcDir        = "src"
bin           = @["spriterot"]


# Dependencies

requires "nim >= 1.6.10"
requires "pixie >= 5.0.0 & < 6.0.0"
requires "argparse >= 4.0.0 & < 5.0.0"
requires "regex >= 0.20.0 & < 1.0.0"