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

appscreen: int;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	ic = load Icurses Icurses->PATH;
	if(ic == nil)
		raise "fail:load icurses";

	ic->init();
	appscreen = 0;
}

enter(out: ref Sys->FD): int
{
	if(out == nil)
		return -1;

	if(appscreen)
		return 0;

	sys->fprint(out, "%c[?1049h", 27);
	ic->resettty(out);
	ic->hidecursor(out);
	ic->cleartty(out);

	appscreen = 1;

	return 0;
}

leave(out: ref Sys->FD)
{
	if(out == nil)
		return;

	ic->resettty(out);
	ic->showcursor(out);
	ic->cleartty(out);

	if(appscreen){
		sys->fprint(out, "%c[?1049l", 27);
		appscreen = 0;
	}

	ic->resettty(out);
	ic->showcursor(out);
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