#!/usr/bin/env rdmd

import std.stdio;
import std.file;
import std.string;
import std.process;

int main()
{
	static immutable sources = [
		"all.d",
		"state.d",
		"error.d",
		"base.d",
		"lfunction.d",
		"reference.d",
		"stack.d",
		"table.d",
		"testing.d",
		"conversions/arrays.d",
		"conversions/assocarrays.d",
		"conversions/classes.d",
		"conversions/functions.d",
		"conversions/structs.d",
		"conversions/variant.d",
		"c/all.d"
	];

	auto sourcePath = environment.get("LUAD_PATH");
	if(sourcePath is null)
	{
		sourcePath = "..";
	}

	if(!isDir(sourcePath ~ "/luad"))
	{
		stderr.writefln("Specified path does not contain sub-directory 'luad' (%s)", sourcePath);
		return 1;
	}
	
	auto cmdLine = format(`dmd -c -op -o- -Dd"_dochack_" -I"%s" candydoc/candy.ddoc candydoc/modules.ddoc index.d`, sourcePath);
	foreach(source; sources)
		cmdLine ~= format(` "%s/luad/%s"`, sourcePath, source);
	
	auto result = system(cmdLine);
	if(result != 0)
		return result;
	
	scope(exit) rmdirRecurse("_dochack_");
	copy("_dochack_/index.html", "index.html");
	return 0;
}