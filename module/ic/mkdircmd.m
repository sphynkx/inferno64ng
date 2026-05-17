include "ic/state.m";

IcMkdirCmd: module
{
	PATH: con "/dis/ic/mkdircmd.dis";

	init: fn();

	active: fn(state: ref IcState->AppState): int;
	start: fn(state: ref IcState->AppState): int;
	handlekey: fn(state: ref IcState->AppState, k: int): int;
};