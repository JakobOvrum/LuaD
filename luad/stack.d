/++
This internal module, with the help of the luad.conversions package, takes care of converting between D and Lua types.

The conversion rules are as follows, where conversion goes both ways:
$(DL
	$(DT boolean
		$(DD bool)
	)
	$(DT number
		$(DD lua_Integer (default int))
		$(DD lua_Number (default double))
	)
	$(DT string
		$(DD string, const(char)[], char[])
		$(DD const(char)*)
		$(DD char)
	)
	$(DT table
		$(DD $(LINKSUBMODULE2 conversions,assocarrays,associative arrays))
		$(DD $(LINKSUBMODULE2 conversions,arrays,arrays))
		$(DD $(LINKSUBMODULE2 conversions,structs,structs))
		$(DD $(LINKMODULE2 table,LuaTable))
	)
	$(DT function (see $(LINKSUBMODULE conversions,functions))
		$(DD function pointers)
		$(DD delegates)
		$(DD $(LINKMODULE2 lfunction,LuaFunction))
	)
	$(DT userdata
		$(DD $(LINKSUBMODULE2 conversions,classes,classes))
	)
	$(DT nil
		$(DD the special identifier nil)
		$(DD null class references)
	)
	$(DT any of the above
		$(DD $(LINKMODULE2 base,LuaObject))
		$(DD $(LINKMODULE2 dynamic,LuaDynamic))
		$(DD $(LINKSUBMODULE2 conversions,variant,Algebraic) (when given a compatible value))
	)
)

The conversions are checked in the specified order. For example, even though bool is implicitly convertible
to lua_Integer, it will be converted to a boolean because boolean has precedence.

wchar and dchar are explicitly disallowed. Lua strings consist of 8-bit characters, if you want to push UTF-16 or UTF-32 strings, convert to UTF-8 first.

Additionally, the following types are pushable to Lua, but can't be retrieved back:
$(DL
	$(DT function
		$(DD lua_CFunction)
	)
)
+/
module luad.stack;

import std.traits;
import std.typecons;

import luad.c.all;

import luad.base;
import luad.table;
import luad.lfunction;
import luad.dynamic;

import luad.conversions.functions;
import luad.conversions.arrays;
import luad.conversions.structs;
import luad.conversions.assocarrays;
import luad.conversions.classes;
import luad.conversions.variant;

/**
 * Push a value of any type to the stack.
 * Params:
 *	 L = stack to push to
 *	 value = value to push
 */
void pushValue(T)(lua_State* L, T value)
{
	static if(is(T : LuaObject))
		value.push();
		
	else static if(is(T == LuaDynamic))
		value.object.push();
		
	else static if(is(T == Nil))
		lua_pushnil(L);
	
	else static if(is(T == bool))
		lua_pushboolean(L, cast(bool)value);
	
	else static if(is(T == char))
		lua_pushlstring(L, &value, 1);
		
	else static if(is(T : lua_Integer))
		lua_pushinteger(L, value);
	
	else static if(is(T : lua_Number))
		lua_pushnumber(L, value);
		
	else static if(is(T : const(char)[]))
		lua_pushlstring(L, value.ptr, value.length);
	
	else static if(is(T : const(char)*))
		lua_pushstring(L, value);
	
	else static if(isVariant!T)
		pushVariant(L, value);
		
	else static if(isAssociativeArray!T)
		pushAssocArray(L, value);
	
	else static if(isArray!T)
		pushArray(L, value);
	
	else static if(is(T == struct))
		pushStruct(L, value);
	
	// luaCFunction's are directly pushed
	else static if(is(T == lua_CFunction) && functionLinkage!T == "C")
		lua_pushcfunction(L, value);

	// other functions are wrapped
	else static if(isSomeFunction!T)
		pushFunction(L, value);
		
	else static if(is(T == class))
	{
		if(value is null)
			lua_pushnil(L);
		else
			pushClass(L, value);
	}
	
	else
		static assert(false, "Unsupported type `" ~ T.stringof ~ "` in stack push operation");
}

/**
 * Get the associated Lua type for T.
 * Returns: Lua type for T
 */
int luaTypeOf(T)()
{
	static if(is(T == bool))
		return LUA_TBOOLEAN;
	
	else static if(is(T == Nil))
		return LUA_TNIL;
	
	else static if(is(T : const(char)[]) || is(T : const(char)*) || is(T == char))
		return LUA_TSTRING;
		
	else static if(is(T : lua_Integer) || is(T : lua_Number))
		return LUA_TNUMBER;
	
	else static if(isSomeFunction!T || is(T == LuaFunction))
		return LUA_TFUNCTION;
		
	else static if(isArray!T || isAssociativeArray!T || is(T == struct) || is(T == LuaTable))
		return LUA_TTABLE;
	
	else static if(is(T : Object))
		return LUA_TUSERDATA;
	
	else
		static assert(false, "No Lua type defined for `" ~ T.stringof ~ "`");
}

