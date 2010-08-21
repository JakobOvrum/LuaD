module luad.base;

import luad.c.all;
import luad.reference;
import luad.stack;

enum LuaType
{
	String = LUA_TSTRING,
	Number = LUA_TNUMBER,
	Table = LUA_TTABLE,
	Nil = LUA_TNIL,
	Boolean = LUA_TBOOLEAN,
	Function = LUA_TFUNCTION,
	Userdata = LUA_TUSERDATA,
	LightUserdata = LUA_TLIGHTUSERDATA,
	Thread = LUA_TTHREAD
}

package struct Nil{}
public Nil nil;

class LuaObject
{
	private:
	LuaReference lref;
		
	package:
	this(lua_State* L, int idx)
	{
		lref = LuaReference(L, idx);
	}
	
	protected:
	void push()
	{
		lref.push();
	}
	
	@property lua_State* state()
	{
		return lref.L;
	}
	
	public:
	@property LuaType type()
	{
		push();
		scope(success) lua_pop(state, 1);
		return cast(LuaType)lua_type(state, -1);
	}
	
	@property bool isNil()
	{
		return lref.r == LUA_REFNIL;
	}
		
	override string toString()
	{
		push();
		scope(success) lua_pop(state, 1);
		
		size_t len;
		const(char)* str = luaL_tolstring(state, -1, &len);
		return str[0 .. len].idup;
	}
	
	T to(T)()
	{
		static void typeMismatch(lua_State* L, int t, int e)
		{
			luaL_error(L, "attempt to convert LuaObject with type %s to a %s", lua_typename(L, t), lua_typename(L, e));
		}
		
		push();
		return popValue!(T, typeMismatch)(state);
	}
}

unittest
{
	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	
	lua_pushstring(L, "foobar");
	auto o = new LuaObject(L, -1);
	lua_pop(L, 1);
	
	assert(o.type == LuaType.String);
	assert(o.to!string == "foobar");
	
	lua_pushnil(L);
	auto nilref = new LuaObject(L, -1);
	lua_pop(L, 1);
	
	assert(nilref.isNil);
}