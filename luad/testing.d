/// Module used internally by the unittest code.
module luad.testing;

import luad.c.all;

import std.c.string : strcmp;
import std.string : format;
import std.string : toStringz;

/** Test a piece of Lua code.
 * Params:
 *    L = Lua state to run in.
 *    code = Lua code.
 */
void unittest_lua(lua_State* L, string code, string chunkName = __FILE__, uint chunkLocation = __LINE__)
{
	chunkName = format("@%s script on line %d", chunkName, chunkLocation);
	if(luaL_loadbuffer(L, code.ptr, code.length, toStringz(chunkName)) != 0)
		lua_error(L);
	
	lua_call(L, 0, 0);
}

/** Main function stub for unittest build. */
version(luad_unittest_main) void main()
{
}