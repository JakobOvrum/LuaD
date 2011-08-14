/**
Internal module for pushing and getting variants (from std._variant).
Currently, only Algebraic is supported.
*/
module luad.conversions.variant;

import luad.c.all;

import luad.stack;
import luad.base;
import std.traits;
import std.variant;
import std.typetuple;

void pushVariant(T)(lua_State* L, ref T value) if(isVariant!T)
{
	if(!value.hasValue())
	{
		lua_pushnil(L);
		return;
	}

	foreach(Type; value.AllowedTypes)
	{
		if(auto v = value.peek!Type)
		{
			pushValue(L, *v);
			return;
		}
	}
	
	assert(false);
}

T getVariant(T)(lua_State* L, int idx) if (isVariant!T)
{
	auto t = lua_type(L, idx);
	
	foreach(Type; T.AllowedTypes)
		if(t == luaTypeOf!Type)
			return T(getValue!Type(L, idx));

	assert(false); // TODO: runtime error
}

bool isAllowedType(T)(lua_State* L, int idx) {
	auto t = lua_type(L, idx);
	
	foreach(Type; T.AllowedTypes)
		if(t == luaTypeOf!Type)
			return true;

	return false;
}

// Urgh...
template isVariant(T)
{
	enum isVariant = is(typeof(isVariantImpl(T.init)));
}

private void isVariantImpl(size_t max, AllowedTypes...)(VariantN!(max, AllowedTypes) v){}

version(unittest) import luad.testing;

unittest
{
	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	luaL_openlibs(L);
	
	version(none)
	{
		Variant v = 123;
		pushValue(L, v);
		assert(popValue!int(L) == 123);
	}
	
	alias Algebraic!(real, string, bool) BasicLuaType;
	
	BasicLuaType v = "test";
	pushValue(L, v);
	assert(lua_isstring(L, -1));
	assert(getValue!string(L, -1) == "test");
	assert(popValue!BasicLuaType(L) == "test");
	
	v = 2.3L;
	pushValue(L, v);
	assert(lua_isnumber(L, -1));
	lua_setglobal(L, "num");
	
	unittest_lua(L, `
		assert(num == 2.3)
	`);
	
	v = true;
	pushValue(L, v);
	assert(lua_isboolean(L, -1));
	assert(popValue!bool(L));
	
	struct S
	{
		int i;
		double n;
		string s;
		
		void f(){}
	}
	pushValue(L, Algebraic!(S, int)(S(1, 2.3, "hello")));
	assert(lua_istable(L, -1));
	lua_setglobal(L, "struct");
	
	unittest_lua(L, `
		for key, expected in pairs{i = 1, n = 2.3, s = "hello"} do 
			local value = struct[key]
			assert(value == expected, 
	("bad table pair: '%s' = '%s' (expected '%s')"):format(key, value, expected)
			)
		end
	`);
}

