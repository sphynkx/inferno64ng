implement IcApp;

include "icurses/app.m";

sys: Sys;
ic: Icurses;
uimod: IcUi;

_appname: string;

init(name: string)
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	ic = load Icurses Icurses->PATH;
	if(ic == nil)
		raise "fail:load icurses";

	uimod = load IcUi IcUi->PATH;
	if(uimod == nil)
		raise "fail:load icui";

	ic->init();
	uimod->init();

	_appname = name;
	if(_appname == "")
		_appname = "icapp";
}

name(): string
{
	return _appname;
}

note(s: string)
{
	if(sys != nil)
		sys->print("NOTE[%s]: %s\n", _appname, s);
}

warn(s: string)
{
	if(sys != nil)
		sys->print("WARN[%s]: %s\n", _appname, s);
}

fail(s: string)
{
	if(sys != nil)
		sys->print("FAIL[%s]: %s\n", _appname, s);

	if(_appname == "")
		raise "fail:icapp";

	raise "fail:" + _appname;
}

check(ok: int, s: string): int
{
	if(!ok)
		fail(s);

	return ok;
}

stdout(): ref Sys->FD
{
	fd: ref Sys->FD;

	if(sys == nil)
		raise "fail:icapp:sys";

	fd = sys->fildes(1);
	if(fd == nil)
		fail("stdout");

	return fd;
}

stderr(): ref Sys->FD
{
	fd: ref Sys->FD;

	if(sys == nil)
		raise "fail:icapp:sys";

	fd = sys->fildes(2);
	if(fd == nil)
		fail("stderr");

	return fd;
}

requirefd(fd: ref Sys->FD, s: string): ref Sys->FD
{
	if(fd == nil)
		fail(s);

	return fd;
}

requireui(u: ref IcUi->Ui, s: string): ref IcUi->Ui
{
	if(u == nil)
		fail(s);

	return u;
}

requireactions(a: ref IcActions->Actions, s: string): ref IcActions->Actions
{
	if(a == nil)
		fail(s);

	return a;
}

status(u: ref IcUi->Ui, s: string)
{
	if(u == nil)
		return;

	u.status = s;
}

help(u: ref IcUi->Ui, s: string)
{
	if(u == nil)
		return;

	u.help = s;
}

pause(ms: int)
{
	if(sys == nil)
		return;

	if(ms > 0)
		sys->sleep(ms);
}

defaultopts(): Options
{
	o: Options;

	o.screenmode = ScreenNormal;
	o.mouse = 0;
	o.tickms = 100;

	return o;
}

newctx(out: ref Sys->FD, opts: Options): ref Context
{
	c: ref Context;

	c = ref Context;
	c.out = out;
	c.ui = nil;

	c.w = Icurses->DefaultCols;
	c.h = Icurses->DefaultRows;

	c.screenmode = opts.screenmode;
	c.mouse = opts.mouse != 0;
	c.tickms = opts.tickms;
	if(c.tickms <= 0)
		c.tickms = 100;

	c.appscreen = 0;
	c.opened = 0;
	c.started = 0;

	return c;
}

open(c: ref Context): int
{
	if(c == nil)
		return -1;

	if(c.opened)
		return 0;

	if(c.out == nil)
		c.out = stdout();

	(c.w, c.h) = ic->termsize();
	if(c.w <= 0)
		c.w = Icurses->DefaultCols;
	if(c.h <= 0)
		c.h = Icurses->DefaultRows;

	if(c.screenmode == ScreenAlternate){
		sys->fprint(c.out, "%c[?1049h", 27);
		ic->resettty(c.out);
		ic->hidecursor(c.out);
		ic->cleartty(c.out);
		c.appscreen = 1;
	}

	c.ui = uimod->new(c.out, c.w, c.h);
	if(c.ui == nil){
		close(c);
		return -1;
	}

	uimod->settick(c.ui, c.tickms);
	if(uimod->enablemouse(c.ui, c.mouse) < 0){
		close(c);
		return -1;
	}

	c.opened = 1;
	return 0;
}

close(c: ref Context)
{
	if(c == nil)
		return;

	if(c.ui != nil){
		uimod->close(c.ui);
		c.ui = nil;
	}

	if(c.out != nil){
		ic->resettty(c.out);
		ic->showcursor(c.out);
		ic->cleartty(c.out);

		if(c.appscreen){
			sys->fprint(c.out, "%c[?1049l", 27);
			c.appscreen = 0;
		}

		ic->resettty(c.out);
		ic->showcursor(c.out);
	}

	c.opened = 0;
	c.started = 0;
}

ui(c: ref Context): ref IcUi->Ui
{
	if(c == nil)
		return nil;

	return c.ui;
}

width(c: ref Context): int
{
	if(c == nil)
		return Icurses->DefaultCols;

	return c.w;
}

height(c: ref Context): int
{
	if(c == nil)
		return Icurses->DefaultRows;

	return c.h;
}

step(c: ref Context): IcUi->Step
{
	s: IcUi->Step;

	if(c == nil || c.ui == nil){
		s.kind = IcUi->StepDone;
		s.done = 1;
		s.key = -1;
		s.tick = 0;
		s.status = "nil app";
		return s;
	}

	if(!c.started){
		if(uimod->start(c.ui) < 0){
			s.kind = IcUi->StepDone;
			s.done = 1;
			s.key = -1;
			s.tick = 0;
			s.status = "start failed";
			return s;
		}
		c.started = 1;
	}

	return uimod->step(c.ui);
}

draw(c: ref Context): int
{
	if(c == nil || c.ui == nil)
		return -1;

	if(c.out != nil)
		ic->hidecursor(c.out);

	uimod->draw(c.ui);

	if(c.out != nil)
		ic->hidecursor(c.out);

	return 0;
}

pollresize(c: ref Context, oldw, oldh: int): (int, int, int)
{
	nw, nh: int;

	c = c;

	(nw, nh) = ic->termsize();

	if(nw < 1)
		nw = oldw;
	if(nh < 1)
		nh = oldh;

	if(nw != oldw || nh != oldh)
		return (nw, nh, 1);

	return (oldw, oldh, 0);
}