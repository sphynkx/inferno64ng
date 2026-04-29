include "icurses/ui.m";

IcSession: module
{
	PATH: con "/dis/lib/icurses/session.dis";

	UseKeyboard: con 1;
	UseMouse:    con 2;
	UseAll:      con UseKeyboard | UseMouse;

	StepDone:  con 0;
	StepKey:   con 1;
	StepMouse: con 2;

	ButtonNone:   con 0;
	ButtonLeft:   con 1;
	ButtonRight:  con 2;
	ButtonMiddle: con 4;

	ButtonWheelUp:   con 8;
	ButtonWheelDown: con 16;

	ButtonMask: con ButtonLeft | ButtonMiddle | ButtonRight;
	WheelMask:  con ButtonWheelUp | ButtonWheelDown;

	ModNone:  con 0;
	ModShift: con 1;
	ModCtrl:  con 2;
	ModAlt:   con 4;

	MouseNone:    con 0;
	MouseMove:    con 1;
	MousePress:   con 2;
	MouseRelease: con 3;
	MouseDrag:    con 4;
	MouseWheel:   con 5;
	MouseChange:  con 6;

	MouseEvent: adt
	{
		x:        int;
		y:        int;
		buttons:  int;
		mods:     int;

		kind:     int;
		changed:  int;
		pressed:  int;
		released: int;

		ok:       int;
		raw:      string;
	};

	Session: adt
	{
		u:        ref IcUi->Ui;
		running:  int;
		flags:    int;

		consctl:  ref Sys->FD;

		keyc:     chan of int;
		mousec:   chan of MouseEvent;
	};

	Step: adt
	{
		kind:  int;
		done:  int;

		key:   int;
		mouse: MouseEvent;
	};

	init: fn();

	open: fn(u: ref IcUi->Ui, flags: int): ref Session;
	close: fn(s: ref Session);

	step: fn(s: ref Session): Step;

	isrunning: fn(s: ref Session): int;

	mousebuttons: fn(e: MouseEvent): string;
	mousemods: fn(e: MouseEvent): string;
	mousekind: fn(e: MouseEvent): string;
};