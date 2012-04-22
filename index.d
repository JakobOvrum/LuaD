/++
LuaD is a bridge between the D and Lua programming languages.
Unlike many other libraries built on the Lua C API, LuaD doesn't expose the Lua stack - instead,
it has wrappers for references to Lua objects, and supports seamlessly and directly converting any D type into a Lua type and vice versa.

See $(LINKMODULE2 state,LuaState) to get started.

See_Also:
Check out the $(LINK2 http://github.com/JakobOvrum/LuaD,github project page) for the full source code
and usage information.

See $(LINKMODULE stack) for the full list of possible type conversions.

Examples:
"Hello, world"
----------------------
import luad.all;

void main()
{
	auto lua = new LuaState;
	lua.openLibs();

	lua.doString(`print("Hello, world!")`);
}
----------------------
Another "Hello, world"
----------------------
import luad.all;

void main()
{
	auto lua = new LuaState;
	lua.openLibs();
	
	//LuaState also works as an alias for the global table
	auto print = lua.get!LuaFunction("print");
	print("Hello, world!");
}
----------------------
Simple function example
----------------------
import luad.all;
import std.stdio;

int printTimes(int times, const(char)[] message)
{
    for(int i = 0; i <= times; i++)
        writeln(message);
    return times;
}

void main()
{
    auto lua = new LuaState;
    lua["printTimes"] = &printTimes;
    lua.doString(`
        printTimes(3, "hello, world!")
    `);
}
----------------------
Configuration file
----------------------
import luad.all;

struct Config
{
	string Name;
	double Version;
}

string configFile = `
Name = "foo"
Version = 1.23
`;

void main()
{
	auto lua = new LuaState;
	
	lua.doString(configFile);
	auto config = lua.globals.toStruct!Config();
	
	assert(config.Name == "foo");
	assert(config.Version == 1.23);
}
----------------------
Macros:
REPOSRCTREE = http://github.com/JakobOvrum/LuaD/tree/gh-pages
+/
module index;