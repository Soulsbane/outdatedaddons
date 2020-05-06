module addonlistgenerator;

import std.stdio;
import std.algorithm;
import std.file;
import std.array;
import std.path;
import std.conv;
import std.string;
import core.exception : RangeError;

import colored;

import addonlistformatter;
import luaaddon.tocparser;

import constants;
// Used to add additional methods to TocParser.
struct AdditionalMethods
{
	string Title;
	size_t Interface; // Has to be capitalized since it is a keyword.
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

class AddonListGenerator
{
private:
	AddonListFormatter formatter_;
public:
	this()
	{
		formatter_ = new AddonListFormatter(3);
	}

	string isAddonOutdated(const size_t addonVersion)
	{
		if((CURRENT_INTERFACE_VERSION - addonVersion) >= MAX_VERSION_TOLERANCE)
		{
			immutable string yes = "YES".red.toString;
			return yes;
		}

		return "No";
	}

	// INFO: The name of an addon can be colorized sometimes. So use the directory name instead.
	string getAddonTitle(string title, string dirName)
	{
		if(title.length)
		{
			// INFO: Some addons use | in there name to colorize it.
			if(title.canFind("|"))
			{
				return dirName;
			}

			return title;
		}

		return dirName;
	}

	void processAddonDir(DirEntry e)
	{
		immutable string name = buildNormalizedPath(e.name, e.name.baseName ~ ".toc");

		if(name.exists)
		{
			TocParser!AdditionalMethods parser;
			parser.loadFile(name);

			immutable size_t addonInterfaceVer = parser.getInterface();
			immutable string isSeverelyOutdated = isAddonOutdated(addonInterfaceVer);

			if(addonInterfaceVer != CURRENT_INTERFACE_VERSION)
			{
				immutable string title = getAddonTitle(parser.getTitle(), e.name.baseName);
				formatter_.addRow(title, addonInterfaceVer, isSeverelyOutdated);
			}
		}
	}

	void scanAddonDir()
	{
		formatter_.writeHeader("Name", "Version", "Outdated");

		getcwd.dirEntries(SpanMode.shallow)
			.filter!(a => (!isHiddenFileOrDir(a) && a.isDir))
			.array
			.sort!((a, b) => a.name < b.name)
			.each!((entry) => processAddonDir(entry));

		formatter_.render();
	}
}

