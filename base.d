module luad.base;

import luad.c.all;
import luad.reference;
import luad.stack;

/**
 * Enumerates all Lua types.
 */
enum LuaType
{
	///string
	String = LUA_TSTRING,
	///number
	Number = LUA_TNUMBER,
	//table
	Table = LUA_TTABLE,
	///nil
	Nil = LUA_TNIL,
	///boolean
	Boolean = LUA_TBOOLEAN,
	///function
	Function = LUA_TFUNCTION,
	///userdata
	Userdata = LUA_TUSERDATA,
	///ditto
	LightUserdata = LUA_TLIGHTUSERDATA,
	///thread
	Thread = LUA_TTHREAD
}

package struct Nil{}

/**
 * Special value representing the Lua type and value nil.
 * Examples:
 * Useful for clearing keys in a table:
 * --------------------------
	lua["n"] = 1.23;
	assert(lua.get!double("n") == 1.23);

	lua["n"] = nil;
	assert(lua["n"].type == LuaType.Nil);
 * --------------------------
 */
public Nil nil;

/// Represents a reference to a Lua value of any type
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
	
	static void checkType(lua_State* L, int idx, int expectedType, const(char)* expectedName)
	{
		int t = lua_type(L, idx);
		if(t != expectedType)
		{
			luaL_error(L, "attempt to create %s with %s", expectedName, lua_typename(L, expectedType));
		}
	}
	
	public:
	/**
	 * Type of referenced object
	 * See_Also:
	 *     LuaType
	 */
	@property LuaType type()
	{
		push();
		scope(success) lua_pop(state, 1);
		return cast(LuaType)lua_type(state, -1);
	}
	
	/// Boolean whether or not the referenced object is nil
	@property bool isNil()
	{
		return lref.r == LUA_REFNIL;
	}
	
	/**
	 * Convert the referenced object into a textual representation.
	 *
	 * The returned string is formatted exactly like the Lua 'tostring' function.
	 *
	 * Returns: string representation of referenced object
	 */
	override string toString()
	{
		push();
		scope(success) lua_pop(state, 1);
		
		size_t len;
		const(char)* str = luaL_tolstring(state, -1, &len);
		return str[0 .. len].idup;
	}
	
	/**
	 * Attempt to convert the referenced object to any D type.
	 */
	T to(T)()
	{
		static void typeMismatch(lua_State* L, int t, int e)
		{
			luaL_error(L, "attempt to convert LuaObject with type %s to a %s", lua_typename(L, t), lua_typename(L, e));
		}
		
		push();
		return popValue!(T, typeMismatch)(state);
	}
	
	/**
	 * Compares this object to another with Lua's equality semantics.
	 * Also, if the other object is not a LuaObject or a derived class of LuaObject,
	 * or the two refer to objects in different Lua states, this function returns false.
	 */
	override bool opEquals(Object o)
	{
		LuaObject other = cast(LuaObject)o;
		if(other is null || other.state != state)
			return false;
		
		push();
		other.push();
		scope(success) lua_pop(state, 2);
		return lua_equal(state, -1, -2);
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