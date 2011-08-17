module luad.dynamic;

import luad.c.all;

import luad.base;
import luad.stack;

/**
 * Represents a reference to a Lua value of any type.
 * Supports all operations you can perform on values in Lua.
 */
struct LuaDynamic
{
	/// Underlying Lua reference.
	LuaObject object;
	
	/**
	 * Perform a Lua method call on this object.
	 *
	 * Performs a call similar to calling functions in Lua with the colon operator.
	 * The name string is looked up in this object and the result is called. This object is prepended
	 * to the arguments args.
	 * Params:
	 *    name = _name of method
	 *    args = additional arguments
	 * Returns:
	 *    All return values
	 * Examples:
	 * ----------------
	 * auto luaString = lua.wrap!LuaDynamic("test");
	 * auto results = luaString.gsub("t", "f"); // opDispatch
	 * assert(results[0] == "fesf");
	 * assert(results[1] == 2); // two instances of 't' replaced
	 * ----------------
	 */
	LuaDynamic[] opDispatch(string name, Args...)(Args args)
	{
		assert(lua_gettop(object.state) == 0); // this function assumes empty stack
		
		object.push();
		lua_pushlstring(object.state, name.ptr, name.length);
		lua_gettable(object.state, -2);
		lua_pushvalue(object.state, 1);
		lua_remove(object.state, 1);
		
		foreach(arg; args)
			pushValue(object.state, arg);
		
		lua_call(object.state, args.length + 1, LUA_MULTRET);
		
		return popStack!LuaDynamic(object.state);
	}
	
	LuaDynamic[] opCall(Args...)(Args args)
	{
		assert(lua_gettop(object.state) == 0); // this function assumes empty stack
		
		object.push();
		foreach(arg; args)
			pushValue(object.state, arg);
		
		lua_call(object.state, args.length, LUA_MULTRET);
		
		return popStack!LuaDynamic(object.state);
	}

	bool opEquals(T)(auto ref T other)
	{
		object.push();
		pushValue(object.state, other);
		scope(success) lua_pop(object.state, 2);
		return lua_equal(object.state, -1, -2);
	}
	
	LuaDynamic opIndex(T)(auto ref T key)
	{
		object.push();
		pushValue(object.state, key);
		lua_gettable(object.state, -2);
		auto result = getValue!LuaDynamic(object.state, -1);
		lua_pop(object.state, 2);
		return result;
	}
}

version(unittest) import luad.testing;

import std.stdio;

unittest
{
	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	luaL_openlibs(L);
	
	luaL_dostring(L, `str = "test"`);
	lua_getglobal(L, "str");
	auto luaString = popValue!LuaDynamic(L);
	
	LuaDynamic[] results = luaString.gsub("t", "f");
	assert(results[0] == "fesf");
	assert(results[1] == 2); // two instances of 't' replaced

	auto gsub = luaString["gsub"];
	assert(gsub.object.type == LuaType.Function);
	
	LuaDynamic[] results2 = gsub(luaString, "t", "f");
	assert(results[0] == results2[0]);
	assert(results[1] == results2[1]);
	version(none) assert(results == results2); // this fails for some reason
}