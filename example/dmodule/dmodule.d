import luad.all;

import std.string;
import core.sys.windows.windows;

LuaTable initModule(LuaState lua)
{
	auto lib = lua.newTable();
	lib["message_box"] = (in char[] title, in char[] message) {
		MessageBoxA(null, toStringz(message), toStringz(title), MB_OK);
	};
	return lib;
}

mixin(LuaModule!("dmodule", initModule));