// generic type mismatch message
private void defaultTypeMismatch(lua_State* L, int idx, int expectedType)
{
	luaL_error(L, "expected %s, got %s", lua_typename(L, expectedType), luaL_typename(L, idx));
}

// type mismatch for function arguments of unexpected type
private void argumentTypeMismatch(lua_State* L, int idx, int expectedType)
{
	luaL_typerror(L, idx, lua_typename(L, expectedType));
}

/**
 * Get a value of any type from the stack.
 * Params:
 *	 T = type of value
 *	 typeMismatchHandler = function called to produce an error in case of an invalid conversion.
 *	 L = stack to get from
 *	 idx = value stack index
 */
T getValue(T, alias typeMismatchHandler = defaultTypeMismatch)(lua_State* L, int idx)
{
	debug //ensure unchanged stack
	{
		int _top = lua_gettop(L);
		scope(success) assert(lua_gettop(L) == _top);
	}
	
	//ambiguous types
	static if(is(T == wchar) || is(T : const(wchar)[]) ||
			  is(T == dchar) || is(T : const(dchar)[]))
	{
		static assert("Ambiguous type " ~ T.stringof ~ " in stack push operation. Consider converting before pushing.");
	}
	
	static if(!is(T == LuaObject) && !is(T == LuaDynamic) && !isVariant!T)
	{
		int type = lua_type(L, idx);
		int expectedType = luaTypeOf!T();
		if(type != expectedType)
			typeMismatchHandler(L, idx, expectedType);
	}

	static if(is(T == LuaFunction)) // WORKAROUND: bug #6036
	{
		LuaFunction func;
		func.object = LuaObject(L, idx);
		return func;
	}	
	else static if(is(T == LuaDynamic)) // ditto
	{
		LuaDynamic obj;
		obj.object = LuaObject(L, idx);
		return obj;
	}	
	else static if(is(T : LuaObject))
		return T(L, idx);
		
	else static if(is(T == Nil))
		return nil;
	
	else static if(is(T == bool))
		return lua_toboolean(L, idx);

	else static if(is(T == char))
		return *lua_tostring(L, idx); // TODO: better define this
			
	else static if(is(T : lua_Integer))
		return cast(T)lua_tointeger(L, idx);
	
	else static if(is(T : lua_Number))
		return cast(T)lua_tonumber(L, idx);
	
	else static if(is(T : const(char)[]))
	{
		size_t len;
		const(char)* str = lua_tolstring(L, idx, &len);
		static if(is(T == char[]))
			return str[0 .. len].dup;
		else
			return str[0 .. len].idup;
	}
	else static if(is(T : const(char)*))
		return lua_tostring(L, idx);
	
	else static if(isAssociativeArray!T)
		return getAssocArray!T(L, idx);
	
	else static if(isArray!T)
		return getArray!T(L, idx);
	
	else static if(isVariant!T)
	{
		if(!isAllowedType!T(L, idx))
			luaL_error(L, "Type not allowed in Variant: %s", luaL_typename(L, idx));

		return getVariant!T(L, idx);
	}
	else static if(is(T == struct))
		return getStruct!T(L, idx);
	
	else static if(isSomeFunction!T)
		return getFunction!T(L, idx);
	
	else static if(is(T : Object))
		return getClass!T(L, idx);
			
	else
	{
		static assert(false, "Unsupported type `" ~ T.stringof ~ "` in stack read operation");
	}
}

/**
 * Same as calling getValue!(T, typeMismatchHandler)(L, -1), then popping one value from the stack.
 * See_Also: getValue
 */
T popValue(T, alias typeMismatchHandler = defaultTypeMismatch)(lua_State* L)
{
	scope(success) lua_pop(L, 1);
	return getValue!(T, typeMismatchHandler)(L, -1);
}

/**
 * Get all objects on a stack, then clear the stack.
 * Params:
 *   T = wrapper type to use
 *   L = stack to dump
 * Returns:
 *	 array of objects
 */
T[] popStack(T = LuaObject)(lua_State* L)
{
	int top = lua_gettop(L);
	auto stack = new T[top];
	foreach(i; 0..top)
	{
		stack[i] = getValue!T(L, i + 1);
	}
	lua_settop(L, 0);
	return stack;
}

/// Get a function argument from the stack.
auto getArgument(T, int narg)(lua_State* L, int idx)
{
	alias ParameterTypeTuple!T Args;
	
	static if(narg == -1) // varargs causes this
		alias ForeachType!(Args[$-1]) Arg;
	else
		alias Args[narg] Arg;

	static if(is(typeof(Variadic.TYPESAFE)))
		enum isVarargs = variadicFunctionStyle!T == Variadic.TYPESAFE;
	else // Phobos >= 2.055
		enum isVarargs = variadicFunctionStyle!T == Variadic.typesafe;
	
	static if(isVarargs && narg == Args.length-1)
	{
		alias Args[narg] LastArg;
		alias ForeachType!LastArg ElemType;
		
		auto top = lua_gettop(L);
		auto size = top - idx + 1;
		LastArg result = new LastArg(size);
		foreach(i; 0 .. size)
		{
			result[i] = getArgument!(T, -1)(L, idx + i);
		}
		return result;
	}
	else static if(is(Arg == const(char)[]) || is(Arg == const(void)[]))
	{
		if(lua_type(L, idx) != LUA_TSTRING)
			argumentTypeMismatch(L, idx, LUA_TSTRING);
			
		size_t len;
		const(char)* cstr = lua_tolstring(L, idx, &len);
		return cstr[0 .. len];
	}
	else
		return getValue!(Arg, argumentTypeMismatch)(L, idx);
}

