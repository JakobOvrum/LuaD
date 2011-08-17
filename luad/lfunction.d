module luad.lfunction;

import luad.base;
import luad.table;
import luad.stack;

import luad.c.all;

/// Represents a Lua function.
struct LuaFunction
{
	/// LuaTable sub-types LuaObject through this reference.
	LuaObject object;
	alias object this;
	
	version(none) package this(lua_State* L, int idx)
	{
		LuaObject.checkType(L, idx, LUA_TFUNCTION, "LuaFunction");
		object = LuaObject(L, idx);
	}
	
	/**
	 * Same as call!(LuaObject[])(args);
	 * Examples:
	 -----------------------
	lua.doString(`function f(...) return ... end`);
	auto f = lua.get!LuaFunction("f");
	
	LuaObject[] ret = f(1.2, "hello!", true);
	
	assert(ret[0].to!double() == 1.2);
	assert(ret[1].to!string() == "hello!");
	assert(ret[2].to!bool());
	 -----------------------
	 */
	LuaObject[] opCall(U...)(U args)
	{
		return call!(LuaObject[])(args);
	}
	
	/**
	 * Call this function.
	 * Params:
	 *	 T = expected return type.
	 *	 args = list of arguments.
	 * Returns:
	 *	 Return value of type T, or nothing if T was unspecified.
	 *   For multiple return values, use a Tuple (from std.typecons).
	 *	 Additionally, a value of LuaObject[] for T will result
	 *	 all return values being collected and returned in a LuaObject[].
	 * Examples:
	 * ------------------
	lua.doString(`function ask(question) return 42 end`);
	auto ask = lua.get!LuaFunction("ask");
	
	auto answer = ask.call!int("What's the answer to life, the universe and everything?");
	assert(answer == 42);
	 * ------------------
	 */
	T call(T = void, U...)(U args)
	{
		assert(lua_gettop(this.state) == 0); // this function assumes empty stack
		
		this.push();
		foreach(arg; args)
			pushValue(this.state, arg);

		lua_call(this.state, args.length, returnTypeSize!T);
		
		return popReturnValues!T(this.state);
	}
	
	/**
	 * Set a new environment for this function.
	 *
	 * The environment of a function is the table used for looking up non-local (global) variables.
	 * Params:
	 *    env = new environment
	 * Examples:
	 * -------------------
	 * lua["foo"] = "bar";
	 * auto func = lua.loadString(`return foo`);
	 * assert(func.call!string() == "bar");
	 *
	 * auto env = lua.wrap(["foo": "test"]);
	 * func.setEnvironment(env);
	 * assert(func.call!string() == "test");
	 * -------------------
	 */
	void setEnvironment(ref LuaTable env)
	in { assert(this.state == env.state); }
	body
	{
		this.push();
		env.push();
		lua_setfenv(this.state, -2);
		lua_pop(this.state, 1);
	}
}

version(unittest)
{
	import std.variant;
	import std.typecons;
}

unittest
{
	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	luaL_openlibs(L);
	
	lua_getglobal(L, "tostring");
	auto tostring = popValue!LuaFunction(L);
	
	LuaObject[] ret = tostring(123);
	assert(ret[0].to!string() == "123");

	assert(tostring.call!string(123) == "123");
	
	tostring.call(321);
	
	// Multiple return values
	luaL_dostring(L, "function singleRet() return 42 end");
	lua_getglobal(L, "singleRet");
	auto singleRet = popValue!LuaFunction(L);
	
	auto singleRetResult = singleRet.call!(Tuple!int)();
	assert(singleRetResult[0] == 42);
	
	alias Algebraic!(string, double) BasicLuaType;
	BasicLuaType a = "foo";
	BasicLuaType b = 1.5;
	
	pushValue(L, [a, b]);
	lua_setglobal(L, "test");
	
	luaL_dostring(L, "function multRet() return unpack(test) end");
	lua_getglobal(L, "multRet");
	auto multRet = popValue!LuaFunction(L);

	auto result = multRet.call!(Tuple!(string, double))();
	assert(result[0] == a);
	assert(result[1] == b);
	
	// setEnvironment
	pushValue(L, ["test": [42]]);
	auto env = popValue!LuaTable(L);
	
	lua_getglobal(L, "unpack");
	env["unpack"] = popValue!LuaObject(L);
	
	multRet.setEnvironment(env);
	assert(multRet.call!int() == 42);
}