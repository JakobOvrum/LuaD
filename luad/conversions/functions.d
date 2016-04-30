/**
Internal module for pushing and getting _functions and delegates.

LuaD allows for pushing of all D function or delegate types with return type and parameter types compatible with LuaD (see $(DPMODULE stack)).

For a fixed number of multiple return values, return a $(STDREF typecons,Tuple) or a static array. For a variable number of return values, return $(MREF LuaVariableReturn).

As a special case for $(D const(char)[]) parameter types in _functions pushed to Lua, no copy of the string is made when called; take care not to escape such references, they are effectively $(D scope) parameters.
When a copy is desired, use $(D char[]) or $(D string), or $(D dup) or $(D idup) the string manually.

If a function with the $(D lua_CFunction) signature is encountered, it is pushed directly with no inserted conversions or overhead.

Typesafe varargs is supported when pushing _functions to Lua, but as of DMD 2.054, compiler bugs prevent getting delegates with varargs from Lua (use $(DPREF lfunction,LuaFunction) instead).
*/
module luad.conversions.functions;

import luad.conversions.helpers;
import luad.all;

import core.memory;
import std.range;
import std.string : toStringz;
import std.traits;
import std.typetuple;
import std.typecons;

import luad.c.all;

import luad.stack;

private void argsError(lua_State* L, int nargs, ptrdiff_t expected)
{
	lua_Debug debugInfo;
	lua_getstack(L, 0, &debugInfo);
	lua_getinfo(L, "n", &debugInfo);
	luaL_error(L, "call to %s '%s': got %d arguments, expected %d",
		debugInfo.namewhat, debugInfo.name, nargs, expected);
}

template StripHeadQual(T : const(T*))
{
	alias StripHeadQual = const(T)*;
}

template StripHeadQual(T : const(T[]))
{
	alias StripHeadQual = const(T)[];
}

template StripHeadQual(T : immutable(T*))
{
	alias StripHeadQual = immutable(T)*;
}

template StripHeadQual(T : immutable(T[]))
{
	alias StripHeadQual = immutable(T)[];
}

template StripHeadQual(T : T[])
{
	alias StripHeadQual = T[];
}

template StripHeadQual(T : T*)
{
	alias StripHeadQual = T*;
}

template StripHeadQual(T : T[N], size_t N)
{
	alias StripHeadQual = T[N];
}

template StripHeadQual(T)
{
	alias StripHeadQual = T;
}

template FillableParameterTypeTuple(T)
{
	alias FillableParameterTypeTuple = staticMap!(StripHeadQual, ParameterTypeTuple!T);
}

template BindableReturnType(T)
{
	alias BindableReturnType = StripHeadQual!(ReturnType!T);
}

template TreatArgs(T...)
{
	static if(T.length == 0)
		alias TreatArgs = TypeTuple!();
	else static if(isUserStruct!(T[0])) // TODO: we might do this for static arrays too in future...?
		// we need to convert struct's into Ref's because 'ref' isn't part of the type in D, and it gets lots in the function calling logic
		alias TreatArgs = TypeTuple!(Ref!(T[0]), TreatArgs!(T[1..$]));
	else static if(is(T[0] == class))
		alias TreatArgs = TypeTuple!(Rebindable!(T[0]), TreatArgs!(T[1..$]));
	else
		alias TreatArgs = TypeTuple!(T[0], TreatArgs!(T[1..$]));
}

//Call with or without return value, propagating Exceptions as Lua errors.
//This should rather be throwing a userdata with __tostring and a reference to
//the thrown exception, as it is now, everything but the error type and message is lost.
int callFunction(T, RT = BindableReturnType!T)(lua_State* L, T func, ParameterTypeTuple!T args)
	if((returnsRef!T && isUserStruct!RT) ||
	   (!is(RT == const) && !is(RT == immutable)))
{
	try
	{
		static if(!is(RT == void))
		{
			// TODO: should we support references for all types?
			static if(returnsRef!T && isUserStruct!RT)
				auto ret = Ref!RT(func(args));
			else
				RT ret = func(args);
			return pushReturnValues(L, ret);
		}
		else
			func(args);
	}
	catch(Exception e)
	{
		luaL_error(L, "%s", toStringz(e.toString()));
	}

	return 0;
}

