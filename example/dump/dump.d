
import luad.all;
import std.stream;

void main()
{
	auto lua = new LuaState;
	lua.openLibs();

    LuaFunction func = lua.loadString( `return "Hello from Lua"` );
    func();

    auto f = new File("/tmp/ldump.1", FileMode.Out);
    func.dump( (data) => f.writeBlock(data.ptr, data.length) == data.length );

//    func.dump( &writer );

    LuaObject[] ret = lua.doFile( "/tmp/ldump.1" );
    assert( ret.length > 0 && ret[ 0 ].toString() == "Hello from Lua" );
}
