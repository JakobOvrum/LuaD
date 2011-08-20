/**
Internal module for pushing and getting _structs.

A struct is treated as a table layout schema.
Pushing a struct to Lua will create a table and fill it with key-value pairs - corresponding to struct fields - from the struct; the field name becomes the table key as a string.
Struct methods are treated as if they were delegate fields pointing to the method.
For an example, see the "Configuration File" example on the $(LINK2 $(GHROOT),front page).
*/
module luad.conversions.structs;

import luad.c.all;

import luad.stack;

private template isInternal(string field)
{
	enum isInternal = field.length >= 2 && field[0..2] == "__";
}

//TODO: ignore static fields, post-blits, destructors, etc?
void pushStruct(T)(lua_State* L, ref T value) if (is(T == struct))
{
	lua_createtable(L, 0, value.tupleof.length);
	
	foreach(field; __traits(allMembers, T))
	{
		static if(!isInternal!(field) &&
		          field != "this" &&
		          field != "opAssign")
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
		static if(field != "this" && !isInternal!(field))
		{
			static if(__traits(getOverloads, T, field).length == 0)
			{
				lua_getfield(L, idx, field.ptr);
				mixin("s." ~ field ~ " = popValue!(typeof(s." ~ field ~ "))(L);");
			}
		}
	}
}

version(unittest)
{
	import luad.testing;
	import luad.base;
}

unittest
{
	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	luaL_openlibs(L);
	
	struct S
	{
		LuaObject o;
		int i;
		double n;
		string s;
		
		string f(){ return "foobar"; }
	}
	
	pushValue(L, "test");
	auto obj = popValue!LuaObject(L);
	
	pushValue(L, S(obj, 1, 2.3, "hello"));
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
	
	assert(s.o.equals(obj));
	assert(s.i == 1);
	assert(s.n == 2.3);
	assert(s.s == "hello");
	
	lua_pop(L, 1);
}