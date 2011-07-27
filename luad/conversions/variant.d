module luad.conversions.variant;

import luad.c.all;

import luad.stack;
import luad.base;
import std.traits;
import std.variant;
import std.typetuple;

void pushVariant(T)(lua_State* L, ref T value) if(isVariant!T)
{
	foreach(Type; value.AllowedTypes)
	{
		if(auto v = value.peek!Type)
		{
			pushValue(L, *v);
			return;
		}
	}
}

T getVariant(T)(lua_State* L, int idx) if (isVariant!T)
{
	auto t = lua_type(L, idx);
	
	foreach(Type; T.AllowedTypes)
		if(t == luaTypeOf!Type)
			return getValue!Type(L, idx);

	assert(false);
}

bool isAllowedType(T)(lua_State* L, int idx) {
	auto t = lua_type(L, idx);
	
	foreach(Type; T.AllowedTypes)
		if(t == luaTypeOf!Type)
			return true;

	return false;
}

template isVariant(T : T!(size_t, Types), Types...)
{
	enum isVariant = is(T == VariantN);
}

template isVariant(T)
{
	enum isVariant = false;
}


unittest
{
	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	luaL_openlibs(L);
	
	Variant v = 123;
	pushValue(L, v);
	assert(popValue!int == 123);

	struct S
	{
		int i;
		double n;
		string s;
		
		void f(){}
	}
	pushValue(L, Algebraic!(S,int)(S(1, 2.3, "hello")));
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

