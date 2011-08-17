/**
Internal module for pushing and getting associative arrays.
All associative arrays with LuaD compatible key and value types are supported.
For tables with heterogeneous key or value types, use $(LINKSUBMODULE2 conversions,variant,Algebraic) keys/values or $(LINKMODULE2 table,LuaTable).
For string keys and heterogeneous value types, consider using a $(LINKSUBMODULE2 conversions,structs,struct).
*/
module luad.conversions.assocarrays;

import luad.c.all;
import std.traits;
import luad.stack;

void pushAssocArray(T, U)(lua_State* L, T[U] aa)
{
	assert(aa.length <= int.max, "lua_createtable only supports int.max many elements");
	lua_createtable(L, 0, cast(int) aa.length);
	foreach(key, value; aa)
	{
		pushValue(L, key);
		pushValue(L, value);
		lua_rawset(L, -3);
	}
}

T getAssocArray(T)(lua_State* L, int idx) if (isAssociativeArray!T)
{
	T aa;
	alias typeof(aa.values[0]) ElemType;
	alias typeof(aa.keys[0]) KeyType;
	
	lua_pushnil(L);
	while(lua_next(L, idx < 0? idx - 1 : idx) != 0)
	{
		aa[getValue!KeyType(L, -2)] = getValue!ElemType(L, -1);
		lua_pop(L, 1);
	}
	
	return aa;
}

version(unittest) import luad.testing;

unittest
{
	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	luaL_openlibs(L);
	
	pushValue(L, ["foo": "bar", "hello": "world"]);
	lua_setglobal(L, "aa");
	
	unittest_lua(L, `
		assert(aa.foo == "bar")
		assert(aa.hello == "world")
			
		aa = {one = 1, two = 2}
	`);
	
	lua_getglobal(L, "aa");
	auto aa = popValue!(uint[string])(L);
	assert(aa["one"] == 1);
	assert(aa["two"] == 2);
}
