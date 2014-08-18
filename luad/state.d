module luad.state;

import std.array, std.range;

import std.string : toStringz;
import std.typecons : isTuple;

import luad.c.all;
import luad.stack;
import luad.conversions.classes;
import luad.conversions.enums;

import luad.base, luad.table, luad.lfunction, luad.dynamic, luad.error;

/// Specify error handling scheme for $(MREF LuaState.doString) and $(MREF LuaState.doFile).
enum LuaErrorHandler
{
	None, /// No extra error handler.
	Traceback /// Append a stack traceback to the error message.
}

/**
 * Represents a Lua state instance.
 */
class LuaState
{
private:
	lua_State* L; // underlying state
	LuaTable _G, _R; // global and registry tables
	LuaFunction traceback; // debug.traceback, set in openLibs()
	bool owner = false; // whether or not to close the underlying state in the finalizer

public:
	/**
	 * Create a new, empty Lua state. The standard library is not loaded.
	 *
	 * If an uncaught error for any operation on this state
	 * causes a Lua panic for the underlying state,
	 * an exception of type $(DPREF error, LuaErrorException) is thrown.
	 *
	 * See_Also: $(MREF LuaState.openLibs)
	 */
	this()
	{
		lua_State* L = luaL_newstate();
		owner = true;

		extern(C) static int panic(lua_State* L)
		{
			size_t len;
			const(char)* cMessage = lua_tolstring(L, -1, &len);
			string message = cMessage[0 .. len].idup;

			lua_pop(L, 1);

			throw new LuaErrorException(message);
		}

		lua_atpanic(L, &panic);

		this(L);
	}

	/**
	 * Create a D wrapper for an existing Lua state.
	 *
	 * The new $(D LuaState) object does not assume ownership of the state.
	 * Params:
	 *	 L = state to wrap
	 * Note:
	 *	 The panic function is not changed - a Lua panic will not throw a D exception!
	 * See_Also:
		$(MREF LuaState.setPanicHandler)
	 */
	this(lua_State* L)
	{
		this.L = L;
		_G = LuaTable(L, LUA_GLOBALSINDEX);
		_R = LuaTable(L, LUA_REGISTRYINDEX);

		lua_pushlightuserdata(L, cast(void*)this);
		lua_setfield(L, LUA_REGISTRYINDEX, "__dstate");
	}

	~this()
	{
		if(owner)
		{
			_R.release();
			_G.release();
			traceback.release();
			lua_close(L);
		}
		else // Unregister state
		{
			lua_pushnil(L);
			lua_setfield(L, LUA_REGISTRYINDEX, "__dstate");
		}
	}

	/// The underlying $(D lua_State) pointer for interfacing with C.
	@property lua_State* state() nothrow pure @safe
	{
		return L;
	}

	/**
	 * Get the $(D LuaState) instance for a Lua state.
	 * Params:
	 *	 L = Lua state
	 * Returns:
	 *	 $(D LuaState) for the given $(D lua_State*), or $(D null) if a $(D LuaState) is not currently attached to the state
	 */
	static LuaState fromPointer(lua_State* L) @trusted
	{
		lua_getfield(L, LUA_REGISTRYINDEX, "__dstate");
		auto lua = cast(LuaState)lua_touserdata(L, -1);
		lua_pop(L, 1);
		return lua;
	}

	/// Open the standard library.
	void openLibs() @trusted
	{
		luaL_openlibs(L);
		traceback = _G.get!LuaFunction("debug", "traceback");
	}

	/// The global table for this instance.
	@property LuaTable globals() @trusted
	{
		return _G;
	}

	/// The _registry table for this instance.
	@property LuaTable registry() @trusted
	{
		return _R;
	}

	/**
	 * Set a new panic handler.
	 * Params:
	 *	 onPanic = new panic handler
	 * Examples:
	 * ----------------------
	auto L = luaL_newstate(); // found in luad.c.all
	auto lua = new LuaState(L);

	static void panic(LuaState lua, in char[] error)
	{
		throw new LuaErrorException(error.idup);
	}

	lua.setPanicHandler(&panic);
	 * ----------------------
	 */
	void setPanicHandler(void function(LuaState, in char[]) onPanic) @trusted
	{
		extern(C) static int panic(lua_State* L)
		{
			size_t len;
			const(char)* message = lua_tolstring(L, -1, &len);
			auto error = message[0 .. len];

			lua_getfield(L, LUA_REGISTRYINDEX, "__dpanic");
			auto callback = cast(void function(LuaState, in char[]))lua_touserdata(L, -1);
			assert(callback);

			scope(exit) lua_pop(L, 2);

			callback(LuaState.fromPointer(L), error);
			return 0;
		}

		lua_pushlightuserdata(L, onPanic);
		lua_setfield(L, LUA_REGISTRYINDEX, "__dpanic");

		lua_atpanic(L, &panic);
	}

	/*
	 * push debug.traceback error handler to the stack
	 */
	private void pushErrorHandler()
	{
		if(traceback.isNil)
			throw new Exception("LuaErrorHandler.Traceback requires openLibs()");
		traceback.push();
	}

