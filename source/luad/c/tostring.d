module luad.c.tostring;

import luad.c.lua, luad.c.lauxlib;

const(char)* luaL_tolstring(lua_State* L, int idx, size_t* len)
{
	if(!luaL_callmeta(L, idx, "__tostring")) /* no metamethod? */
	{
		switch(lua_type(L, idx))
		{
			case LUA_TSTRING, LUA_TNUMBER:
				lua_pushvalue(L, idx);
				break;
			case LUA_TBOOLEAN:
				lua_pushstring(L, (lua_toboolean(L, idx)? "true" : "false"));
				break;
			case LUA_TNIL:
				lua_pushliteral(L, "nil");
				break;
			default:
				lua_pushfstring(L, "%s: %p", luaL_typename(L, idx), lua_topointer(L, idx));
				break;
		}
	}
	return lua_tolstring(L, -1, len);
}