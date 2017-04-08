import std.stdio;
import std.algorithm;
import std.file;
import std.array;
import std.path;

import luaaddon.tocparser;
import ctoptions.structoptions;
import ctoptions.getoptmixin;

enum CURRENT_INTERFACE_VERSION = 70200;

bool isHiddenFileOrDir(DirEntry entry)
{
	auto dirParts = entry.name.pathSplitter;

	foreach(dirPart; dirParts)
	{
		version(linux)
		{
			if(dirPart.startsWith("."))
			{
				return true;
			}
		}
		version (Windows)
		{
			import core.sys.windows;

			if(getAttributes(dirPart) & FILE_ATTRIBUTE_HIDDEN)
			{
				return true;
			}
		}
	}

	return false;
}

void scanAddonDir()
{

	auto dirs = getcwd.dirEntries(SpanMode.shallow)
		.filter!(a => (!isHiddenFileOrDir(a) && a.isDir))
		.array;

	immutable size_t numberOfAddons = dirs.length;
	size_t numberOfOutdated;

	writeln(numberOfAddons, " addons found. Scanning toc files...");

	foreach(e; dirs)
	{

		auto files = e.name.dirEntries(SpanMode.shallow)
			.filter!(a => (!isHiddenFileOrDir(a) && a.isFile && a.name.endsWith(".toc")));

		foreach(file; files)
		{
			immutable string name = buildNormalizedPath(file.name);
			TocParser parser;

			parser.loadFile(name);

			if(parser.as!uint("Interface") != CURRENT_INTERFACE_VERSION)
			{
				immutable string title = parser.getValue("Title");

				if(title.length)
				{
					if(title.canFind("|"))
					{
						writeln(name.baseName.stripExtension, " => ", parser.getValue("Interface"));
					}
					else
					{
						writeln(parser.getValue("Title"), " => ", parser.getValue("Interface"));
					}
				}
				else
				{
					writeln(name.baseName.stripExtension, " => ", parser.getValue("Interface"));
				}
				++numberOfOutdated;
			}
		}
	}

	writeln("Found a total of ", numberOfOutdated, " outdated addons!");
}

void showVersion()
{
	writeln("Version 0.9");
}

void main(string[] arguments)
{
	struct Options
	{
		@GetOptOptions("Sets the minimum toc version to scan for.", "st", "settoc")
		size_t tocVersion;
		@GetOptFunction("version", "showVersion")
		string appVersion;
	}

	StructOptions!Options options;

	try
	{
		if(arguments.length == 1)
		{
			scanAddonDir();
		}
		else
		{
			generateGetOptCode!Options(arguments, options);
		}
	}
	catch(GetOptMixinException ex)
	{
		writeln(ex.msg);
	}
}
