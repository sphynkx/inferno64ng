implement IcSession;

include "icurses/session.m";

IcMouse: module
{
	PATH: con "/dis/lib/icurses/mouse.dis";

	Event: adt
	{
		x:       int;
		y:       int;
		buttons: int;
		mods:    int;

		kind:     int;
		changed:  int;
		pressed:  int;
		released: int;

		ok:      int;
		raw:     string;
	};

	init: fn();

	open: fn(): int;
	close: fn();

	read: fn(): Event;
};

sys: Sys;
mouse: IcMouse;

KeyboardPath: con "/dev/ekeyboard";
ConsctlPath:  con "/dev/consctl";

emptyMouse: fn(): IcSession->MouseEvent;
convertmouse: fn(e: IcMouse->Event): IcSession->MouseEvent;
newstep: fn(kind, done, key: int, e: IcSession->MouseEvent): IcSession->Step;

keyreader: fn(s: ref IcSession->Session);
mousereader: fn(s: ref IcSession->Session);

sendkey: fn(s: ref IcSession->Session, k: int): int;
sendmouse: fn(s: ref IcSession->Session, e: IcSession->MouseEvent): int;

appendname: fn(s, name: string): string;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	mouse = load IcMouse IcMouse->PATH;
	if(mouse == nil)
		raise "fail:load icmouse";

	mouse->init();
}

emptyMouse(): IcSession->MouseEvent
{
	e: IcSession->MouseEvent;

	e.x = 0;
	e.y = 0;
	e.buttons = 0;
	e.mods = 0;

	e.kind = IcSession->MouseNone;
	e.changed = 0;
	e.pressed = 0;
	e.released = 0;

	e.ok = 0;
	e.raw = "";

	return e;
}

convertmouse(e: IcMouse->Event): IcSession->MouseEvent
{
	m: IcSession->MouseEvent;

	m.x = e.x;
	m.y = e.y;
	m.buttons = e.buttons;
	m.mods = e.mods;

	m.kind = e.kind;
	m.changed = e.changed;
	m.pressed = e.pressed;
	m.released = e.released;

	m.ok = e.ok;
	m.raw = e.raw;

	return m;
}

newstep(kind, done, key: int, e: IcSession->MouseEvent): IcSession->Step
{
	st: IcSession->Step;

	st.kind = kind;
	st.done = done;
	st.key = key;
	st.mouse = e;

	return st;
}

open(u: ref IcUi->Ui, flags: int): ref IcSession->Session
{
	s: ref IcSession->Session;

	if(u == nil)
		return nil;

	if(flags == 0)
		flags = IcSession->UseAll;

	s = ref IcSession->Session;
	s.u = u;
	s.running = 0;
	s.flags = flags;

	s.consctl = nil;

	s.keyc = chan of int;
	s.mousec = chan of IcSession->MouseEvent;

	#
	# Exactly like the successful manual test:
	# open consctl and enable raw input first.
	#
	if(flags & (IcSession->UseKeyboard | IcSession->UseMouse)){
		s.consctl = sys->open(ConsctlPath, Sys->OWRITE);
		if(s.consctl != nil)
			sys->fprint(s.consctl, "rawon");
	}

	#
	# Exactly like the successful manual test:
	# open mouse in the owner before spawning readers.
	#
	if(flags & IcSession->UseMouse){
		if(mouse->open() < 0){
			if(s.consctl != nil)
				sys->fprint(s.consctl, "rawoff");
			s.consctl = nil;
			s.u = nil;
			return nil;
		}
	}

	s.running = 1;

	if(flags & IcSession->UseMouse)
		spawn mousereader(s);

	#
	# Important: keyreader opens /dev/ekeyboard itself, with a local FD.
	# This matches the successful manual test and avoids storing the
	# keyboard FD in the Session ADT.
	#
	if(flags & IcSession->UseKeyboard)
		spawn keyreader(s);

	return s;
}

close(s: ref IcSession->Session)
{
	if(s == nil)
		return;

	#
	# Exactly the successful manual-test shutdown order:
	# 1. stop readers;
	# 2. close mouse wrapper;
	# 3. write rawoff;
	# 4. drop framework refs.
	#
	s.running = 0;

	if(s.flags & IcSession->UseMouse)
		mouse->close();

	if(s.consctl != nil)
		sys->fprint(s.consctl, "rawoff");

	s.consctl = nil;
	s.u = nil;
}

