/**
Internal module for pushing and getting _functions and delegates.

LuaD allows for pushing of all D function or delegate types with return type and parameter types compatible with LuaD (see $(LINKMODULE stack)).

For multiple return values, return a Tuple (from std.typecons). For a variable number of return values, return LuaObject[] (for returning an array of LuaObject as a table, wrap it in LuaTable).

As a special case for const(char)[] parameter types in _functions pushed to Lua, no copy of the string is made when called; take care not to escape such references, they are effectively scope parameters.
When a copy is desired, use char[] or string, or dup or idup the string manually.

If a function with the lua_CFunction signature is encountered, it is pushed directly with no inserted conversions or overhead.

Typesafe varargs is supported when pushing _functions to Lua, but as of DMD 2.054, compiler bugs prevent getting delegates with varargs from Lua (use $(LINKMODULE2 lfunction,LuaFunction) instead).
*/
module luad.conversions.functions;

import core.memory;
import std.traits;
import std.typetuple;
import std.string : toStringz;
import luad.c.all;

import luad.stack;

private:

void argsError(lua_State* L, int nargs, int expected)
{
	lua_Debug debugInfo;
	lua_getstack(L, 0, &debugInfo);
	lua_getinfo(L, "n", &debugInfo);
	luaL_error(L, "call to %s '%s': got %d arguments, expected %d",
		debugInfo.namewhat, debugInfo.name, nargs, expected);
}

template StripHeadQual(T : const(T*))
{
	alias const(T)* StripHeadQual;
}

template StripHeadQual(T : const(T[]))
{
	alias const(T)[] StripHeadQual;
}

template StripHeadQual(T : immutable(T*))
{
	alias immutable(T)* StripHeadQual;
}

template StripHeadQual(T : immutable(T[]))
{
	alias immutable(T)[] StripHeadQual;
}

template StripHeadQual(T : T[])
{
	alias T[] StripHeadQual;
}

template StripHeadQual(T : T*)
{
	alias T* StripHeadQual;
}

template StripHeadQual(T)
{
	alias T StripHeadQual;
}

template FillableParameterTypeTuple(T)
{
	alias staticMap!(StripHeadQual, ParameterTypeTuple!T) FillableParameterTypeTuple;
}

template BindableReturnType(T)
{
	alias StripHeadQual!(ReturnType!T) BindableReturnType;
}

int callFunction(T)(lua_State* L, T func, ParameterTypeTuple!T args)
{
	//Call with or without return value, propagating Exceptions as Lua errors.
	//This should rather be throwing a userdata with __tostring and a reference to
	//the thrown exception, as it is now, everything but the error type and message is lost.
	alias BindableReturnType!T RetType;
	enum hasReturnValue = !is(RetType == void);
	
	static if(hasReturnValue)
		RetType ret;

	try
	{
		static if(hasReturnValue)
			ret = func(args);
		else
			func(args);
	}
	catch(Exception e)
	{
		luaL_error(L, "%s", toStringz(e.toString()));
	}

	static if(hasReturnValue)
		return pushReturnValues(L, ret);
	else
		return 0;
}

// TODO: right now, virtual functions on specialized classes can be called on base classes, not safe!
extern(C) int methodWrapper(T, Class, bool virtual)(lua_State* L)
{
	alias ParameterTypeTuple!T Args;
	
	//Check arguments
	int top = lua_gettop(L);
	if(top < Args.length + 1)
		argsError(L, top, Args.length + 1);

	Class self =  *cast(Class*)luaL_checkudata(L, 1, toStringz(Class.mangleof));
	
	static if(virtual)
	{
		alias ReturnType!T function(Class, Args) VirtualWrapper;
		VirtualWrapper func = cast(VirtualWrapper)lua_touserdata(L, lua_upvalueindex(1));
	}
	else
	{
		T func;
		func.ptr = cast(void*)self;
		func.funcptr = cast(typeof(func.funcptr))lua_touserdata(L, lua_upvalueindex(1));
	}
	
	//Assemble arguments
	static if(virtual)
	{
		ParameterTypeTuple!VirtualWrapper allArgs;
		allArgs[0] = self;
		alias allArgs[1..$] args;
	}
	else
	{
		Args allArgs;
		alias allArgs args;
	}

	foreach(i, Arg; Args)
		args[i] = getArgument!(T, i)(L, i + 2);
	
	return callFunction!(typeof(func))(L, func, allArgs);
}

