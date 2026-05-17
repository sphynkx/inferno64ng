implement IcDeleteCmd;

include "ic/deletecmd.m";

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

	init: fn();
	close: fn(state: ref IcState->AppState): int;
	showdeleteconfirm: fn(state: ref IcState->AppState, count: int, target: string): int;
	handlekey: fn(state: ref IcState->AppState, k: int): int;
};

sys: Sys;
appanel: IcAppPanel;
panelui: IcPanelMod;
modal: IcModal;

PhaseNone: con 0;
PhaseConfirm: con 1;
PhaseDelete: con 2;

KindFile: con "file";
KindDir: con "dir";

activepanel: fn(state: ref IcState->AppState): ref IcState->PanelState;
passivepanel: fn(state: ref IcState->AppState): ref IcState->PanelState;
initdelete: fn(state: ref IcState->AppState);
trimdirsuffix: fn(name: string): string;
basename: fn(path: string): string;
joinpath: fn(base, name: string): string;
currentpath: fn(srcp: ref IcState->PanelState): string;
appendtask: fn(a: array of IcState->DeleteTask, t: IcState->DeleteTask): array of IcState->DeleteTask;
prepareone: fn(tasks: array of IcState->DeleteTask, path: string): array of IcState->DeleteTask;
preparecurrent: fn(srcp: ref IcState->PanelState): array of IcState->DeleteTask;
prepareselected: fn(srcp: ref IcState->PanelState): array of IcState->DeleteTask;
targetsummary: fn(state: ref IcState->AppState): string;
depth: fn(path: string): int;
sorttasks: fn(a: array of IcState->DeleteTask): array of IcState->DeleteTask;
deletetaskless: fn(a, b: IcState->DeleteTask): int;
swaptasks: fn(a: array of IcState->DeleteTask, i, j: int);
deletetask: fn(t: IcState->DeleteTask): int;
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

initdelete(state: ref IcState->AppState)
{
	if(state == nil)
		return;

	if(state.delete != nil)
		return;

	state.delete = ref IcState->DeleteState;
	state.delete.active = 0;
	state.delete.phase = PhaseNone;
	state.delete.index = 0;
	state.delete.errors = 0;
	state.delete.targetsummary = "";
	state.delete.tasks = array[0] of IcState->DeleteTask;
}

