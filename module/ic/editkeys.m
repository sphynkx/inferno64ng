include "ic/state.m";

IcEditKeys: module
{
	PATH: con "/dis/ic/editkeys.dis";

	init: fn();
	settheme: fn(theme: ref IcState->ThemeState);

	handlekey: fn(state: ref IcState->AppState, e: ref IcState->EditorState, k, h: int): int;
	handletick: fn(state: ref IcState->AppState, e: ref IcState->EditorState): int;
};