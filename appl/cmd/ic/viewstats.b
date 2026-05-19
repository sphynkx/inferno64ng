implement IcViewStats;

include "ic/viewstats.m";

sys: Sys;

ScanChunkSize: con 32768;

statstoken: int;
statspath: string;
stats: IcViewCommon->ViewerStats;

worker: fn(path: string, token: int);

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	statstoken = 0;
	statspath = "";
	stats.ready = 0;
	stats.dirty = 0;
	stats.bytes = big 0;
	stats.lines = big 0;
	stats.chars = big 0;
}

start(path: string, knownbytes: big)
{
	statstoken++;
	statspath = path;

	stats.ready = 0;
	stats.dirty = 1;
	stats.bytes = big 0;
	stats.lines = big 0;
	stats.chars = big 0;

	if(knownbytes > big 0){
		stats.bytes = knownbytes;
		stats.chars = knownbytes;
	}

	if(path == "")
		return;

	spawn worker(path, statstoken);
}

stop()
{
	statstoken++;
	statspath = "";

	stats.ready = 0;
	stats.dirty = 0;
	stats.bytes = big 0;
	stats.lines = big 0;
	stats.chars = big 0;
}

get(): IcViewCommon->ViewerStats
{
	return stats;
}

cleardirty()
{
	stats.dirty = 0;
}

worker(path: string, token: int)
{
	fd: ref Sys->FD;
	buf: array of byte;
	n, i: int;
	bytes, lines, chars: big;

	fd = sys->open(path, Sys->OREAD);
	if(fd == nil)
		return;

	buf = array[ScanChunkSize] of byte;
	bytes = big 0;
	lines = big 0;
	chars = big 0;

	for(;;){
		n = sys->read(fd, buf, len buf);
		if(n <= 0)
			break;

		bytes += big n;
		chars += big n;

		for(i = 0; i < n; i++){
			if(int buf[i] == '\n')
				lines++;
		}
	}

	fd = nil;

	if(token != statstoken)
		return;

	if(path != statspath)
		return;

	stats.bytes = bytes;
	stats.lines = lines;
	stats.chars = chars;
	stats.ready = 1;
	stats.dirty = 1;
}