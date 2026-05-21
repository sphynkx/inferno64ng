include "ic/state.m";

IcEditKeys: module
{
	PATH: con "/dis/ic/editkeys.dis";

	init: fn();

	handlekey: fn(state: ref IcState->AppState, e: ref IcState->EditorState, k, h: int): int;
};