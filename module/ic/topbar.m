include "ic/state.m";
include "ic/layout.m";

IcTopBar: module
{
	PATH: con "/dis/ic/topbar.dis";

	init: fn();
	newbar: fn(): ref IcState->TopBarState;
	build: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState, rect: IcLayout->Rect): int;
};