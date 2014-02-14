/**
Internal module for pushing and getting class types.
This feature is still a work in progress, currently, only the simplest of _classes are supported.
See the source code for details.
*/
module luad.conversions.classes;

import luad.conversions.functions;

import luad.c.all;
import luad.stack;
import luad.base;

import core.memory;

import std.traits;
import std.string : toStringz;

extern(C) private int classCleaner(lua_State* L)
{
	GC.removeRoot(lua_touserdata(L, 1));
	return 0;
}

private void pushMeta(T)(lua_State* L, T obj)
{
	if(luaL_newmetatable(L, T.mangleof.ptr) == 0)
		return;

	pushValue(L, T.stringof);
	lua_setfield(L, -2, "__dclass");

	pushValue(L, T.mangleof);
	lua_setfield(L, -2, "__dmangle");

	lua_newtable(L); //__index fallback table

	foreach(member; __traits(derivedMembers, T))
	{
		static if(__traits(getProtection, __traits(getMember, T, member)) == "public" && //ignore non-public fields
			member != "this" && member != "__ctor" && //do not handle
			member != "Monitor" && member != "toHash" && //do not handle
			member != "toString" && member != "opEquals" && //handle below
			member != "opCmp") //handle below
		{
			static if(__traits(getOverloads, T.init, member).length > 0 && !__traits(isStaticFunction, mixin("T." ~ member)))
			{
				pushMethod!(T, member)(L);
				lua_setfield(L, -2, toStringz(member));
			}
		}
	}

	lua_setfield(L, -2, "__index");

	pushMethod!(T, "toString")(L);
	lua_setfield(L, -2, "__tostring");

	pushMethod!(T, "opEquals")(L);
	lua_setfield(L, -2, "__eq");

	//TODO: handle opCmp here


	lua_pushcfunction(L, &classCleaner);
	lua_setfield(L, -2, "__gc");

	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__metatable");
}

void pushClassInstance(T)(lua_State* L, T obj) if (is(T == class))
{
	T* ud = cast(T*)lua_newuserdata(L, obj.sizeof);
	*ud = obj;

	pushMeta(L, obj);
	lua_setmetatable(L, -2);

	GC.addRoot(ud);
}

//TODO: handle foreign userdata properly (i.e. raise errors)
T getClassInstance(T)(lua_State* L, int idx) if (is(T == class))
{
	if(lua_getmetatable(L, idx) == 0)
	{
		luaL_error(L, "attempt to get 'userdata: %p' as a D object", lua_topointer(L, idx));
	}

	lua_getfield(L, -1, "__dmangle"); //must be a D object

	static if(!is(T == Object)) //must be the right object
	{
		size_t manglelen;
		auto cmangle = lua_tolstring(L, -1, &manglelen);
		if(cmangle[0 .. manglelen] != T.mangleof)
		{
			lua_getfield(L, -2, "__dclass");
			auto cname = lua_tostring(L, -1);
			luaL_error(L, `attempt to get instance %s as type "%s"`, cname, toStringz(T.stringof));
		}
	}
	lua_pop(L, 2); //metatable and metatable.__dmangle

	Object obj = *cast(Object*)lua_touserdata(L, idx);
	return cast(T)obj;
}

template hasCtor(T)
{
	enum hasCtor = __traits(compiles, __traits(getOverloads, T.init, "__ctor"));
}

// TODO: exclude private members (I smell DMD bugs...)
template isStaticMember(T, string member)
{
	static if(__traits(compiles, mixin("&T." ~ member)))
	{
		static if(is(typeof(mixin("&T.init." ~ member)) == delegate))
			enum isStaticMember = __traits(isStaticFunction, mixin("T." ~ member));
		else
			enum isStaticMember = true;
	}
	else
		enum isStaticMember = false;
}

// For use as __call
void pushCallMetaConstructor(T)(lua_State* L)
{
	alias typeof(__traits(getOverloads, T.init, "__ctor")) Ctor;

	static T ctor(LuaObject self, ParameterTypeTuple!Ctor args)
	{
		return new T(args);
	}

	pushFunction(L, &ctor);
}

// TODO: Private static fields are mysteriously pushed without error...
// TODO: __index should be a function querying the static fields directly
void pushStaticTypeInterface(T)(lua_State* L)
{
	lua_newtable(L);

	enum metaName = T.mangleof ~ "_static";
	if(luaL_newmetatable(L, metaName.ptr) == 0)
	{
		lua_setmetatable(L, -2);
		return;
	}

	static if(hasCtor!T)
	{
		pushCallMetaConstructor!T(L);
		lua_setfield(L, -2, "__call");
	}

	lua_newtable(L);

	foreach(member; __traits(derivedMembers, T))
	{
		static if(isStaticMember!(T, member))
		{
			enum isFunction = is(typeof(mixin("T." ~ member)) == function);

			static if(isFunction)
				pushValue(L, mixin("&T." ~ member));
			else
				pushValue(L, mixin("T." ~ member));

			lua_setfield(L, -2, member.ptr);
		}
	}

	lua_setfield(L, -2, "__index");

	lua_setmetatable(L, -2);
}

version(unittest)
{
	import luad.testing;
	private lua_State* L;
}

unittest
{
	L = luaL_newstate();

	static class A
	{
		private:
		string s;

		public:
		int n;

		this(int n, string s)
		{
			this.n = n;
			this.s = s;
		}

		string foo(){ return s; }

		int bar(int i)
		{
			return n += i;
		}

		void verifyN(int n)
		{
			assert(this.n == n);
		}
	}

	static class B : A
	{
		this(int a, string s)
		{
			super(a, s);
		}

		override string foo() { return "B"; }

		override string toString() { return "B"; }
	}

	void addA(in char* name, A a)
	{
		pushValue(L, a);
		lua_setglobal(L, name);
	}

	auto a = new A(2, "foo");
	addA("a", a);

	pushValue(L, a.toString());
	lua_setglobal(L, "a_toString");

	auto b = new B(2, "foo");
	addA("b", b);
	addA("otherb", b);

	pushValue(L, (A a)
	{
		assert(a);
		a.bar(2);
	});
	lua_setglobal(L, "func");

	luaL_openlibs(L);
	unittest_lua(L, `
		--assert(a.n == 2)
		assert(a:bar(2) == 4)
		--assert(a.n == 4)
		func(a)
		assert(a:bar(2) == 8)

		--a.n = 42
		--a:verifyN(42)
		--assert(a.n == 42)

		assert(a:foo() == "foo")
		assert(tostring(a) == a_toString)

		assert(b:bar(2) == 4)
		func(b)
		assert(b:bar(2) == 8)

		assert(b:foo() == "B")
		assert(tostring(b) == "B")

		assert(a ~= b)
		assert(b == otherb)
	`);

	pushValue(L, cast(B)null);
	lua_setglobal(L, "c");
	unittest_lua(L, `assert(c == nil)`);

	pushValue(L, (B b) => assert(b is null));
	lua_setglobal(L, "checkNull");
	unittest_lua(L, `checkNull(nil)`);
}
