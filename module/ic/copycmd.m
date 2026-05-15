include "ic/state.m";

IcCopyCmd: module
{
	PATH: con "/dis/ic/copycmd.dis";

	init: fn();

	hasconflicts: fn(state: ref IcState->AppState): int;
	run: fn(state: ref IcState->AppState, overwrite: int): int;
};