module luad.c.lauxlib;
import luad.c.luaconf;
/*
** Auxiliary functions for building Lua libraries
** See Copyright Notice in lua.h
*/


//C	 #ifndef lauxlib_h
//C	 #define lauxlib_h


//C	 #include <stddef.h>
//import std.stddef;
//C	 #include <stdio.h>
//import std.stdio;

//C	 #include "lua.h"
import luad.c.lua;

extern (C):

//C	 #if defined(LUA_COMPAT_GETN)
//C	 LUALIB_API int (luaL_getn) (lua_State *L, int t);
//C	 LUALIB_API void (luaL_setn) (lua_State *L, int t, int n);
//C	 #else
//C	 #define luaL_getn(L,i)		  ((int)lua_objlen(L, i))
//C	 #define luaL_setn(L,i,j)		((void)0)  /* no op! */
//C	 #endif
int luaL_getn(lua_State* L, int i) { return cast(int) lua_objlen(L, i); }

void luaL_setn(lua_State* L, int i, int j) { }

//C	 #if defined(LUA_COMPAT_OPENLIB)
//C	 #define luaI_openlib	luaL_openlib
//C	 #endif
alias luaL_openlib luaI_openlib;


/* extra error code for `luaL_load' */
//C	 #define LUA_ERRFILE	 (LUA_ERRERR+1)


//C	 typedef struct luaL_Reg {
//C	   const char *name;
//C	   lua_CFunction func;
//C	 } luaL_Reg;
struct luaL_Reg
{
	char* name;
	lua_CFunction func;
}



//C	 LUALIB_API void (luaI_openlib) (lua_State *L, const char *libname,
//C									 const luaL_Reg *l, int nup);
void  luaL_openlib(lua_State *L, const(char)* libname, luaL_Reg *l, int nup);
//C	 LUALIB_API void (luaL_register) (lua_State *L, const char *libname,
//C									 const luaL_Reg *l);
void  luaL_register(lua_State *L, const(char)* libname, luaL_Reg *l);
//C	 LUALIB_API int (luaL_getmetafield) (lua_State *L, int obj, const char *e);
int  luaL_getmetafield(lua_State *L, int obj, const(char)* e);
//C	 LUALIB_API int (luaL_callmeta) (lua_State *L, int obj, const char *e);
int  luaL_callmeta(lua_State *L, int obj, const(char)* e);
//C	 LUALIB_API int (luaL_typerror) (lua_State *L, int narg, const char *tname);
int  luaL_typerror(lua_State *L, int narg, const(char)* tname);
//C	 LUALIB_API int (luaL_argerror) (lua_State *L, int numarg, const char *extramsg);
int  luaL_argerror(lua_State *L, int numarg, const(char)* extramsg);
//C	 LUALIB_API const char *(luaL_checklstring) (lua_State *L, int numArg,
//C															   size_t *l);
const(char)* luaL_checklstring(lua_State *L, int numArg, size_t *l);
//C	 LUALIB_API const char *(luaL_optlstring) (lua_State *L, int numArg,
//C											   const char *def, size_t *l);
const(char)* luaL_optlstring(lua_State *L, int numArg, const(char)* def, size_t *l);
//C	 LUALIB_API lua_Number (luaL_checknumber) (lua_State *L, int numArg);
lua_Number  luaL_checknumber(lua_State *L, int numArg);
//C	 LUALIB_API lua_Number (luaL_optnumber) (lua_State *L, int nArg, lua_Number def);
lua_Number  luaL_optnumber(lua_State *L, int nArg, lua_Number def);

//C	 LUALIB_API lua_Integer (luaL_checkinteger) (lua_State *L, int numArg);
lua_Integer  luaL_checkinteger(lua_State *L, int numArg);
//C	 LUALIB_API lua_Integer (luaL_optinteger) (lua_State *L, int nArg,
//C											   lua_Integer def);
lua_Integer  luaL_optinteger(lua_State *L, int nArg, lua_Integer def);

//C	 LUALIB_API void (luaL_checkstack) (lua_State *L, int sz, const char *msg);
void  luaL_checkstack(lua_State *L, int sz, const(char)* msg);
//C	 LUALIB_API void (luaL_checktype) (lua_State *L, int narg, int t);
void  luaL_checktype(lua_State *L, int narg, int t);
//C	 LUALIB_API void (luaL_checkany) (lua_State *L, int narg);
void  luaL_checkany(lua_State *L, int narg);

