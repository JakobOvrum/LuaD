/*
 * terse_lua - zero overhead convenience wrapper for the Lua C API
 *
 * goals & principles
 *      Expose the standard Lua C API
 *      while reducing verbosity and artifacts
 *         (remove Lua name prefixes made redundant by namespaces;
 *          use native arg types where they provide pointer or type safety;
 *          use default args and function overloading where sensible;
 *          remove base and aux library distinction)
 *      and incurring no runtime overhead.
 *
 * notes
 *      functions can be invoked as L.f() (i.e. unified function call syntax)
 *      ref renamed makeref
 *      register renamed registercfunction
 *      luaL register renamed registerlibrary
 *      createtable removed, folded into newtable
 *      pushcclosure removed, folded into pushcfunction
 *      pushlstring renamed pushstring, has overload accepting D char[]
 *      pushfstring return value elided since raw pointer can't be made safe
 *          without overhead, and it's likely not used often
 *      tostring returns D char[]
 *      newuserdata returns D byte[]
 */

module luad.c_terse;

import core.vararg;

import luad.c.all;

alias lua_State State;
alias lua_Number Number;
alias lua_Integer Integer;
alias lua_CFunction CFunction;
alias lua_Reader Reader;
alias lua_Writer Writer;
alias lua_Alloc Alloc;

alias LUA_MULTRET MULTRET;

/*
 * pseudo-indices
 */
alias LUA_REGISTRYINDEX REGISTRYINDEX;
alias LUA_ENVIRONINDEX ENVIRONINDEX;
alias LUA_GLOBALSINDEX GLOBALSINDEX;
alias lua_upvalueindex upvalueindex;

/*
 * thread status
 */
alias LUA_YIELD YIELD;
alias LUA_ERRRUN ERRRUN;
alias LUA_ERRSYNTAX ERRSYNTAX;
alias LUA_ERRMEM ERRMEM;
alias LUA_ERRERR ERRERR;

/*
 * state manipulation
 */
State* newstate(Alloc f, void* ud=null);
void close(State* L) { lua_close(L); }
State* newthread(State* L) { return lua_newthread(L); }
CFunction atpanic(State* L, CFunction f) { return lua_atpanic(L, f); }

/*
 * basic stack manipulation
 */
int gettop(const State* L) nothrow { return lua_gettop(cast(State*)L); }
void settop(State* L, int i) nothrow { lua_settop(L, i); }
void pushvalue(State* L, int i=-1) nothrow { lua_pushvalue(L, i); }
void remove(State* L, int i) { lua_remove(L, i); }
void insert(State* L, int i) { lua_insert(L, i); }
void replace(State* L, int i) { lua_replace(L, i); }
bool checkstack(State* L, int n) { return cast(bool)lua_checkstack(L, n); }
void xmove(State* from, State* to, int n) { lua_xmove(from, to, n); }

/*
 * access functions (stack -> C)
 */
bool isnumber(State* L, int i=-1) { return cast(bool)lua_isnumber(L, i); }
bool isstring(State* L, int i=-1) { return cast(bool)lua_isstring(L, i); }
bool iscfunction(State* L, int i=-1) { return cast(bool)lua_iscfunction(L, i); }
bool isuserdata(State* L, int i=-1) { return cast(bool)lua_isuserdata(L, i); }
// TODO: use enum for type-- subsume luad.base.LuaType?
int type(State* L, int i=-1) nothrow { return lua_type(L, i); }
char* typename(State* L, int tp) nothrow { return lua_typename(L, tp); }

bool equal(State* L, int i1=-2, int i2=-1) { return cast(bool)lua_equal(L, i1, i2); }
bool rawequal(State* L, int i1=-2, int i2=-1) { return cast(bool)lua_rawequal(L, i1, i2); }
bool lessthan(State* L, int i1=-2, int i2=-1) { return cast(bool)lua_lessthan(L, i1, i2); }

