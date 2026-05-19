include "icurses/ui.m";
include "ic/viewcommon.m";

IcViewSearch: module
{
	PATH: con "/dis/ic/viewsearch.dis";

	init: fn();

	open: fn(u: ref IcUi->Ui, parentid, w, h: int, pattern: string);
	alert: fn(u: ref IcUi->Ui, parentid, w, h: int, text: string);
	close: fn(u: ref IcUi->Ui);

	active: fn(): int;
	isalert: fn(): int;

	draw: fn(u: ref IcUi->Ui, parentid, w, h: int): int;
	handletick: fn(u: ref IcUi->Ui, parentid, w, h: int): int;
	handlekey: fn(u: ref IcUi->Ui, parentid, w, h, k: int): int;

	options: fn(): IcViewCommon->SearchOptions;
	pattern: fn(): string;
};