//C	 LUALIB_API int   (luaL_newmetatable) (lua_State *L, const char *tname);
int  luaL_newmetatable(lua_State *L, const(char)* tname);
//C	 LUALIB_API void *(luaL_checkudata) (lua_State *L, int ud, const char *tname);
void * luaL_checkudata(lua_State *L, int ud, const(char)* tname);

//C	 LUALIB_API void (luaL_where) (lua_State *L, int lvl);
void  luaL_where(lua_State *L, int lvl);
//C	 LUALIB_API int (luaL_error) (lua_State *L, const char *fmt, ...);
int  luaL_error(lua_State *L, const(char)* fmt,...);

//C	 LUALIB_API int (luaL_checkoption) (lua_State *L, int narg, const char *def,
//C										const char *const lst[]);
int  luaL_checkoption(lua_State *L, int narg, const(char)* def, const(char*)* lst);

//C	 LUALIB_API int (luaL_ref) (lua_State *L, int t);
int  luaL_ref(lua_State *L, int t);
//C	 LUALIB_API void (luaL_unref) (lua_State *L, int t, int ref);
void  luaL_unref(lua_State *L, int t, int _ref);

//C	 LUALIB_API int (luaL_loadfile) (lua_State *L, const char *filename);
	int  luaL_loadfile(lua_State *L, const(char)* filename);
//C	 LUALIB_API int (luaL_loadbuffer) (lua_State *L, const char *buff, size_t sz,
//C									   const char *name);
int  luaL_loadbuffer(lua_State *L, const(char)* buff, size_t sz, const(char)* name);
//C	 LUALIB_API int (luaL_loadstring) (lua_State *L, const char *s);
int  luaL_loadstring(lua_State *L, const(char)* s);

//C	 LUALIB_API lua_State *(luaL_newstate) (void);
lua_State * luaL_newstate();


//C	 LUALIB_API const char *(luaL_gsub) (lua_State *L, const char *s, const char *p,
//C													   const char *r);
const(char)* luaL_gsub(lua_State *L, const(char)* s, const(char)* p, const(char)* r);

//C	 LUALIB_API const char *(luaL_findtable) (lua_State *L, int idx,
//C											  const char *fname, int szhint);
const(char)* luaL_findtable(lua_State *L, int idx, const(char)* fname, int szhint);




/*
** ===============================================================
** some useful macros
** ===============================================================
*/

//C	 #define luaL_argcheck(L, cond,numarg,extramsg)			((void)((cond) || luaL_argerror(L, (numarg), (extramsg))))
void luaL_argcheck(lua_State* L, int cond, int numarg, const(char)* extramsg) { if (!cond) luaL_argerror(L, numarg, extramsg); }
//C	 #define luaL_checkstring(L,n)	(luaL_checklstring(L, (n), NULL))
const(char)* luaL_checkstring(lua_State* L, int n) { return luaL_checklstring(L, n, null); }
//C	 #define luaL_optstring(L,n,d)	(luaL_optlstring(L, (n), (d), NULL))
const(char)* luaL_optstring(lua_State* L, int n, const(char)* d) { return luaL_optlstring(L, n, d, null); }
//C	 #define luaL_checkint(L,n)	((int)luaL_checkinteger(L, (n)))
int luaL_checkint(lua_State* L, int n) { return cast(int) luaL_checkinteger(L, n); }
//C	 #define luaL_optint(L,n,d)	((int)luaL_optinteger(L, (n), (d)))
int luaL_optint (lua_State* L, int n, int d) { return cast(int) luaL_optinteger(L, n, d); }
//C	 #define luaL_checklong(L,n)	((long)luaL_checkinteger(L, (n)))
long luaL_checklong(lua_State* L, int n) { return cast(long)luaL_checkinteger(L, n); }
//C	 #define luaL_optlong(L,n,d)	((long)luaL_optinteger(L, (n), (d)))
long luaL_optlong(lua_State* L, int n, int d) { return cast(long)luaL_optinteger(L, n, d); }

//C	 #define luaL_typename(L,i)	lua_typename(L, lua_type(L,(i)))
const(char)* luaL_typename(lua_State* L, int i) { return lua_typename(L, lua_type(L, i)); }

//C	 #define luaL_dofile(L, fn) 	(luaL_loadfile(L, fn) || lua_pcall(L, 0, LUA_MULTRET, 0))
int luaL_dofile(lua_State* L, const(char)* fn) { return luaL_loadfile(L, fn) || lua_pcall(L, 0, LUA_MULTRET, 0); }

