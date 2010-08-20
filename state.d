module luad.state;

import std.string;

import luad.c.all;

import luad.table, luad.error;

class LuaState
{
	private:
	lua_State* L;
	LuaTable _G, _R;
	bool owner = true;
	
	public:
	alias globals this;
		
	this()
	{
		lua_State* L = luaL_newstate();
			
		extern(C) static int panic(lua_State* L)
		{
			size_t len;
			const(char)* message = lua_tolstring(L, -1, &len);
			throw new LuaError(cast(string)message[0 .. len]);
		}
		
		lua_atpanic(L, &panic);
		this(L);
	}
	
	this(lua_State* L)
	{
		this.L = L;
		owner = false;
		_G = new LuaTable(L, LUA_GLOBALSINDEX);
		_R = new LuaTable(L, LUA_REGISTRYINDEX);
	}
	
	~this()
	{
		if(owner)
			lua_close(L);
	}
	
	void openLibs()
	{
		luaL_openlibs(L);
	}
	
	@property LuaTable globals()
	{
		return _G;
	}
	
	@property LuaTable registry()
	{
		return _R;
	}
	
	void doString(string code)
	{
		if(luaL_dostring(L, toStringz(code)) == 1)
			lua_error(L);
	}
	
	void doFile(string path)
	{
		if(luaL_dofile(L, toStringz(path)) == 1)
			lua_error(L);
	}
}

unittest
{
	auto lua = new LuaState;
	lua.openLibs();
	
	lua.set("integer", 123);
	assert(lua.get!int("integer") == 123);
	
	bool threw = false;
	try
	{
		lua.get!string("integer");
	}
	catch(LuaError) //expected number, got string
	{
		threw = true;
	}
	
	assert(threw);
	
	lua.doString(`executed = true`);
	assert(lua.get!bool("executed"));
}

