implement IcCopyCmd;

include "ic/copycmd.m";

IcAppPanel: module
{
	PATH: con "/dis/ic/appanel.dis";

	init: fn();
	refresh: fn(state: ref IcState->AppState, p: ref IcState->PanelState): int;
	clearselection: fn(state: ref IcState->AppState, p: ref IcState->PanelState): int;
};

IcPanelMod: module
{
	PATH: con "/dis/lib/icurses/panel.dis";

	init: fn();
	currentname: fn(p: ref IcPanel->Panel): string;
	currentkind: fn(p: ref IcPanel->Panel): string;
};

sys: Sys;
appanel: IcAppPanel;
panelui: IcPanelMod;

activepanel: fn(state: ref IcState->AppState): ref IcState->PanelState;
passivepanel: fn(state: ref IcState->AppState): ref IcState->PanelState;
trimdirsuffix: fn(name: string): string;
basename: fn(path: string): string;
joinpath: fn(base, name: string): string;
samefile: fn(a, b: Sys->Dir): int;
dstpath: fn(src, dstbase: string): string;
exists: fn(path: string): int;
copyfile: fn(src, dst: string, overwrite: int): int;
copydir: fn(src, dst: string, overwrite: int): int;
copyone: fn(src, dstbase: string, overwrite: int): int;
currentpath: fn(srcp: ref IcState->PanelState): string;
hascurrentconflict: fn(srcp, dstp: ref IcState->PanelState): int;
hasselectedconflicts: fn(srcp, dstp: ref IcState->PanelState): int;
copycurrent: fn(srcp, dstp: ref IcState->PanelState, overwrite: int): int;
copyselected: fn(srcp, dstp: ref IcState->PanelState, overwrite: int): int;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	appanel = load IcAppPanel IcAppPanel->PATH;
	if(appanel == nil)
		raise "fail:load ic/appanel";

	panelui = load IcPanelMod IcPanelMod->PATH;
	if(panelui == nil)
		raise "fail:load icurses/panel";

	appanel->init();
	panelui->init();
}

activepanel(state: ref IcState->AppState): ref IcState->PanelState
{
	if(state == nil)
		return nil;

	if(state.activepanel == IcState->PanelLeft)
		return state.left;

	return state.right;
}

passivepanel(state: ref IcState->AppState): ref IcState->PanelState
{
	if(state == nil)
		return nil;

	if(state.activepanel == IcState->PanelLeft)
		return state.right;

	return state.left;
}

trimdirsuffix(name: string): string
{
	if(len name > 1 && name[len name - 1] == '/')
		return name[0:len name - 1];

	return name;
}

basename(path: string): string
{
	i: int;

	if(path == "" || path == "/")
		return path;

	if(len path > 1 && path[len path - 1] == '/')
		path = path[0:len path - 1];

	for(i = len path - 1; i >= 0; i--){
		if(path[i] == '/')
			return path[i + 1:];
	}

	return path;
}

joinpath(base, name: string): string
{
	name = trimdirsuffix(name);

	if(base == "" || base == ".")
		return name;

	if(base == "/")
		return "/" + name;

	return base + "/" + name;
}

samefile(a, b: Sys->Dir): int
{
	return a.qid.path == b.qid.path && a.dev == b.dev && a.dtype == b.dtype;
}

dstpath(src, dstbase: string): string
{
	return joinpath(dstbase, basename(src));
}

exists(path: string): int
{
	ok: int;
	d: Sys->Dir;

	(ok, d) = sys->stat(path);
	d = d;

	return ok >= 0;
}

copyfile(src, dst: string, overwrite: int): int
{
	sfd, dfd: ref Sys->FD;
	ok: int;
	ds, dd: Sys->Dir;
	buf: array of byte;
	n: int;

	(ok, ds) = sys->stat(src);
	if(ok < 0)
		return -1;

	if((ds.mode & Sys->DMDIR) != 0)
		return -1;

	(ok, dd) = sys->stat(dst);
	if(ok >= 0){
		if((dd.mode & Sys->DMDIR) != 0)
			return -1;

		if(samefile(ds, dd))
			return 0;

		if(!overwrite)
			return -1;

		if(sys->remove(dst) < 0)
			return -1;
	}

	sfd = sys->open(src, Sys->OREAD);
	if(sfd == nil)
		return -1;

	dfd = sys->create(dst, Sys->OWRITE, ds.mode & 8r777);
	if(dfd == nil)
		return -1;

	buf = array[Sys->ATOMICIO] of byte;

	for(;;){
		n = sys->read(sfd, buf, len buf);
		if(n < 0)
			return -1;

		if(n == 0)
			break;

		if(sys->write(dfd, buf, n) != n)
			return -1;
	}

	return 0;
}

