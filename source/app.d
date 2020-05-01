import std.stdio;
import std.algorithm;
import std.file;
import std.array;
import std.path;
import std.conv;
import core.exception : RangeError;

import luaaddon.tocparser;
import ctoptions.structoptions;
import ctoptions.getoptmixin;

import addonlistformatter;

enum CURRENT_INTERFACE_VERSION = 80_300;

// Used to add additional methods to TocParser.
struct AdditionalMethods
{
	string Title;
	size_t Interface; // Has to be capitalized since it is a keyword.
}

// Used to determine how outdated an Addon is.
enum InterfaceVersionTypes
{
	current, // Ex 80100
	minor, // Ex 80000
	major // Ex 60000
}

bool isHiddenFileOrDir(const DirEntry entry)
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
		version(Windows)
		{
			import core.sys.windows : getAttributes, FILE_ATTRIBUTE_HIDDEN;

			if(getAttributes(dirPart) & FILE_ATTRIBUTE_HIDDEN)
			{
				return true;
			}
		}
	}

	return false;
}

bool isAddonOutdated(const size_t addonVersion)
{
	immutable size_t currentVersion = CURRENT_INTERFACE_VERSION;

	if(addonVersion < currentVersion)
	{
		return true;
	}

	return false;
}

//TODO Create a formated string that is colorized by how out of date an addons is.
void scanAddonDir(const size_t apiVersion = CURRENT_INTERFACE_VERSION, const string author = string.init)
{
	auto dirs = getcwd.dirEntries(SpanMode.shallow)
		.filter!(a => (!isHiddenFileOrDir(a) && a.isDir))
		.array
		.sort!((a, b) => a.name < b.name);

	immutable size_t numberOfAddons = dirs.length;
	size_t numberOfOutdated;

	writeln("Found ", numberOfAddons, " to check. Scanning addons...");

	foreach(e; dirs)
	{
		immutable string name = buildNormalizedPath(e.name, e.name.baseName ~ ".toc");

		if(name.exists)
		{
			TocParser!AdditionalMethods parser;
			parser.loadFile(name);

			immutable size_t addonInterfaceVer = parser.getInterface();
			immutable bool severe = isAddonOutdated(addonInterfaceVer);

			if(addonInterfaceVer != apiVersion)
			{
				immutable string title = parser.getTitle();

				if(title.length)
				{
					// INFO Some addons use | in there name to colorize it.
					if(title.canFind("|"))
					{
						writeln(name.baseName.stripExtension, " => ", addonInterfaceVer, " Severely Outdated: ", severe);
					}
					else
					{
						writeln(parser.getValue("Title"), " => ", addonInterfaceVer, " Severely Outdated: ", severe);
					}
				}
				else // INFO: Use the directory name for the name of the addon.
				{
					writeln(name.baseName.stripExtension, " => ", addonInterfaceVer, " Severely Outdated: ", severe);
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
	}
}
