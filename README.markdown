LuaD
============================================
Hello, world!
--------------------------------------------
`import luad.all;

void main()
{
	auto lua = new LuaState;
	lua.openLibs();
	
	auto print = lua.get!LuaFunction("print");
	print("hello, world!");
}`
(See the documentation for more examples)

LuaD is a bridge between the D and Lua programming languages. Unlike many other libraries built on the Lua C API, LuaD doesn't expose the Lua stack - instead, it has wrappers for references to Lua objects, and supports converting any D type into a Lua type.

LuaD also includes bindings for the Lua C API, simply import the module luad.c.all or selectively import the modules in the luad.c package. The usage is identical to that of working with the Lua API in C. Documentation for the C API can be found [here](http://www.lua.org/manual/5.1/manual.html).

(LuaD uses Lua version 5.1, support for other versions will be provided when there's demand)

Goals
============================================
Current progress noted in parentheses:
 * Run Lua code from D, and D code from Lua (*Yes*)
 * Support automatic conversions between any D type and its Lua equivalent (*Yes* - except classes, but including structs)
 * Support automatic conversions between D classes and Lua userdata (No)
 * Support D1 and Tango (No. The D1 version will not allow conversions between D classes and Lua userdata)
 * Provide access to the entire underlying Lua C API (*Yes*)

Usage
============================================
LuaD is currently only being tested with DMD 2.048. Once D1 support comes around, testing will be done on other compilers as well as with Tango.

To use, import the luad.all module in your project and compile all the files in the luad package. You must also link Lua 5.1; on Unix-like systems, the library is typically called liblua5.1.a or similar. On Windows, you need a lua51.lib in OMF format to be linkable with DMD.

An example/ subdirectory with extensive examples is coming soon.

(I'm planning on putting up a binaries branch with lua51.lib in the correct format for convenience as well as links to pre-compiled GCC libraries for Unix systems)

Documentation
============================================
You can find automatically generated documentation in the gh-pages branch, or [browse it online](http://jakobovrum.github.com/LuaD/).

License
============================================
LuaD is licensed under the terms of the MIT license (see the LICENSE file for details).