// Ditto, but wrap the try-catch in a nested function because the return value's
// declaration and initialization cannot be separated.
int callFunction(T, RT = BindableReturnType!T)(lua_State* L, T func, ParameterTypeTuple!T args)
	if((!returnsRef!T || !isUserStruct!RT) &&
	   (is(RT == const) || is(RT == immutable)))
{
	// TODO: reconsider if this is necessary?
	//       surely it would be easier just to wrap the return statement in the try?
	auto ref call()
	{
		try
			return func(args);
		catch(Exception e)
			luaL_error(L, "%s", e.toString().toStringz());
	}

	return pushReturnValues(L, call());
}

package:

// TODO: right now, virtual functions on specialized classes can be called with base classes as 'self', not safe!
extern(C) int methodWrapper(M, T, bool virtual)(lua_State* L)
{
	alias Args = ParameterTypeTuple!M;

	static assert ((variadicFunctionStyle!M != Variadic.d && variadicFunctionStyle!M != Variadic.c),
		"Non-typesafe variadic functions are not supported.");

	//Check arguments
	int top = lua_gettop(L);

	static if (variadicFunctionStyle!M == Variadic.typesafe)
		enum requiredArgs = Args.length;
	else
		enum requiredArgs = Args.length + 1;

	if(top < requiredArgs)
		argsError(L, top, requiredArgs);

	static if(is(T == struct))
		Ref!T self = *cast(Ref!T*)luaL_checkudata(L, 1, toStringz(T.mangleof));
	else
		T self = *cast(T*)luaL_checkudata(L, 1, toStringz(T.mangleof));

	static if(virtual)
	{
		alias RT = InOutReturnType!(M.init, T);
		static if(returnsRef!M && isUserStruct!RT)
			alias VirtualWrapper = ref RT function(T, Args);
		else
			alias VirtualWrapper = RT function(T, Args);
		VirtualWrapper func = cast(VirtualWrapper)lua_touserdata(L, lua_upvalueindex(1));
	}
	else
	{
		M func;
		static if(is(T == struct))
			func.ptr = cast(void*)&self.__instance();
		else
			func.ptr = cast(void*)self;
		func.funcptr = cast(typeof(func.funcptr))lua_touserdata(L, lua_upvalueindex(1));
	}

	//Assemble arguments
	static if(virtual)
	{
		TreatArgs!(ParameterTypeTuple!VirtualWrapper) allArgs;
		allArgs[0] = self;
		alias args = allArgs[1..$];
	}
	else
	{
		// TODO: maybe we should build a tuple of 'ReturnType!(getArgument!(T, i))' for each arg?
		//       then we could get rid of this TreatArgs! rubbish...
		TreatArgs!Args allArgs;
		alias args = allArgs;
	}

	foreach(i, Arg; Args)
		args[i] = getArgument!(M, i)(L, i + 2);

	return callFunction!(typeof(func))(L, func, allArgs);
}

extern(C) int functionWrapper(T)(lua_State* L)
{
	alias Args = FillableParameterTypeTuple!T;

	static assert ((variadicFunctionStyle!T != Variadic.d && variadicFunctionStyle!T != Variadic.c),
		"Non-typesafe variadic functions are not supported.");

	//Check arguments
	int top = lua_gettop(L);

	static if (variadicFunctionStyle!T == Variadic.typesafe)
		enum requiredArgs = Args.length - 1;
	else
		enum requiredArgs = Args.length;

	if(top < requiredArgs)
		argsError(L, top, requiredArgs);

	//Get function
	static if(isFunctionPointer!T)
		T func = cast(T)lua_touserdata(L, lua_upvalueindex(1));
	else
		T func = *cast(T*)lua_touserdata(L, lua_upvalueindex(1));

	//Assemble arguments
	TreatArgs!Args args;
	foreach(i, Arg; Args)
		args[i] = getArgument!(T, i)(L, i + 1);

	return callFunction!T(L, func, args);
}

public:

void pushFunction(T)(lua_State* L, T func) if (isSomeFunction!T)
{
	static if(isFunctionPointer!T)
		lua_pushlightuserdata(L, func);
	else
	{
		T* udata = cast(T*)lua_newuserdata(L, T.sizeof);
		*udata = func;

		GC.addRoot(udata);

		if(luaL_newmetatable(L, "__dcall") == 1)
		{
			lua_pushcfunction(L, &userdataCleaner);
			lua_setfield(L, -2, "__gc");
		}

		lua_setmetatable(L, -2);
	}

	lua_pushcclosure(L, &functionWrapper!T, 1);
}

