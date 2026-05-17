include "ic/state.m";

IcScreen: module
{
	PATH: con "/dis/ic/screen.dis";

	init: fn();
	build: fn(state: ref IcState->AppState): int;
	rebuild: fn(state: ref IcState->AppState): int;
	redraw: fn(state: ref IcState->AppState): int;
};