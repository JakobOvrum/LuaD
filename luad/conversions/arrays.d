/**
Internal module for pushing and getting _arrays.
All _arrays with LuaD compatible element types are supported.
*/
module luad.conversions.arrays;

import std.traits;
import std.range : ElementType;

import luad.c.all;
import luad.stack;

void pushArray(T)(lua_State* L, ref T arr) if (isArray!T)
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

// TODO: do the immutable/const initialization *properly*
T getArray(T)(lua_State* L, int idx) if (isArray!T)
{
	alias ElemType = ElementType!T;
	auto len = lua_objlen(L, idx);

	static if(isStaticArray!T)
	{
		if(len != T.length)
			luaL_error(L, "Incorrect number of array elements: %d, expected: %d", len, T.length);

		Unqual!ElemType[T.length] arr;
	}
	else
		auto arr = new Unqual!ElemType[len];

	foreach(i; 0 .. len)
	{
		lua_pushinteger(L, i + 1);
		lua_gettable(L, idx < 0? idx - 1 : idx);
		arr[i] = popValue!ElemType(L);
	}

	return cast(T)arr;
}

void fillStaticArray(T)(lua_State* L, ref T arr) if(isStaticArray!T)
{
	foreach(i, ref elem; arr)
	{
		elem = getValue!(typeof(elem))(L, cast(int)(-arr.length + i));
	}
}

void pushStaticArray(T)(lua_State* L, ref T arr) if(isStaticArray!T)
{
	foreach(elem; arr)
		pushValue(L, elem);
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
