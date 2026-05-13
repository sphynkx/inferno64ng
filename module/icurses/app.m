include "icurses/actions.m";

IcApp: module
{
	PATH: con "/dis/lib/icurses/app.dis";

	ScreenNormal: con 0;
	ScreenAlternate: con 1;

	Options: adt
	{
		screenmode: int;
		mouse: int;
		tickms: int;
	};

	Context: adt
	{
		out: ref Sys->FD;
		ui: ref IcUi->Ui;

		w: int;
		h: int;

		screenmode: int;
		mouse: int;
		tickms: int;

		appscreen: int;
		opened: int;
		started: int;
	};

	init: fn(name: string);

	name: fn(): string;

	note: fn(s: string);
	warn: fn(s: string);
	fail: fn(s: string);

	check: fn(ok: int, s: string): int;

	stdout: fn(): ref Sys->FD;
	stderr: fn(): ref Sys->FD;

	requirefd: fn(fd: ref Sys->FD, s: string): ref Sys->FD;
	requireui: fn(u: ref IcUi->Ui, s: string): ref IcUi->Ui;
	requireactions: fn(a: ref IcActions->Actions, s: string): ref IcActions->Actions;

	status: fn(u: ref IcUi->Ui, s: string);
	help: fn(u: ref IcUi->Ui, s: string);

	pause: fn(ms: int);

	defaultopts: fn(): Options;
	newctx: fn(out: ref Sys->FD, opts: Options): ref Context;

	open: fn(c: ref Context): int;
	close: fn(c: ref Context);

	ui: fn(c: ref Context): ref IcUi->Ui;
	width: fn(c: ref Context): int;
	height: fn(c: ref Context): int;

	step: fn(c: ref Context): IcUi->Step;
	draw: fn(c: ref Context): int;
	pollresize: fn(c: ref Context, oldw, oldh: int): (int, int, int);
};