include "ic/state.m";
include "ic/layout.m";

IcTopBar: module
{
	PATH: con "/dis/ic/topbar.dis";

	CmdNone: con 0;
	CmdHandled: con 1;

	CmdOptionsScreensavers: con 1001;

	init: fn();
	newbar: fn(): ref IcState->TopBarState;
	build: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState, rect: IcLayout->Rect): int;

	active: fn(bar: ref IcState->TopBarState): int;
	toggle: fn(bar: ref IcState->TopBarState);
	close: fn(bar: ref IcState->TopBarState);
	handlekey: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState, k: int): int;
	handletick: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState): int;
};