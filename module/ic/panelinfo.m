include "ic/state.m";

IcPanelInfo: module
{
	PATH: con "/dis/ic/panelinfo.dis";

	init: fn();
	current: fn(p: ref IcState->PanelState, width: int): string;
};