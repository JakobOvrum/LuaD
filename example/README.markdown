Examples
===========================
This directory contains some samples to help get the gist of LuaD.

hello
---------------------------
"Hello, world!" in LuaD fashion.

This example demonstrates creating a new state and opening the standard library.

It then goes on to showing how to use a LuaState as its global table by getting the global function 'print' and invoking it.

phonebook
---------------------------
Lua is an excellent data descriptor. This example shows how to use structs to quickly map objects in Lua into D.

precompiled
---------------------------
This example shows how to precompile Lua to bytecode using `LuaFunction.dump` and then run the precompiled code.

dmodule
---------------------------
This example shows how to use LuaD to quickly create a binary Lua module. Use `bin/module.lua` to run the example.
