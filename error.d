module luad.error;

class LuaError : Exception
{
	this(string err){ super(err); }
}