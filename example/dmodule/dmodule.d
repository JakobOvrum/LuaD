import luad.all;

import std.traits;
import core.cpuid;

LuaTable initModule(LuaState lua)
{
	auto lib = lua.newTable();

	foreach(member; __traits(allMembers, core.cpuid))
	{
		enum qualifiedName = "core.cpuid." ~ member;
		static if(__traits(compiles, mixin(qualifiedName)) && isSomeFunction!(mixin(qualifiedName)))
			lib[member] = &mixin(qualifiedName);
	}

	auto datacache = lua.newTable();

	foreach(i, cache; core.cpuid.datacache)
	{
		if(cache.size != size_t.max)
			datacache[i + 1] = cache;
		else
			break;
	}

	lib["datacache"] = datacache;

	return lib;
}

mixin(LuaModule!("dmodule", initModule));
