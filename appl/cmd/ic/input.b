implement IcInputData;

include "ic/input.m";

IcCommands: module
{
	PATH: con "/dis/ic/commands.dis";

	CmdExit: con 1;
	CmdSwitchPanel: con 2;
	CmdTogglePanels: con 3;
	CmdToggleSelection: con 4;
	CmdCopy: con 5;
	CmdMove: con 6;
	CmdMkdir: con 7;
	CmdDelete: con 8;
	CmdView: con 9;
	CmdEdit: con 10;
	CmdEditNew: con 11;

	init: fn();
	exec: fn(state: ref IcState->AppState, cmd: int): int;
};

IcAppPanel: module
{
	PATH: con "/dis/ic/appanel.dis";

	init: fn();
	handlekey: fn(state: ref IcState->AppState, p: ref IcState->PanelState, k: int): int;
};

IcCopyCmd: module
{
	PATH: con "/dis/ic/copycmd.dis";

	init: fn();
	active: fn(state: ref IcState->AppState): int;
	handlekey: fn(state: ref IcState->AppState, k: int): int;
};

IcMkdirCmd: module
{
	PATH: con "/dis/ic/mkdircmd.dis";

	init: fn();
	active: fn(state: ref IcState->AppState): int;
	handlekey: fn(state: ref IcState->AppState, k: int): int;
};

IcDeleteCmd: module
{
	PATH: con "/dis/ic/deletecmd.dis";

	init: fn();
	active: fn(state: ref IcState->AppState): int;
	handlekey: fn(state: ref IcState->AppState, k: int): int;
};

IcModal: module
{
	PATH: con "/dis/ic/modal.dis";

	init: fn();
	handletick: fn(state: ref IcState->AppState): int;
};

IcBottomBar: module
{
	PATH: con "/dis/ic/bottombar.dis";

	init: fn();
	activatefkey: fn(state: ref IcState->AppState, fkey: int): int;
	handletick: fn(state: ref IcState->AppState): int;
};

IcViewerMod: module
{
	PATH: con "/dis/ic/viewer.dis";

	init: fn();
	active: fn(state: ref IcState->AppState): int;
	handlekey: fn(state: ref IcState->AppState, k: int): int;
	handletick: fn(state: ref IcState->AppState): int;
};

IcEditorMod: module
{
	PATH: con "/dis/ic/editor.dis";

	init: fn();
	active: fn(state: ref IcState->AppState): int;
	handlekey: fn(state: ref IcState->AppState, k: int): int;
	handletick: fn(state: ref IcState->AppState): int;
};

IcScreenMod: module
{
	PATH: con "/dis/ic/screen.dis";

	init: fn();
	rebuild: fn(state: ref IcState->AppState): int;
	redraw: fn(state: ref IcState->AppState): int;
};

sys: Sys;
commands: IcCommands;
appanel: IcAppPanel;
copycmd: IcCopyCmd;
mkdircmd: IcMkdirCmd;
deletecmd: IcDeleteCmd;
modal: IcModal;
bottombar: IcBottomBar;
viewer: IcViewerMod;
editor: IcEditorMod;
screen: IcScreenMod;

CtrlO: con 15;
TabKey: con 9;
F3Key: con 57411;
F4Key: con 57412;
F5Key: con 57413;
F6Key: con 57414;
F7Key: con 57415;
F8Key: con 57416;
F10Key: con 57418;
ShiftF4Key: con 57460;
InsKey: con 57443;

ViewFlashDelayMs: con 80;

