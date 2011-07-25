module luad.error;

/**
 * Thrown on Lua panic.

 * This exception is only thrown if there is no protected Lua call (e.g. pcall)
 * to handle the error. Whenever this documentation says a function throws
 * a LuaError, no D exception is actually thrown if a Lua error handler is in place.

 * Additionally, exceptions thrown in D functions given to Lua are converted to
 * and propagated as Lua errors. You can subvert this by throwing an object not
 * deriving from Exception (i.e. derive from Error, Throwable, etc).
 */
class LuaError : Exception
{
	this(string err){ super(err); }
}