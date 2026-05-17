include "ic/state.m";

IcThemeData: module
{
	PATH: con "/dis/ic/theme.dis";

	init: fn();
	loadstate: fn(cfg: ref IcState->ConfigState): ref IcState->ThemeState;
};