module luad.lmodule;

import luad.state;
import luad.stack;
import luad.conversions.functions;

import luad.c.lua : lua_State;

import std.traits;

// Internal, but needs to be public
extern(C) int openDModule(F)(lua_State* L, F initFunc)
{
	auto lua = new LuaState(L);

	alias ParameterTypeTuple!F Args;

	static assert(Args.length > 0 && Args.length < 3 &&
				  is(Args[0] == LuaState),
				  "invalid initFunc signature");
	
	Args args;
	args[0] = lua;

	static if(Args.length == 2)
	{
		static assert(is(Args[1] : const(char[])), "second parameter to initFunc must be a const string");
		args[1] = getValue!(Args[1])(L, -1);
	}

	return callFunction!F(L, initFunc, args);
}

/**
 * 
 */
// TODO: verify modname
template LuaModule(string modname, alias initFunc)
{
	enum LuaModule = "import luad.c.lua : lua_State;" ~
		// The first exported C symbol always gets a preceeding
		// underscore on Windows with DMD/OPTLINK, but Lua
		// expects "luaopen_*" exactly.
		"version(Windows) export extern(C) void _luad_" ~ modname ~ "_systemconvdummy() {}" ~
		"export extern(C) int luaopen_" ~ modname ~ "(lua_State* L) {" ~
			  "return openDModule(L, &" ~ __traits(identifier, initFunc) ~ ");" ~
		"}";
}