active(state: ref IcState->AppState): int
{
	if(state == nil || state.delete == nil)
		return 0;

	return state.delete.active != 0;
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

appendtask(a: array of IcState->DeleteTask, t: IcState->DeleteTask): array of IcState->DeleteTask
{
	r: array of IcState->DeleteTask;
	i, n: int;

	if(a == nil){
		r = array[1] of IcState->DeleteTask;
		r[0] = t;
		return r;
	}

	n = len a;
	r = array[n + 1] of IcState->DeleteTask;

	for(i = 0; i < n; i++)
		r[i] = a[i];

	r[n] = t;
	return r;
}

prepareone(tasks: array of IcState->DeleteTask, path: string): array of IcState->DeleteTask
{
	ok, n, i: int;
	d: Sys->Dir;
	fd: ref Sys->FD;
	dirs: array of Sys->Dir;
	t: IcState->DeleteTask;

	(ok, d) = sys->stat(path);
	if(ok < 0)
		return tasks;

	if((d.mode & Sys->DMDIR) != 0){
		fd = sys->open(path, Sys->OREAD);
		if(fd != nil){
			for(;;){
				(n, dirs) = sys->dirread(fd);
				if(n <= 0)
					break;

				for(i = 0; i < n; i++)
					tasks = prepareone(tasks, joinpath(path, dirs[i].name));
			}
		}

		t.path = path;
		t.kind = KindDir;
		return appendtask(tasks, t);
	}

	t.path = path;
	t.kind = KindFile;
	return appendtask(tasks, t);
}

preparecurrent(srcp: ref IcState->PanelState): array of IcState->DeleteTask
{
	src: string;
	tasks: array of IcState->DeleteTask;

	tasks = array[0] of IcState->DeleteTask;

	if(srcp == nil)
		return tasks;

	src = currentpath(srcp);
	if(src == "")
		return tasks;

	return prepareone(tasks, src);
}

prepareselected(srcp: ref IcState->PanelState): array of IcState->DeleteTask
{
	i: int;
	tasks: array of IcState->DeleteTask;

	tasks = array[0] of IcState->DeleteTask;

	if(srcp == nil || srcp.selected == nil)
		return tasks;

	for(i = 0; i < len srcp.selected; i++)
		tasks = prepareone(tasks, srcp.selected[i].path);

	return tasks;
}

targetsummary(state: ref IcState->AppState): string
{
	srcp: ref IcState->PanelState;
	p: string;

	srcp = activepanel(state);
	if(srcp == nil)
		return "";

	if(state == nil || state.delete == nil || len state.delete.tasks == 0)
		return "";

	if(len state.delete.tasks == 1)
		return state.delete.tasks[0].path;

	p = srcp.path;
	if(p == "")
		return string (len state.delete.tasks) + " item(s)";

	return p + "  (" + string (len state.delete.tasks) + " item(s))";
}

depth(path: string): int
{
	i, d: int;

	d = 0;
	for(i = 0; i < len path; i++)
		if(path[i] == '/')
			d++;

	return d;
}

deletetaskless(a, b: IcState->DeleteTask): int
{
	if(a.kind != b.kind){
		if(a.kind == KindFile)
			return 1;
		return 0;
	}

	if(a.kind == KindDir){
		if(depth(a.path) > depth(b.path))
			return 1;
		if(depth(a.path) < depth(b.path))
			return 0;
	}

	return a.path < b.path;
}

swaptasks(a: array of IcState->DeleteTask, i, j: int)
{
	t: IcState->DeleteTask;

	t = a[i];
	a[i] = a[j];
	a[j] = t;
}

sorttasks(a: array of IcState->DeleteTask): array of IcState->DeleteTask
{
	i, j: int;

	if(a == nil)
		return array[0] of IcState->DeleteTask;

	for(i = 0; i < len a; i++){
		for(j = i + 1; j < len a; j++){
			if(deletetaskless(a[j], a[i]))
				swaptasks(a, i, j);
		}
	}

	return a;
}

deletetask(t: IcState->DeleteTask): int
{
	return sys->remove(t.path);
}

start(state: ref IcState->AppState): int
{
	srcp: ref IcState->PanelState;

	if(state == nil)
		return -1;

	initdelete(state);

	srcp = activepanel(state);
	if(srcp == nil)
		return 0;

	state.delete.active = 1;
	state.delete.phase = PhaseConfirm;
	state.delete.index = 0;
	state.delete.errors = 0;
	state.delete.targetsummary = "";

	if(srcp.selected != nil && len srcp.selected > 0)
		state.delete.tasks = prepareselected(srcp);
	else
		state.delete.tasks = preparecurrent(srcp);

	state.delete.tasks = sorttasks(state.delete.tasks);

	if(len state.delete.tasks == 0)
		return finish(state);

	state.delete.targetsummary = targetsummary(state);

	return modal->showdeleteconfirm(state, len state.delete.tasks, state.delete.targetsummary);
}

proceed(state: ref IcState->AppState): int
{
	t: IcState->DeleteTask;

	if(state == nil || state.delete == nil)
		return 0;

	state.delete.phase = PhaseDelete;

	while(state.delete.index < len state.delete.tasks){
		t = state.delete.tasks[state.delete.index];

		if(deletetask(t) < 0)
			state.delete.errors++;

		state.delete.index++;
	}

	return finish(state);
}

finish(state: ref IcState->AppState): int
{
	srcp, dstp: ref IcState->PanelState;
	errors: int;

	if(state == nil)
		return -1;

	initdelete(state);

	srcp = activepanel(state);
	dstp = passivepanel(state);

	errors = state.delete.errors;

	if(srcp != nil)
		srcp.selected = array[0] of IcState->SelectedItem;

	state.delete.active = 0;
	state.delete.phase = PhaseNone;
	state.delete.index = 0;
	state.delete.errors = 0;
	state.delete.targetsummary = "";
	state.delete.tasks = array[0] of IcState->DeleteTask;

	modal->close(state);

	if(srcp != nil)
		appanel->refresh(state, srcp);
	if(dstp != nil)
		appanel->refresh(state, dstp);

	if(state.ui != nil){
		if(errors > 0)
			state.ui.status = "delete finished with errors";
		else
			state.ui.status = "delete done";
	}

	return 0;
}

handlekey(state: ref IcState->AppState, k: int): int
{
	r: int;

	if(state == nil || state.delete == nil || !state.delete.active)
		return 0;

	r = modal->handlekey(state, k);
	if(r == IcModal->ResultNone)
		return 0;

	if(state.delete.phase == PhaseConfirm){
		if(r == IcModal->ResultCancel)
			return finish(state);

		if(r == IcModal->ResultOk){
			modal->close(state);
			return proceed(state);
		}
	}

	return 0;
}