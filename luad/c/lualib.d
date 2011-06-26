/* Converted to D from lualib.h by htod */
module luad.c.lualib;
import luad.c.lua;
/*
** Lua standard libraries
** See Copyright Notice in lua.h
*/


//C	 #ifndef lualib_h
//C	 #define lualib_h

//C	 #include "lua.h"

extern (C):

/* Key to file-handle type */
//C	 #define LUA_FILEHANDLE		"FILE*"
const char[] LUA_FILEHANDLE = "FILE*";


//C	 #define LUA_COLIBNAME	"coroutine"
const char[] LUA_COLIBNAME = "coroutine";
//C	 LUALIB_API int (luaopen_base) (lua_State *L);
int  luaopen_base(lua_State *L);

//C	 #define LUA_TABLIBNAME	"table"
const char[] LUA_TABLIBNAME = "table";
//C	 LUALIB_API int (luaopen_table) (lua_State *L);
int  luaopen_table(lua_State *L);

//C	 #define LUA_IOLIBNAME	"io"
const char[] LUA_IOLIBNAME = "io";
//C	 LUALIB_API int (luaopen_io) (lua_State *L);
int  luaopen_io(lua_State *L);

//C	 #define LUA_OSLIBNAME	"os"
const char[] LUA_OSLIBNAME = "os";
//C	 LUALIB_API int (luaopen_os) (lua_State *L);
int  luaopen_os(lua_State *L);

//C	 #define LUA_STRLIBNAME	"string"
const char[] LUA_STRLIBNAME = "string";
//C	 LUALIB_API int (luaopen_string) (lua_State *L);
int  luaopen_string(lua_State *L);

//C	 #define LUA_MATHLIBNAME	"math"
const char[] LUA_MATHLIBNAME = "math";
//C	 LUALIB_API int (luaopen_math) (lua_State *L);
int  luaopen_math(lua_State *L);

//C	 #define LUA_DBLIBNAME	"debug"
const char[] LUA_DBLIBNAME = "debug";
//C	 LUALIB_API int (luaopen_debug) (lua_State *L);
int  luaopen_debug(lua_State *L);

//C	 #define LUA_LOADLIBNAME	"package"
const char[] LUA_LOADLIBNAME = "package";
//C	 LUALIB_API int (luaopen_package) (lua_State *L);
int  luaopen_package(lua_State *L);


/* open all previous libraries */
//C	 LUALIB_API void (luaL_openlibs) (lua_State *L);
void  luaL_openlibs(lua_State *L);



//C	 #ifndef lua_assert
//C	 #define lua_assert(x)	((void)0)
//C	 #endif


//C	 #endif
