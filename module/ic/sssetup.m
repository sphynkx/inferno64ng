include "ic/state.m";

IcSsSetup: module
{
	PATH: con "/dis/ic/sssetup.dis";

	init: fn();

	active: fn(state: ref IcState->AppState): int;
	open: fn(state: ref IcState->AppState): int;
	close: fn(state: ref IcState->AppState): int;

	handlekey: fn(state: ref IcState->AppState, k: int): int;
	handletick: fn(state: ref IcState->AppState): int;
	build: fn(state: ref IcState->AppState): int;
};