//C	 #define luaL_dostring(L, s) 	(luaL_loadstring(L, s) || lua_pcall(L, 0, LUA_MULTRET, 0))
int luaL_dostring(lua_State*L, const(char)* s) { return luaL_loadstring(L, s) || lua_pcall(L, 0, LUA_MULTRET, 0); }

//C	 #define luaL_getmetatable(L,n)	(lua_getfield(L, LUA_REGISTRYINDEX, (n)))
void luaL_getmetatable(lua_State* L, const(char)* s) { lua_getfield(L, LUA_REGISTRYINDEX, s); }

//C	 #define luaL_opt(L,f,n,d)	(lua_isnoneornil(L,(n)) ? (d) : f(L,(n)))
bool luaL_opt(lua_State* L, int function(lua_State*, int) f, int n, int d) { return luaL_opt(L, f, n, d); }

/*
** {======================================================
** Generic Buffer manipulation
** =======================================================
*/



//C	 typedef struct luaL_Buffer {
//C	   char *p;			/* current position in buffer */
//C	   int lvl;  /* number of strings in the stack (level) */
//C	   lua_State *L;
//C	   char buffer[LUAL_BUFFERSIZE];
//C	 } luaL_Buffer;
struct luaL_Buffer
{
	char *p;
	int lvl;
	lua_State *L;
	char [LUAL_BUFFERSIZE]buffer;
}
//C	 #define luaL_addchar(B,c)   ((void)((B)->p < ((B)->buffer+LUAL_BUFFERSIZE) || luaL_prepbuffer(B)),	(*(B)->p++ = (char)(c)))
void luaL_addchar(luaL_Buffer* B, char c)
{
	if (B.p < B.buffer.ptr + LUAL_BUFFERSIZE || (luaL_prepbuffer(B)))
	{
		*B.p = c;
		B.p++;
	}
}

/* compatibility only */
//C	 #define luaL_putchar(B,c)	luaL_addchar(B,c)
alias luaL_addchar luaL_putchar;

//C	 #define luaL_addsize(B,n)	((B)->p += (n))
void luaL_addsize(luaL_Buffer* B, int n) { B.p += n; }

//C	 LUALIB_API void (luaL_buffinit) (lua_State *L, luaL_Buffer *B);
void  luaL_buffinit(lua_State *L, luaL_Buffer *B);
//C	 LUALIB_API char *(luaL_prepbuffer) (luaL_Buffer *B);
char * luaL_prepbuffer(luaL_Buffer *B);
//C	 LUALIB_API void (luaL_addlstring) (luaL_Buffer *B, const char *s, size_t l);
void  luaL_addlstring(luaL_Buffer *B, const char *s, size_t l);
//C	 LUALIB_API void (luaL_addstring) (luaL_Buffer *B, const char *s);
void  luaL_addstring(luaL_Buffer *B, const char *s);
//C	 LUALIB_API void (luaL_addvalue) (luaL_Buffer *B);
void  luaL_addvalue(luaL_Buffer *B);
//C	 LUALIB_API void (luaL_pushresult) (luaL_Buffer *B);
void  luaL_pushresult(luaL_Buffer *B);


/* }====================================================== */


/* compatibility with ref system */

/* pre-defined references */
//C	 #define LUA_NOREF	   (-2)
const LUA_NOREF = -2;
//C	 #define LUA_REFNIL	  (-1)
const LUA_REFNIL = -1;

//C	 #define lua_ref(L,lock) ((lock) ? luaL_ref(L, LUA_REGISTRYINDEX) :	   (lua_pushstring(L, "unlocked references are obsolete"), lua_error(L), 0))
void lua_ref(lua_State* L, int lock) { lock ? luaL_ref(L, LUA_REGISTRYINDEX) : lua_pushstring(L, "unlocked reference are obsolete"); lua_error(L); }

//C	 #define lua_unref(L,ref)		luaL_unref(L, LUA_REGISTRYINDEX, (ref))
void lua_unref(lua_State* L, int _ref) { luaL_unref(L, LUA_REGISTRYINDEX, _ref); }

//C	 #define lua_getref(L,ref)	   lua_rawgeti(L, LUA_REGISTRYINDEX, (ref))
void lua_getref(lua_State* L, int _ref) { lua_rawgeti(L, LUA_REGISTRYINDEX, _ref); }


//C	 #define luaL_reg	luaL_Reg

alias luaL_Reg luaL_reg;
//C	 #endif


