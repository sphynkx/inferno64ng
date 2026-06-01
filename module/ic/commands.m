include "ic/state.m";

IcCommands: module
{
	PATH: con "/dis/ic/commands.dis";

	CmdNone: con 0;
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
	CmdRunLimbo: con 12;

	init: fn();
	exec: fn(state: ref IcState->AppState, cmd: int): int;
};