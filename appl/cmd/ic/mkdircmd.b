implement IcMkdirCmd;

include "ic/mkdircmd.m";

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
	selectid: fn(u: ref IcUi->Ui, p: ref IcPanel->Panel, itemid: int): IcMsg->Msg;
	render: fn(u: ref IcUi->Ui, p: ref IcPanel->Panel): int;
};

IcModal: module
{
	PATH: con "/dis/ic/modal.dis";

	ResultNone: con 0;
	ResultOk: con 1;
	ResultCancel: con 2;

	init: fn();
	close: fn(state: ref IcState->AppState): int;
	showmkdirconfirm: fn(state: ref IcState->AppState, basepath: string): int;
	handlekey: fn(state: ref IcState->AppState, k: int): int;
};

sys: Sys;
appanel: IcAppPanel;
panelui: IcPanelMod;
modal: IcModal;

PhaseNone: con 0;
PhaseConfirm: con 1;

activepanel: fn(state: ref IcState->AppState): ref IcState->PanelState;
joinpath: fn(base, name: string): string;
trimdirsuffix: fn(name: string): string;
normalizepath: fn(path: string): string;
visiblecreatedname: fn(name: string): string;
makeparentdirs: fn(path: string): int;
makedir: fn(path: string, mode: int): int;
selectcreated: fn(state: ref IcState->AppState, p: ref IcState->PanelState, name: string): int;
initmkdir: fn(state: ref IcState->AppState);
finish: fn(state: ref IcState->AppState, ok: int, createdname: string): int;

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

initmkdir(state: ref IcState->AppState)
{
	if(state == nil)
		return;

	if(state.mkdir != nil)
		return;

	state.mkdir = ref IcState->MkdirState;
	state.mkdir.active = 0;
	state.mkdir.phase = PhaseNone;
	state.mkdir.target = "";
	state.mkdir.errors = 0;
}

active(state: ref IcState->AppState): int
{
	if(state == nil || state.mkdir == nil)
		return 0;

	return state.mkdir.active != 0;
}

activepanel(state: ref IcState->AppState): ref IcState->PanelState
{
	if(state == nil)
		return nil;

	if(state.activepanel == IcState->PanelLeft)
		return state.left;

	return state.right;
}

trimdirsuffix(name: string): string
{
	if(len name > 1 && name[len name - 1] == '/')
		return name[0:len name - 1];

	return name;
}

normalizepath(path: string): string
{
	if(path == "")
		return ".";

	if(len path > 1 && path[len path - 1] == '/')
		return path[0:len path - 1];

	return path;
}

joinpath(base, name: string): string
{
	base = normalizepath(base);
	name = trimdirsuffix(name);

	if(base == "" || base == ".")
		return name;

	if(base == "/")
		return "/" + name;

	return base + "/" + name;
}

visiblecreatedname(name: string): string
{
	i: int;

	name = trimdirsuffix(name);

	for(i = 0; i < len name; i++){
		if(name[i] == '/')
			return name[0:i];
	}

	return name;
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

makedir(path: string, mode: int): int
{
	ok: int;
	d: Sys->Dir;
	fd: ref Sys->FD;

	(ok, d) = sys->stat(path);
	if(ok >= 0){
		if((d.mode & Sys->DMDIR) != 0)
			return -1;

		return -1;
	}

	if(makeparentdirs(path) < 0)
		return -1;

	fd = sys->create(path, Sys->OREAD, Sys->DMDIR | (mode & 8r777) | 8r300);
	if(fd == nil)
		return -1;

	return 0;
}

selectcreated(state: ref IcState->AppState, p: ref IcState->PanelState, name: string): int
{
	i: int;
	id: int;
	m: IcMsg->Msg;

	if(state == nil || state.ui == nil || p == nil || p.panel == nil || p.model == nil)
		return -1;

	name = visiblecreatedname(name);
	if(name == "")
		return -1;

	id = -1;

	for(i = 0; i < len p.model.items; i++){
		if(p.model.items[i].kind == "dir" && trimdirsuffix(p.model.items[i].name) == name){
			id = p.model.items[i].id;
			break;
		}
	}

	if(id < 0)
		return -1;

	m = panelui->selectid(state.ui, p.panel, id);
	m = m;

	return panelui->render(state.ui, p.panel);
}

start(state: ref IcState->AppState): int
{
	p: ref IcState->PanelState;

	if(state == nil)
		return -1;

	initmkdir(state);

	p = activepanel(state);
	if(p == nil)
		return 0;

	state.mkdir.active = 1;
	state.mkdir.phase = PhaseConfirm;
	state.mkdir.target = "";
	state.mkdir.errors = 0;

	return modal->showmkdirconfirm(state, p.path);
}

finish(state: ref IcState->AppState, ok: int, createdname: string): int
{
	p: ref IcState->PanelState;

	if(state == nil)
		return -1;

	initmkdir(state);

	p = activepanel(state);

	state.mkdir.active = 0;
	state.mkdir.phase = PhaseNone;
	state.mkdir.target = "";

	modal->close(state);

	if(p != nil){
		appanel->refresh(state, p);

		if(ok)
			selectcreated(state, p, createdname);
	}

	if(state.ui != nil){
		if(ok)
			state.ui.status = "directory created";
		else
			state.ui.status = "mkdir failed";
	}

	return 0;
}

handlekey(state: ref IcState->AppState, k: int): int
{
	r: int;
	p: ref IcState->PanelState;
	name, path: string;

	if(state == nil || state.mkdir == nil || !state.mkdir.active)
		return 0;

	r = modal->handlekey(state, k);
	if(r == IcModal->ResultNone)
		return 0;

	if(state.mkdir.phase != PhaseConfirm)
		return 0;

	if(r == IcModal->ResultCancel)
		return finish(state, 0, "");

	if(r != IcModal->ResultOk)
		return 0;

	p = activepanel(state);
	if(p == nil || state.modal == nil)
		return finish(state, 0, "");

	name = trimdirsuffix(state.modal.input);
	if(name == "" || name == "." || name == "..")
		return finish(state, 0, "");

	path = joinpath(p.path, name);

	if(makedir(path, 8r777) < 0)
		return finish(state, 0, "");

	return finish(state, 1, name);
}