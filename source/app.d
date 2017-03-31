import std.stdio;
import std.algorithm;
import std.range;
import std.file;
import std.array;
import std.path;

import luaaddon.tocparser;

enum CURRENT_INTERFACE_VERSION = 70200;

bool isHiddenFileOrDir(DirEntry entry)
{
	auto dirParts = entry.name.pathSplitter;

	foreach(dirPart; dirParts)
	{
		if(dirPart.startsWith("."))
		{
			return true;
		}
	}

	return false;
}

void scanAddonDir()
{

	auto dirs = getcwd.dirEntries(SpanMode.shallow)
		.filter!(a => (!isHiddenFileOrDir(a) && a.isDir));

	auto numberOfAddons = getcwd.dirEntries(SpanMode.shallow)
		.filter!(a => (!isHiddenFileOrDir(a) && a.isDir))
		.walkLength;

	uint numberOfOutdated;

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
				writeln(name, " => ", parser.getValue("Interface"));
				++numberOfOutdated;
			}
		}
	}

	writeln("Found a total of ", numberOfOutdated, " outdated addons!");
}

void main(string[] arguments)
{
	scanAddonDir();
}
