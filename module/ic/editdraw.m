include "ic/state.m";

IcEditDraw: module
{
	PATH: con "/dis/ic/editdraw.dis";

	init: fn();
	settheme: fn(theme: ref IcState->ThemeState);

	draw: fn(u: ref IcUi->Ui, parentid: int, e: ref IcState->EditorState, w, h: int);
	hide: fn(u: ref IcUi->Ui, e: ref IcState->EditorState);
	handletick: fn(e: ref IcState->EditorState): int;
};