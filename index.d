/++
LuaD is a bridge between the D and Lua programming languages.
Unlike many other libraries built on the Lua C API, LuaD doesn't expose the Lua stack - instead,
it has wrappers for references to Lua objects, and supports converting any D type into a Lua type.

See_Also:
Check out the $(LINK2 http://github.com/JakobOvrum/LuaD,github project page) for the full source code
and usage information.

See $(LINK2 /LuaD/luad/stack.html,stack.d) for the full list of possible type conversions.

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

int printTimes(int times, string message)
{
    for(int i = 0; i <= times; i++)
        writeln(message);
    return times;
}

void main()
{
    auto lua = new LuaState;
    lua.set("printTimes", &printTimes);
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
	auto config = lua.toStruct!Config();
	
	assert(config.Name == "foo");
	assert(config.Version == 1.23);
}
----------------------
+/
module index;