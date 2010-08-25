LuaD
============================================
Hello, world!
--------------------------------------------
	import luad.all;

	void main()
	{
		auto lua = new LuaState;
		lua.openLibs();
		
		auto print = lua.get!LuaFunction("print");
		print("hello, world!");
	}

LuaD is a bridge between the D and Lua programming languages. Unlike many other libraries built on the Lua C API, LuaD doesn't expose the Lua stack - instead, it has wrappers for references to Lua objects, and supports converting any D type into a Lua type. This makes it very easy to use and encourages a much less error-prone style of programming, as well as boosting productivity by a substantial order. Due to D's powerful generic programming capabilities, performance remains the same as the equivalent using the C API.

LuaD also includes bindings for the Lua C API. To use it, import the module `luad.c.all` or selectively import the modules in the `luad.c` package. The usage is identical to that of working with the Lua API in C. Documentation for the C API can be found [here](http://www.lua.org/manual/5.1/manual.html).

(LuaD uses Lua version 5.1, support for other versions will be provided when there's demand)

Goals
============================================
Current progress noted in parentheses:

 * Run Lua code from D, and D code from Lua (_Yes_)
 * Support automatic conversions between any D type and its Lua equivalent (_Yes_ - except classes, but including structs)
 * Support automatic conversions between D classes and Lua userdata (Not yet)
 * Support D1 and Tango (Not yet. Also, the D1 version will not allow conversions between D classes and Lua userdata)
 * Provide access to the entire underlying Lua C API (_Yes_)

Usage
============================================
LuaD is currently only being tested with DMD 2.048. Once D1 support comes around, testing will be done on other compilers as well as with the Tango library.

To use, import the `luad.all` module in your project and compile all the files in the `luad` package. You can also compile the `luad` package to a static libary, but you still need the full LuaD sources available because of heavy use of templates. You must also link Lua 5.1; on Unix-like systems, the library is typically called `liblua5.1.a` or similar. On Windows, you need a `lua51.lib` in OMF format to be linkable with DMD.

Check out the [binaries branch](http://github.com/JakobOvrum/LuaD/tree/binaries) for a `lua51.lib` import library and download instructions for a DMD-compatible library for Unix-like systems.

An example/ subdirectory with more extensive examples is in progress, but for now, look at the examples in the documentation.

Documentation
============================================
You can find automatically generated documentation on the `gh-pages` branch, or you can [browse it online](http://jakobovrum.github.com/LuaD/).

License
============================================
LuaD is licensed under the terms of the MIT license (see the LICENSE file for details).