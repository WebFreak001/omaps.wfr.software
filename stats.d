/+ dub.sdl:
dependency "asdf" version="~>0.7.9"
+/

import std;
import asdf;

struct Downloaded
{
        string file;
        long ts; // in hnsecs
        size_t size;
        double duration;
}

long convTs(double ts)
{
        return unixTimeToStdTime(cast(long)ts) + lround((ts % 1.0) * 10_000_000);
}

bool isRelevantPath(string s)
{
        return s.startsWith("/maps") && !s.endsWith(".html", ".md", ".txt");
}

string cleanURI(string s)
{
        auto query = s.indexOf("?");
        if (query != -1) s = s[0 .. query];
        return s.decodeComponent.chompPrefix("/maps/");
}

auto decompressReader(string file)
{
        static struct Decomp
        {
                File f;
                typeof(f.byChunk(4096)) it;
                UnCompress gzip;
                bool nextFlushed, flushed;

                this(string file)
                {
                        f = File(file);
                        it = f.byChunk(4096);
                        if (file.endsWith(".gz"))
                                gzip = new UnCompress(HeaderFormat.gzip);
                }

                ubyte[] cached;
                ubyte[] front()
                {
                        if (cached.length) return cached;

                        if (gzip)
                        {
                                if (it.empty)
                                {
                                        cached = cast(ubyte[])gzip.flush();
                                        nextFlushed = true;
                                }
                                else
                                {
                                        cached = cast(ubyte[])gzip.uncompress(it.front);
                                }
                                return cached;
                        }
                        else
                                return it.front;
                }

                bool empty()
                {
                        if (gzip)
                                return it.empty && (front.length == 0 || flushed);
                        else
                                return it.empty;
                }

                void popFront()
                {
                        cached = null;
                        if (!gzip || !it.empty)
                                it.popFront;
                        flushed = nextFlushed;
                }
        }

        return Decomp(file);
}

string anys(string[] s)
{
	return s.length ? s[0] : null;
}

auto getDownloaded(string file)
{
        return decompressReader(file)
                .parseJsonByLine()
                .filter!(a => a["request", "uri"].get!string("").isRelevantPath
                        && a["status"].get(0) == 200
			&& !a["request", "headers", "User-Agent"].get([""]).anys.startsWith("mirror from ")
                        && a["resp_headers", "Content-Length"].byElement.any!(l => a["size"].get!string("0") == l.get!string("0")))
                .map!(a => Downloaded(a["request", "uri"].get("").cleanURI, a["ts"].get!double(0).convTs, a["size"].get!long(0), a["duration"].get!double(0)));
}

void main()
{
        foreach (line; stdin.byLine)
                if (!line.strip.length) break;

        auto now = Clock.currTime();
        enum historyCount = 14;
        // 0 = today, 1 = yesterday, 2 = 2 days ago, etc.
        int[historyCount] recentDownloadCount;
        long[historyCount] recentDownloadSum;
        double[historyCount] recentDownloadDuration = 0;
        int[string] fileDownloadCount;
        long total;
        long totalBytes;
        double totalDuration = 0;
        long earliest = now.stdTime;

        void handle(Downloaded dl)
        {
                if (dl.ts < earliest) earliest = dl.ts;
                total++;
                totalBytes += dl.size;
                totalDuration += dl.duration;
                auto ago = (cast(Date)now - cast(Date)SysTime(dl.ts)).total!"days";
                if (ago >= 0 && ago < recentDownloadCount.length)
                {
                        recentDownloadCount[ago]++;
                        recentDownloadSum[ago] += dl.size;
                        recentDownloadDuration[ago] += dl.duration;
                }
                fileDownloadCount[dl.file]++;
        }

        static immutable historical = "/data/logs/http/historical/omaps";

        foreach (hist; dirEntries(historical, SpanMode.shallow).filter!(a => a.name.endsWith(".jsonl")))
        {
                foreach (dl; File(hist).byChunk(4096).parseJsonByLine)
                        handle(dl.deserialize!Downloaded);
        }

        foreach (log; dirEntries("/data/logs/http", SpanMode.shallow).filter!(a => a.name.startsWith("/data/logs/http/org.webfreak.omaps.access")))
        {
                bool store;
                string cache = buildPath(historical, log.baseName ~ ".jsonl");
                File cacheOut;
                if (log.name.endsWith(".gz"))
                {
                        if (exists(cache))
                                continue;
                        store = true;
                        cacheOut = File(cache, "w");
                }

                foreach (dl; getDownloaded(log))
                {
                        handle(dl);
                        if (store)
                                cacheOut.writeln(dl.serializeToJson);
                }
        }

        JSONValue[string] popularFiles;
        foreach (file, count; fileDownloadCount)
        {
                if (count >= 5)
                        popularFiles[file] = count;
        }

        write("HTTP/1.1 200 OK\r\n");
        write("Connection: close\r\n");
        write("Content-Type: application/json\r\n");
        write("\r\n");
        writefln(`{"start":"%s","hist":[%s,%s,%s],"popular":%s,"dls":%s,"bytes":%s,"secs":%s}`, SysTime(earliest, UTC()).toISOExtString, recentDownloadCount, recentDownloadSum, recentDownloadDuration, JSONValue(popularFiles), total, totalBytes, totalDuration);
        stdout.close();
}