// TODO: optimize for non-virtual functions
void pushMethod(T, string member)(lua_State* L) if (isSomeFunction!(__traits(getMember, T, member)))
{
	alias M = typeof(mixin("&T.init." ~ member));

	enum isVirtual = !is(T == struct); // TODO: final methods should also be handled...

	static if(isVirtual)
	{
		alias RT = InOutReturnType!(mixin("T." ~ member), T);

		// Delay vtable lookup until the right time
		static if(returnsRef!M && isUserStruct!RT)
		{
			static ref RT virtualWrapper(T self, ParameterTypeTuple!M args)
			{
				return mixin("self." ~ member)(args);
			}
		}
		else
		{
			static RT virtualWrapper(T self, ParameterTypeTuple!M args)
			{
				return mixin("self." ~ member)(args);
			}
		}
		lua_pushlightuserdata(L, &virtualWrapper);
	}
	else
		lua_pushlightuserdata(L, mixin("&T.init." ~ member).funcptr);

	lua_pushcclosure(L, &methodWrapper!(M, T, isVirtual), 1);
}

/**
 * Currently this function allocates a reference in the registry that is never deleted,
 * one for each call... see code comments
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

/**
 * Type for efficiently returning a variable number of return values
 * from a function.
 *
 * Use $(D variableReturn) to instantiate it.
 * Params:
 *   Range = any input range
 */
struct LuaVariableReturn(Range) if(isInputRange!Range)
{
	alias WrappedType = Range; /// The type of the wrapped input range.
	Range returnValues; /// The wrapped input range.
}

/**
 * Create a LuaVariableReturn object for efficiently returning
 * a variable number of values from a function.
 * Params:
 *   returnValues = any input range
 * Example:
-----------------------------
	LuaVariableReturn!(uint[]) makeList(uint n)
	{
		uint[] list;

		foreach(i; 1 .. n + 1)
		{
			list ~= i;
		}

		return variableReturn(list);
	}

	lua["makeList"] = &makeList;

	lua.doString(`
		local one, two, three, four = makeList(4)
		assert(one == 1)
		assert(two == 2)
		assert(three == 3)
		assert(four == 4)
	`);
-----------------------------
 */
LuaVariableReturn!Range variableReturn(Range)(Range returnValues)
	if(isInputRange!Range)
{
	return typeof(return)(returnValues);
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

version(unittest) import luad.base;

// multiple return values
unittest
{
	// tuple returns
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

	// static array returns
	static string[2] getName()
	{
		string[2] ret;
		ret[0] = "Foo";
		ret[1] = "Bar";
		return ret;
	}

	pushValue(L, &getName);
	lua_setglobal(L, "getName");

	unittest_lua(L, `
		local first, last = getName()
		assert(first == "Foo")
		assert(last == "Bar")
	`);

	// variable length returns
	LuaVariableReturn!(uint[]) makeList(uint n)
	{
		uint[] list;

		foreach(i; 1 .. n + 1)
		{
			list ~= i;
		}

		return variableReturn(list);
	}

	auto makeList2(uint n)
	{
		return variableReturn(iota(1, n + 1));
	}

	pushValue(L, &makeList);
	lua_setglobal(L, "makeList");
	pushValue(L, &makeList2);
	lua_setglobal(L, "makeList2");

	unittest_lua(L, `
		for i, f in pairs{makeList, makeList2} do
			local one, two, three, four = f(4)
			assert(one == 1)
			assert(two == 2)
			assert(three == 3)
			assert(four == 4)
		end
	`);
}

// Variadic function arguments
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

	//Test with zero parameters.
	unittest_lua(L, `
		local blank = concat()
		assert (string.len(blank) == 0)
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

	//C- and D-style variadic versions of concat for
	//future use if/when these are supported.

	//C varargs require at least one fixed argument.
	import core.vararg;
	// C-style varargs broken on Linux for 2.066.1?
	version(none) extern(C) static string concat_cvar (size_t count, ...)
	{
		string result;

		va_list args;

		va_start(args, count);

		foreach(immutable i; 0 .. count)
		{
			auto arg = va_arg!LuaObject(args);
			result ~= arg.toString();
		}

		va_end(args);

		return result;
	}

	//D-style variadics have an _arguments array that specifies
	//the type of each passed argument.
	static string concat_dvar (...) {
		string result;

		foreach (argtype; _arguments) {
			assert (argtype == typeid(LuaObject));
			auto arg = va_arg!(LuaObject)(_argptr);

			result ~= arg.toString();
		}

		return result;
	}
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
