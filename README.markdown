Lua Binaries for DMD
==============================
Linux, OSX, etc (GCC linker)
------------------------------
On these systems, DMD uses the GCC linker. GCC-compatible libraries can be found at: [LuaBinaries for 5.1.4](http://sourceforge.net/projects/luabinaries/files/5.1.4)

Windows
------------------------------
DMD uses a quite old format for import libaries on Windows called OMF, and although OMF library files tend to share the .lib extension with COFF library files (used by MSVC), they aren't compatible with eachother. A DMD-compatible OMF import library for lua51.dll is included on this branch for convenience. It is an import library, so you need lua51.dll (and if it's a proxy DLL, you also need lua5.1.dll) at runtime. The Lua runtime libraries can also be found at the [LuaBinaries](http://sourceforge.net/projects/luabinaries/files/5.1.4) repository linked above.

I have absolutely no idea if that infringes on any copyright or license issues, so please inform me if it does!