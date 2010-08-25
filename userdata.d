module luad.userdata;

import luad.c.all;
import luad.stack;

import std.string : toStringz;

private void pushMeta(T)(lua_State* L)
{
	if(luaL_newmetatable(L, toStringz("__" ~ T.mangleof)) == 0)
		return;
	
	lua_newtable(L); //__index fallback table
	
	foreach(member; __traits(allMembers, T))
	{
		pragma(msg, member);
		static if(member != "this")
		{
			static if(!__traits(isStaticFunction, mixin("T." ~ member)))
			{
				//pragma(msg, member);
			}
		}
	}
}

void pushClass(T)(lua_State* L, T o) if (is(T == class))
{	
	void** ud = cast(void**)lua_newuserdata(L, o.sizeof);
	*ud = cast(void*)o;
	
	pushMeta!T(L);

	lua_setmetatable(L, -2);
}

unittest
{
	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	
	class A
	{
		public:
		int a;
		string s;
		
		this(int a, string s)
		{
			this.a = a, this.s = s;
		}
		
		string foo(){ return s; }
		
		int bar(int b)
		{
			return a += b;
		}
	}
	
	/*auto o = new A(2, "foo");
	pushClass(L, o);
	lua_setglobal(L, "o");*/
}