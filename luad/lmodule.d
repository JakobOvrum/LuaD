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
		args[1] = getArgument!(F, 1)(L, -1);
	}

	return callFunction!F(L, initFunc, args);
}

/**
 * Generate module entry point for use by Lua's $(D require) function.
 *
 * Params:
 *   modname = module name. Typically this should be the same as the name of
 *   the shared library containing this module. Only characters in the set
 *   $(D [a-zA-Z_]) are allowed. Underscores are used to denote a submodule.
 *   The module name must be unique for the current executable.
 *
 *   initFunc = module initialization function. Called when the module is loaded.
 *   Its return value is returned by $(D require) on the Lua side. Its first
 *   parameter must be of type $(DPREF state,LuaState), which is the state of the calling environment.
 *   Optionally, there may be a second parameter implicitly convertible to the type
 *   $(D const(char[])), which is the name of the module to be loaded (useful for submodules).
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
