implement IcArchiveUtil;

include "sys.m";
	sys: Sys;
include "draw.m";
include "ic/archiveutil.m";

GunzipMod: module
{
	PATH: con "/dis/gunzip.dis";

	init: fn(ctxt: ref Draw->Context, argv: list of string);
};

gunzip: GunzipMod;

dogunzip: fn(src, dst: string): int;
tmptarpath: fn(path: string): string;
mounttag: fn(path: string): string;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	gunzip = load GunzipMod GunzipMod->PATH;
	if(gunzip == nil)
		raise "fail:load gunzip";
}

istargz(path: string): int
{
	if(path == "")
		return 0;

	if(len path >= len ".tar.gz" && path[len path - len ".tar.gz":] == ".tar.gz")
		return 1;

	if(len path >= len ".tgz" && path[len path - len ".tgz":] == ".tgz")
		return 1;

	return 0;
}

stagedtarpath(path: string): string
{
	if(path == "")
		return "";

	if(len path >= len ".tar.gz" && path[len path - len ".tar.gz":] == ".tar.gz")
		return tmptarpath(path[0:len path - len ".gz"]);

	if(len path >= len ".tgz" && path[len path - len ".tgz":] == ".tgz")
		return tmptarpath(path[0:len path - len ".tgz"] + ".tar");

	return "";
}

preparetarpath(path: string): (string, string)
{
	staged: string;

	if(!istargz(path))
		return (path, "");

	staged = stagedtarpath(path);
	if(staged == "")
		return ("", "");

	if(dogunzip(path, staged) < 0){
		sys->remove(staged);
		return ("", "");
	}

	return (staged, staged);
}

dogunzip(src, dst: string): int
{
	infd, outfd: ref Sys->FD;
	argv: list of string;

	if(src == "" || dst == "")
		return -1;

	infd = sys->open(src, Sys->OREAD);
	if(infd == nil)
		return -1;

	outfd = sys->create(dst, Sys->OWRITE, 8r666);
	if(outfd == nil){
		infd = nil;
		return -1;
	}

	sys->pctl(Sys->FORKFD, nil);
	sys->dup(infd.fd, 0);
	sys->dup(outfd.fd, 1);

	argv = "gunzip" :: nil;
	gunzip->init(nil, argv);

	infd = nil;
	outfd = nil;

	return 0;
}

tmptarpath(path: string): string
{
	i: int;
	base, tag, out: string;
	fd: ref Sys->FD;
	ticks: int;

	base = "/tmp/ic";
	fd = sys->open(base, Sys->OREAD);
	if(fd == nil)
		sys->create(base, Sys->OREAD, Sys->DMDIR | 8r777);

	tag = mounttag(path);
	ticks = sys->millisec();

	for(i = 0; i < 64; i++){
		out = base + "/" + tag + "_" + string ticks + "_" + string i;
		fd = sys->open(out, Sys->OREAD);
		if(fd != nil)
			continue;

		return out;
	}

	return "";
}

mounttag(path: string): string
{
	i: int;
	tag: string;

	tag = path;
	for(i = len tag - 1; i >= 0; i--){
		if(tag[i] == '/')
			return tag[i + 1:];
	}

	return tag;
}