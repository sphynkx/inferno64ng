include "ic/state.m";

IcFlashlighter: module
{
	PATH: con "/dis/ic/flashlighter.dis";

	init: fn();

	newstate: fn(cfg: ref IcState->ConfigState): ref IcState->ScreenSaverState;

	active: fn(state: ref IcState->AppState): int;
	start: fn(state: ref IcState->AppState): int;
	stop: fn(state: ref IcState->AppState): int;

	resetidle: fn(state: ref IcState->AppState);
	handletick: fn(state: ref IcState->AppState): int;

	build: fn(state: ref IcState->AppState): int;
};