copydir(src, dst: string, overwrite: int): int
{
	ok, n, i: int;
	ds, dd: Sys->Dir;
	fd, dfd: ref Sys->FD;
	dirs: array of Sys->Dir;
	childsrc, childdst: string;

	(ok, ds) = sys->stat(src);
	if(ok < 0)
		return -1;

	if((ds.mode & Sys->DMDIR) == 0)
		return -1;

	(ok, dd) = sys->stat(dst);
	if(ok >= 0){
		if((dd.mode & Sys->DMDIR) == 0)
			return -1;

		if(samefile(ds, dd))
			return 0;
	}else{
		dfd = sys->create(dst, Sys->OREAD, Sys->DMDIR | (ds.mode & 8r777) | 8r300);
		if(dfd == nil)
			return -1;
	}

	fd = sys->open(src, Sys->OREAD);
	if(fd == nil)
		return -1;

	for(;;){
		(n, dirs) = sys->dirread(fd);
		if(n <= 0)
			break;

		for(i = 0; i < n; i++){
			childsrc = joinpath(src, dirs[i].name);
			childdst = joinpath(dst, dirs[i].name);

			if((dirs[i].mode & Sys->DMDIR) != 0){
				if(copydir(childsrc, childdst, overwrite) < 0)
					return -1;
			}else{
				if(copyfile(childsrc, childdst, overwrite) < 0)
					return -1;
			}
		}
	}

	return 0;
}

copyone(src, dstbase: string, overwrite: int): int
{
	ok: int;
	d: Sys->Dir;
	dst: string;

	if(src == "" || dstbase == "")
		return -1;

	(ok, d) = sys->stat(src);
	if(ok < 0)
		return -1;

	dst = dstpath(src, dstbase);

	if((d.mode & Sys->DMDIR) != 0)
		return copydir(src, dst, overwrite);

	return copyfile(src, dst, overwrite);
}

currentpath(srcp: ref IcState->PanelState): string
{
	name, kind: string;

	if(srcp == nil || srcp.panel == nil)
		return "";

	name = panelui->currentname(srcp.panel);
	kind = panelui->currentkind(srcp.panel);

	if(kind == "parent" || name == "..")
		return "";

	if(kind != "dir" && kind != "file")
		return "";

	return joinpath(srcp.path, name);
}

hascurrentconflict(srcp, dstp: ref IcState->PanelState): int
{
	src, dst: string;

	if(srcp == nil || dstp == nil)
		return 0;

	src = currentpath(srcp);
	if(src == "")
		return 0;

	dst = dstpath(src, dstp.path);
	return exists(dst);
}

hasselectedconflicts(srcp, dstp: ref IcState->PanelState): int
{
	i: int;
	dst: string;

	if(srcp == nil || dstp == nil || srcp.selected == nil)
		return 0;

	for(i = 0; i < len srcp.selected; i++){
		dst = dstpath(srcp.selected[i].path, dstp.path);
		if(exists(dst))
			return 1;
	}

	return 0;
}

hasconflicts(state: ref IcState->AppState): int
{
	srcp, dstp: ref IcState->PanelState;

	srcp = activepanel(state);
	dstp = passivepanel(state);

	if(srcp == nil || dstp == nil)
		return 0;

	if(srcp.selected != nil && len srcp.selected > 0)
		return hasselectedconflicts(srcp, dstp);

	return hascurrentconflict(srcp, dstp);
}

copycurrent(srcp, dstp: ref IcState->PanelState, overwrite: int): int
{
	src: string;

	if(srcp == nil || dstp == nil)
		return -1;

	src = currentpath(srcp);
	if(src == "")
		return 0;

	return copyone(src, dstp.path, overwrite);
}

copyselected(srcp, dstp: ref IcState->PanelState, overwrite: int): int
{
	i, rc: int;

	if(srcp == nil || dstp == nil || srcp.selected == nil)
		return -1;

	rc = 0;
	for(i = 0; i < len srcp.selected; i++){
		if(copyone(srcp.selected[i].path, dstp.path, overwrite) < 0)
			rc = -1;
	}

	return rc;
}

run(state: ref IcState->AppState, overwrite: int): int
{
	srcp, dstp: ref IcState->PanelState;
	rc: int;

	if(state == nil)
		return -1;

	srcp = activepanel(state);
	dstp = passivepanel(state);

	if(srcp == nil || dstp == nil)
		return -1;

	if(srcp.selected != nil && len srcp.selected > 0)
		rc = copyselected(srcp, dstp, overwrite);
	else
		rc = copycurrent(srcp, dstp, overwrite);

	appanel->clearselection(state, srcp);
	appanel->refresh(state, srcp);
	appanel->refresh(state, dstp);

	rc = rc;
	return 0;
}