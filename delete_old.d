/+ dub.sdl:
        dependency "requests" version="~>2.0.0"
        dependency "rm-rf" version="~>0.1.0"
+/

import std;
import requests;
import rm.rf;

enum keep_latest = 3;

void main(string[] args)
{
        if (args.length != 3)
        {
                writeln("usage: ", args[0], " [mirror] [folder]");
                return;
        }

        auto config = readText("config.json").parseJSON;
        auto keep_latest = config["keepLatest"].integer;

        string[] folders = dirEntries(args[2], SpanMode.shallow).map!(a => cast(string)a.chompPrefix(args[2]).chompPrefix("/")).filter!(a => !a.startsWith(".") && a != "README.txt").array;
        folders.sort!"a<b";
        writeln("local:  ", folders);

        string[] remote  = getContent(args[1]).to!string.matchAll(`<a\s+href="([^"]+?)/"\s*>`).map!(a => a[1]).filter!(a => !a.startsWith(".")).array;
        remote.sort!"a<b";
        if (remote.length > keep_latest)
                remote = remote[$ - keep_latest .. $];
        writeln("remote: ", remote);

        auto toDelete = setDifference(folders, remote);

        foreach (del; toDelete)
        {
                writeln("$ rm -rf ", buildPath(args[2], del));
                rmdirRecurseForce(buildPath(args[2], del));
        }
}

