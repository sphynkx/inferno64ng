implement IcCommands;

include "ic/commands.m";

IcAppPanel: module
{
	PATH: con "/dis/ic/appanel.dis";

	init: fn();
	setactive: fn(state: ref IcState->AppState, p: ref IcState->PanelState, active: int): int;
	togglemarkadvance: fn(state: ref IcState->AppState, p: ref IcState->PanelState): int;
};

IcCopyCmd: module
{
	PATH: con "/dis/ic/copycmd.dis";

	init: fn();
	startcopy: fn(state: ref IcState->AppState): int;
	startmove: fn(state: ref IcState->AppState): int;
};

IcMkdirCmd: module
{
	PATH: con "/dis/ic/mkdircmd.dis";

	init: fn();
	start: fn(state: ref IcState->AppState): int;
};

IcDeleteCmd: module
{
	PATH: con "/dis/ic/deletecmd.dis";

	init: fn();
	start: fn(state: ref IcState->AppState): int;
};

IcViewCmd: module
{
	PATH: con "/dis/ic/viewcmd.dis";

	init: fn();
	start: fn(state: ref IcState->AppState): int;
};

IcEditCmd: module
{
	PATH: con "/dis/ic/editcmd.dis";

	init: fn();
	start: fn(state: ref IcState->AppState): int;
	startnew: fn(state: ref IcState->AppState): int;
};

IcScreenMod: module
{
	PATH: con "/dis/ic/screen.dis";

	init: fn();
	rebuild: fn(state: ref IcState->AppState): int;
};

appanel: IcAppPanel;
copycmd: IcCopyCmd;
mkdircmd: IcMkdirCmd;
deletecmd: IcDeleteCmd;
viewcmd: IcViewCmd;
editcmd: IcEditCmd;
screen: IcScreenMod;

init()
{
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

	viewcmd = load IcViewCmd IcViewCmd->PATH;
	if(viewcmd == nil)
		raise "fail:load ic/viewcmd";

	editcmd = load IcEditCmd IcEditCmd->PATH;
	if(editcmd == nil)
		raise "fail:load ic/editcmd";

	screen = load IcScreenMod IcScreenMod->PATH;
	if(screen == nil)
		raise "fail:load ic/screen";

	appanel->init();
	copycmd->init();
	mkdircmd->init();
	deletecmd->init();
	viewcmd->init();
	editcmd->init();
	screen->init();
}

exec(state: ref IcState->AppState, cmd: int): int
{
	rc: int;

	if(state == nil)
		return -1;

	case cmd {
	IcCommands->CmdExit =>
		state.running = 0;
		return 0;

	IcCommands->CmdSwitchPanel =>
		if(state.activepanel == IcState->PanelLeft)
			state.activepanel = IcState->PanelRight;
		else
			state.activepanel = IcState->PanelLeft;

		appanel->setactive(state, state.left, state.activepanel == IcState->PanelLeft);
		appanel->setactive(state, state.right, state.activepanel == IcState->PanelRight);
		return 0;

	IcCommands->CmdTogglePanels =>
		if(state.panelshidden)
			state.panelshidden = 0;
		else
			state.panelshidden = 1;

		return screen->rebuild(state);

	IcCommands->CmdToggleSelection =>
		if(state.activepanel == IcState->PanelLeft)
			return appanel->togglemarkadvance(state, state.left);

		return appanel->togglemarkadvance(state, state.right);

	IcCommands->CmdCopy =>
		return copycmd->startcopy(state);

	IcCommands->CmdMove =>
		return copycmd->startmove(state);

	IcCommands->CmdMkdir =>
		return mkdircmd->start(state);

	IcCommands->CmdDelete =>
		return deletecmd->start(state);

	IcCommands->CmdView =>
		rc = viewcmd->start(state);
		if(rc < 0)
			return rc;
		return screen->rebuild(state);

	IcCommands->CmdEdit =>
		rc = editcmd->start(state);
		if(rc < 0)
			return rc;
		return screen->rebuild(state);

	IcCommands->CmdEditNew =>
		rc = editcmd->startnew(state);
		if(rc < 0)
			return rc;
		return screen->rebuild(state);
	}

	return 0;
}