	/*
	 * a variant of luaL_do(string|file) with advanced error handling
	 */
	private void doChunk(alias loader)(in char[] s, LuaErrorHandler handler)
	{
		if(handler == LuaErrorHandler.Traceback)
			pushErrorHandler();

		if(loader(L, toStringz(s)) || lua_pcall(L, 0, LUA_MULTRET, handler == LuaErrorHandler.Traceback? -2 : 0))
			lua_error(L);

		if(handler == LuaErrorHandler.Traceback)
			lua_remove(L, 1);
	}

	/**
	 * Compile a string of Lua _code.
	 * Params:
	 *	 code = _code to compile
	 * Returns:
	 *   Loaded _code as a function.
	 */
	LuaFunction loadString(in char[] code) @trusted
	{
		if(luaL_loadstring(L, toStringz(code)) != 0)
			lua_error(L);

		return popValue!LuaFunction(L);
	}

	/**
	 * Compile a file of Lua code.
	 * Params:
	 *	 path = _path to file
	 * Returns:
	 *   Loaded code as a function.
	 */
	LuaFunction loadFile(in char[] path) @trusted
	{
		if(luaL_loadfile(L, toStringz(path)) != 0)
			lua_error(L);

		return popValue!LuaFunction(L);
	}

	/**
	 * Execute a string of Lua _code.
	 * Params:
	 *	 code = _code to run
	 *   handler = error handling scheme
	 * Returns:
	 *	 Any _code return values
	 * See_Also:
	 *   $(MREF LuaErrorHandler)
	 */
	LuaObject[] doString(in char[] code, LuaErrorHandler handler = LuaErrorHandler.None) @trusted
	{
		auto top = lua_gettop(L);

		doChunk!(luaL_loadstring)(code, handler);

		auto nret = lua_gettop(L) - top;

		return popStack(L, nret);
	}

	/**
	 * Execute a file of Lua code.
	 * Params:
	 *	 path = _path to file
	 *   handler = error handling scheme
	 * Returns:
	 *	 Any script return values
	 * See_Also:
	 *   $(MREF LuaErrorHandler)
	 */
	LuaObject[] doFile(in char[] path, LuaErrorHandler handler = LuaErrorHandler.None) @trusted
	{
		auto top = lua_gettop(L);

		doChunk!(luaL_loadfile)(path, handler);

		auto nret = lua_gettop(L) - top;

		return popStack(L, nret);
	}

	/**
	 * Create a new, empty table.
	 * Returns:
	 *	 The new table
	 */
	LuaTable newTable()() @trusted
	{
		return newTable(0, 0);
	}

	/**
	 * Create a new, empty table with pre-allocated space for members.
	 * Params:
	 *	 narr = number of pre-allocated array slots
	 *	 nrec = number of pre-allocated non-array slots
	 * Returns:
	 *	 The new table
	 */
	LuaTable newTable()(uint narr, uint nrec) @trusted
	{
		lua_createtable(L, narr, nrec);
		return popValue!LuaTable(L);
	}

	/**
	 * Create a new table from an $(D InputRange).
	 * If the element type of the range is $(D Tuple!(T, U)),
	 * then each element makes up a key-value pair, where
	 * $(D T) is the key and $(D U) is the value of the pair.
	 * For any other element type $(D T), a table with sequential numeric
	 * keys is created (an array).
	 * Params:
	 *   range = $(D InputRange) of key-value pairs or elements
	 * Returns:
	 *	 The new table
	 */
	LuaTable newTable(Range)(Range range) @trusted if(isInputRange!Range)
	{
		alias ElementType!Range Elem;

		static if(hasLength!Range)
		{
			immutable numElements = range.length;
			assert(numElements < int.max, "lua_createtable only supports int.max many elements");
		}
		else
		{
			immutable numElements = 0;
		}

		static if(isTuple!Elem) // Key-value pairs
		{
			static assert(range.front.length == 2, "key-value tuple must have exactly 2 values.");

			lua_createtable(L, 0, cast(int)numElements);

			foreach(pair; range)
			{
				pushValue(L, pair[0]);
				pushValue(L, pair[1]);
				lua_rawset(L, -3);
			}
		}
		else // Sequential table
		{
			lua_createtable(L, cast(int)numElements, 0);

			int i = 1;

			foreach(value; range)
			{
				pushValue(L, value);
				lua_rawseti(L, -2, i);
				++i;
			}
		}

		return popValue!LuaTable(L);
	}

	/**
	 * Wrap a D value in a Lua reference.
	 *
	 * Note that using this method is only necessary in certain situations,
	 * such as when you want to act on the reference before fully exposing it to Lua.
	 * Params:
	 *   T = type of reference. Must be $(D LuaObject), $(D LuaTable), $(D LuaFunction) or $(D LuaDynamic).
	 *   Defaults to $(D LuaObject).
	 *	 value = D value to _wrap
	 * Returns:
	 *	 A Lua reference to value
	 */
	T wrap(T = LuaObject, U)(U value) @trusted if(is(T : LuaObject) || is(T == LuaDynamic))
	{
		pushValue(L, value);
		return popValue!T(L);
	}

