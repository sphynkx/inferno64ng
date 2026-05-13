implement IcRuntime;

include "ic/runtime.m";

Icurses: module
{
	PATH: con "/dis/lib/icurses/icurses.dis";

	init: fn();
	termsize: fn(): (int, int);
	cleartty: fn(out: ref Sys->FD);
	resettty: fn(out: ref Sys->FD);
	hidecursor: fn(out: ref Sys->FD);
	showcursor: fn(out: ref Sys->FD);
};

sys: Sys;
ic: Icurses;

EnterAltSeq: con "\033[?1049h";
LeaveAltSeq: con "\033[?1049l";

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	ic = load Icurses Icurses->PATH;
	if(ic == nil)
		raise "fail:load icurses";

	ic->init();
}

enter(out: ref Sys->FD): int
{
	if(out == nil)
		return -1;

	sys->fprint(out, "%s", EnterAltSeq);
	ic->hidecursor(out);
	ic->cleartty(out);

	return 0;
}

leave(out: ref Sys->FD)
{
	if(out == nil)
		return;

	ic->resettty(out);
	ic->showcursor(out);
	ic->cleartty(out);
	sys->fprint(out, "%s", LeaveAltSeq);
}

size(): (int, int)
{
	return ic->termsize();
}

pollresize(oldw, oldh: int): (int, int, int)
{
	nw, nh: int;

	(nw, nh) = ic->termsize();

	if(nw < 1)
		nw = oldw;
	if(nh < 1)
		nh = oldh;

	if(nw != oldw || nh != oldh)
		return (nw, nh, 1);

	return (oldw, oldh, 0);
}