isrunning(s: ref IcSession->Session): int
{
	if(s == nil)
		return 0;

	return s.running;
}

sendkey(s: ref IcSession->Session, k: int): int
{
	for(;;){
		if(s == nil || !s.running)
			return 0;

		alt {
		s.keyc <-= k =>
			return 1;

		* =>
			sys->sleep(1);
		}
	}
}

sendmouse(s: ref IcSession->Session, e: IcSession->MouseEvent): int
{
	for(;;){
		if(s == nil || !s.running)
			return 0;

		alt {
		s.mousec <-= e =>
			return 1;

		* =>
			sys->sleep(1);
		}
	}
}

keyreader(s: ref IcSession->Session)
{
	fd: ref Sys->FD;
	buf: array of byte;
	n, i: int;

	if(s == nil)
		return;

	fd = sys->open(KeyboardPath, Sys->OREAD);
	if(fd == nil)
		return;

	buf = array[64] of byte;

	for(;;){
		if(s == nil || !s.running)
			return;

		n = sys->read(fd, buf, len buf);
		if(n <= 0)
			return;

		for(i = 0; i < n; i++){
			if(s == nil || !s.running)
				return;

			if(!sendkey(s, int buf[i]))
				return;
		}
	}
}

mousereader(s: ref IcSession->Session)
{
	e: IcMouse->Event;
	me: IcSession->MouseEvent;

	for(;;){
		if(s == nil || !s.running)
			return;

		e = mouse->read();

		if(s == nil || !s.running)
			return;

		if(!e.ok)
			return;

		me = convertmouse(e);

		if(!sendmouse(s, me))
			return;
	}
}

step(s: ref IcSession->Session): IcSession->Step
{
	k: int;
	e: IcSession->MouseEvent;

	if(s == nil || !s.running)
		return newstep(IcSession->StepDone, 1, -1, emptyMouse());

	alt {
	k = <-s.keyc =>
		if(!s.running)
			return newstep(IcSession->StepDone, 1, -1, emptyMouse());
		return newstep(IcSession->StepKey, 0, k, emptyMouse());

	e = <-s.mousec =>
		if(!s.running)
			return newstep(IcSession->StepDone, 1, -1, emptyMouse());
		return newstep(IcSession->StepMouse, 0, -1, e);
	}

	return newstep(IcSession->StepDone, 1, -1, emptyMouse());
}

appendname(s, name: string): string
{
	if(s == "")
		return name;

	return s + "+" + name;
}

mousebuttons(e: IcSession->MouseEvent): string
{
	s: string;

	s = "";

	if(e.buttons & IcSession->ButtonLeft)
		s = appendname(s, "left");

	if(e.buttons & IcSession->ButtonMiddle)
		s = appendname(s, "middle");

	if(e.buttons & IcSession->ButtonRight)
		s = appendname(s, "right");

	if(e.buttons & IcSession->ButtonWheelUp)
		s = appendname(s, "wheel-up");

	if(e.buttons & IcSession->ButtonWheelDown)
		s = appendname(s, "wheel-down");

	if(s == "")
		s = "none";

	return s;
}

mousemods(e: IcSession->MouseEvent): string
{
	s: string;

	s = "";

	if(e.mods & IcSession->ModShift)
		s = appendname(s, "shift");

	if(e.mods & IcSession->ModCtrl)
		s = appendname(s, "ctrl");

	if(e.mods & IcSession->ModAlt)
		s = appendname(s, "alt");

	if(s == "")
		s = "none";

	return s;
}

mousekind(e: IcSession->MouseEvent): string
{
	if(e.kind == IcSession->MouseMove)
		return "move";

	if(e.kind == IcSession->MousePress)
		return "press";

	if(e.kind == IcSession->MouseRelease)
		return "release";

	if(e.kind == IcSession->MouseDrag)
		return "drag";

	if(e.kind == IcSession->MouseWheel)
		return "wheel";

	if(e.kind == IcSession->MouseChange)
		return "change";

	return "none";
}