import luad.all;

void main()
{
	auto lua = new LuaState;
	lua.openLibs();
	
	auto print = lua.get!LuaFunction("print");
	print.call("Hello, world!");
}