include "ic/state.m";

IcCopyCmd: module
{
	PATH: con "/dis/ic/copycmd.dis";

	init: fn();

	active: fn(state: ref IcState->AppState): int;
	start: fn(state: ref IcState->AppState): int;
	handlekey: fn(state: ref IcState->AppState, k: int): int;
};