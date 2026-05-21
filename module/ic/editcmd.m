include "ic/state.m";

IcEditCmd: module
{
	PATH: con "/dis/ic/editcmd.dis";

	init: fn();

	start: fn(state: ref IcState->AppState): int;
	startnew: fn(state: ref IcState->AppState): int;
};