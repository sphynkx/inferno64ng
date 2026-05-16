include "ic/state.m";

IcViewCmd: module
{
	PATH: con "/dis/ic/viewcmd.dis";

	init: fn();
	start: fn(state: ref IcState->AppState): int;
};