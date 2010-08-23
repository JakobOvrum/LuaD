module luad.lfunction;

import luad.base;
import luad.stack;

import luad.c.all;

class LuaFunction : LuaObject
{
	package this(lua_State* L, int idx)
	{
		super(L, idx);
	}
	
	LuaObject[] opCall(U...)(U args)
	{
		return call!(LuaObject[])(args);	
	}
	
	T call(T, U...)(U args)
	{
		push();
		foreach(arg; args)
			pushValue(state, arg);
		
		lua_call(state, args.length, 1);
		
		return popValue!T(state);
	}
}

unittest
{
	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	luaL_openlibs(L);
	
	lua_getglobal(L, "tostring");
	auto tostring = popValue!LuaFunction(L);
	
	//LuaObject[] ret = tostring(123);
	//assert(ret[0].to!string() == "123");
}