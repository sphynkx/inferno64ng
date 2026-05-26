include "ic/state.m";

IcRuntimeTheme: module
{
	PATH: con "/dis/ic/runtheme.dis";

	init: fn();

	loadcfg: fn(): ref IcState->ConfigState;
	loadtheme: fn(): ref IcState->ThemeState;
};