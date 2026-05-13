implement IcInputData;

include "ic/input.m";

IcCommands: module
{
	PATH: con "/dis/ic/commands.dis";

	CmdExit: con 1;
	CmdSwitchPanel: con 2;
	CmdTogglePanels: con 3;

	init: fn();
	exec: fn(state: ref IcState->AppState, cmd: int): int;
};

IcAppPanel: module
{
	PATH: con "/dis/ic/appanel.dis";

	init: fn();
	handlekey: fn(state: ref IcState->AppState, p: ref IcState->PanelState, k: int): int;
};

commands: IcCommands;
appanel: IcAppPanel;

CtrlO: con 15;
TabKey: con 9;
F10Key: con 57418;

init()
{
	commands = load IcCommands IcCommands->PATH;
	if(commands == nil)
		raise "fail:load ic/commands";

	appanel = load IcAppPanel IcAppPanel->PATH;
	if(appanel == nil)
		raise "fail:load ic/appanel";

	commands->init();
	appanel->init();
}

handlekey(state: ref IcState->AppState, k: int): int
{
	if(state == nil)
		return -1;

	if(k == TabKey)
		return commands->exec(state, IcCommands->CmdSwitchPanel);

	if(k == CtrlO)
		return commands->exec(state, IcCommands->CmdTogglePanels);

	if(k == F10Key)
		return commands->exec(state, IcCommands->CmdExit);

	if(state.activepanel == IcState->PanelLeft)
		return appanel->handlekey(state, state.left, k);

	return appanel->handlekey(state, state.right, k);
}