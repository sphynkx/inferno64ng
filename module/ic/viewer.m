include "ic/state.m";

IcViewer: module
{
	PATH: con "/dis/ic/viewer.dis";

	ModeText: con 0;
	ModeHex: con 1;

	init: fn();

	newstate: fn(): ref IcState->ViewerState;

	runfile: fn(path: string): int;
	runfilemode: fn(path: string, mode: int): int;

	start: fn(state: ref IcState->AppState, path: string, mode: int): int;
	active: fn(state: ref IcState->AppState): int;
	build: fn(state: ref IcState->AppState, parentid, w, h: int): int;
	handlekey: fn(state: ref IcState->AppState, k: int): int;
	handletick: fn(state: ref IcState->AppState): int;
};