flashfkey: fn(state: ref IcState->AppState, fkey: int);
flashviewkey: fn(state: ref IcState->AppState);

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	commands = load IcCommands IcCommands->PATH;
	if(commands == nil)
		raise "fail:load ic/commands";

	appanel = load IcAppPanel IcAppPanel->PATH;
	if(appanel == nil)
		raise "fail:load ic/appanel";

	copycmd = load IcCopyCmd IcCopyCmd->PATH;
	if(copycmd == nil)
		raise "fail:load ic/copycmd";

	mkdircmd = load IcMkdirCmd IcMkdirCmd->PATH;
	if(mkdircmd == nil)
		raise "fail:load ic/mkdircmd";

	deletecmd = load IcDeleteCmd IcDeleteCmd->PATH;
	if(deletecmd == nil)
		raise "fail:load ic/deletecmd";

	modal = load IcModal IcModal->PATH;
	if(modal == nil)
		raise "fail:load ic/modal";

	bottombar = load IcBottomBar IcBottomBar->PATH;
	if(bottombar == nil)
		raise "fail:load ic/bottombar";

	viewer = load IcViewerMod IcViewerMod->PATH;
	if(viewer == nil)
		raise "fail:load ic/viewer";

	editor = load IcEditorMod IcEditorMod->PATH;
	if(editor == nil)
		raise "fail:load ic/editor";

	screen = load IcScreenMod IcScreenMod->PATH;
	if(screen == nil)
		raise "fail:load ic/screen";

	commands->init();
	appanel->init();
	copycmd->init();
	mkdircmd->init();
	deletecmd->init();
	modal->init();
	bottombar->init();
	viewer->init();
	editor->init();
	screen->init();
}

flashfkey(state: ref IcState->AppState, fkey: int)
{
	if(state == nil)
		return;

	bottombar->activatefkey(state, fkey);
}

flashviewkey(state: ref IcState->AppState)
{
	if(state == nil)
		return;

	flashfkey(state, 3);
	screen->redraw(state);

	if(sys != nil && ViewFlashDelayMs > 0)
		sys->sleep(ViewFlashDelayMs);
}

handlekey(state: ref IcState->AppState, k: int): int
{
	r: int;

	if(state == nil)
		return -1;

	if(editor->active(state)){
		r = editor->handlekey(state, k);
		if(r != 0)
			screen->rebuild(state);
		return 0;
	}

	if(viewer->active(state)){
		r = viewer->handlekey(state, k);
		if(r == 2)
			screen->rebuild(state);
		return 0;
	}

	if(copycmd->active(state))
		return copycmd->handlekey(state, k);

	if(mkdircmd->active(state))
		return mkdircmd->handlekey(state, k);

	if(deletecmd->active(state))
		return deletecmd->handlekey(state, k);

	if(k == TabKey)
		return commands->exec(state, IcCommands->CmdSwitchPanel);

	if(k == CtrlO)
		return commands->exec(state, IcCommands->CmdTogglePanels);

	if(k == InsKey)
		return commands->exec(state, IcCommands->CmdToggleSelection);

	if(k == F3Key){
		flashviewkey(state);
		return commands->exec(state, IcCommands->CmdView);
	}

	if(k == F4Key){
		flashfkey(state, 4);
		return commands->exec(state, IcCommands->CmdEdit);
	}

	if(k == ShiftF4Key){
		flashfkey(state, 4);
		return commands->exec(state, IcCommands->CmdEditNew);
	}

	if(k == F5Key){
		flashfkey(state, 5);
		return commands->exec(state, IcCommands->CmdCopy);
	}

	if(k == F6Key){
		flashfkey(state, 6);
		return commands->exec(state, IcCommands->CmdMove);
	}

	if(k == F7Key){
		flashfkey(state, 7);
		return commands->exec(state, IcCommands->CmdMkdir);
	}

	if(k == F8Key){
		flashfkey(state, 8);
		return commands->exec(state, IcCommands->CmdDelete);
	}

	if(k == F10Key){
		flashfkey(state, 10);
		return commands->exec(state, IcCommands->CmdExit);
	}

	if(state.activepanel == IcState->PanelLeft)
		return appanel->handlekey(state, state.left, k);

	return appanel->handlekey(state, state.right, k);
}

handletick(state: ref IcState->AppState): int
{
	redraw: int;

	if(state == nil)
		return 0;

	redraw = 0;

	if(editor->active(state)){
		if(editor->handletick(state))
			redraw = 1;
		return redraw;
	}

	if(viewer->active(state)){
		if(viewer->handletick(state))
			redraw = 1;
		return redraw;
	}

	if(modal->handletick(state))
		redraw = 1;

	if(bottombar->handletick(state))
		redraw = 1;

	return redraw;
}