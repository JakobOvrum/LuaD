module luad.table;

import luad.c.all;

import luad.base;
import luad.reference;

import luad.stack;
import luad.conversions.structs;

/// Represents a Lua table.
class LuaTable : LuaObject
{	
	package:
	this(lua_State* L, int idx)
	{
		checkType(L, idx, LUA_TTABLE, "LuaTable");
		super(L, idx);
	}
	
	public:
	/**
	 * Lookup a value in this table or in a sub-table of this table.
	 * Params:
	 *     T = type of value
	 *     args = list of keys, where all keys but the last one should result in a table
	 * Returns:
	 *     t[k] where t is the table for the second-to-last parameter, and k is the last parameter
	 *
	 * Examples:
	 * ----------------------
	auto execute = lua.get!LuaFunction("os", "execute");
	execute(`echo hello, world!`);
	 * ----------------------
	 */
	T get(T, U...)(U args)
	{
		push();
		scope(success) lua_pop(state, 1);
		
		foreach(key; args)
		{
			pushValue(state, key);
			lua_gettable(state, -2);
		}
		
		return popValue!T(state);
	}
	
	/**
	 * Same as calling get!LuaObject with the same arguments.
	 * Examples:
	 * ---------------------
	auto luapath = lua["package", "path"];
	writefln("LUA_PATH:\n%s", luapath);
	 * ---------------------
	 * See_Also:
	 *     get
	 */
	LuaObject opIndex(T...)(T args)
	{
		return get!LuaObject(args);
	}
	
	/**
	 * Sets a key-value pair in this table.
	 * Params:
	 *     key = key to set
	 *     value = value of key
	 */
	void set(T, U)(T key, U value)
	{
		push();
		scope(success) lua_pop(state, 1);
		
		pushValue(state, key);
		pushValue(state, value);
		lua_settable(state, -3);
	}
	
	/**
	 * Sets a key-value pair this table or in a sub-table of this table.
	 * Params:
	 *     value = value to set
	 *     args = list of keys, where all keys but the last one should result in a table
	 * Returns:
	 *     t[k] = value, where t is the table for the second-to-last parameter in args, 
	 *     and k is the last parameter in args
	 *
	 * Examples:
	 * ----------------------
	lua["string", "empty"] = (string s){ return s.length == 0; };
	lua.doString(`assert(string.empty(""))`);
	 * ----------------------
	 */
	void opIndexAssign(T, U...)(T value, U args)
	{
		push();
		scope(success) lua_pop(state, 1);
		
		foreach(i, arg; args)
		{
			static if(i != args.length - 1)
			{
				pushValue(state, arg);
				lua_gettable(state, -2);
			}
		}
		
		pushValue(state, args[$-1]);
		pushValue(state, value);
		lua_settable(state, -3);
	}
	
	/**
	 * Create struct of type T and fill its members with fields from this table.
	 *
	 * Struct fields that are not present in this table are left at their default value.
	 *
	 * Params:
	 *     T = any struct type
	 * 
	 * Returns:
	 *     Newly created struct
	 */
	T toStruct(T)() if (is(T == struct))
	{
		push();
		return popValue!T(state);
	}
	
	/**
	 * Fills a struct's members with fields from this table.
	 * Params:
	 *     s = struct to fill
	 */
	void copyTo(T)(ref T s) if (is(T == struct))
	{
		push();
		fillStruct(state, -1, s);
		lua_pop(L, 1);
	}
	
	/**
	 * Sets the metatable for this table.
	 * Params:
	 *     meta = new metatable
 	 */
	void setMetaTable(LuaTable meta)
	in{ assert(state == meta.state); }
	body
	{
		push();
		meta.push();
		lua_setmetatable(state, -2);
		lua_pop(state, 1);
	}
	
	/**
	 * Gets the metatable for this table.
	 * Returns:
	 *     A reference to the metatable for this table, or null if this table has no metatable.
	 */
	LuaTable getMetaTable()
	{
		push();
		scope(success) lua_pop(state, 1);
		
		return lua_getmetatable(state, -1) == 0? null : popValue!LuaTable(state);
	}
}

unittest
{
	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	
	lua_newtable(L);
	auto t = new LuaTable(L, -1);
	lua_pop(L, 1);
	
	assert(t.type == LuaType.Table);
	
	t.set("foo", "bar");
	assert(t.get!string("foo") == "bar");
	
	t.set("foo", nil);
	assert(t.get!LuaObject("foo").isNil);
	
	t.set("foo", ["outer": ["inner": "hi!"]]);
	auto s = t.get!(string)("foo", "outer", "inner");
	assert(s == "hi!");

	auto o = t["foo", "outer"];
	assert(o.type == LuaType.Table);
	
	t["foo", "outer", "inner"] = "hello!";
	auto s2 = t.get!(string)("foo", "outer", "inner");
	assert(s2 == "hello!");
	
	//metatable
	pushValue(L, ["__index": (LuaObject self, string key){
		return key;
	}]);
	auto meta = popValue!LuaTable(L);
	
	lua_newtable(L);
	auto t2 = new LuaTable(L, -1);
	lua_pop(L, 1);
	
	t2.setMetaTable(meta);
	
	auto test = t2.get!string("foobar");
	assert(test == "foobar");
		
	assert(t2.getMetaTable() == meta);
}