/// Used for getting a suitable nresults argument to lua_call or lua_pcall.
template returnTypeSize(T)
{
	static if(is(T == LuaObject[]))
		enum returnTypeSize = LUA_MULTRET;
		
	else static if(isTuple!T)
		enum returnTypeSize = T.Types.length;
		
	else static if(is(T == void))
		enum returnTypeSize = 0;
		
	else
		enum returnTypeSize = 1;
}

/**
 * Pop return values from stack. 
 * Defaults to popValue, but has special handling for LuaObject[], Tuple!(...), and void.
 */
T popReturnValues(T)(lua_State* L)
{
	static if(is(T == LuaObject[]))
		return popStack(L);
		
	else static if(isTuple!T)
	{
		auto top = lua_gettop(L);
		if(top < T.Types.length)
			luaL_error(L, "expected %s return values, got %s", T.Types.length, top);
		
		return popTuple!T(L);
	}	
	else static if(is(T == void))
		return;
		
	else
		return popValue!T(L);
}

/**
 * Push return values to the stack.
 * Defaults to pushValue, but has special handling for LuaObject[] and Tuple!(...).
 */
int pushReturnValues(T)(lua_State* L, T value)
{
	static if(is(T == LuaObject[]))
	{
		foreach(obj; value)
		{
			assert(obj.state == L);
			obj.push();
		}
		return value.length;
	}
	else static if(isTuple!T)
	{
		pushTuple(L, value);
		return T.Types.length;
	}
	else
	{
		pushValue(L, value);
		return 1;
	}
}

/// Pops a Tuple from the values at the top of the stack.
T popTuple(T)(lua_State* L) if(isTuple!T)
{
	T tup;
	foreach(i, Elem; T.Types)
		tup[i] = getValue!Elem(L, cast(int)(-T.Types.length + i));
		
	lua_pop(L, T.Types.length);
	return tup;
}

/// Pushes all the values in a Tuple to the stack.
void pushTuple(T)(lua_State* L, ref T tup) if(isTuple!T)
{
	foreach(i, Elem; T.Types)
		pushValue(L, tup[i]);
}

version(unittest) import luad.testing;

unittest
{
	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	
	// pushValue and popValue
	//number
	pushValue(L, cast(ubyte)123);
	assert(lua_isnumber(L, -1) && (popValue!ubyte(L) == 123));
	
	pushValue(L, cast(short)123);
	assert(lua_isnumber(L, -1) && (popValue!short(L) == 123));
	
	pushValue(L, 123);
	assert(lua_isnumber(L, -1) && (popValue!int(L) == 123));
	
	pushValue(L, 123UL);
	assert(lua_isnumber(L, -1) && (popValue!ulong(L) == 123));
	
	pushValue(L, 1.2f);
	assert(lua_isnumber(L, -1) && (popValue!float(L) == 1.2f));

	pushValue(L, 1.23);
	assert(lua_isnumber(L, -1) && (popValue!double(L) == 1.23));
	
	//string
	string istr = "foobar";
	pushValue(L, istr);
	assert(lua_isstring(L, -1) && (popValue!string(L) == "foobar"));
	
	char[] str = "baz".dup;
	pushValue(L, str);
	assert(lua_isstring(L, -1) && (popValue!(char[])(L) == "baz"));
	
	const(char)* cstr = "hi";
	pushValue(L, cstr);
	assert(lua_isstring(L, -1) && (strcmp(cstr, popValue!(const(char)*)(L)) == 0));
	
	//char
	pushValue(L, '\t');
	assert(lua_isstring(L, -1) && getValue!string(L, -1) == "\t");
	assert(popValue!char(L) == '\t');
	
	//boolean
	pushValue(L, true);
	assert(lua_isboolean(L, -1) && (popValue!bool(L) == true));
	
	assert(lua_gettop(L) == 0, "bad popValue semantics for primitives");
	
	//popStack
	extern(C) static int luacfunc(lua_State* L)
	{
		return 0;
	}
	
	pushValue(L, &luacfunc);
	pushValue(L, "test");
	pushValue(L, 123);
	pushValue(L, true);
	
	auto stack = popStack(L);
	assert(lua_gettop(L) == 0);
	assert(stack[0].type == LuaType.Function);
	assert(stack[1].type == LuaType.String);
	assert(stack[2].type == LuaType.Number);
	assert(stack[3].type == LuaType.Boolean);
}