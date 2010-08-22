module luad.conversions.functions;

import core.memory;
import std.traits;
import std.string : toStringz;
import luad.c.all;

import luad.stack;

private extern(C) int functionWrapper(T)(lua_State* L)
{
	T func = *cast(T*)lua_touserdata(L, lua_upvalueindex(1));
	
	//Assemble arguments
	ParameterTypeTuple!T args;
	foreach(i, arg; args)
	{
		void typeMismatch(lua_State* L, int t, int e)
		{
			luaL_error(L, "bad argument #%d (got %s, expected %s)", i + 1, lua_typename(L, t), lua_typename(L, e));
		}
		
		args[i] = getValue!(typeof(arg), typeMismatch)(L, i + 1);
	}
	
	//Call with or without return value
	alias ReturnType!T RetType;
	enum hasReturnValue = !is(RetType == void);
	
	static if(hasReturnValue)
			RetType ret;
	try
	{
		static if(hasReturnValue)
			ret = func(args);
		else
			func(args);
	}
	catch(Exception e)
	{
		luaL_error(L, "%s", toStringz(e.toString()));
	}
	
	static if(hasReturnValue)
		pushValue(L, ret);
	
	return hasReturnValue? 1 : 0;
}

private extern(C) int functionCleaner(lua_State* L)
{
	GC.removeRoot(lua_touserdata(L, 1));
	return 0;
}

void pushFunction(T)(lua_State* L, T func) if (isSomeFunction!T)
{	
	T* udata = cast(T*)lua_newuserdata(L, T.sizeof);
	*udata = func;
	GC.addRoot(udata);
	
	if(luaL_newmetatable(L, "__dcall") == 1)
	{
		lua_pushcfunction(L, &functionCleaner); 
		lua_setfield(L, -2, "__gc");
	}
	
	lua_setmetatable(L, -2);
	
	lua_pushcclosure(L, &functionWrapper!T, 1);
}

/**
 * Currently this function allocates a reference in the registry that is never deleted,
   one for each call...
 */
T getFunction(T)(lua_State* L, int idx) if (is(T == delegate))
{
	alias ReturnType!T RetType;
	enum hasReturnValue = !is(RetType == void);
	
	alias ParameterTypeTuple!T Args;
	
	auto func = new class
	{
		int lref;
		this()
		{
			lua_pushvalue(L, idx);
			lref = luaL_ref(L, LUA_REGISTRYINDEX);
		}
		
		~this()
		{
			//Alright... how to fix this!?
			//luaL_unref(L, LUA_REGISTRYINDEX, lref);
		}
		
		void push()
		{
			lua_rawgeti(L, LUA_REGISTRYINDEX, lref);
		}
	};
	
	return delegate RetType(Args args)
	{
		func.push();
		
		foreach(arg; args)
			pushValue(L, arg);
		
		lua_call(L, args.length, hasReturnValue? 1 : 0);
		static if(hasReturnValue)
			return popValue!RetType(L);
	};
}

unittest
{
	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	luaL_openlibs(L);
	
	//functions
	static string func(string s)
	{
		return "Hello, " ~ s;
	}
	
	pushValue(L, &func);
	assert(lua_isfunction(L, -1));
	lua_setglobal(L, "sayHello");
	
	unittest_lua(L, `
		local ret = sayHello("foo")
		local expect = "Hello, foo"
		assert(ret == expect, 
			("sayHello return type - got '%s', expected '%s'"):format(ret, expect)
		)
	`, __FILE__);
	
	//delegates
	double curry = 3.14 * 2;
	double closure(double x)
	{
		return curry * x;
	}
	
	pushValue(L, &closure);
	assert(lua_isfunction(L, -1));
	lua_setglobal(L, "circle");
	
	unittest_lua(L, `
		assert(circle(2) == 3.14 * 4, "closure return type mismatch!")
	`, __FILE__);
	
	{
		lua_getglobal(L, "string");
		lua_getfield(L, -1, "match");
		auto match = popValue!(string delegate(string, string))(L); 
		lua_pop(L, 1);
		
		auto result = match("foobar@example.com", "([^@]+)@example.com");
		assert(result == "foobar");
	}
}