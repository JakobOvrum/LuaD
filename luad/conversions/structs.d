/**
Internal module for pushing and getting structs.
Structs are handled by-value across the LuaD API boundary, but internally managed by reference, with semantics equivalent to tables.
Fields and properties are handled via a thin shim implemented in __index/__newindex. Methods are registered directly.
mutable, const and immutable are all supported as expected. immutable structs will capture a direct reference to the D instance, and not be duplicated by LuaD.
For an example, see the "Configuration File" example on the $(LINK2 $(REFERENCETOP),front page).
*/
module luad.conversions.structs;

import luad.conversions.helpers;
import luad.conversions.functions;

import luad.c.all;
import luad.stack;

import core.memory;

import std.traits;
import std.conv;


private void pushGetters(T)(lua_State* L)
{
	lua_newtable(L); // -2 is getters
	lua_newtable(L); // -1 is methods

	// populate getters
	foreach(member; __traits(allMembers, T))
	{
		static if(!skipMember!(T, member) &&
		          !isStaticMember!(T, member))
		{
			static if(isMemberFunction!(T, member) && !isProperty!(T, member))
			{
				static if(canCall!(T, member))
				{
					pushMethod!(T, member)(L);
					lua_setfield(L, -2, member.ptr);
				}
			}
			else static if(canRead!(T, member)) // TODO: move into the getter for inaccessable fields (...and throw a useful error messasge)
			{
				pushGetter!(T, member)(L);
				lua_setfield(L, -3, member.ptr);
			}
		}
	}

	lua_pushcclosure(L, &index, 2);
}

private void pushSetters(T)(lua_State* L)
{
	lua_newtable(L);

	// populate setters
	foreach(member; __traits(allMembers, T))
	{
		static if(!skipMember!(T, member) &&
		          !isStaticMember!(T, member) &&
		          canWrite!(T, member)) // TODO: move into the setter for readonly fields
		{
			static if(!isMemberFunction!(T, member) || isProperty!(T, member))
			{
				pushSetter!(T, member)(L);
				lua_setfield(L, -2, member.ptr);
			}
		}
	}

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

	pushGetters!T(L);
	lua_setfield(L, -2, "__index");
	pushSetters!T(L);
	lua_setfield(L, -2, "__newindex");

	static if(__traits(hasMember, T, "toString"))
	{
		pushMethod!(T, "toString")(L);
		lua_setfield(L, -2, "__tostring");
	}

	static if(__traits(hasMember, T, "opEquals"))
	{
		pushMethod!(T, "opEquals")(L);
		lua_setfield(L, -2, "__eq");
	}
	// TODO: __lt,__le (wrap opCmp)

	// TODO: operators, etc...

	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__metatable");
}

void pushStruct(T)(lua_State* L, ref T value) if (is(T == struct))
{
	// if T is immutable, we can capture a reference, otherwise we need to take a copy
	static if(is(T == immutable)) // TODO: verify that this is actually okay?
	{
		auto udata = cast(Ref!T*)lua_newuserdata(L, Ref!T.sizeof);
		*udata = Ref!T(value);
	}
	else
	{
		Ref!T* udata = cast(Ref!T*)lua_newuserdata(L, Ref!T.sizeof);
		// TODO: we should try and call the postblit here maybe...?
//		T* copy = new T(value);
//		T* copy = std.conv.emplace(cast(T*)GC.malloc(T.sizeof), value);
		Unqual!T* copy = cast(Unqual!T*)GC.malloc(T.sizeof);
		*copy = value;
		*udata = Ref!T(*copy);
	}

	GC.addRoot(udata);

	pushMeta!T(L);
	lua_setmetatable(L, -2);
}

void pushStruct(R : Ref!T, T)(lua_State* L, R value) if (is(T == struct))
{
	auto udata = cast(Ref!T*)lua_newuserdata(L, Ref!T.sizeof);
	*udata = Ref!T(value);

	GC.addRoot(udata);

	pushMeta!T(L);
	lua_setmetatable(L, -2);
}

ref T getStruct(T)(lua_State* L, int idx) if(is(T == struct))
{
	verifyType!T(L, idx);

	Ref!T* udata = cast(Ref!T*)lua_touserdata(L, idx);
	return *udata;
}

version(unittest)
{
	import luad.base;
	struct S
	{
		LuaObject o;
		int i;
		double n;
		string s;

		string f(){ return "foobar"; }
	}
}

unittest
{
	import luad.testing;

	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	luaL_openlibs(L);

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

	assert(s.o == obj);
	assert(s.i == 1);
	assert(s.n == 2.3);
	assert(s.s == "hello");

	lua_pop(L, 1);

	struct S2
	{
		string a, b;
	}

	unittest_lua(L, `
		incompleteStruct = {a = "foo"}
	`);

	lua_getglobal(L, "incompleteStruct");
	S2 s2 = getStruct!S2(L, -1);

	assert(s2.a == "foo");
	assert(s2.b == null);

	lua_pop(L, 1);
}
