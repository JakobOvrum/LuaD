module luad.table;

import luad.c.all;

import luad.base;
import luad.stack;
import luad.conversions.structs;

/// Represents a Lua table.
struct LuaTable
{
	/// LuaTable sub-types LuaObject through this reference.
	LuaObject object;
	alias object this;
	
	package this(lua_State* L, int idx)
	{
		LuaObject.checkType(L, idx, LUA_TTABLE, "LuaTable");
		object = LuaObject(L, idx);
	}
	
	/**
	 * Lookup a value in this table or in a sub-table of this table.
	 * Params:
	 *	 T = type of value
	 *	 args = list of keys, where all keys but the last one should result in a table
	 * Returns:
	 *	 t[k] where t is the table for the second-to-last parameter, and k is the last parameter
	 *
	 * Examples:
	 * ----------------------
	auto execute = lua.get!LuaFunction("os", "execute");
	execute(`echo hello, world!`);
	 * ----------------------
	 */
	T get(T, U...)(U args)
	{
		this.push();
		
		foreach(key; args)
		{
			pushValue(this.state, key);
			lua_gettable(this.state, -2);
		}
		
		auto ret = getValue!T(this.state, -1);
		lua_pop(this.state, args.length + 1);
		return ret;
	}
	
	/**
	 * Read a string value in this table without making a copy of the string.
	 * The read string is passed to dg, and should not be escaped.
	 * If the value for key is not a string, dg is not called.
	 * Params:
	 *    key = lookup _key
	 *    dg = delegate to receive string
	 * Returns:
	 *    true if the value for key was a string and passed to dg, false otherwise
	 * Examples:
	 --------------------
	 t[2] = "two";
	 t.readString(2, (in char[] str) {
		assert(str == "two");
	 });
	 --------------------
	 */
	bool readString(T)(T key, scope void delegate(in char[] str) dg)
	{
		this.push();
		scope(exit) lua_pop(this.state, 1);
		
		pushValue(this.state, key);
		
		lua_gettable(this.state, -2);
		scope(exit) lua_pop(this.state, 1);
		
		size_t len;
		const(char)* cstr = lua_tolstring(this.state, -1, &len);
		if(cstr is null)
			return false;
		
		dg(cstr[0 .. len]);
		return true;
	}
	
	/**
	 * Same as calling get!LuaObject with the same arguments.
	 * Examples:
	 * ---------------------
	auto luapath = lua["package", "path"];
	writefln("LUA_PATH:\n%s", luapath);
	 * ---------------------
	 * See_Also:
	 *	 get
	 */
	LuaObject opIndex(T...)(T args)
	{
		return get!LuaObject(args);
	}
	
	/**
	 * Set a key-value pair in this table.
	 * Params:
	 *	 key = key to _set
	 *	 value = value of key
	 */
	void set(T, U)(T key, U value)
	{
		this.push();
		scope(success) lua_pop(this.state, 1);
		
		pushValue(this.state, key);
		pushValue(this.state, value);
		lua_settable(this.state, -3);
	}
	
	/**
	 * Set a key-value pair this table or in a sub-table of this table.
	 * Params:
	 *	 value = value to set
	 *	 args = list of keys, where all keys but the last one should result in a table
	 * Returns:
	 *	 t[k] = value, where t is the table for the second-to-last parameter in args, 
	 *	 and k is the last parameter in args
	 *
	 * Examples:
	 * ----------------------
	lua["string", "empty"] = (const(char)[] s){ return s.length == 0; };
	lua.doString(`assert(string.empty(""))`);
	 * ----------------------
	 */
	void opIndexAssign(T, U...)(T value, U args)
	{
		this.push();
		scope(success) lua_pop(this.state, 1);
		
		foreach(i, arg; args)
		{
			static if(i != args.length - 1)
			{
				pushValue(this.state, arg);
				lua_gettable(this.state, -2);
			}
		}
		
		pushValue(this.state, args[$-1]);
		pushValue(this.state, value);
		lua_settable(this.state, -3);

		lua_pop(this.state, args.length - 1);
	}
	
