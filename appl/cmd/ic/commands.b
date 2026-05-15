implement IcCommands;

include "ic/commands.m";

IcAppPanel: module
{
	PATH: con "/dis/ic/appanel.dis";

	init: fn();
	setactive: fn(state: ref IcState->AppState, p: ref IcState->PanelState, active: int): int;
	togglemarkadvance: fn(state: ref IcState->AppState, p: ref IcState->PanelState): int;
};

IcScreenMod: module
{
	PATH: con "/dis/ic/screen.dis";

	init: fn();
	rebuild: fn(state: ref IcState->AppState): int;
};

IcCopyCmd: module
{
	PATH: con "/dis/ic/copycmd.dis";

	init: fn();
	hasconflicts: fn(state: ref IcState->AppState): int;
	run: fn(state: ref IcState->AppState, overwrite: int): int;
};

IcModal: module
{
	PATH: con "/dis/ic/modal.dis";

	ResultNone: con 0;
	ResultOk: con 1;
	ResultCancel: con 2;

	Dialog: adt
	{
		title: string;
		message: array of string;

		checkbox: string;
		checked: int;

		result: int;
	};

	init: fn();
	copyconfirm: fn(title, message, checkbox: string, checked: int): ref Dialog;
	handlekey: fn(d: ref Dialog, k: int): int;
};

appanel: IcAppPanel;
screen: IcScreenMod;
copycmd: IcCopyCmd;
modal: IcModal;

init()
{
	appanel = load IcAppPanel IcAppPanel->PATH;
	if(appanel == nil)
		raise "fail:load ic/appanel";

	screen = load IcScreenMod IcScreenMod->PATH;
	if(screen == nil)
		raise "fail:load ic/screen";

	copycmd = load IcCopyCmd IcCopyCmd->PATH;
	if(copycmd == nil)
		raise "fail:load ic/copycmd";

	modal = load IcModal IcModal->PATH;
	if(modal == nil)
		raise "fail:load ic/modal";

	appanel->init();
	screen->init();
	copycmd->init();
	modal->init();
}

exec(state: ref IcState->AppState, cmd: int): int
{
	d: ref IcModal->Dialog;
	r: int;

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
		if(copycmd->hasconflicts(state)){
			d = modal->copyconfirm("Copy", "Destination contains existing item(s).", "Overwrite all", 0);

			#
			# Temporary logical modal default: do not overwrite unless this is changed
			# by the future visual modal UI.
			#
			r = modal->handlekey(d, '\n');
			if(r != IcModal->ResultOk)
				return 0;

			return copycmd->run(state, d.checked);
		}

		return copycmd->run(state, 0);
	}

	return 0;
}