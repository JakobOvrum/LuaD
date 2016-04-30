/**
Internal module for pushing and getting class types.
This feature is still a work in progress, currently, only the simplest of _classes are supported.
See the source code for details.
*/
module luad.conversions.classes;

import luad.conversions.helpers;
import luad.conversions.functions;

import luad.c.all;
import luad.stack;
import luad.base;

import core.memory;

import std.traits;
import std.typetuple;
import std.typecons;


private void pushGetters(T)(lua_State* L)
{
	lua_newtable(L); // -2 is getters
	lua_newtable(L); // -1 is methods

	// populate getters
	foreach(member; __traits(derivedMembers, T))
	{
		static if(!skipMember!(T, member) &&
		          !isStaticMember!(T, member) &&
		          member != "Monitor")
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
	foreach(member; __traits(derivedMembers, T))
	{
		static if(!skipMember!(T, member) &&
		          !isStaticMember!(T, member) &&
		          canWrite!(T, member) && // TODO: move into the setter for readonly fields (...and throw a useful error messasge)
		          member != "Monitor")
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

	// TODO: look into why we can't call these on const objects... that's insane, right?
	static if(canCall!(T, "toString"))
	{
		pushMethod!(T, "toString")(L);
		lua_setfield(L, -2, "__tostring");
	}
	static if(canCall!(T, "opEquals"))
	{
		pushMethod!(T, "opEquals")(L);
		lua_setfield(L, -2, "__eq");
	}

	// TODO: handle opCmp here

	// TODO: operators, etc...

	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__metatable");
}

void pushClassInstance(T)(lua_State* L, T obj) if (is(T == class))
{
	Rebindable!T* ud = cast(Rebindable!T*)lua_newuserdata(L, obj.sizeof);
	*ud = obj;

	GC.addRoot(ud);

	pushMeta!T(L);
	lua_setmetatable(L, -2);
}

T getClassInstance(T)(lua_State* L, int idx) if (is(T == class))
{
	//TODO: handle foreign userdata properly (i.e. raise errors)
	verifyType!T(L, idx);

	Object obj = *cast(Object*)lua_touserdata(L, idx);
	return cast(T)obj;
}

template hasCtor(T)
{
	enum hasCtor = __traits(compiles, __traits(getOverloads, T.init, "__ctor"));
}

// For use as __call
void pushCallMetaConstructor(T)(lua_State* L)
{
	static if(!hasCtor!T)
	{
		static T ctor(LuaObject self)
		{
			static if(is(T == class))
				return new T;
			else
				return T.init;
		}
	}
	else
	{
		// TODO: handle each constructor overload in a loop.
		//   TODO: handle each combination of default args
		alias Ctors = typeof(__traits(getOverloads, T.init, "__ctor"));
		alias Args = ParameterTypeTuple!(Ctors[0]);

		static T ctor(LuaObject self, Args args)
		{
			static if(is(T == class))
				return new T(args);
			else
				return T(args);
		}
	}

	pushFunction(L, &ctor);
	lua_setfield(L, -2, "__call");
}

// TODO: Private static fields are mysteriously pushed without error...
// TODO: __index should be a function querying the static fields directly
void pushStaticTypeInterface(T)(lua_State* L) if(is(T == class) || is(T == struct))
{
	lua_newtable(L);

	enum metaName = T.mangleof ~ "_static";
	if(luaL_newmetatable(L, metaName.ptr) == 0)
	{
		lua_setmetatable(L, -2);
		return;
	}

	pushCallMetaConstructor!T(L);

	lua_newtable(L);

	foreach(member; __traits(derivedMembers, T))
	{
		static if(isStaticMember!(T, member))
		{
			enum isFunction = is(typeof(mixin("T." ~ member)) == function);
			static if(isFunction)
				enum isProperty = (functionAttributes!(mixin("T." ~ member)) & FunctionAttribute.property);
			else
				enum isProperty = false;

			// TODO: support static properties
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