	/**
	 * Register a D class or struct with Lua.
	 *
	 * This method exposes a type's constructors and static interface to Lua.
	 * Params:
	 *    T = class or struct to register
	 * Returns:
	 *    Reference to the registered type in Lua
	 */
	LuaObject registerType(T)() @trusted
	{
		pushStaticTypeInterface!T(L);
		return popValue!LuaObject(L);
	}

	/**
	 * Same as calling $(D globals._get) with the same arguments.
	 * See_Also:
	 *	 $(DPREF table, LuaTable._get)
	 */
	T get(T, U...)(U args)
	{
		return globals.get!T(args);
	}

	/**
	 * Same as calling $(D globals.get!LuaObject) with the same arguments.
	 * See_Also:
	 *	 $(DPREF table, LuaTable._opIndex)
	 */
	LuaObject opIndex(T...)(T args)
	{
		return globals.get!LuaObject(args);
	}

	/**
	 * Same as calling $(D globals._set) with the same arguments.
	 * See_Also:
	 *	 $(DPREF table, LuaTable._set)
	 */
	void set(T, U)(T key, U value)
	{
		globals.set(key, value);
	}

	/**
	 * Same as calling $(D globals._opIndexAssign) with the same arguments.
	 * See_Also:
	 *	 $(DPREF table, LuaTable._opIndexAssign)
	 */
	void opIndexAssign(T, U...)(T value, U args)
	{
		globals()[args] = value;
	}
}

version(unittest)
{
	import luad.testing;
	import std.string : splitLines;
	private LuaState lua;
}

unittest
{
	lua = new LuaState;
	assert(LuaState.fromPointer(lua.state) == lua);

	lua.openLibs();

	//default panic handler
	try
	{
		lua.doString(`error("Hello, D!")`, LuaErrorHandler.Traceback);
		assert(false);
	}
	catch(LuaErrorException e)
	{
		auto lines = splitLines(e.msg);
		assert(lines.length > 1);
		assert(lines[0] == `[string "error("Hello, D!")"]:1: Hello, D!`);
	}

	lua.set("success", false);
	assert(!lua.get!bool("success"));

	lua.doString(`success = true`);
	assert(lua.get!bool("success"));

	auto foo = lua.wrap!LuaTable([1, 2, 3]);
	foo[4] = "test"; // Lua tables start at 1
	lua["foo"] = foo;
	unittest_lua(lua.state, `
		for i = 1, 3 do
			assert(foo[i] == i)
		end
		assert(foo[4] == "test")
	`);

	LuaFunction multipleReturns = lua.loadString(`return 1, "two", 3`);
	LuaObject[] results = multipleReturns();

	assert(results.length == 3);
	assert(results[0].type == LuaType.Number);
	assert(results[1].type == LuaType.String);
	assert(results[2].type == LuaType.Number);
}

unittest // LuaState.newTable(range)
{
	import std.algorithm;

	auto input = [1, 2, 3];

	lua["tab"] = lua.newTable(input);

	unittest_lua(lua.state, `
		assert(#tab == 3)
		for i = 1, 3 do
			assert(tab[i] == i)
		end
	`);

	lua["tab"] = lua.newTable(filter!(i => i == 2)(input));

	unittest_lua(lua.state, `
		assert(#tab == 1)
		assert(tab[1] == 2)
	`);

	auto keys = iota(7, 14);
	auto values = repeat(42);

	lua["tab"] = lua.newTable(zip(keys, values));

	unittest_lua(lua.state, `
		assert(not tab[1])
		assert(not tab[6])
		for i = 7, 13 do
			assert(tab[i] == 42)
		end
		assert(not tab[14])
	`);
}

unittest
{
	static class Test
	{
		private:
		/+ Not working as of 2.062
		static int priv;
		static void priv_fun() {}
		+/

		public:
		static int pub = 123;

		static string foo() { return "bar"; }

		this(int i)
		{
			_bar = i;
		}

		int bar(){ return _bar; }
		int _bar;
	}

	lua["Test"] = lua.registerType!Test();

	unittest_lua(lua.state, `
		assert(type(Test) == "table")
		-- TODO: private members are currently pushed too...
		--assert(Test.priv == nil)
		--assert(Test.priv_fun == nil)
		assert(Test._foo == nil)
		assert(Test._bar == nil)

		local test = Test(42)
		assert(test:bar() == 42)

		assert(Test.pub == 123)
		assert(Test.foo() == "bar")
	`);
}

unittest
{
	// setPanicHandler, keep this test last
	static void panic(LuaState lua, in char[] error)
	{
		throw new Exception("hijacked error!");
	}

	lua.setPanicHandler(&panic);

	try
	{
		lua.doString(`error("test")`);
	}
	catch(Exception e)
	{
		assert(e.msg == "hijacked error!");
	}
}
