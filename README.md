LuaD - Lua for the D Programming Language
============================================
--------------------------------------------
```D
import luad.all;

void main()
{
	auto lua = new LuaState;
	lua.openLibs();

	auto print = lua.get!LuaFunction("print");
	print("hello, world!");
}
```
LuaD is a bridge between the D and Lua programming languages.
Unlike many other libraries built on the Lua C API, LuaD doesn't expose the Lua stack - instead,
it has wrappers for references to Lua objects, and supports seamlessly and directly converting any D type into a Lua type and vice versa. This makes it very easy to use and encourages a much less error-prone style of programming, as well as boosting productivity by a substantial order. Due to D's powerful generic programming capabilities, performance remains the same as the equivalent using the C API.

LuaD also includes bindings for the Lua C API. To use it, import the module `luad.c.all` or selectively import the modules in the `luad.c` package. Usage is identical to that of working with the Lua C API. Documentation for the C API can be found [here](http://www.lua.org/manual/5.1/manual.html).

(LuaD currently supports Lua version 5.1)

Goals
============================================
Current progress noted in parentheses:

 * Run Lua code from D, and D code from Lua (_Yes_)
 * Support automatic conversions between any D type and its Lua equivalent (_Yes_)
 * Support automatic conversions between D classes and Lua userdata (_Partial_)
 * Provide access to the entire underlying Lua C API (_Yes_)
 * Support Lua 5.2 (_Not yet_)

Directory Structure
============================================

 * `luad` - the LuaD package.
 * `visuald` - [VisualD](http://www.dsource.org/projects/visuald) project files.
 * `test` - unittest executable (when built).
 * `lib` - LuaD library files (when built).
 * `example` - LuaD examples.

Usage
============================================
The recommended way of using LuaD is with [dub](https://github.com/rejectedsoftware/dub). See [LuaD on the package repository](http://code.dlang.org/packages/luad) for instructions.

The examples can be tested by running `dub run` in the example's
directory ([see also the examples' readme](/example/README.md)).

Apart from dub, there are [makefiles](#build-with-make) as well as [VisualD project files](#build-with-visualdwindows) for both the library and the examples.

[Documentation](http://jakobovrum.github.com/LuaD/)
============================================
You can find automatically generated documentation on the [gh-pages branch](http://github.com/JakobOvrum/LuaD/tree/gh-pages/), or you can [browse it online](http://jakobovrum.github.com/LuaD/).

### [Tutorial](https://github.com/JakobOvrum/LuaD/wiki/Tutorial)
A tutorial can be found on the project's Wiki.

Manual Usage
============================================
Import the `luad.all` module in your project, and compile all the files in the `luad`, `luad.c` and `luad.conversions` packages. You can also compile the LuaD packages to a static libary, but you still need the full LuaD sources available at compile-time due to heavy use of templates. You must also link Lua version 5.1; on Unix-like systems, the library is typically called `liblua5.1.a` or similar. On Windows, you need a `lua51.lib` in OMF format to be linkable with DMD.

Check out the [binaries branch](http://github.com/JakobOvrum/LuaD/tree/binaries) for a `lua51.lib` import library and download instructions for a DMD-compatible library for Unix-like systems. Since the provided `lua51.lib` is only an import library, you also need the Lua DLLs at runtime (which can be found [here](http://sourceforge.net/projects/luabinaries/files/5.1.4/Executables/lua5_1_4_Win32_bin.zip/download)).

**Please report bugs and issues to the [Github issue tracker](https://github.com/JakobOvrum/LuaD/issues). Thanks!**

Build with Make
============================================
The `MODEL` variable should be either `32` or `64` depending on whether you want to make a 32 bit or 64 bit build. It defaults to `64`.

The `BUILD` variable controls the build configuration; it can be `debug`, `release` or `test`.
`debug` and `release` will build `lib/libluad.a` in debug and release mode respectively. The `test` configuration will build `test/luad_unittest` and then run it with `gdb`. Additionally, code coverage files (*.lst) are generated. The `BUILD` variable defaults to `debug`.

For example, if you want to build and run the unit tests on a 32 bit machine, the command would be:

    make MODEL=32 BUILD=test

Build with VisualD/Windows
============================================
[VisualD](http://www.dsource.org/projects/visuald) project files are included in the `visuald` subdirectory. The Release and Debug configurations produce `lib/luad.lib` and `lib/luad-d.lib` respectively. The Unittest configuration produces `test/luad_unittest.exe`.

Project files for the examples can be found in `visuald/examples` and produce binaries in the `example/bin` directory.

The location of `lua51.lib` needs to be configured for the LuaD Unittest configuration as well as for the examples. The projects are pre-configured to `%LUA_OMFLIB%/lua51.lib`; either add the `LUA_OMFLIB` environment variable, or edit the linker settings manually. `lua51.lib` in OMF format can be found on the [binaries branch](https://github.com/JakobOvrum/LuaD/tree/binaries).

License
============================================
LuaD is licensed under the terms of the MIT license (see the [LICENSE file](/LICENSE.txt) for details).
