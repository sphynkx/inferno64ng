implement IcFsModel;

include "ic/fsmodel.m";

sys: Sys;

appendentry: fn(a: array of IcState->FsEntry, e: IcState->FsEntry): array of IcState->FsEntry;
entryname: fn(d: Sys->Dir): string;
isdir: fn(d: Sys->Dir): int;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";
}

appendentry(a: array of IcState->FsEntry, e: IcState->FsEntry): array of IcState->FsEntry
{
	r: array of IcState->FsEntry;
	i, n: int;

	if(a == nil){
		r = array[1] of IcState->FsEntry;
		r[0] = e;
		return r;
	}

	n = len a;
	r = array[n + 1] of IcState->FsEntry;

	for(i = 0; i < n; i++)
		r[i] = a[i];

	r[n] = e;
	return r;
}

isdir(d: Sys->Dir): int
{
	if((d.mode & Sys->DMDIR) != 0)
		return 1;

	return 0;
}

entryname(d: Sys->Dir): string
{
	if(isdir(d))
		return d.name + "/";

	return d.name;
}

readdir(path: string): ref IcState->PanelDir
{
	d: ref IcState->PanelDir;
	fd: ref Sys->FD;
	n, i: int;
	dirs: array of Sys->Dir;
	e: IcState->FsEntry;

	d = ref IcState->PanelDir;
	d.path = path;
	d.items = array[0] of IcState->FsEntry;

	if(path == "")
		d.path = ".";

	fd = sys->open(d.path, Sys->OREAD);
	if(fd == nil)
		return d;

	for(;;){
		(n, dirs) = sys->dirread(fd);
		if(n <= 0)
			break;

		for(i = 0; i < n; i++){
			e.name = entryname(dirs[i]);
			e.isdir = isdir(dirs[i]);
			d.items = appendentry(d.items, e);
		}
	}

	return d;
}

renderitems(d: ref IcState->PanelDir): array of string
{
	r: array of string;
	i: int;

	if(d == nil || d.items == nil)
		return array[0] of string;

	r = array[len d.items] of string;

	for(i = 0; i < len d.items; i++)
		r[i] = d.items[i].name;

	return r;
}