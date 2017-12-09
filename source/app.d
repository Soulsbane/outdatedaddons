import std.stdio;
import std.algorithm;
import std.file;
import std.array;
import std.path;
import std.exception;
import core.exception : RangeError;

import requests;

import luaaddon.tocparser;
import ctoptions.structoptions;
import ctoptions.getoptmixin;

enum CURRENT_INTERFACE_VERSION = 70300;

// Used to add additional methods to TocParser.
struct AdditionalMethods
{
	string Title;
	size_t Interface; // Has to be capitalized since it is a keyword.
}

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

void scanAddonDir(const size_t apiVersion = CURRENT_INTERFACE_VERSION)
{
	auto dirs = getcwd.dirEntries(SpanMode.shallow)
		.filter!(a => (!isHiddenFileOrDir(a) && a.isDir))
		.array
		.sort!((a, b) => a.name < b.name);

	immutable size_t numberOfAddons = dirs.length;
	size_t numberOfOutdated;

	writeln(numberOfAddons, " addons found. Scanning toc files...");

	foreach(e; dirs)
	{
		immutable string name = buildNormalizedPath(e.name, e.name.baseName ~ ".toc");

		if(name.exists)
		{
			TocParser!AdditionalMethods parser;
			parser.loadFile(name);

			if(parser.getInterface() != apiVersion)
			{
				immutable string title = parser.getTitle();

				if(title.length)
				{
					if(title.canFind("|"))
					{
						writeln(name.baseName.stripExtension, " => ", parser.getInterface());
					}
					else
					{
						writeln(parser.getValue("Title"), " => ", parser.getInterface());
					}
				}
				else
				{
					writeln(name.baseName.stripExtension, " => ", parser.getInterface());
				}
				++numberOfOutdated;
			}
		}
	}

	writeln("Found a total of ", numberOfOutdated, " outdated addons!");
}

size_t getCurrentInterfaceVersion()
{
	Buffer!ubyte temp;

	immutable string apiUrl = "https://raw.githubusercontent.com/tomrus88/BlizzardInterfaceCode/master/Interface/FrameXML/FrameXML.toc";
	immutable string content = cast(string)getContent(apiUrl)
		.ifThrown!ConnectError(temp)
		.ifThrown!TimeoutException(temp)
		.ifThrown!ErrnoException(temp)
		.ifThrown!RequestException(temp);

	TocParser!AdditionalMethods parser;

	parser.loadString(content);
	return parser.getInterface(CURRENT_INTERFACE_VERSION);
}

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

	if(arguments.length == 1)
	{
		scanAddonDir();
	}
	else
	{
		generateGetOptCode!Options(arguments, options);

		if(options.hasUpdate())
		{
			immutable size_t apiVersion = getCurrentInterfaceVersion();
			scanAddonDir(apiVersion);
		}
	}
}
