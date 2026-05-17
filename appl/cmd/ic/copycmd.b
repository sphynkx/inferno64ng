implement IcCopyCmd;

include "ic/copycmd.m";

IcAppPanel: module
{
	PATH: con "/dis/ic/appanel.dis";

	init: fn();
	refresh: fn(state: ref IcState->AppState, p: ref IcState->PanelState): int;
};

IcPanelMod: module
{
	PATH: con "/dis/lib/icurses/panel.dis";

	init: fn();
	currentname: fn(p: ref IcPanel->Panel): string;
	currentkind: fn(p: ref IcPanel->Panel): string;
};

IcModal: module
{
	PATH: con "/dis/ic/modal.dis";

	ResultNone: con 0;
	ResultOk: con 1;
	ResultCancel: con 2;
	ResultOverwrite: con 3;
	ResultSkip: con 4;

	init: fn();
	close: fn(state: ref IcState->AppState): int;
	showcopyconfirm: fn(state: ref IcState->AppState, count: int, direction, target: string): int;
	showmoveconfirm: fn(state: ref IcState->AppState, count: int, direction, target: string): int;
	showoverwrite: fn(state: ref IcState->AppState, path: string): int;
	handlekey: fn(state: ref IcState->AppState, k: int): int;
};

sys: Sys;
appanel: IcAppPanel;
panelui: IcPanelMod;
modal: IcModal;

PhaseNone: con 0;
PhaseConfirm: con 1;
PhaseCopy: con 2;
PhaseOverwrite: con 3;

KindFile: con "file";
KindDir: con "dir";

activepanel: fn(state: ref IcState->AppState): ref IcState->PanelState;
passivepanel: fn(state: ref IcState->AppState): ref IcState->PanelState;
initcopy: fn(state: ref IcState->AppState);
trimdirsuffix: fn(name: string): string;
basename: fn(path: string): string;
joinpath: fn(base, name: string): string;
samefile: fn(a, b: Sys->Dir): int;
copydst: fn(state: ref IcState->AppState, t: IcState->CopyTask): string;
appendtask: fn(a: array of IcState->CopyTask, t: IcState->CopyTask): array of IcState->CopyTask;
prepareone: fn(tasks: array of IcState->CopyTask, src, rel: string): array of IcState->CopyTask;
preparecurrent: fn(srcp: ref IcState->PanelState): array of IcState->CopyTask;
prepareselected: fn(srcp: ref IcState->PanelState): array of IcState->CopyTask;
currentpath: fn(srcp: ref IcState->PanelState): string;
directiontext: fn(state: ref IcState->AppState): string;
defaulttarget: fn(state: ref IcState->AppState, srcp, dstp: ref IcState->PanelState): string;
makeparentdirs: fn(path: string): int;
copyfile: fn(src, dst: string, overwrite: int): int;
makedir: fn(path: string, mode: int): int;
removefile: fn(path: string): int;
removedirempty: fn(path: string): int;
processtask: fn(state: ref IcState->AppState, t: IcState->CopyTask, overwrite: int): int;
cleanupmove: fn(state: ref IcState->AppState, t: IcState->CopyTask): int;
conflict: fn(state: ref IcState->AppState, t: IcState->CopyTask): int;
startop: fn(state: ref IcState->AppState, move: int): int;
proceed: fn(state: ref IcState->AppState): int;
finish: fn(state: ref IcState->AppState): int;

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

	modal = load IcModal IcModal->PATH;
	if(modal == nil)
		raise "fail:load ic/modal";

	appanel->init();
	panelui->init();
	modal->init();
}

initcopy(state: ref IcState->AppState)
{
	if(state == nil)
		return;

	if(state.copy != nil)
		return;

	state.copy = ref IcState->CopyState;
	state.copy.active = 0;
	state.copy.phase = PhaseNone;
	state.copy.move = 0;
	state.copy.index = 0;
	state.copy.overwriteall = 0;
	state.copy.errors = 0;
	state.copy.target = "";
	state.copy.singletarget = 0;
	state.copy.tasks = array[0] of IcState->CopyTask;
}