	/**
	 * Create struct of type T and fill its members with fields from this table.
	 *
	 * Struct fields that are not present in this table are left at their default value.
	 *
	 * Params:
	 *	 T = any struct type
	 * 
	 * Returns:
	 *	 Newly created struct
	 */
	T toStruct(T)() if (is(T == struct))
	{
		push();
		return popValue!T(this.state);
	}
	
	/**
	 * Fill a struct's members with fields from this table.
	 * Params:
	 *	 s = struct to fill
	 */
	void copyTo(T)(ref T s) if (is(T == struct))
	{
		push();
		fillStruct(this.state, -1, s);
		lua_pop(L, 1);
	}
	
	/**
	 * Set the metatable for this table.
	 * Params:
	 *	 meta = new metatable
 	 */
	void setMetaTable(ref LuaTable meta)
	in{ assert(this.state == meta.state); }
	body
	{
		this.push();
		meta.push();
		lua_setmetatable(this.state, -2);
		lua_pop(this.state, 1);
	}
	
	/**
	 * Get the metatable for this table.
	 * Returns:
	 *	 A reference to the metatable for this table. The reference is nil if this table has no metatable.
	 */
	LuaTable getMetaTable()
	{
		this.push();
		scope(success) lua_pop(this.state, 1);
		
		return lua_getmetatable(this.state, -1) == 0? LuaTable() : popValue!LuaTable(this.state);
	}
	
	/**
	 * Iterate over the values in this table.
	 */
	int opApply(T)(int delegate(ref T value) dg)
	{
		this.push();
		lua_pushnil(this.state);
		while(lua_next(this.state, -2) != 0)
		{
			auto value = popValue!T(this.state);
			int result = dg(value);
			if(result != 0)
			{
				lua_pop(this.state, 2);
				return result;
			}
		}
		lua_pop(this.state, 1);
		return 0;
	}
	
	/**
	 * Iterate over the key-value pairs in this table.
	 */
	int opApply(T, U)(int delegate(ref U key, ref T value) dg)
	{
		this.push();
		lua_pushnil(this.state);
		while(lua_next(this.state, -2) != 0)
		{
			auto value = popValue!T(this.state);
			auto key = getValue!U(this.state, -1);
			 
			int result = dg(key, value);
			if(result != 0)
			{
				lua_pop(this.state, 2);
				return result;
			}
		}
		lua_pop(this.state, 1);
		return 0;
	}
}

unittest
{
	lua_State* L = luaL_newstate();
	scope(success)
	{
		assert(lua_gettop(L) == 0);
		lua_close(L);
	}
	
	lua_newtable(L);
	auto t = popValue!LuaTable(L);
	
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
	
	// readString
	t[2] = "two";
	bool success = t.readString(2, (in char[] str) {
		assert(str == "two");
	});
	assert(success);
	
	t[2] = true;
	success = t.readString(2, (in char[] str) { assert(false); });
	assert(!success);
	
	// metatable
	pushValue(L, ["__index": (LuaObject self, string key){
		return key;
	}]);
	auto meta = popValue!LuaTable(L);
	
	lua_newtable(L);
	auto t2 = popValue!LuaTable(L);
	
	t2.setMetaTable(meta);
	
	auto test = t2.get!string("foobar");
	assert(test == "foobar");
		
	assert(t2.getMetaTable().equals(meta));
	
	// opApply
	auto input = [1, 2, 3];
	pushValue(L, input);
	auto applyTest = popValue!LuaTable(L);
	
	int i = 0;
	foreach(int v; applyTest)
	{
		assert(input[i++] == v);
	}
	
	auto inputWithKeys = ["one": 1, "two": 2, "three": 3];
	pushValue(L, inputWithKeys);
	auto applyTestKeys = popValue!LuaTable(L);
	
	foreach(string key, int value; applyTestKeys)
	{
		assert(inputWithKeys[key] == value);
	}
}