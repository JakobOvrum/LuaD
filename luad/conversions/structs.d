/// Internal module for pushing and getting structs.
module luad.conversions.structs;

import luad.c.all;

import luad.stack;

void pushStruct(T)(lua_State* L, ref T value) if (is(T == struct))
{
	lua_createtable(L, 0, value.tupleof.length);
	
	foreach(field; __traits(allMembers, T))
	{	
		static if(field != "this")
		{
			pushValue(L, field);
		
			enum isMemberFunction = mixin("is(typeof(&value." ~ field ~ ") == delegate)");
			
			static if(isMemberFunction)
				pushValue(L, mixin("&value." ~ field));
			else
				pushValue(L, mixin("value." ~ field));
			
			lua_settable(L, -3);
		}
	}
}

T getStruct(T)(lua_State* L, int idx) if(is(T == struct))
{
	T s;
	fillStruct(L, idx, s);
	return s;
}

void fillStruct(T)(lua_State* L, int idx, ref T s) if(is(T == struct))
{
	foreach(field; __traits(allMembers, T))
	{
		static if(field != "this")
		{
			static if(__traits(getOverloads, T, field).length == 0)
			{
				lua_getfield(L, idx, field.ptr);
				mixin("s." ~ field ~ " = popValue!(typeof(s." ~ field ~ "))(L);");
			}
		}
	}
}

version(unittest) import luad.testing;

unittest
{
	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	luaL_openlibs(L);
	
	struct S
	{
		int i;
		double n;
		string s;
		
		string f(){ return "foobar"; }
	}
	
	pushValue(L, S(1, 2.3, "hello"));
	assert(lua_istable(L, -1));
	lua_setglobal(L, "struct");
	
	unittest_lua(L, `
		for key, expected in pairs{i = 1, n = 2.3, s = "hello"} do 
			local value = struct[key]
			assert(value == expected, 
				("bad table pair: '%s' = '%s' (expected '%s')"):format(key, value, expected)
			)
		end
		
		assert(struct.f() == "foobar")
	`);
	
	lua_getglobal(L, "struct");
	S s = getStruct!S(L, -1);
	
	assert(s.i == 1);
	assert(s.n == 2.3);
	assert(s.s == "hello");
	
	lua_pop(L, 1);
}