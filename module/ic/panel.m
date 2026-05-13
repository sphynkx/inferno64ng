include "ic/state.m";
include "ic/layout.m";

IcPanel: module
{
	PATH: con "/dis/ic/panel.dis";

	init: fn();
	newpanel: fn(side: int): ref IcState->PanelState;
	build: fn(state: ref IcState->AppState, p: ref IcState->PanelState, rect: IcLayout->Rect): int;
	refresh: fn(state: ref IcState->AppState, p: ref IcState->PanelState): int;
	setactive: fn(state: ref IcState->AppState, p: ref IcState->PanelState, active: int): int;
	handlekey: fn(state: ref IcState->AppState, p: ref IcState->PanelState, k: int): int;
};