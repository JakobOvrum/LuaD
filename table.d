module luad.table;

import luad.c.all;

import luad.reference;
import luad.stack;

class LuaTable
{
	private:
	LuaReference lref;
	
	package this(lua_State* L, int idx)
	{
		lref = LuaReference(L, idx);
	}
	
	public:
	T get(T, U)(U key)
	{
		lref.push();
		scope(success) lua_pop(lref.L, 1);
		
		pushValue(lref.L, key);
		lua_gettable(lref.L, -2);
		
		return popValue!T(lref.L);
	}
	
	void set(T, U)(T key, U value)
	{
		lref.push();
		scope(success) lua_pop(lref.L, 1);
		
		pushValue(lref.L, key);
		pushValue(lref.L, value);
		lua_settable(lref.L, -3);
	}
}