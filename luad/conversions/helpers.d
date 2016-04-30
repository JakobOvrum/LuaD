/**
Various helper functions, templates, and common code used by the conversion routines.
*/
module luad.conversions.helpers;

import luad.conversions.functions;

import luad.c.all;
import luad.all;

import core.memory;

import std.traits;
import std.typetuple;

package:

// resolves the proper return type for functions that return inout(T)
template InOutReturnType(alias func, T)
{
	alias InOutReturnType = typeof((){
		ReturnType!func function(inout Unqual!T) f;
		T t;
		return f(t);
	}());
}

// Note: should we only consider @property functions?
enum isGetter(alias m) = !is(ReturnType!m == void) && ParameterTypeTuple!(m).length == 0;// && isProperty!m;
enum isSetter(alias m) = is(ReturnType!m == void) && ParameterTypeTuple!(m).length == 1;// && isProperty!m;

template GetterType(T, string member)
{
	// TODO: parse the overloads, find the getter, ie, function matching T() (only allow @property?)
	//       (currently this only works if the getter appears first)
	static if(isProperty!(T, member))
		alias GetterType = InOutReturnType!(mixin("T."~member), T);
	else
		alias GetterType = typeof(mixin("T."~member));
}

template SetterTypes(T, string member)
{
	// find setter overloads
	template Impl(Overloads...)
	{
		static if(Overloads.length == 0)
			alias Impl = TypeTuple!();
		else static if(isSetter!(Overloads[0]))
			alias Impl = TypeTuple!(ParameterTypeTuple!(Overloads[0])[0], Impl!(Overloads[1..$]));
		else
			alias Impl = TypeTuple!(Impl!(Overloads[1..$]));
	}

	// TODO: do all overloads need to be properties?
	//       perhaps this should be changed to isMemberFunction, and add an isProperty filter to isSetter?
	static if(isProperty!(T, member))
		alias SetterTypes = Impl!(__traits(getOverloads, T, member));
	else
		alias SetterTypes = TypeTuple!(typeof(mixin("T."~member)));
}

template MethodsExclusingProperties(T, string member)
{
	// TODO: this should be used when populating methods. it should filter out getter/setter overloads
	alias MethodsExclusingProperties = Alias!(__traits(getOverloads, T, member));
}

struct Ref(T)
{
	alias __instance this;

	this(ref T s) { ptr = &s; }

	@property ref T __instance() { return *ptr; }

private:
	T* ptr;
}

alias AliasMember(T, string member) = Alias!(__traits(getMember, T, member));

enum isInternal(string field) = field.length >= 2 && field[0..2] == "__";
enum isMemberFunction(T, string member) = mixin("is(typeof(&T.init." ~ member ~ ") == delegate)");
enum isUserStruct(T) = is(T == struct) && !is(T == LuaObject) && !is(T == LuaTable) && !is(T == LuaDynamic) && !is(T == LuaFunction) && !is(T == Ref!S, S);
enum isValueType(T) = isUserStruct!T || isStaticArray!T;

enum canRead(T, string member) = mixin("__traits(compiles, (T* a) => a."~member~")");
template canCall(T, string member)
{
	// TODO: this is neither robust, nor awesome. surely there is a better way than this...?
	static if(mixin("is(typeof(T."~member~") == const)"))
		enum canCall = !is(T == shared);
	else static if(mixin("is(typeof(T."~member~") == immutable)"))
		enum canCall = is(T == immutable);
	else static if(mixin("is(typeof(T."~member~") == shared)"))
		enum canCall = is(T == shared);
	else
		enum canCall = !is(T == const) && !is(T == immutable) && !is(T == shared);
}
// TODO: in the presence of a setter property with no getter, '= typeof(T.member).init' doesn't work
//       we need to use the setter's argument type instead...
enum canWrite(T, string member) = mixin("__traits(compiles, (cast(T*)null)."~member~" = typeof(T."~member~").init)");

template isOperator(string field)
{
	enum isOperator = field == "toString" ||
	                  field == "toHash" ||
	                  field == "opEquals" ||
	                  field == "opCmp" ||
	                  field == "opCall" ||
	                  field == "opUnary" ||
	                  field == "opBinary" ||
	                  field == "opBinaryRight" ||
	                  field == "opAssign" ||
	                  field == "opOpAssign" ||
	                  field == "opDispatch";
}

template isProperty(T, string member)
{
	static if(isMemberFunction!(T, member))
		enum isProperty = functionAttributes!(mixin("T.init." ~ member)) & FunctionAttribute.property;
	else
		enum isProperty = false;
}

template skipMember(T, string member)
{
	static if(isInternal!member ||
			  isOperator!member ||
			  member == "this" ||
			  mixin("is(T."~member~")") ||
			  __traits(getProtection, __traits(getMember, T, member)) != "public")
		enum skipMember = true;
	else
		enum skipMember = hasAttribute!(__traits(getMember, T, member), noscript) >= 0;
}

template returnsRef(F...)
{
	static if(isSomeFunction!(F[0]))
		enum returnsRef = !!(functionAttributes!(F[0]) & FunctionAttribute.ref_);
	else
		enum returnsRef = false;
}

template hasAttribute(alias x, alias attr)
{
	template typeImpl(int i, A...)
	{
		static if(A.length == 0)
			enum typeImpl = -1;
		else static if(is(A[0]))
			enum typeImpl = is(A[0] == attr) ? i : typeImpl!(i+1, A[1..$]);
		else
			enum typeImpl = is(typeof(A[0]) == attr) ? i : typeImpl!(i+1, A[1..$]);
	}
	template valImpl(int i, A...)
	{
		static if(A.length == 0)
			enum valImpl = -1;
		else static if(is(A[0]) || !is(typeof(A[0]) : typeof(attr)))
			enum valImpl = valImpl!(i+1, A[1..$]);
		else
			enum valImpl = A[0] == attr ? i : valImpl!(i+1, A[1..$]);
	}
	static if(is(attr))
		enum hasAttribute = typeImpl!(0, __traits(getAttributes, x));
	else
		enum hasAttribute = valImpl!(0, __traits(getAttributes, x));
}

