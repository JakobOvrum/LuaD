module luad.conversions.variant;

import luad.c.all;

import luad.stack;
import luad.base;
import std.traits;
import std.variant;

void pushVariant(T)(lua_State* L, ref T value) if (isVariant!T)
{
	foreach(Type; value.AllowedTypes)
		if(value.peek!Type)
			pushValue(L, value.get!Type);
}

T getVariant(T)(lua_State* L, int idx) if (isVariant!T)
{
	T v;
	foreach(Type; T.AllowedTypes)
		if(isStackNativeType!Type(L, idx))
			v = getValue!Type(L, idx);

	return v;
}

bool isAllowedType(T)(lua_State* L, int idx) {
	foreach(Type; T.AllowedTypes)
		if(isStackNativeType!Type(L, idx))
			return true;

	return false;
}


bool isStackNativeType(T)(lua_State* L, int idx) {
	auto luaT = lua_type(L, idx);
	
	if(lua_iscfunction(L, idx))
		return isSomeFunction!T;

	if(luaT == LuaType.Function)
		return isSomeFunction!T;

	if(luaT == LuaType.Table)
		static if(is(T == class) || is(T == struct))
			return true;

		else static if(isVariant!T)
			return true;

		else static if(isAssociativeArray!T)
			return true;

		else static if(isArray!T)
			return true;

	if(luaT == LuaType.Boolean)
		return is(T == bool);

	if(luaT == LuaType.Number)
		return isNumeric!T;

	if(luaT == LuaType.String)
		return isSomeString!T;

	return false;
}

template isVariant(T)
{
	enum isVariant = hasMember!(T,"AllowedTypes");
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
//	("bad table pair: '%s' = '%s' (expected '%s')"):format(key, value, expected)
//			)
//		end
//	`, __FILE__);
//	
}

