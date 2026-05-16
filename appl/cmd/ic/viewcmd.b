implement IcViewCmd;

include "ic/viewcmd.m";

IcPanelMod: module
{
	PATH: con "/dis/lib/icurses/panel.dis";

	init: fn();
	currentname: fn(p: ref IcPanel->Panel): string;
	currentkind: fn(p: ref IcPanel->Panel): string;
};

IcViewerMod: module
{
	PATH: con "/dis/ic/viewer.dis";

	ModeText: con 0;

	init: fn();
	start: fn(state: ref IcState->AppState, path: string, mode: int): int;
};

panelui: IcPanelMod;
viewer: IcViewerMod;

activepanel: fn(state: ref IcState->AppState): ref IcState->PanelState;
trimdirsuffix: fn(name: string): string;
joinpath: fn(base, name: string): string;

init()
{
	panelui = load IcPanelMod IcPanelMod->PATH;
	if(panelui == nil)
		raise "fail:load icurses/panel";

	viewer = load IcViewerMod IcViewerMod->PATH;
	if(viewer == nil)
		raise "fail:load ic/viewer";

	panelui->init();
	viewer->init();
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

joinpath(base, name: string): string
{
	name = trimdirsuffix(name);

	if(base == "" || base == ".")
		return name;

	if(base == "/")
		return "/" + name;

	return base + "/" + name;
}

start(state: ref IcState->AppState): int
{
	p: ref IcState->PanelState;
	name, kind, path: string;

	if(state == nil)
		return -1;

	p = activepanel(state);
	if(p == nil || p.panel == nil)
		return 0;

	name = panelui->currentname(p.panel);
	kind = panelui->currentkind(p.panel);

	if(kind != "file")
		return 0;

	path = joinpath(p.path, name);
	if(path == "")
		return 0;

	return viewer->start(state, path, IcViewerMod->ModeText);
}