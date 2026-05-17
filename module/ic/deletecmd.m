include "ic/state.m";

IcDeleteCmd: module
{
	PATH: con "/dis/ic/deletecmd.dis";

	init: fn();

	active: fn(state: ref IcState->AppState): int;
	start: fn(state: ref IcState->AppState): int;
	handlekey: fn(state: ref IcState->AppState, k: int): int;
};