template getAttribute(alias x, size_t i)
{
	alias Attrs = TypeTuple!(__traits(getAttributes, x));
	static if(is(Attrs[i]))
		alias getAttribute = TypeTuple!(Attrs[i]);
	else
		enum getAttribute = TypeTuple!(Attrs[i]);
}


void pushGetter(T, string member)(lua_State* L)
{
	alias RT = GetterType!(T, member);

	static if(is(T == class))
	{
		final class X
		{
			static if((!isMemberFunction!(T, member) || returnsRef!(AliasMember!(T, member))) && isUserStruct!RT)
			{
				ref RT get()
				{
					T _this = *cast(T*)&this;
					return mixin("_this."~member);
				}
			}
			else
			{
				RT get()
				{
					T _this = *cast(T*)&this;
					return mixin("_this."~member);
				}
			}
		}
	}
	else
	{
		struct X
		{
			static if((!isMemberFunction!(T, member) || returnsRef!(AliasMember!(T, member))) && isUserStruct!RT)
			{
				ref RT get()
				{
					T* _this = cast(T*)&this;
					return mixin("_this."~member);
				}
			}
			else
			{
				RT get()
				{
					T* _this = cast(T*)&this;
					return mixin("_this."~member);
				}
			}
		}
	}

	lua_pushlightuserdata(L, (&X.init.get).funcptr);
	lua_pushcclosure(L, &methodWrapper!(typeof(&X.init.get), T, false), 1);
}

void pushSetter(T, string member)(lua_State* L)
{
	alias OverloadTypes = SetterTypes!(T, member);
	static assert(OverloadTypes.length, T.stringof~"."~member~": no setters?! shouldn't be here...");

	// TODO: This is broken if there are setter overloads, we need to support overloads eventually...
	static if(OverloadTypes.length > 1)
		pragma(msg, T.stringof~"."~member~" has overloaded setter: "~OverloadTypes.stringof);
	alias ArgType = OverloadTypes[0];

	static if(is(T == class))
	{
		final class X
		{
			static if(isUserStruct!ArgType)
			{
				final void set(ref ArgType value)
				{
					T _this = *cast(T*)&this;
					mixin("_this."~member) = value;
				}
			}
			else
			{
				final void set(ArgType value)
				{
					T _this = *cast(T*)&this;
					mixin("_this."~member) = value;
				}
			}
		}
	}
	else
	{
		struct X
		{
			static if(isUserStruct!ArgType)
			{
				void set(ref ArgType value)
				{
					T* _this = cast(T*)&this;
					mixin("_this."~member) = value;
				}
			}
			else
			{
				void set(ArgType value)
				{
					T* _this = cast(T*)&this;
					mixin("_this."~member) = value;
				}
			}
		}
	}

	lua_pushlightuserdata(L, (&X.init.set).funcptr);
	lua_pushcclosure(L, &methodWrapper!(typeof(&X.init.set), T, false), 1);
}


// TODO: exclude private members (I smell DMD bugs...)
template isStaticMember(T, string member)
{
	static if(__traits(compiles, mixin("&T." ~ member)))
	{
		static if(is(typeof(mixin("&T.init." ~ member)) == delegate))
			enum isStaticMember = __traits(isStaticFunction, mixin("T." ~ member));
		else
			enum isStaticMember = true;
	}
	else
		enum isStaticMember = false;
}

void verifyType(T)(lua_State* L, int idx)
{
	if(lua_getmetatable(L, idx) == 0)
		luaL_error(L, "attempt to get 'userdata: %p' as a D object", lua_topointer(L, idx));

	lua_getfield(L, -1, "__dmangle"); //must be a D object

	// TODO: support pointers...

	// TODO: if is(T == const), then we need to check __dmangle == T, const(T) or immutable(T)
	size_t manglelen;
	auto cmangle = lua_tolstring(L, -1, &manglelen);
	if(cmangle[0 .. manglelen] != T.mangleof)
	{
		lua_getfield(L, -2, "__dtype");
		auto cname = lua_tostring(L, -1);
		luaL_error(L, `attempt to get instance %s as type "%s"`, cname, toStringz(T.stringof));
	}
	lua_pop(L, 2); //metatable and metatable.__dmangle
}


extern(C) int userdataCleaner(lua_State* L)
{
	GC.removeRoot(lua_touserdata(L, 1));
	return 0;
}

extern(C) int index(lua_State* L)
{
	auto field = lua_tostring(L, 2);

	// check the getter table
	lua_getfield(L, lua_upvalueindex(1), field);
	if(!lua_isnil(L, -1))
	{
		lua_pushvalue(L, 1);
		lua_call(L, 1, LUA_MULTRET);
		return lua_gettop(L) - 2;
	}
	else
		lua_pop(L, 1);

	// return method
	lua_getfield(L, lua_upvalueindex(2), field);
	return 1;
}

extern(C) int newIndex(lua_State* L)
{
	auto field = lua_tostring(L, 2);

	// call setter
	lua_getfield(L, lua_upvalueindex(1), field);
	if(!lua_isnil(L, -1))
	{
		lua_pushvalue(L, 1);
		lua_pushvalue(L, 3);
		lua_call(L, 2, LUA_MULTRET);
	}
	else
	{
		// TODO: error?
	}

	return 0;
}
