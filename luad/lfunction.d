module luad.lfunction;

import luad.base;
import luad.stack;

import luad.c.all;

/// Represents a Lua function.
struct LuaFunction
{
	LuaObject object;
	alias object this;
	
	// WORKAROUND: bug #6036
	package static LuaFunction make(lua_State* L, int idx)
	{
		LuaObject.checkType(L, idx, LUA_TFUNCTION, "LuaFunction");
		LuaFunction f;
		f.object = LuaObject(L, idx);
		return f;
	}
	
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
	// TODO: why doesn't this work? see unittest
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
	 *	 As a special case, a value of LuaObject[] for T will result
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
		this.push();
		foreach(arg; args)
			pushValue(this.state, arg);
		
		enum hasReturnValue = !is(T == void);
		enum multiRet = is(T == LuaObject[]);
		
		lua_call(this.state, args.length, hasReturnValue? (multiRet? LUA_MULTRET : 1) : 0);
		
		static if(hasReturnValue)
		{
			static if(multiRet)
				return getStack(this.state);
			else
				return popValue!T(this.state);
		}
	}
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
}