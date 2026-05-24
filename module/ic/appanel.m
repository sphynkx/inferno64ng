include "ic/state.m";
include "ic/layout.m";

IcAppPanel: module
{
	PATH: con "/dis/ic/appanel.dis";

	init: fn();
	reloadtheme: fn(): int;

	newpanel: fn(side: int): ref IcState->PanelState;
	build: fn(state: ref IcState->AppState, p: ref IcState->PanelState, rect: IcLayout->Rect): int;
	refresh: fn(state: ref IcState->AppState, p: ref IcState->PanelState): int;
	setactive: fn(state: ref IcState->AppState, p: ref IcState->PanelState, active: int): int;
	togglemarkadvance: fn(state: ref IcState->AppState, p: ref IcState->PanelState): int;
	handlekey: fn(state: ref IcState->AppState, p: ref IcState->PanelState, k: int): int;
	clearselection: fn(state: ref IcState->AppState, p: ref IcState->PanelState): int;
};