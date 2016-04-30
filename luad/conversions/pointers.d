/**
Internal module for pushing and getting pointers.
Pointers are stored in metadata with metatables to enfirce type-safety.
A 'deref' property is created to access the pointer's value.
*/
module luad.conversions.pointers;

import luad.conversions.helpers;
import luad.conversions.functions;

import luad.c.all;
import luad.stack;

import core.memory;

import std.traits;
import std.conv;

void pushGetter(T)(lua_State* L)
{
	static if(isUserStruct!(PointerTarget!T))
	{
		static ref PointerTarget!T deref(T ptr)
		{
			return *ptr;
		}
	}
	else
	{
		static PointerTarget!T deref(T ptr)
		{
			return *ptr;
		}
	}

	lua_pushlightuserdata(L, &deref);
	lua_pushcclosure(L, &functionWrapper!(typeof(&deref)), 1);
}

private void pushGetters(T)(lua_State* L)
{
	lua_newtable(L); // -2 is getters
	lua_newtable(L); // -1 is methods

	pushGetter!T(L);
	lua_setfield(L, -3, "deref");

	lua_pushcclosure(L, &index, 2);
}

void pushSetter(T)(lua_State* L)
{
	static if(isUserStruct!(PointerTarget!T))
	{
		static void deref(T ptr, ref PointerTarget!T val)
		{
			*ptr = val;
		}
	}
	else
	{
		static void deref(T ptr, PointerTarget!T val)
		{
			*ptr = val;
		}
	}

	lua_pushlightuserdata(L, &deref);
	lua_pushcclosure(L, &functionWrapper!(typeof(&deref)), 1);
}

private void pushSetters(T)(lua_State* L)
{
	lua_newtable(L);

	pushSetter!T(L);
	lua_setfield(L, -2, "deref");

	lua_pushcclosure(L, &newIndex, 1);
}

private void pushMeta(T)(lua_State* L)
{
	if(luaL_newmetatable(L, T.mangleof.ptr) == 0)
		return;

	pushValue(L, T.stringof);
	lua_setfield(L, -2, "__dtype");

	// TODO: mangled names can get REALLY long in D, it might be nicer to store a hash instead?
	pushValue(L, T.mangleof);
	lua_setfield(L, -2, "__dmangle");

	lua_pushcfunction(L, &userdataCleaner);
	lua_setfield(L, -2, "__gc");

	static if(!is(Unqual!(PointerTarget!T) == void))
	{
		pushGetters!T(L);
		lua_setfield(L, -2, "__index");
		static if(isMutable!(PointerTarget!T))
		{
			pushSetters!T(L);
			lua_setfield(L, -2, "__newindex");
		}
	}

	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__metatable");
}

void pushPointer(T)(lua_State* L, T value) if (isPointer!T)
{
	T* udata = cast(T*)lua_newuserdata(L, T.sizeof);
	*udata = value;

	GC.addRoot(udata);

	pushMeta!T(L);
	lua_setmetatable(L, -2);
}


T getPointer(T)(lua_State* L, int idx) if(isPointer!T)
{
	verifyType!T(L, idx);

	T* udata = cast(T*)lua_touserdata(L, idx);
	return *udata;
}

version(unittest)
{
	import luad.base;
}

unittest
{
	import luad.testing;

	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	luaL_openlibs(L);

}