Number tonumber(State* L, int i=-1) { return lua_tonumber(L, i); }
Integer tointeger(State* L, int i=-1) { return lua_tointeger(L, i); }
bool toboolean(State* L, int i=-1) { return cast(bool)lua_toboolean(L, i); }
const(char)[] tostring(State* L, int i=-1) {
    size_t n;
    auto s_ptr = lua_tolstring(L, i, &n);
    return s_ptr[0 .. n];
}
size_t objlen(State* L, int i=-1) { return lua_objlen(L, i); }
CFunction tocfunction(State* L, int i=-1) { return lua_tocfunction(L, i); }
void* touserdata(State* L, int i=-1) { return lua_touserdata(L, i); }
State* tothread(State* L, int i=-1) { return lua_tothread(L, i); }
void* topointer(State* L, int i=-1) { return lua_topointer(L, i); }

/*
 * push functions (C -> stack)
 */
void pushnil(State* L) { lua_pushnil(L); }
void pushnumber(State* L, Number x) { lua_pushnumber(L, x); }
void pushinteger(State* L, Integer x) { lua_pushinteger(L, x); }
void pushstring(State* L, const(char)* s, size_t len) { lua_pushlstring(L, s, len); }
void pushstring(State* L, const(char)[] s) { lua_pushlstring(L, s.ptr, s.length); }
void pushfstring(lua_State* L, const(char)* fmt, va_list argp) { lua_pushvfstring(L, fmt, argp); }
void pushfstring(lua_State* L, const(char)* fmt, ...) { lua_pushvfstring(L, fmt, _argptr); }
void pushcfunction(State* L, CFunction fn, int n=0) { lua_pushcclosure(L, fn, n); }
void pushboolean(State* L, bool x) { lua_pushboolean(L, x); }
void pushlightuserdata(State* L, void* p) { lua_pushlightuserdata(L, p); }
bool pushthread(State* L) { return cast(bool)lua_pushthread(L); }

/*
 * get functions (Lua -> stack)
 */
void gettable(State* L, int i) { lua_gettable(L, i); }
void getfield(State* L, int i, const(char)* name) { lua_getfield(L, i, name); }
void rawget(State* L, int i) { lua_rawget(L, i); }
void rawgeti(State* L, int i, int n) nothrow { lua_rawgeti(L, i, n); }
void newtable(State* L, int narr=0, int nrec=0) { lua_createtable(L, narr, nrec); }
byte[] newuserdata(State* L, size_t size) { return (cast(byte*)lua_newuserdata(L, size))[0 .. size]; }
bool getmetatable(State* L, int i) { return cast(bool)lua_getmetatable(L, i); }
void getfenv(State* L, int i) { lua_getfenv(L, i); }

/*
 * set functions (stack -> Lua)
 */
void settable(State* L, int i) { lua_settable(L, i); }
void setfield(State* L, int i, const(char)* name) { lua_setfield(L, i, name); }
void rawset(State* L, int i) { lua_rawset(L, i); }
void rawseti(State* L, int i, int n) { lua_rawseti(L, i, n); }
int setmetatable(State* L, int i) { return lua_setmetatable(L, i); }
int setfenv(State* L, int i) { return lua_setfenv(L, i); }

/*
 * `load' and `call' functions (load and run Lua code)
 */
void call(State* L, int nargs=0, int nresults=0) { lua_call(L, nargs, nresults); }
// TODO: enum for pcall/cpcall results
int pcall(State* L, int nargs=0, int nresults=0, int errfunc=0) { return lua_pcall(L, nargs, nresults, errfunc); }
int cpcall(State* L, CFunction func, void* ud=null) { return lua_cpcall(L, func, ud); }
// ISSUE: data=null default make sense?
int load(State* L, Reader reader, void* data, const(char)* chunkname=null) { return lua_load(L, reader, data, chunkname); }
int dump(State* L, Writer writer, void* data) { return lua_dump(L, writer, data); }

/*
 * coroutine functions
 */
int yield(State* L, int nresults=0) { return lua_yield(L, nresults); }
int resume(State* L, int narg=0) { return lua_resume(L, narg); }
// TODO: enum for return value
int status(State* L) { return lua_status(L); }

/*
 * garbage-collection function and options
 */
// TODO: enum for what
int gc(State* L, int what, int data) { return lua_gc(L, what, data); }


/*
 * miscellaneous functions
 */
int error(State* L) { return lua_error(L); }
bool next(State* L, int i) { return cast(bool)lua_next(L, i); }
void concat(State* L, int n) { lua_concat(L, n); }
Alloc getallocf(State* L, void** ud=null) { return lua_getallocf(L, ud); }
void setallocf(State* L, Alloc f, void* ud=null) { lua_setallocf(L, f, ud); }

