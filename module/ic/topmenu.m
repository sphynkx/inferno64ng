include "ic/state.m";
include "ic/layout.m";

IcTopMenu: module
{
	PATH: con "/dis/ic/topmenu.dis";

	init: fn();

	newstate: fn(): ref IcState->TopBarState;

	active: fn(bar: ref IcState->TopBarState): int;
	toggle: fn(bar: ref IcState->TopBarState);
	close: fn(bar: ref IcState->TopBarState);

	build: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState, rect: IcLayout->Rect): int;
	handlekey: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState, k: int): int;
};