/++
This module takes care of converting between D and Lua types.

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
		$(DD const(char)[] (string), char[])
		$(DD const(char)*)
		$(DD char)
	)
	$(DT table
		$(DD associative arrays)
		$(DD arrays)
		$(DD structs)
		$(DD LuaTable)
	)
	$(DT function
		$(DD function pointers)
		$(DD delegates)
		$(DD LuaFunction)
	)
	$(DT userdata
		$(DD classes)
	)
	$(DT nil
		$(DD the special identifier nil)
		$(DD null LuaObject references)
		$(DD null class references)
	)
	$(DT any of the above
		$(DD LuaObject)
	)
)
The conversions are checked in the specified order. For example, even though bool is implicitly convertible
to lua_Integer, it will be converted to a boolean because boolean has precedence.

Additionally, the following types are pushable to Lua, but can't be retrieved back:
$(DL
	$(DT function
		$(DD lua_CFunction)
	)
)
+/
module luad.stack;

import std.traits;

import luad.c.all;

import luad.base;
import luad.table;
import luad.lfunction;

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
	{
		value.push();
	}
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
	
	else static if(isArray!T || isAssociativeArray!T || is(T == struct) || is(T == LuaTable))
		return LUA_TTABLE;
	
	else static if(isSomeFunction!T || is(T == LuaFunction))
		return LUA_TFUNCTION;
	
	else static if(is(T : Object))
		return LUA_TUSERDATA;
	
	else
		static assert(false, "No Lua type defined for `" ~ T.stringof ~ "`");
}

private void defaultTypeMismatch(lua_State* L, int idx, int expectedType)
{
	luaL_error(L, "expected %s, got %s", lua_typename(L, expectedType), luaL_typename(L, idx));
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

	static if(!is(T : LuaObject) && !isVariant!T)
	{
		int type = lua_type(L, idx);
		int expectedType = luaTypeOf!T();
		if(type != expectedType)
			typeMismatchHandler(L, idx, expectedType);
	}
	
	static if(is(T == LuaFunction)) // WORKAROUND: bug #6036
		return LuaFunction.make(L, idx);
		
	else static if(is(T == LuaObject) || is(T == LuaTable))
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
 * Get all objects on a stack, then clear the stack.
 * Params:
 *	 L = stack to dump
 * Returns:
 *	 array of objects
 */
LuaObject[] getStack(lua_State* L)
{
	int top = lua_gettop(L);
	auto stack = new LuaObject[top];
	foreach(i; 0..top)
	{
		stack[i] = getValue!LuaObject(L, i + 1);
	}
	lua_settop(L, 0);
	return stack;
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

version(unittest) import luad.testing;

unittest
{
	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	
	//	pushValue and popValue
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
	
	//getStack
	extern(C) static int luacfunc(lua_State* L)
	{
		return 0;
	}
	
	pushValue(L, &luacfunc);
	pushValue(L, "test");
	pushValue(L, 123);
	pushValue(L, true);
	
	auto stack = getStack(L);
	assert(lua_gettop(L) == 0);
	assert(stack[0].type == LuaType.Function);
	assert(stack[1].type == LuaType.String);
	assert(stack[2].type == LuaType.Number);
	assert(stack[3].type == LuaType.Boolean);
}