import std.stdio;

import ctoptions.structoptions;
import ctoptions.getoptmixin;

import addonlistgenerator;

void showVersion()
{
	writeln("Version 0.9");
}

void main(string[] arguments)
{
	@GetOptCallback("version", "showVersion")
	struct Options
	{
		@GetOptOptions("Sets the minimum toc version to scan for.", "st", "settoc")
		size_t tocVersion;
		@GetOptOptions("Attempt to get the latest API version.") @DisableSave
		bool update;
	}

	StructOptions!Options options;
	auto listGenerator = new AddonListGenerator;

	if(arguments.length == 1)
	{
		listGenerator.scanAddonDir();
	}
	else
	{
		generateGetOptCode!Options(arguments, options);
	}
}
