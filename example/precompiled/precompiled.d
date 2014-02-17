import luad.all;
import std.stream;
import std.stdio;

void main()
{
    auto lua = new LuaState;
    lua.openLibs();

    LuaFunction func = lua.loadString(`return "Hello from precompiled Lua!"`);

    string fileName = "./ldump.luac";
    auto f = new std.stream.File(fileName, FileMode.Out);
    scope(exit) std.file.remove(fileName);
    func.dump(data => f.writeBlock(data.ptr, data.length) == data.length);
    f.close();

    LuaObject[] ret = lua.doFile(fileName);
    writeln(ret[0]);
}
