/**
Internal module for pushing and getting _enums.

Enum's are treated in Lua as strings.

Conversion of enum keys is case-insensitive, which I think is more useful for Lua's typical 'config' style usage

This is still a work-in-progress. Outstanding issues include:
  Handling of bitfields.
  Assignment of integer keys?
  Conversion function needs to be improved (linear search! >_<)
*/
module luad.conversions.enums;

import luad.c.all;
import luad.stack;

import std.traits;
import std.conv;
import std.range;
import std.string;

struct KeyValuePair(ValueType)
{
	string key;
	ValueType value;
}

// produce a tuple of KeyValuePair's for an enum.
template EnumKeyValuePair(Enum)
{
	template impl(size_t len, size_t offset, Items...)
	{
		static if(offset == len)
			alias impl = TypeTuple!();
		else
			alias impl = TypeTuple!(KeyValuePair!Enum(Items[offset], Items[len + offset]), impl!(len, offset + 1, Items));
	}

	alias Keys = TypeTuple!(__traits(allMembers, Enum));
	alias Values = EnumMembers!Enum;
	static assert(Keys.length == Values.length);

	alias EnumKeyValuePair = impl!(Keys.length, 0, TypeTuple!(Keys, Values));
}

immutable(KeyValuePair!Enum)[] getKeyValuePairs(Enum)() pure nothrow @nogc
{
	static immutable(KeyValuePair!Enum[]) kvp = [ EnumKeyValuePair!Enum ];
	return kvp;
}

// TODO: These linear lookups are pretty crappy... we can do better, but this get's us working.
Enum getEnumValue(Enum)(lua_State* L, const(char)[] value) if(is(Enum == enum))
{
	value = value.strip;
	if(!value.empty)
	{
		auto kvp = getKeyValuePairs!Enum();
		foreach(ref i; kvp)
		{
			if(!icmp(i.key, value)) // case inseneitive enum keys...
				return i.value;
		}
	}
	luaL_error(L, "invalid enum key '%s' for enum type %s", value.ptr, Enum.stringof.ptr);
	return Enum.init;
}

string getEnumFromValue(Enum)(Enum value)
{
	auto kvp = getKeyValuePairs!Enum();
	foreach(ref i; kvp)
	{
		if(value == i.value)
			return i.key;
	}
	return null;
}

void pushEnum(T)(lua_State* L, T value) if (is(T == enum))
{
	string key = getEnumFromValue(value);
	if(key)
		lua_pushlstring(L, key.ptr, key.length);
	else
		luaL_error(L, "invalid value for enum type %s", T.stringof.ptr);
}

T getEnum(T)(lua_State* L, int idx) if(is(T == enum))
{
	// TODO: check to see if idx is a number, if it is, convert it directly?

	size_t len;
	const(char)* s = lua_tolstring(L, idx, &len);
	return getEnumValue!T(L, s[0..len]);
}

void pushStaticTypeInterface(T)(lua_State* L) if(is(T == enum))
{
	lua_newtable(L);

	// TODO: we could get fancy and make an __index table of keys, so that they are read-only
	//       ... but for now, we'll just populate a table with the keys as strings

	// set 'init'
	string initVal = getEnumFromValue(T.init);
	lua_pushlstring(L, initVal.ptr, initVal.length);
	lua_setfield(L, -2, "init");

	// TODO: integral enums also have 'min' and 'max'

	// we'll create tables for the keys and valyes arrays.
	lua_newtable(L); // keys
	lua_newtable(L); // values

	// add the enum keys
	auto kvp = getKeyValuePairs!T();
	foreach(int i, ref e; kvp)
	{
		// set the key to the key string (lua will carry enums by string)
		lua_pushlstring(L, e.key.ptr, e.key.length);
		lua_setfield(L, -4, e.key.ptr);

		// push the key to the keys array
		lua_pushlstring(L, e.key.ptr, e.key.length);
		lua_rawseti(L, -3, i+1);

		// push the value to the values array
		pushValue!(OriginalType!T)(L, e.value);
		lua_rawseti(L, -2, i+1);
	}

	lua_setfield(L, -3, "values");
	lua_setfield(L, -2, "keys");
}

version(unittest)
{
	import luad.base;

	enum E
	{
		Key0,
		Key1
	}
}

unittest
{
	import luad.testing;

	lua_State* L = luaL_newstate();
	scope(success) lua_close(L);
	luaL_openlibs(L);

	pushValue(L, E.Key0);
	assert(lua_isstring(L, -1));
	lua_setglobal(L, "enum");

	unittest_lua(L, `
		assert(enum == "Key0")

		enum = "key1"
	`);

	lua_getglobal(L, "enum");
	E e = getValue!E(L, -1);
	assert(e == E.Key1);
	lua_pop(L, 1);

	// TODO: test the enum type interface...
}
