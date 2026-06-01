include "icurses/ui.m";

IcViewCodepage: module
{
	PATH: con "/dis/ic/viewcodepage.dis";

	Style: adt
	{
		windowcode: string;
		framecode: string;
		textcode: string;
		focuscode: string;
		shadowcode: string;

		animticks: int;

		frameh: string;
		framev: string;
		framenw: string;
		framene: string;
		framesw: string;
		framese: string;
	};

	init: fn();
	setstyle: fn(style: Style);

	open: fn(u: ref IcUi->Ui, parentid, w, h: int, current: string);
	close: fn(u: ref IcUi->Ui);

	active: fn(): int;
	draw: fn(u: ref IcUi->Ui, parentid, w, h: int): int;
	handletick: fn(u: ref IcUi->Ui, parentid, w, h: int): int;
	handlekey: fn(u: ref IcUi->Ui, parentid, w, h, k: int): int;

	selected: fn(): string;
};