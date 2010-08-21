module luad.state;

import std.string;

import luad.c.all;

import luad.table, luad.error;

class LuaState
{
	private:
	lua_State* L;
	LuaTable _G, _R;
	bool owner = false;
	
	public:
	alias globals this;
		
	this()
	{
		lua_State* L = luaL_newstate();
		owner = true;
			
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
		_G = new LuaTable(L, LUA_GLOBALSINDEX);
		_R = new LuaTable(L, LUA_REGISTRYINDEX);
		
		lua_pushlightuserdata(L, cast(void*)this);
		lua_setfield(L, LUA_REGISTRYINDEX, "__luadstate");
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

import std.stdio;
import luad.base;
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