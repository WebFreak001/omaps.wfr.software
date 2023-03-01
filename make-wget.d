/+ dub.sdl:
        dependency "requests" version="~>2.0.0"
        dependency "rm-rf" version="~>0.1.0"
+/
module makewget;

import std;
import requests;

void main(string[] args)
{
        auto config = readText("config.json").parseJSON;
        auto keep_latest = config["keepLatest"].integer;

        auto link = ctRegex!`<a href="([^"]*)"`;
        auto content = getContent("http://mirror.organicmaps.app/").toString;
        string[] dirs;
        foreach (match; content.matchAll(link))
        {
                auto file = match[1];
                if (file != "../" && file.length && file[$ - 1] == '/')
                        dirs ~= match[1].chomp("/");
        }
        dirs.sort!"a<b";
        stderr.writeln("all dirs: ", dirs);
        if (dirs.length > keep_latest)
        {
                // exclude all other than latest 3
                dirs = dirs[0 .. $ - keep_latest];
                writeln(`wget -U "mirror from omaps.wfr.software" -4 -X `, dirs.join(","), ` --mirror http://mirror.organicmaps.app/`);
        }
        else
                writeln(`wget -U "mirror from omaps.wfr.software" -4 --mirror http://mirror.organicmaps.app/`);
}
