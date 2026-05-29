include "icurses/ui.m";
include "ic/viewcommon.m";

IcViewSearch: module
{
	PATH: con "/dis/ic/viewsearch.dis";

	Style: adt
	{
		windowcode: string;
		framecode: string;
		textcode: string;
		fieldcode: string;
		fieldfocuscode: string;
		focuscode: string;
		cursorcode: string;
		buttoncode: string;
		buttonfocuscode: string;
		disabledcode: string;
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