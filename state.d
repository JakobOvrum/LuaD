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
		
		lua_pushlightuserdata(L, cast(void*)this);
		lua_setfield(L, LUA_REGISTRYINDEX, "__dstate");
	}
	
	~this()
	{
		if(owner)
			lua_close(L);
	}
	
	/**
	 * Get the LuaState instance for a Lua state.
	 * Params:
	 *     L = Lua state
	 * Returns:
	 *     LuaState for the given lua_State*.
	 */
	static LuaState fromPointer(lua_State* L)
	{
	    lua_getfield(L, LUA_REGISTRYINDEX, "__dstate");
	    scope(exit) lua_pop(L, 1);
	    return cast(LuaState)lua_touserdata(L, -1);
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
	 * Set a new panic handler.
	 * Params:
	 *     onPanic = new panic handler
	 */
	void setPanicHandler(void function(LuaState, string) onPanic)
	{
	    extern(C) static int panic(lua_State* L)
	    {
            size_t len;
			const(char)* message = lua_tolstring(L, -1, &len);
			auto error = message[0 .. len].idup;
	        
	        lua_getfield(L, LUA_REGISTRYINDEX, "__dpanic");
	        auto callback = cast(void function(LuaState, string))lua_touserdata(L, -1);
	        assert(callback);
	        
	        callback(LuaState.fromPointer(L), error);
	        return 0;
	    }
	    
	    lua_pushlightuserdata(L, onPanic);
	    lua_setfield(L, LUA_REGISTRYINDEX, "__dpanic");
	    
	    lua_atpanic(L, &panic);
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
	
	/**
	 * Create a new, empty table.
	 * Returns:
	 *     new table
	 */
	LuaTable newTable()
	{
		return newTable(0, 0);
	}
	
	/**
	 * Create a new, empty table with pre-allocated space for members.
	 * Params:
	 *     narr = number of pre-allocated array slots
	 *     nrec = number of pre-allocated non-array slots
	 * Returns:
	 *     new table
	 */
	LuaTable newTable(uint narr, uint nrec)
	{
		lua_createtable(L, narr, nrec);
		return popValue!LuaTable(L);
	}
	
	/**
	 * Wrap a D value in a LuaObject.
	 * Params:
	 *     value = D value to wrap
	 * Returns:
	 *     reference to value as a LuaObject
	 */
    LuaObject wrap(T)(T value)
    {
        pushValue(L, value);
        return popValue!T(L);
    }
	
	/**
	 * You can use this state as a table to operate on its global table.
	 */
	/**
	 * Same as calling globals.get with the same arguments.
	 * See Also:
	 *     LuaTable.get
	 */
	T get(T, U...)(U args)
	{
		return globals.get!T(args);
	}
	
	/**
	 * Same as calling globals.get!LuaObject with the same arguments.
	 * See Also:
	 *     LuaTable.opIndex
	 */
	LuaObject opIndex(T...)(T args)
	{
		return globals.get!LuaObject(args);
	}
	
	/**
	 * Same as calling globals.set with the same arguments.
	 * See Also:
	 *     LuaTable.set
	 */
	void set(T, U)(T key, U value)
	{
		globals.set(key, value);
	}
	
	/**
	 * Same as calling globals.opIndexAssign with the same arguments.
	 * See Also:
	 *     LuaTable.opIndexAssign
	 */
	void opIndexAssign(T, U...)(T value, U args)
	{
		globals()[args] = value;
	}
}

unittest
{
	auto lua = new LuaState;
	assert(LuaState.fromPointer(lua.L) == lua);
	
	lua.openLibs();
	
	//default panic handler
	string msg;
	try
	{
		lua.doString(`error("Hello, D!")`);
	}
	catch(LuaError e)
	{
		assert(e.msg == `[string "error("Hello, D!")"]:1: Hello, D!`);
	}
	
	
	lua.set("success", false);
	assert(!lua.get!bool("success"));
	
	lua.doString(`success = true`);
	assert(lua.get!bool("success"));
	
	// setPanicHandler
	static void panic(LuaState lua, string error)
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