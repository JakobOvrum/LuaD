module luad.conversions.structs;

import luad.c.all;

import luad.stack;

void pushStruct(T)(lua_State* L, ref T value) if (is(T == struct))
{
	lua_createtable(L, 0, value.tupleof.length);
	
	foreach(field; __traits(allMembers, T))
	{	
		static if(field != "this") //God damn __traits documentation
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
		//Damn __traits documentation...
		//if not the constructor (_ctor? Where are you?) and not a member function
		static if(field != "this" && !mixin("is(typeof(&s." ~ field ~ ") == delegate)"))
		{
			lua_getfield(L, idx, field.ptr);
			mixin("s." ~ field ~ " = popValue!(typeof(s." ~ field ~ "))(L);");
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
		
		void f(){}
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
	`);
}