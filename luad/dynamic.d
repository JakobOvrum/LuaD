module luad.dynamic;

import luad.c_terse;

import luad.base;
import luad.stack;

/**
 * Represents a reference to a Lua value of any type.
 * Supports all operations you can perform on values in Lua.
 */
struct LuaDynamic
{
	/**
	 * Underlying Lua reference.
	 * LuaDynamic does not sub-type LuaObject - qualify access to this reference explicitly.
	 */
	LuaObject object;
	
	/**
	 * Perform a Lua method call on this object.
	 *
	 * Performs a call similar to calling functions in Lua with the colon operator.
	 * The name string is looked up in this object and the result is called. This object is prepended
	 * to the arguments args.
	 * Params:
	 *    name = _name of method
	 *    args = additional arguments
	 * Returns:
	 *    All return values
	 * Examples:
	 * ----------------
	 * auto luaString = lua.wrap!LuaDynamic("test");
	 * auto results = luaString.gsub("t", "f"); // opDispatch
	 * assert(results[0] == "fesf");
	 * assert(results[1] == 2); // two instances of 't' replaced
	 * ----------------
	 * Note:
	 *    To call a member named "object", instantiate this function template explicitly.
	 */
	LuaDynamic[] opDispatch(string name, string file = __FILE__, uint line = __LINE__, Args...)(Args args)
	{
		// Push self
		object.push();

		auto frame = object.state.gettop();
		
		// push name and self[name]
		object.state.pushstring(name);
		object.state.gettable(-2);

		// TODO: How do I properly generalize this to include other types,
		// while not stepping on the __call metamethod?
		if(object.state.isnil())
		{
			object.state.pop(2);
			object.state.error("%s:%d: attempt to call method '%s' (a nil value)", file.ptr, line, name.ptr);
		}

		// Copy 'this' to the top of the stack
		object.state.pushvalue(-2);
		
		foreach(arg; args)
			pushValue(object.state, arg);

		object.state.call(args.length + 1, MULTRET);

		auto nret = object.state.gettop() - frame;

		auto ret = popStack!LuaDynamic(object.state, nret);
		
		// Pop self
		object.state.pop();

		return ret;
	}
	
	/**
	 * Call this object.
	 * This object must either be a function, or have a metatable providing the ___call metamethod.
	 * Params:
	 *    args = arguments for the call
	 * Returns:
	 *    Array of return values, or a null array if there were no return values
	 */
	LuaDynamic[] opCall(Args...)(Args args)
	{
		auto frame = object.state.gettop();

		object.push(); // Callable
		foreach(arg; args)
			pushValue(object.state, arg);
		
		object.state.call(args.length, MULTRET);

		auto nret = object.state.gettop() - frame;
		
		return popStack!LuaDynamic(object.state, nret);
	}
	
	/**
	 * Index this object.
	 * This object must either be a table, or have a metatable providing the ___index metamethod.
	 * Params:
	 *    key = _key to lookup
	 */
	LuaDynamic opIndex(T)(auto ref T key)
	{
		object.push();
		pushValue(object.state, key);
		object.state.gettable(-2);
		auto result = getValue!LuaDynamic(object.state, -1);
		object.state.pop(2);
		return result;
	}

	/**
	 * Compare the referenced object to another value with Lua's equality semantics.
	 * If the _other value is not a Lua reference wrapper, it will go through the
	 * regular D to Lua conversion process first.
	 * To check for nil, compare against the special constant "nil".
	 */
	bool opEquals(T)(auto ref T other)
	{
		object.push();
		static if(is(T == Nil))
		{
			scope(success) object.state.pop();
			return object.state.isnil();
		}
		else
		{
			pushValue(object.state, other);
			scope(success) object.state.pop(2);
			return object.state.equal();
		}
	}
}

version(unittest) import luad.testing;

import std.stdio;

unittest
{
	State* L = newstate();
	scope(success) L.close();
	L.openlibs();
	
	L.dostring(`str = "test"`);
	L.getglobal("str");
	auto luaString = popValue!LuaDynamic(L);
	
	LuaDynamic[] results = luaString.gsub("t", "f");

	assert(results[0] == "fesf");
	assert(results[1] == 2); // two instances of 't' replaced

	auto gsub = luaString["gsub"];
	assert(gsub.object.type == LuaType.Function);
	
	LuaDynamic[] results2 = gsub(luaString, "t", "f");
	assert(results[0] == results2[0]);
	assert(results[1] == results2[1]);
	assert(results == results2);

	L.getglobal("thisisnil");
	auto nilRef = popValue!LuaDynamic(L);

	assert(nilRef == nil);
}