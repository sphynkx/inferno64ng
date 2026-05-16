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

IcDeleteCmd: module
{
	PATH: con "/dis/ic/deletecmd.dis";

	init: fn();
	start: fn(state: ref IcState->AppState): int;
};

IcScreenMod: module
{
	PATH: con "/dis/ic/screen.dis";

	init: fn();
	rebuild: fn(state: ref IcState->AppState): int;
};

appanel: IcAppPanel;
copycmd: IcCopyCmd;
deletecmd: IcDeleteCmd;
screen: IcScreenMod;

init()
{
	appanel = load IcAppPanel IcAppPanel->PATH;
	if(appanel == nil)
		raise "fail:load ic/appanel";

	copycmd = load IcCopyCmd IcCopyCmd->PATH;
	if(copycmd == nil)
		raise "fail:load ic/copycmd";

	deletecmd = load IcDeleteCmd IcDeleteCmd->PATH;
	if(deletecmd == nil)
		raise "fail:load ic/deletecmd";

	screen = load IcScreenMod IcScreenMod->PATH;
	if(screen == nil)
		raise "fail:load ic/screen";

	appanel->init();
	copycmd->init();
	deletecmd->init();
	screen->init();
}

exec(state: ref IcState->AppState, cmd: int): int
{
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

	IcCommands->CmdDelete =>
		return deletecmd->start(state);
	}

	return 0;
}