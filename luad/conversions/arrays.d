/** 
Internal module for pushing and getting _arrays.
All _arrays with LuaD compatible element types are supported.
*/
module luad.conversions.arrays;

import std.traits;

import luad.c.all;
import luad.stack;

void pushArray(T)(lua_State* L, T arr) if (isArray!T)
{
	assert(arr.length <= int.max, "lua_createtable only supports int.max many elements");
	lua_createtable(L, cast(int) arr.length, 0);
	foreach(i, v; arr)
	{
		pushValue(L, i + 1); //Lua tables start at 1, not 0
		pushValue(L, v);
		lua_rawset(L, -3);
	}
}

T getArray(T)(lua_State* L, int idx) if (isArray!T)
{
	alias typeof(T[0]) ElemType;
	auto len = lua_objlen(L, idx);
	
	auto arr = new ElemType[len];
	foreach(i; 0 .. len)
	{
		lua_pushinteger(L, i + 1);
		lua_gettable(L, idx < 0? idx - 1 : idx);
		arr[i] = popValue!ElemType(L);
	}
	
	return arr;
}

version(unittest) import luad.testing;

unittest
{
	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	luaL_openlibs(L);
	
	{
		int[] arr = [1, 2, 3];
		pushValue(L, arr);
		assert(lua_istable(L, -1));
		lua_setglobal(L, "array");
		
		unittest_lua(L, `
			for i, expected in pairs{1, 2, 3} do
				local value = array[i]
				assert(value == expected, 
					("bad array index: '%s' = '%s' (expected '%s')"):format(i, value, expected)
				)
			end
		`);
	}
	
	{
		unittest_lua(L, `array = {"hello", "from", "lua"}`);
		
		lua_getglobal(L, "array");
		string[] arr = popValue!(string[])(L);
		assert(arr[0] == "hello");
		assert(arr[1] == "from");
		assert(arr[2] == "lua");
	}
}
