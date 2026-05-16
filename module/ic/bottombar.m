include "ic/state.m";
include "ic/layout.m";

IcBottomBar: module
{
	PATH: con "/dis/ic/bottombar.dis";

	init: fn();
	newbar: fn(): ref IcState->BottomBarState;
	build: fn(state: ref IcState->AppState, bar: ref IcState->BottomBarState, rect: IcLayout->Rect): int;
	activatefkey: fn(state: ref IcState->AppState, fkey: int): int;
	handletick: fn(state: ref IcState->AppState): int;
};