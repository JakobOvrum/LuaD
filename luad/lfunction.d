module luad.lfunction;

import luad.base;
import luad.table;
import luad.stack;
import luad.conversions.functions;

import luad.c.all;

/// Represents a Lua function.
struct LuaFunction
{
	/// LuaFunction sub-types $(DPREF base, LuaObject) through this reference.
	LuaObject object;
	alias object this;

	version(none) package this(lua_State* L, int idx)
	{
		LuaObject.checkType(L, idx, LUA_TFUNCTION, "LuaFunction");
		object = LuaObject(L, idx);
	}

	/**
	 * Call this function and collect all return values as
	 * an array of $(DPREF base, LuaObject) references.
	 * Examples:
	 -----------------------
	lua.doString(`function f(...) return ... end`);
	auto f = lua.get!LuaFunction("f");

	LuaObject[] ret = f(1.2, "hello!", true);

	assert(ret[0].to!double() == 1.2);
	assert(ret[1].to!string() == "hello!");
	assert(ret[2].to!bool());
	 -----------------------
	 */
	LuaObject[] opCall(U...)(U args)
	{
		return call!(LuaVariableReturn!(LuaObject[]))(args).returnValues;
	}

	/**
	 * Call this function.
	 * Params:
	 *	 T = expected return type.
	 *	 args = list of arguments.
	 * Returns:
	 *	 Return value of type $(D T), or nothing if $(D T) was unspecified.
	 *   See $(DPMODULE2 conversions,functions) for how to
	 *   catch multiple return values.
	 * Examples:
	 * ------------------
	lua.doString(`function ask(question) return 42 end`);
	auto ask = lua.get!LuaFunction("ask");

	auto answer = ask.call!int("What's the answer to life, the universe and everything?");
	assert(answer == 42);
	 * ------------------
	 */
	T call(T = void, U...)(U args)
	{
		this.push();
		foreach(arg; args)
			pushValue(this.state, arg);

		return callWithRet!T(this.state, args.length);
	}

	/**
	 * Set a new environment for this function.
	 *
	 * The environment of a function is the table used for looking up non-local (global) variables.
	 * Params:
	 *    env = new environment
	 * Examples:
	 * -------------------
	 * lua["foo"] = "bar";
	 * auto func = lua.loadString(`return foo`);
	 * assert(func.call!string() == "bar");
	 *
	 * auto env = lua.wrap(["foo": "test"]);
	 * func.setEnvironment(env);
	 * assert(func.call!string() == "test");
	 * -------------------
	 */
	void setEnvironment(ref LuaTable env)
	in { assert(this.state == env.state); }
	do
	{
		this.push();
		env.push();
		lua_setfenv(this.state, -2);
		lua_pop(this.state, 1);
	}

	/**
	 * Dump this function as a binary chunk of Lua bytecode to the specified
	 * writer delegate.  Multiple chunks may be produced to dump a single
	 * function.
	 *
	 * Params:
	 *    writer = delegate to forward writing calls to
	 *
	 *  If the delegate returns $(D false) for any of the chunks,
	 *  the _dump process ends, and the writer won't be called again.
	 */
	bool dump(scope bool delegate(in void[]) writer)
	{
		alias typeof(writer) LuaWriter;

		extern(C) static int luaCWriter(lua_State* L, const void* p, size_t sz, void* ud)
		{
			auto writer = *cast(LuaWriter*)ud;
			return writer(p[0..sz]) ? 0 : 1;
		}

		this.push();
		auto ret = lua_dump(this.state, &luaCWriter, &writer);
		lua_pop(this.state, 1);
		return ret == 0;
	}
}

version(unittest)
{
	import luad.testing;
	import std.variant;
	import std.typecons;
}

unittest
{
	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	luaL_openlibs(L);

	lua_getglobal(L, "tostring");
	auto tostring = popValue!LuaFunction(L);

	LuaObject[] ret = tostring(123);
	assert(ret[0].to!string() == "123");

	assert(tostring.call!string(123) == "123");

	tostring.call(321);

	// Multiple return values
	luaL_dostring(L, "function singleRet() return 42 end");
	lua_getglobal(L, "singleRet");
	auto singleRet = popValue!LuaFunction(L);

	auto singleRetResult = singleRet.call!(Tuple!int)();
	assert(singleRetResult[0] == 42);

	alias Algebraic!(string, double) BasicLuaType;
	BasicLuaType a = "foo";
	BasicLuaType b = 1.5;

	pushValue(L, [a, b]);
	lua_setglobal(L, "test");

	luaL_dostring(L, "function multRet() return unpack(test) end");
	lua_getglobal(L, "multRet");
	auto multRet = popValue!LuaFunction(L);

	auto result = multRet.call!(Tuple!(string, double))();
	assert(result[0] == a);
	assert(result[1] == b);

	unittest_lua(L, `function getName() return "Foo", "Bar" end`);

	lua_getglobal(L, "getName");
	auto getName = popValue!LuaFunction(L);

	string[2] arrayRet = getName.call!(string[2])();
	assert(arrayRet[0] == "Foo");
	assert(arrayRet[1] == "Bar");

	// setEnvironment
	pushValue(L, ["test": [42]]);
	auto env = popValue!LuaTable(L);

	lua_getglobal(L, "unpack");
	env["unpack"] = popValue!LuaObject(L);

	multRet.setEnvironment(env);
	assert(multRet.call!int() == 42);

}
