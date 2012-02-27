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
	LuaDynamic[] opDispatch(string name, string file = __FILE__, uint line = __LINE__, Args...)(Args args)
	{
		// Push self
		object.push();

		auto frame = lua_gettop(object.state);
		
		// push name and self[name]
		lua_pushlstring(object.state, name.ptr, name.length);
		lua_gettable(object.state, -2);

		// TODO: How do I properly generalize this to include other types,
		// while not stepping on the __call metamethod?
		if(lua_isnil(object.state, -1))
		{
			lua_pop(object.state, 2);
			luaL_error(object.state, "%s:%d: attempt to call method '%s' (a nil value)", file.ptr, line, name.ptr);
		}

		// Copy 'this' to the top of the stack
		lua_pushvalue(object.state, -2);
		
		foreach(arg; args)
			pushValue(object.state, arg);

		lua_call(object.state, args.length + 1, LUA_MULTRET);

		auto nret = lua_gettop(object.state) - frame;

		auto ret = popStack!LuaDynamic(object.state, nret);
		
		// Pop self
		lua_pop(object.state, 1);

		return ret;
	}
	
	LuaDynamic[] opCall(Args...)(Args args)
	{
		auto frame = lua_gettop(object.state);

		object.push(); // Callable
		foreach(arg; args)
			pushValue(object.state, arg);
		
		lua_call(object.state, args.length, LUA_MULTRET);

		auto nret = lua_gettop(object.state) - frame;
		
		return popStack!LuaDynamic(object.state, nret);
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
	assert(results == results2);
}