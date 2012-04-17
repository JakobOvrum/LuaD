
import luad.all;
import std.stream;

void main()
{
    auto lua = new LuaState;
    lua.openLibs();

    LuaFunction func = lua.loadString( `return "Hello from Lua"` );
    func();

    string fileName = "./ldump.luac";
    auto f = new File(fileName, FileMode.Out);
    assert(std.file.exists(fileName));
    scope(exit) std.file.remove(fileName);
    func.dump( (data) => f.writeBlock(data.ptr, data.length) == data.length );

    LuaObject[] ret = lua.doFile( "./ldump.luac" );
    assert( ret.length > 0 && ret[ 0 ].toString() == "Hello from Lua" );
}
