include "ic/state.m";

IcUserState: module
{
	PATH: con "/dis/ic/userstate.dis";

	init: fn();

	loadstate: fn(state: ref IcState->AppState): int;
	restore: fn(state: ref IcState->AppState): int;
	save: fn(state: ref IcState->AppState): int;
};