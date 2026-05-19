include "icurses/ui.m";
include "ic/viewcommon.m";

IcViewGoto: module
{
	PATH: con "/dis/ic/viewgoto.dis";

	init: fn();

	open: fn(u: ref IcUi->Ui, parentid, w, h: int);
	close: fn(u: ref IcUi->Ui);

	active: fn(): int;
	draw: fn(u: ref IcUi->Ui, parentid, w, h: int): int;
	handletick: fn(u: ref IcUi->Ui, parentid, w, h: int): int;
	handlekey: fn(u: ref IcUi->Ui, parentid, w, h, k: int): int;

	mode: fn(): int;
	input: fn(): string;
};