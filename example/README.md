Examples
===========================
This directory contains some samples to help get the gist of LuaD.

Each example can be tested by running `dub run` from the example's directory.

hello
---------------------------
"Hello, world!" using LuaD.

This example demonstrates creating a new state and loading the Lua standard library.

It then shows how to use a `LuaState` as its global table by getting the global function `print` and invoking it.

phonebook
---------------------------
Lua is an excellent data descriptor language. This example shows how to use structs to quickly map objects in Lua onto D.

precompiled
---------------------------
This example shows how to precompile Lua to bytecode using `LuaFunction.dump`, as well as how to run the precompiled code.

dmodule
---------------------------
This example shows how to use LuaD to quickly create a binary Lua module implemented in D. Use `bin/module.lua` to print what it provides.
