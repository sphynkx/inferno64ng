include "ic/state.m";

IcViewButtons: module
{
	PATH: con "/dis/ic/viewbuttons.dis";

	init: fn();
	settheme: fn(theme: ref IcState->ThemeState);

	draw: fn(u: ref IcUi->Ui, parentid, bottomid, w, h: int);
	activate: fn(fkey: int);
	handletick: fn(): int;
};