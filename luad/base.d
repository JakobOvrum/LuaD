module luad.base;

import luad.c.all;
import luad.stack;

import std.c.string : strlen;

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

/**
 * Represents a reference to a Lua value of any type.
 * It contains only the bare minimum of functionality which all Lua values support.
 * For a generic reference type with more functionality, see $(LINKMODULE2 dynamic,LuaDynamic).
 */
struct LuaObject
{
	private:
	int r = LUA_REFNIL;
	lua_State* L = null;
		
	package:
	this(lua_State* L, int idx)
	{
		this.L = L;
		
		lua_pushvalue(L, idx);
		r = luaL_ref(L, LUA_REGISTRYINDEX);
	}
	
	void push()
	{
		lua_rawgeti(L, LUA_REGISTRYINDEX, r);
	}
	
	lua_State* state() @property
	{
		return L;
	}
	
	static void checkType(lua_State* L, int idx, int expectedType, const(char)* expectedName)
	{
		int t = lua_type(L, idx);
		if(t != expectedType)
		{
			luaL_error(L, "attempt to create %s with %s", expectedName, lua_typename(L, t));
		}
	}
	
	public:
	this(this)
	{
		push();
		r = luaL_ref(L, LUA_REGISTRYINDEX);
	}
	
	~this()
	{
		luaL_unref(L, LUA_REGISTRYINDEX, r);
	}
	
	/**
	 * Release this reference.
	 *
	 * This reference becomes a nil reference.
	 * This is only required when you want to release the reference before the lifetime
	 * of this LuaObject has ended.
	 */
	void release()
	{
		r = LUA_REFNIL;
		L = null;
	}
	
	/**
	 * Type of referenced object.
	 * See_Also:
	 *	 LuaType
	 */
	@property LuaType type()
	{
		push();
		scope(success) lua_pop(state, 1);
		return cast(LuaType)lua_type(state, -1);
	}
	
	/**
	 * Type name of referenced object.
	 */
	@property string typeName()
	{
		push();
		scope(success) lua_pop(state, 1);
		const(char)* name = luaL_typename(state, -1);
		return name[0.. strlen(name)].idup;
	}
	
	/// Boolean whether or not the referenced object is nil.
	@property bool isNil()
	{
		return r == LUA_REFNIL;
	}
	
	/**
	 * Convert the referenced object into a textual representation.
	 *
	 * The returned string is formatted exactly like the Lua 'tostring' function.
	 *
	 * Returns:
	 * String representation of referenced object
	 */
	string toString()
	{
		push();
		scope(success) lua_pop(state, 1);
		
		size_t len;
		const(char)* str = luaL_tolstring(state, -1, &len);
		return str[0 .. len].idup;
	}
	
	/**
	 * Attempt _to convert the referenced object _to any D type.
	 * Examples:
	 -----------------------
	auto results = lua.doString(`return "hello!"`);
	assert(results[0].to!string() == "hello!");
	 -----------------------
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
	 * Compare this object to another with Lua's equality semantics.
	 * Also returns false if the two objects are in different Lua states. 
	 */
	bool equals(ref LuaObject o)
	{
		if(o.state != this.state)
			return false;
		
		push();
		o.push();
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