/*
 * (originally) C macros
 */
void pop(State* L, int n=1) nothrow { lua_pop(L, n); }
void registercfunction(lua_State* L, const(char)* name, lua_CFunction f) { lua_register(L, name, f); }
alias objlen strlen;
bool isfunction(State* L, int i=-1) { return lua_isfunction(L, i); }
bool istable(State* L, int i=-1) { return lua_istable(L, i); }
bool islightuserdata(State* L, int i=-1) { return lua_islightuserdata(L, i); }
bool isnil(State* L, int i=-1) { return lua_isnil(L, i); }
bool isboolean(State* L, int i=-1) { return lua_isboolean(L, i); }
bool isthread(State* L, int i=-1) { return lua_isthread(L, i); }
bool isnone(State* L, int i=-1) { return lua_isnone(L, i); }
bool isnoneornil(State* L, int i=-1) { return lua_isnoneornil(L, i); }
void setglobal(lua_State* L, const(char)* s) { lua_setglobal(L, s); }
void getglobal(lua_State* L, const(char)* s) { lua_getglobal(L, s); }

// TODO: debug funcs

/*
 * lualib
 */

void openlibs(lua_State* L) { luaL_openlibs(L); }

/*
 * lauxlib
 */
alias luaL_Reg Reg;
alias luaL_Buffer Buffer;

void registerlibrary(State* L, const(char)* name, const Reg* l) { luaL_register(L, name, l); }
bool getmetafield(State* L, int obj, const(char)* e) { return cast(bool)luaL_getmetafield(L, obj, e); }
bool callmeta(State* L, int obj, const(char)* e) { return cast(bool)luaL_callmeta(L, obj, e); }
int typerror(State* L, int narg, const(char)* tname) { return luaL_typerror(L, narg, tname); }
int argerror(State* L, int numarg, const(char)* extramsg) { return luaL_argerror(L, numarg, extramsg); }
auto checkstring(State* L, int numArg) {
    size_t n;
    auto s = luaL_checklstring(L, numArg, &n);
    return s[0 .. n];
}
auto optstring(State* L, int numArg, const(char)* def, size_t* l) {
    size_t n;
    auto s = luaL_optlstring(L, numArg, def, &n);
    return s[0 .. n];
}
Number checknumber(State* L, int numArg) { return luaL_checknumber(L, numArg); }
Number optnumber(State* L, int nArg, Number def) { return luaL_optnumber(L, nArg, def); }
Integer checkinteger(State* L, int numArg) { return luaL_checkinteger(L, numArg); }
Integer optinteger(State* L, int nArg, Integer def) { return luaL_optinteger(L, nArg, def); }
void checkstackordie(State* L, int sz, const(char)* msg) { luaL_checkstack(L, sz, msg); }
void checktype(State* L, int narg, int t) { luaL_checktype(L, narg, t); }
void checkany(State* L, int narg) { luaL_checkany(L, narg); }

bool newmetatable(State* L, const(char)* tname) { return cast(bool)luaL_newmetatable(L, tname); }
void* checkudata(State* L, int ud, const(char)* tname) { return luaL_checkudata(L, ud, tname); }

void where(State* L, int lvl) { return luaL_where(L, lvl); }
// ISSUE: Lua API lacks va_list version of luaL_error
int error(State* L, const(char)* fmt, va_list argp) {
    L.where(1);
    L.pushfstring(fmt, argp);
    L.concat(2);
    return L.error();
}
int error(State* L, const(char)* fmt, ...) { return error(L, fmt, _argptr); }

int checkoption(State* L, int narg, const(char)* def, const(char*)* lst) { return luaL_checkoption(L, narg, def, lst); }

int makeref(State* L, int t) { return luaL_ref(L, t); }
void unref(State* L, int t, int _ref) nothrow { return luaL_unref(L, t, _ref); }

int loadfile(State* L, const(char)* filename) { return luaL_loadfile(L, filename); }
int loadbuffer(State* L, const(char)* buff, size_t sz, const(char)* name) { return luaL_loadbuffer(L, buff, sz, name); }
int loadstring(State* L, const(char)* s) { return luaL_loadstring(L, s); }
State* newstate() { return luaL_newstate(); }