active(state: ref IcState->AppState): int
{
	if(state == nil || state.copy == nil)
		return 0;

	return state.copy.active != 0;
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

copydst(state: ref IcState->AppState, t: IcState->CopyTask): string
{
	if(state != nil && state.copy != nil && state.copy.singletarget)
		return state.copy.target;

	if(state == nil || state.copy == nil)
		return t.rel;

	return joinpath(state.copy.target, t.rel);
}

appendtask(a: array of IcState->CopyTask, t: IcState->CopyTask): array of IcState->CopyTask
{
	r: array of IcState->CopyTask;
	i, n: int;

	if(a == nil){
		r = array[1] of IcState->CopyTask;
		r[0] = t;
		return r;
	}

	n = len a;
	r = array[n + 1] of IcState->CopyTask;

	for(i = 0; i < n; i++)
		r[i] = a[i];

	r[n] = t;
	return r;
}

prepareone(tasks: array of IcState->CopyTask, src, rel: string): array of IcState->CopyTask
{
	ok, n, i: int;
	d: Sys->Dir;
	fd: ref Sys->FD;
	dirs: array of Sys->Dir;
	t: IcState->CopyTask;

	(ok, d) = sys->stat(src);
	if(ok < 0)
		return tasks;

	if((d.mode & Sys->DMDIR) != 0){
		t.src = src;
		t.rel = rel;
		t.kind = KindDir;
		t.mode = d.mode;
		tasks = appendtask(tasks, t);

		fd = sys->open(src, Sys->OREAD);
		if(fd == nil)
			return tasks;

		for(;;){
			(n, dirs) = sys->dirread(fd);
			if(n <= 0)
				break;

			for(i = 0; i < n; i++)
				tasks = prepareone(tasks, joinpath(src, dirs[i].name), joinpath(rel, dirs[i].name));
		}

		return tasks;
	}

	t.src = src;
	t.rel = rel;
	t.kind = KindFile;
	t.mode = d.mode;
	return appendtask(tasks, t);
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

preparecurrent(srcp: ref IcState->PanelState): array of IcState->CopyTask
{
	src: string;
	tasks: array of IcState->CopyTask;

	tasks = array[0] of IcState->CopyTask;

	if(srcp == nil)
		return tasks;

	src = currentpath(srcp);
	if(src == "")
		return tasks;

	return prepareone(tasks, src, basename(src));
}

prepareselected(srcp: ref IcState->PanelState): array of IcState->CopyTask
{
	i: int;
	tasks: array of IcState->CopyTask;

	tasks = array[0] of IcState->CopyTask;

	if(srcp == nil || srcp.selected == nil)
		return tasks;

	for(i = 0; i < len srcp.selected; i++)
		tasks = prepareone(tasks, srcp.selected[i].path, basename(srcp.selected[i].path));

	return tasks;
}

directiontext(state: ref IcState->AppState): string
{
	if(state == nil)
		return "";

	if(state.activepanel == IcState->PanelLeft)
		return "=>";

	return "<=";
}

defaulttarget(state: ref IcState->AppState, srcp, dstp: ref IcState->PanelState): string
{
	if(state == nil || state.copy == nil || dstp == nil)
		return "";

	if(len state.copy.tasks == 1 && state.copy.tasks[0].kind == KindFile){
		state.copy.singletarget = 1;
		return joinpath(dstp.path, state.copy.tasks[0].rel);
	}

	state.copy.singletarget = 0;
	return dstp.path;
}

makeparentdirs(path: string): int
{
	i: int;
	p: string;
	fd: ref Sys->FD;
	ok: int;
	d: Sys->Dir;

	p = "";

	for(i = 0; i < len path; i++){
		if(path[i] != '/')
			continue;

		if(i == 0)
			continue;

		p = path[0:i];

		(ok, d) = sys->stat(p);
		if(ok >= 0){
			if((d.mode & Sys->DMDIR) == 0)
				return -1;
			continue;
		}

		fd = sys->create(p, Sys->OREAD, Sys->DMDIR | 8r777);
		if(fd == nil)
			return -1;
	}

	return 0;
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

	if(makeparentdirs(dst) < 0)
		return -1;

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

makedir(path: string, mode: int): int
{
	ok: int;
	d: Sys->Dir;
	fd: ref Sys->FD;

	(ok, d) = sys->stat(path);
	if(ok >= 0){
		if((d.mode & Sys->DMDIR) != 0)
			return 0;

		return -1;
	}

	if(makeparentdirs(path) < 0)
		return -1;

	fd = sys->create(path, Sys->OREAD, Sys->DMDIR | (mode & 8r777) | 8r300);
	if(fd == nil)
		return -1;

	return 0;
}

removefile(path: string): int
{
	return sys->remove(path);
}

removedirempty(path: string): int
{
	return sys->remove(path);
}

processtask(state: ref IcState->AppState, t: IcState->CopyTask, overwrite: int): int
{
	dst: string;

	dst = copydst(state, t);

	if(t.kind == KindDir)
		return makedir(dst, t.mode);

	return copyfile(t.src, dst, overwrite);
}

cleanupmove(state: ref IcState->AppState, t: IcState->CopyTask): int
{
	dst, src: string;
	ok: int;
	ds, dd: Sys->Dir;

	if(state == nil || state.copy == nil || !state.copy.move)
		return 0;

	src = t.src;
	dst = copydst(state, t);

	(ok, ds) = sys->stat(src);
	if(ok < 0)
		return 0;

	(ok, dd) = sys->stat(dst);
	if(ok < 0)
		return 0;

	if(samefile(ds, dd))
		return 0;

	if(t.kind == KindFile)
		return removefile(src);

	return 0;
}

conflict(state: ref IcState->AppState, t: IcState->CopyTask): int
{
	ok: int;
	d: Sys->Dir;

	if(t.kind != KindFile)
		return 0;

	(ok, d) = sys->stat(copydst(state, t));
	d = d;

	return ok >= 0;
}

startop(state: ref IcState->AppState, move: int): int
{
	srcp, dstp: ref IcState->PanelState;

	if(state == nil)
		return -1;

	initcopy(state);

	srcp = activepanel(state);
	dstp = passivepanel(state);

	if(srcp == nil || dstp == nil)
		return 0;

	state.copy.active = 1;
	state.copy.phase = PhaseConfirm;
	state.copy.move = move != 0;
	state.copy.index = 0;
	state.copy.overwriteall = 0;
	state.copy.errors = 0;
	state.copy.target = "";
	state.copy.singletarget = 0;

	if(srcp.selected != nil && len srcp.selected > 0)
		state.copy.tasks = prepareselected(srcp);
	else
		state.copy.tasks = preparecurrent(srcp);

	if(len state.copy.tasks == 0)
		return finish(state);

	state.copy.target = defaulttarget(state, srcp, dstp);

	if(move)
		return modal->showmoveconfirm(state, len state.copy.tasks, directiontext(state), state.copy.target);

	return modal->showcopyconfirm(state, len state.copy.tasks, directiontext(state), state.copy.target);
}

startcopy(state: ref IcState->AppState): int
{
	return startop(state, 0);
}

startmove(state: ref IcState->AppState): int
{
	return startop(state, 1);
}

proceed(state: ref IcState->AppState): int
{
	t: IcState->CopyTask;
	i: int;

	if(state == nil || state.copy == nil)
		return 0;

	state.copy.phase = PhaseCopy;

	while(state.copy.index < len state.copy.tasks){
		t = state.copy.tasks[state.copy.index];

		if(conflict(state, t) && !state.copy.overwriteall){
			state.copy.phase = PhaseOverwrite;
			return modal->showoverwrite(state, copydst(state, t));
		}

		if(processtask(state, t, state.copy.overwriteall) < 0)
			state.copy.errors++;
		else if(cleanupmove(state, t) < 0)
			state.copy.errors++;

		state.copy.index++;
	}

	if(state.copy.move){
		for(i = len state.copy.tasks - 1; i >= 0; i--){
			if(state.copy.tasks[i].kind != KindDir)
				continue;

			if(removedirempty(state.copy.tasks[i].src) < 0)
				state.copy.errors++;
		}
	}

	return finish(state);
}

finish(state: ref IcState->AppState): int
{
	srcp, dstp: ref IcState->PanelState;
	errors, move: int;

	if(state == nil)
		return -1;

	initcopy(state);

	srcp = activepanel(state);
	dstp = passivepanel(state);

	errors = state.copy.errors;
	move = state.copy.move;

	if(srcp != nil)
		srcp.selected = array[0] of IcState->SelectedItem;

	state.copy.active = 0;
	state.copy.phase = PhaseNone;
	state.copy.move = 0;
	state.copy.index = 0;
	state.copy.overwriteall = 0;
	state.copy.target = "";
	state.copy.singletarget = 0;
	state.copy.tasks = array[0] of IcState->CopyTask;

	modal->close(state);

	if(srcp != nil)
		appanel->refresh(state, srcp);
	if(dstp != nil)
		appanel->refresh(state, dstp);

	if(state.ui != nil){
		if(errors > 0){
			if(move)
				state.ui.status = "move finished with errors";
			else
				state.ui.status = "copy finished with errors";
		}else{
			if(move)
				state.ui.status = "move done";
			else
				state.ui.status = "copy done";
		}
	}

	return 0;
}

handlekey(state: ref IcState->AppState, k: int): int
{
	r: int;
	t: IcState->CopyTask;

	if(state == nil || state.copy == nil || !state.copy.active)
		return 0;

	r = modal->handlekey(state, k);
	if(r == IcModal->ResultNone)
		return 0;

	if(state.copy.phase == PhaseConfirm){
		if(r == IcModal->ResultCancel)
			return finish(state);

		if(r == IcModal->ResultOk){
			if(state.modal != nil){
				state.copy.overwriteall = state.modal.checked != 0;
				state.copy.target = state.modal.input;
			}

			if(state.copy.target == "")
				return finish(state);

			modal->close(state);
			return proceed(state);
		}
	}

	if(state.copy.phase == PhaseOverwrite){
		t = state.copy.tasks[state.copy.index];

		if(r == IcModal->ResultOverwrite){
			if(processtask(state, t, 1) < 0)
				state.copy.errors++;
			else if(cleanupmove(state, t) < 0)
				state.copy.errors++;

			state.copy.index++;
			modal->close(state);
			return proceed(state);
		}

		if(r == IcModal->ResultSkip){
			state.copy.index++;
			modal->close(state);
			return proceed(state);
		}

		if(r == IcModal->ResultCancel)
			return finish(state);
	}

	return 0;
}