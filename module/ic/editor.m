include "ic/state.m";

IcEditor: module
{
	PATH: con "/dis/ic/editor.dis";

	init: fn();

	runfile: fn(path: string): int;

	start: fn(state: ref IcState->AppState, path: string): int;
	startnew: fn(state: ref IcState->AppState, dir: string): int;

	active: fn(state: ref IcState->AppState): int;
	build: fn(state: ref IcState->AppState, parentid, w, h: int): int;
	handlekey: fn(state: ref IcState->AppState, k: int): int;
	handletick: fn(state: ref IcState->AppState): int;
};