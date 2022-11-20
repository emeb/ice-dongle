# ice-dongle LiteX
This builds a minimal LiteX bare-metal demo.

## Building and installing
Install Litex - go here for instructions:
[Litex Github](https://github.com/enjoy-digital/litex)

Put the ice-dongle in DFU mode:
* Press and hold `Boot` button.
* Press and release `RST` button.
* Release `Boot` button.

The RGB LED should by beating a slow cyan color indicating that the DFU
bootloader is ready.

Run the build script
```
./ice-dongle.py --build --flash
```
This will run for a few minutes to build and flash the LiteX demo design onto the
ice-dongle. After it completes you should be able to start up a serial terminal
and communicate with the LiteX command line. Try typing `help` to get started.