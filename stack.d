module luad.stack;

import std.traits;
import std.string : toStringz;

import luad.c.all;

import luad.conversions.tablearray, 
	   luad.conversions.dfunction, 
	   luad.conversions.tablestruct;

/**
 * Push a value of any type
 * Type precedence: 
 *    bool => lua_Integer => lua_Number => string => const(char)* =>
 *    array => struct => function/delegate
 */
void pushValue(T)(lua_State* L, T value)
{
	static if(is(T == bool))
		lua_pushboolean(L, value);
	
	else static if(is(T : lua_Integer))
		lua_pushinteger(L, value);
	
	else static if(is(T : lua_Number))
		lua_pushnumber(L, value);
		
	else static if(is(T : string))
		lua_pushlstring(L, value.ptr, value.length);
	
	else static if(is(T : const(char)*))
		lua_pushstring(L, value);
	
	else static if(isArray!T)
		pushArray(L, value);
	
	else static if(is(T == struct))
		pushStruct(L, value);
	
	else static if(isSomeFunction!T)
		pushFunction(L, value);
	
	else
		static assert(false, "Unsupported type `" ~ T.stringof ~ "` in stack push operation");
}

int luaTypeOf(T)()
{
	static if(is(T == bool))
		return LUA_TBOOLEAN;
	
	else static if(is(T : lua_Integer) || is(T : lua_Number))
		return LUA_TNUMBER;
	
	else static if(is(T : string) || is(T : const(char)*))
		return LUA_TSTRING;
	
	else static if(isArray!T || is(T == struct))
		return LUA_TTABLE;
	
	else
		static assert(false, "No Lua type defined for `" ~ T.stringof ~ "`");
}

/**
 * Get a value of any type from the stack
 * Type precedence is identical to pushValue
 * If T is incompatible with the type of the object on the stack,
 * typeMismatchHandler is called and is expected to error.
 */
private void defaultTypeMismatch(lua_State* L, int type, int expectedType)
{
	luaL_error(L, "expected %s, got %s", lua_typename(L, expectedType), lua_typename(L, type));
}

T getValue(T, alias typeMismatchHandler = defaultTypeMismatch)(lua_State* L, int idx)
{
	debug //ensure intact stack
	{
		int _top = lua_gettop(L);
		scope(success) assert(lua_gettop(L) == _top);
	}
	
	{
		int type = lua_type(L, idx);
		int expectedType = luaTypeOf!T();
		if(type != expectedType)
			typeMismatchHandler(L, type, expectedType);
	}
	
	static if(is(T == bool))
		return lua_toboolean(L, idx);
	
	else static if(is(T : lua_Integer))
		return lua_tointeger(L, idx);
	
	else static if(is(T : lua_Number))
		return lua_tonumber(L, idx);
	
	else static if(is(T : string))
	{
		size_t len;
		const(char*) str = lua_tolstring(L, idx, &len);
		return str[0 .. len].idup;
	}
	else static if(is(T : const(char)*))
		return lua_tostring(L, idx);
	
	else static if(isArray!T)
		return getArray!T(L, idx);
	
	else static if(is(T == struct))
		return getStruct!T(L, idx);
	
	else
	{
		static assert(false, "Unsupported type `" ~ T.stringof ~ "` in stack read operation");
	}
}

/**
 * Pops a value of any type from the top of the stack
 */
T popValue(T)(lua_State* L)
{
	scope(success) lua_pop(L, 1);
	return getValue!T(L, -1);
}

version(unittest)
{
	import std.c.string : strcmp;
	
	void unittest_lua(lua_State* L, string code, string chunkName)
	{
		if(luaL_loadbuffer(L, code.ptr, code.length, toStringz("@" ~ chunkName)) != 0)
			lua_error(L);
		
		lua_call(L, 0, 0);
	}
}

unittest
{
	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	
	//primitives	
	pushValue(L, 123);
	assert(lua_isnumber(L, -1) && (popValue!int(L) == 123));
	
	pushValue(L, 1.23);
	assert(lua_isnumber(L, -1) && (popValue!double(L) == 1.23));
	
	pushValue(L, "foobar");
	assert(lua_isstring(L, -1) && (popValue!string(L) == "foobar"));
	
	pushValue(L, true);
	assert(lua_isboolean(L, -1) && (popValue!bool(L) == true));
	
	const(char)* cstr = "hi";
	pushValue(L, cstr);
	assert(lua_isstring(L, -1) && (strcmp(cstr, popValue!(const(char)*)(L)) == 0));
	
	assert(lua_gettop(L) == 0, "bad popValue semantics for primitives");
}