extern(C) int functionWrapper(T)(lua_State* L)
{
	alias FillableParameterTypeTuple!T Args;
	
	//Check arguments
	int top = lua_gettop(L);
	if(top < Args.length)
		argsError(L, top, Args.length);
	
	//Get function
	static if(is(T == function))
		T func = cast(T)lua_touserdata(L, lua_upvalueindex(1));
	else
		T func = *cast(T*)lua_touserdata(L, lua_upvalueindex(1));
	
	//Assemble arguments
	Args args;
	foreach(i, Arg; Args)
		args[i] = getArgument!(T, i)(L, i + 1);

	return callFunction!T(L, func, args);
}

extern(C) int functionCleaner(lua_State* L)
{
	GC.removeRoot(lua_touserdata(L, 1));
	return 0;
}

public:

void pushFunction(T)(lua_State* L, T func) if (isSomeFunction!T)
{	
	static if(is(T == function))
		lua_pushlightuserdata(L, func);
	else
	{
		T* udata = cast(T*)lua_newuserdata(L, T.sizeof);
		*udata = func;
	
		GC.addRoot(udata);
		
		if(luaL_newmetatable(L, "__dcall") == 1)
		{
			lua_pushcfunction(L, &functionCleaner); 
			lua_setfield(L, -2, "__gc");
		}
		
		lua_setmetatable(L, -2);
	}
	
	lua_pushcclosure(L, &functionWrapper!T, 1);
}

// TODO: optimize for non-virtual functions
void pushMethod(Class, string member)(lua_State* L) if (isSomeFunction!(__traits(getMember, Class, member)))
{
	alias typeof(mixin("&Class.init." ~ member)) T;

	// Delay vtable lookup until the right time
	static ReturnType!T virtualWrapper(Class self, ParameterTypeTuple!T args)
	{
		return mixin("self." ~ member)(args);
	}

	lua_pushlightuserdata(L, &virtualWrapper);
	lua_pushcclosure(L, &methodWrapper!(T, Class, true), 1);
}

/**
 * Currently this function allocates a reference in the registry that is never deleted,
   one for each call... see code comments
 */
T getFunction(T)(lua_State* L, int idx) if (is(T == delegate))
{	
	auto func = new class
	{
		int lref;
		this()
		{
			lua_pushvalue(L, idx);
			lref = luaL_ref(L, LUA_REGISTRYINDEX);
		}
		
		//Alright... how to fix this?
		//The problem is that this object tends to be finalized after L is freed (by LuaState's destructor or otherwise).
		//If you have a good solution to the problem of dangling references to a lua_State,
		//please contact me :)
		
		/+~this()
		{
			luaL_unref(L, LUA_REGISTRYINDEX, lref);
		}+/
		
		void push()
		{
			lua_rawgeti(L, LUA_REGISTRYINDEX, lref);
		}
	};

	alias ReturnType!T RetType;
	alias ParameterTypeTuple!T Args;
	
	return delegate RetType(Args args)
	{
		func.push();
		foreach(arg; args)
			pushValue(L, arg);

		return callWithRet!RetType(L, args.length);
	};
}

version(unittest)
{
	import luad.testing;
	import std.typecons;
	private lua_State* L;
}