const(char)* gsub(State* L, const(char)* s, const(char)* p, const(char)* r) { return luaL_gsub(L, s, p, r); }

void argcheck(State* L, bool cond, int numarg, const(char)* extramsg) { luaL_argcheck(L, cond, numarg, extramsg); }
int checkint(State* L, int n) { return luaL_checkint(L, n); }
int optint (State* L, int n, int d) { return luaL_optint(L, n, d); }
long checklong(State* L, int n) { return luaL_checklong(L, n); }
long optlong(State* L, int n, int d) { return luaL_optlong(L, n, d); }

const(char)* typename(State* L, int i) nothrow { return luaL_typename(L, i); }

int dofile(State* L, const(char)* fn) { return luaL_dofile(L, fn); }
int dostring(State* L, const(char)* s) { return luaL_dostring(L, s); }

void getmetatable(State* L, const(char)* s) { luaL_getmetatable(L, s); }

void addchar(Buffer* B, char c) { luaL_addchar(B, c); }
void addsize(Buffer* B, int n) { luaL_addsize(B, n); }
void buffinit(State* L, Buffer* B) { luaL_buffinit(L, B); }
char* prepbuffer(Buffer* B) { return luaL_prepbuffer( B); }
void addstring(Buffer* B, const char[] s) { luaL_addlstring(B, s.ptr, s.length); }
void addvalue(Buffer* B) { return luaL_addvalue(B); }
void pushresult(Buffer* B) { return luaL_pushresult(B); }


unittest {
    auto L = newstate();
    scope(exit) { L.close(); }

    L.newthread();
    L.pop();

    extern (C) static int atpanic_handler(State* L) {
        throw new Error(L.tostring().idup);
    }

    L.atpanic(&atpanic_handler);

    assert(L.gettop() == 0);
    string s = "hello";
    L.pushstring(s);
    assert(L.gettop() == 1);
    assert(L.isstring());

    L.pushvalue();
    assert(L.equal());
    L.pop();
    assert(L.gettop() == 1);
    assert(L.tostring() == "hello");
    L.pushfstring("foo%d%s", 9, cast(char*)"bar");
    assert(L.tostring() == "foo9bar");

    extern (C) static int f1(State* L) { return 0; }

    L.pushcfunction(&f1);
    L.pushboolean(false);
    L.pushlightuserdata(null);
    assert(L.pushthread());

    L.newtable();

    L.pushstring("foo");
    L.pushnumber(5);
    L.settable(-3);
    L.pushstring("foo");
    L.gettable(-2);
    assert(L.tonumber() == 5);
    L.pop();
    L.pushnumber(10);
    L.setfield(-2, "bar");
    L.getfield(-1, "bar");
    assert(L.tonumber() == 10);
    L.pop();

    L.pushstring("foo");
    L.pushnumber(15);
    L.rawset(-3);
    L.pushstring("foo");
    L.rawget(-2);
    assert(L.tonumber() == 15);
    L.pop();

    L.pushnumber(20);
    L.rawseti(-2, 0);
    L.rawgeti(-1, 0);
    assert(L.tonumber() == 20);
    L.pop();

    L.newtable();
    L.setmetatable(-2);
    assert(L.getmetatable(-1));

    assert(L.newuserdata(10));
    L.newtable();
    assert(L.setfenv(-2));
    L.getfenv(-1);
    assert(L.istable());

    L.pushcfunction(&f1);
    L.call();
    L.pushcfunction(&f1);
    assert(L.pcall() == 0);
    assert(L.cpcall(&f1) == 0);

    // load/dump

    // yield/resume
    assert(L.status() == 0);

    assert(L.gc(LUA_GCCOUNT, 0) > 0);

    auto msg = "oops";
    L.pushstring(msg);
    try {
        L.error();
        assert(false);
    } catch (Error e) {
        assert(e.msg == msg);
    }
    try {
        L.error("%s", msg.ptr);
        assert(false);
    } catch (Error e) {
        assert(e.msg == msg);
    }

    L.newtable();
    L.pushnil();
    assert(!L.next(-2));

    L.pushstring("foo");
    L.pushstring("bar");
    L.concat(2);
    assert(L.tostring() == "foobar");

    L.setallocf(L.getallocf());

    L.openlibs();
}
