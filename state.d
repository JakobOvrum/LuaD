module luad.state;

import std.string;

import luad.c.all;
import luad.stack;

import luad.table, luad.error;

/**
 * Represents a Lua state instance.
 */
class LuaState
{
	private:
	lua_State* L;
	LuaTable _G, _R;
	bool owner = false;
	
	public:
	/**
	 * You can use this state as a table to operate on its global table.
	 */
	alias globals this;
	
	/**
	 * Create a new, empty Lua state. The standard library is not loaded.
	 *
	 * If an uncaught error for any operation on this state
	 * causes a Lua panic for the underlying state, 
	 * an exception of type LuaError is thrown.
	 *
	 * See_Also: openLibs
	 */
	this()
	{
		lua_State* L = luaL_newstate();
		owner = true;
		
		extern(C) static int panic(lua_State* L)
		{
			size_t len;
			const(char)* message = lua_tolstring(L, -1, &len);
			throw new LuaError(message[0 .. len].idup);
		}
		
		lua_atpanic(L, &panic);
		
		this(L);
	}
	
	/**
	 * Create a D wrapper for an existing Lua state.
	 *
	 * The new LuaState does not assume ownership of the state.
	 *
	 * Note: 
	 *     The panic function is not changed - a Lua panic will not throw a D exception!
	 * Params:
	 *     L = state to wrap.
	 */
	this(lua_State* L)
	{
		this.L = L;
		_G = new LuaTable(L, LUA_GLOBALSINDEX);
		_R = new LuaTable(L, LUA_REGISTRYINDEX);
	}
	
	~this()
	{
		if(owner)
			lua_close(L);
	}
	
	/// Opens the standard library.
	void openLibs()
	{
		luaL_openlibs(L);
	}
	
	/// The global table for this instance.
	@property LuaTable globals()
	{
		return _G;
	}
	
	/// The registry table for this instance.
	@property LuaTable registry()
	{
		return _R;
	}
	
	/**
	 * Execute a string of Lua code.
	 * Params:
	 *     code = code to run
	 */
	void doString(string code)
	{
		if(luaL_dostring(L, toStringz(code)) == 1)
			lua_error(L);
	}
	
	/**
	 * Execute a file of Lua code.
	 * Params:
	 *     path = path to file
	 */
	void doFile(string path)
	{
		if(luaL_dofile(L, toStringz(path)) == 1)
			lua_error(L);
	}
	
	LuaTable newTable()
	{
		return newTable(0, 0);
	}
	
	LuaTable newTable(uint narr, uint nrec)
	{
		lua_createtable(L, narr, nrec);
		return popValue!LuaTable(L);
	}
}

unittest
{
	auto lua = new LuaState;
	lua.openLibs();
	
	string msg;
	try
	{
		lua.doString(`error("Hello, D!")`);
	}
	catch(LuaError e)
	{
		msg = e.msg;
	}
	assert(msg == `[string "error("Hello, D!")"]:1: Hello, D!`);
	
	lua.set("success", false);
	assert(!lua.get!bool("success"));
	
	lua.doString(`success = true`);
	assert(lua.get!bool("success"));
}