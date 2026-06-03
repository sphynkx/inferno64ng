implement IcZipMount;

include "sys.m";
	sys: Sys;
include "draw.m";
include "ic/zipmount.m";

ZipFsMod: module
{
	PATH: con "/dis/zip/zipfs.dis";

	init: fn(ctxt: ref Draw->Context, args: list of string);
};

zipfs: ZipFsMod;

runzipfs: fn(zipfile: string, srvfd: ref Sys->FD, sync: chan of int);

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	zipfs = load ZipFsMod ZipFsMod->PATH;
	if(zipfs == nil)
		raise "fail:load zip/zipfs";
}

mount(zipfile, mountpoint: string): int
{
	p: array of ref Sys->FD;
	sync: chan of int;

	if(zipfile == "" || mountpoint == "")
		return -1;

	p = array[2] of ref Sys->FD;
	if(sys->pipe(p) < 0)
		return -1;

	sync = chan of int;
	spawn runzipfs(zipfile, p[1], sync);
	<-sync;

	if(sys->mount(p[0], nil, mountpoint, Sys->MREPL | Sys->MCREATE, nil) < 0)
		return -1;

	return 0;
}

runzipfs(zipfile: string, srvfd: ref Sys->FD, sync: chan of int)
{
	args: list of string;

	sys->pctl(Sys->FORKFD, nil);
	sys->dup(srvfd.fd, 0);
	srvfd = nil;

	args = "zipfs" :: zipfile :: nil;
	sync <-= 0;
	zipfs->init(nil, args);
}