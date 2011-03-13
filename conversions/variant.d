module luad.conversions.variant;

import luad.c.all;

import luad.stack;

import std.traits;
import std.variant;

void pushVariant(T)(lua_State* L, ref T value) if (isVariant!T)
{
	foreach(Type; value.AllowedTypes)
    {
		if(value.peek!Type)
			pushValue(L, value.get!Type);
    }
}

T getVariant(T)(lua_State* L, int idx) if(isVariant!T)
{
	Variant v;
	foreach(Type; value.AllowedTypes)
    {
		static if(isSomeFunction!Type)
			if(lua_iscfunction(L, idx))
				v = getValue!Type(L, idx);

		else static if(is(Type == struct))
			if(lua_istable(L, idx))
				v = getValue!Type(L, idx);

		else static if(is(Type == class))
			if(lua_istable(L, idx))
				v = getValue!Type(L, idx);

		else static if(is(Type == bool))
			if(lua_isboolean(L, idx))
				v = getValue!Type(L, idx);

		else static if(isAssociativeArray!Type)
			if(lua_istable(L, idx))
				v = getValue!Type(L, idx);

		else static if(isArray!Type)
			if(lua_istable(L, idx))
				v = getValue!Type(L, idx);

		else static if(isNumeric!Type)
			if(lua_isnumber(L, idx))
				v = getValue!Type(L, idx);

		else static if(isSomeString!Type)
			if(lua_isstring(L, idx))
				v = getValue!Type(L, idx);

		return v;
    }
}


template isVariant(T)
{
    enum isAlgebraic = hasMember!(T,"AllowedTypes");
}


unittest
{
//	lua_State* L = luaL_newstate();
//	scope(success) lua_close(L);
//	luaL_openlibs(L);
//
//	struct S
//	{
//		int i;
//		double n;
//		string s;
//		
//		void f(){}
//	}
//	pushValue(L, Algebraic!(S,int)(S(1, 2.3, "hello")));
//	assert(lua_istable(L, -1));
//	lua_setglobal(L, "struct");
//	
//	unittest_lua(L, `
//		for key, expected in pairs{i = 1, n = 2.3, s = "hello"} do 
//			local value = struct[key]
//			assert(value == expected, 
//				("bad table pair: '%s' = '%s' (expected '%s')"):format(key, value, expected)
//			)
//		end
//	`, __FILE__);
//	
}

