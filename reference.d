module luad.reference;

import luad.c.all;

package struct LuaReference
{
	public:
	int r = LUA_NOREF;
	lua_State* L;
	
	this(lua_State* L, int idx)
	{
		this.L = L;
		
		lua_pushvalue(L, idx);
		r = luaL_ref(L, LUA_REGISTRYINDEX);
	}
	
	this(this)
	{
		push();
		r = luaL_ref(L, LUA_REGISTRYINDEX);
	}
	
	~this()
	{
		luaL_unref(L, LUA_REGISTRYINDEX, r);
	}
	
	void push()
	{
		lua_rawgeti(L, LUA_REGISTRYINDEX, r);
	}
}