include "ic/state.m";

IcApp: module
{
	PATH: con "/dis/ic/app.dis";

	init: fn();
	newstate: fn(): ref IcState->AppState;
	run: fn(state: ref IcState->AppState): int;
	runnew: fn(): int;
};