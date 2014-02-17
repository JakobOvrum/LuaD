## Lua static library in OMF format for 32-bit Windows
This directory contains a static library of Lua 5.1.5 in OMF format,
compiled with the [DigitalMars C Compiler (DMC)](http://digitalmars.com/features.html). OMF is required by DMD/OPTLINK for 32-bit Windows targets. Although OMF libraries share the `.lib` extension
with the more commonly used COFF format, they are not compatible, so
this binary is included for convenience. It is not an import library - 
there is no dependency on a DLL.

### Reproducing the build
Copy `dmc.mak` from this directory to the top level directory
of the Lua source code release. Then edit `src/luaconf.h` to manually disable `popen` support. Then invoke the makefile with GNU make:

    mingw32-make -fdmc.mak

Requires the [DMC](http://digitalmars.com/features.html) toolchain (specifically, the C compiler and the librarian).
