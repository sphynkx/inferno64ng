include "icurses/ui.m";

IcViewCodepage: module
{
	PATH: con "/dis/ic/viewcodepage.dis";

	init: fn();

	open: fn(u: ref IcUi->Ui, parentid, w, h: int, current: string);
	close: fn(u: ref IcUi->Ui);

	active: fn(): int;
	draw: fn(u: ref IcUi->Ui, parentid, w, h: int): int;
	handletick: fn(u: ref IcUi->Ui, parentid, w, h: int): int;
	handlekey: fn(u: ref IcUi->Ui, parentid, w, h, k: int): int;

	selected: fn(): string;
};