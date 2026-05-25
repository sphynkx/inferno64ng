include "ic/state.m";

IcScreenSaver: module
{
	PATH: con "/dis/ic/screensaver.dis";

	init: fn();

	available: fn(): array of string;
	titleof: fn(name: string): string;

	selected: fn(cfg: ref IcState->ConfigState): string;
	isenabled: fn(cfg: ref IcState->ConfigState): int;
	idlelimit: fn(cfg: ref IcState->ConfigState): int;

	setselected: fn(state: ref IcState->AppState, name: string): int;
	setenabled: fn(state: ref IcState->AppState, on: int): int;
	setidlelimit: fn(state: ref IcState->AppState, ticks: int): int;
	reload: fn(state: ref IcState->AppState): int;

	newstate: fn(cfg: ref IcState->ConfigState): ref IcState->ScreenSaverState;

	active: fn(state: ref IcState->AppState): int;
	start: fn(state: ref IcState->AppState): int;
	stop: fn(state: ref IcState->AppState): int;

	resetidle: fn(state: ref IcState->AppState);
	handletick: fn(state: ref IcState->AppState): int;

	build: fn(state: ref IcState->AppState): int;
};