unittest
{
	L = luaL_newstate();
	luaL_openlibs(L);
	
	//functions
	static const(char)[] func(const(char)[] s)
	{
		return "Hello, " ~ s;
	}
	
	pushValue(L, &func);
	assert(lua_isfunction(L, -1));
	lua_setglobal(L, "sayHello");
	
	unittest_lua(L, `
		local ret = sayHello("foo")
		local expect = "Hello, foo"
		assert(ret == expect, 
			("sayHello return type - got '%s', expected '%s'"):format(ret, expect)
		)
	`);
	
	static uint countSpaces(const(char)[] s)
	{
		uint n = 0;
		foreach(dchar c; s)
			if(c == ' ')
				++n;
		
		return n;
	}
	
	pushValue(L, &countSpaces);
	assert(lua_isfunction(L, -1));
	lua_setglobal(L, "countSpaces");
	
	unittest_lua(L, `
		assert(countSpaces("Hello there, world!") == 2)
	`);
	
	//delegates
	double curry = 3.14 * 2;
	double closure(double x)
	{
		return curry * x;
	}
	
	pushValue(L, &closure);
	assert(lua_isfunction(L, -1));
	lua_setglobal(L, "circle");
	
	unittest_lua(L, `
		assert(circle(2) == 3.14 * 4, "closure return type mismatch!")
	`);

	// Const parameters
	static bool isEmpty(const(char[]) str) { return str.length == 0; }
	static bool isEmpty2(in char[] str) { return str.length == 0; }

	pushValue(L, &isEmpty);
	lua_setglobal(L, "isEmpty");

	pushValue(L, &isEmpty2);
	lua_setglobal(L, "isEmpty2");

	unittest_lua(L, `
		assert(isEmpty(""))
		assert(isEmpty2(""))
		assert(not isEmpty("a"))
		assert(not isEmpty2("a"))
	`);

	// Immutable parameters
	static immutable(char[]) returnArg(immutable(char[]) str) { return str; }

	pushValue(L, &returnArg);
	lua_setglobal(L, "returnArg");

	unittest_lua(L, `assert(returnArg("foo") == "foo")`);
}

// multiple return values
unittest
{
	auto nameInfo = ["foo"];
	auto ageInfo = [42];
		
	alias Tuple!(string, "name", uint, "age") GetInfoResult;
	GetInfoResult getInfo(int idx)
	{
		GetInfoResult result;
		result.name = nameInfo[idx];
		result.age = ageInfo[idx];
		return result;
	}
		
	pushValue(L, &getInfo);
	lua_setglobal(L, "getInfo");
		
	unittest_lua(L, `
		local name, age = getInfo(0)
		assert(name == "foo")
		assert(age == 42)
	`);
}
	
// D-style typesafe varargs
unittest
{
	static string concat(const(char)[][] pieces...)
	{
		string result;
		foreach(piece; pieces)
			result ~= piece;
		return result;
	}
	
	pushValue(L, &concat);
	lua_setglobal(L, "concat");
	
	unittest_lua(L, `
		local whole = concat("he", "llo", ", ", "world!")
		assert(whole == "hello, world!")
	`);
	
	static const(char)[] concat2(char separator, const(char)[][] pieces...)
	{
		if(pieces.length == 0)
			return "";

		string result;
		foreach(piece; pieces[0..$-1])
			result ~= piece ~ separator;
		
		return result ~ pieces[$-1];
	}
	
	pushValue(L, &concat2);
	lua_setglobal(L, "concat2");
	
	unittest_lua(L, `
		local whole = concat2(",", "one", "two", "three", "four")
		assert(whole == "one,two,three,four")
	`);
}

// get delegates from Lua
unittest
{
	lua_getglobal(L, "string");
	lua_getfield(L, -1, "match");
	auto match = popValue!(string delegate(string, string))(L); 
	lua_pop(L, 1);
		
	auto result = match("foobar@example.com", "([^@]+)@example.com");
	assert(result == "foobar");

	// multiple return values
	luaL_dostring(L, `function multRet(a) return "foo", a end`);
	lua_getglobal(L, "multRet");
	auto multRet = popValue!(Tuple!(string, int) delegate(int))(L);
	
	auto results = multRet(42);
	assert(results[0] == "foo");
	assert(results[1] == 42);
}

// Nested call stack testing
unittest
{
	alias string delegate(string) MyFun;
	
	MyFun[string] funcs;

	pushValue(L, (string name, MyFun fun) {
		funcs[name] = fun;	
	});
	lua_setglobal(L, "addFun");

	pushValue(L, (string name, string arg) {
		auto top = lua_gettop(L);
		auto result = funcs[name](arg);
		assert(lua_gettop(L) == top);
		return result;
	});
	lua_setglobal(L, "callFun");

	auto top = lua_gettop(L);

	luaL_dostring(L, q{
		addFun("echo", function(s) return s end)
		local result = callFun("echo", "test")
		assert(result == "test")
	});

	assert(lua_gettop(L) == top);
}

unittest
{
	assert(lua_gettop(L) == 0);
	lua_close(L);
}