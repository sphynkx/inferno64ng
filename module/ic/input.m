include "ic/state.m";

IcInputData: module
{
	PATH: con "/dis/ic/input.dis";

	init: fn();
	handlekey: fn(state: ref IcState->AppState, k: int): int;
	handletick: fn(state: ref IcState->AppState): int;
};