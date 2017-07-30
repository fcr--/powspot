# PowSpot!
Tool for creation and display of slide based presentations.

## Installation instructions.

* Install `luajit`, `lua-lgi` and `make` packages.
* Download, compile and install `cc65`, (you'd probable like to install it using `checkinstall`).
* Download and compile AtariSIO tools from http://www.horus.com/~hias/atari/ even though only `dir2atr` is used.
* Then you'll need a proper bootable DOS according to the disk type used; which is enhanced density by default. In the provided makefile, it is extracted from the `dos2ed+2.5` template from `atrcopy`. You may install it using `pip install atrcopy`.
* Once you've completed the previous steps, create a file named `Images.mak` defining the locations of `DIR2ATR`, `ATRCOPY` and in `IMAGES` the list of images used. Example:

```
DIR2ATR = atarisio-170702/tools/dir2atr
ATRCOPY = ~/.local/bin/atrcopy
IMAGES = \
  Page0057-6.png \
  Page0052-1.png \
  Page0052-2.png \
  Page0052-3.png
```
* Finally run `make` and enjoy your new presentation at `powspot.atr`.
