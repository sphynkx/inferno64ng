include "ic/state.m";

IcCopyCmd: module
{
	PATH: con "/dis/ic/copycmd.dis";

	init: fn();
	run: fn(state: ref IcState->AppState): int;
};