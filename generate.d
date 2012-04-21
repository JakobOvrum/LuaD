#!/usr/bin/env rdmd

import std.file;
import std.path;
import std.process;
import std.regex;
import std.stdio;
import std.string;

immutable allSources = [
	"all.d",
	"state.d",
	"error.d",
	"base.d",
	"lfunction.d",
	"dynamic.d",
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

immutable subPackages = [
	"c",
	"conversions"
];

immutable docDir = "luad";

int main(string[] args)
{
	auto sources = (args.length > 1)? args[1 .. $] : allSources;

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
	
	auto cmdLine = format(`dmd -c -op -o- -Dd"%s" -I"%s" bootstrap.ddoc settings.ddoc modules.ddoc index.d`, docDir, sourcePath);
	foreach(source; sources)
	{
		if(source != "index.d")
			cmdLine ~= format(` "%s/luad/%s"`, sourcePath, source);
	}
	
	auto result = system(cmdLine);
	if(result != 0)
		return result;
	
	// flatten output
	auto r = regex(`^([^/]+)/(.+)\.d$`);
	foreach(source; allSources)
	{
		if(auto m = match(source, r))
		{
			auto pkg = m.captures[1];
			auto mod = m.captures[2];
			
			auto generatedPath = format("%s/%s/%s.html", docDir, pkg, mod);
			auto flattenedPath = format("%s_%s.html", pkg, mod);
			copy(generatedPath, flattenedPath);
		}
		else
		{
			auto name = stripExtension(source);
			copy(format("%s/%s.html", docDir, name), format("%s.html", name)); 
		}
	}
	
	copy(format("%s/index.html", docDir), "index.html");
	
	rmdirRecurse(docDir);
	
	return 0;
}
