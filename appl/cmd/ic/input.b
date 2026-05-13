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

IcPanel: module
{
	PATH: con "/dis/ic/panel.dis";

	init: fn();
	handlekey: fn(state: ref IcState->AppState, p: ref IcState->PanelState, k: int): int;
};

commands: IcCommands;
panel: IcPanel;

CtrlO: con 15;
TabKey: con 9;
F10Key: con 57419;

init()
{
	commands = load IcCommands IcCommands->PATH;
	if(commands == nil)
		raise "fail:load ic/commands";

	panel = load IcPanel IcPanel->PATH;
	if(panel == nil)
		raise "fail:load ic/panel";

	commands->init();
	panel->init();
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
		return panel->handlekey(state, state.left, k);

	return panel->handlekey(state, state.right, k);
}